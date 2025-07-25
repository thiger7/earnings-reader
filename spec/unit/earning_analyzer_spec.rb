require_relative '../spec_helper'
require_relative '../../app/earning_analyzer'

RSpec.describe EarningAnalyzer do
  let(:analyzer) { described_class.new }
  let(:test_date) { Date.new(2023, 12, 1) }
  let(:mock_client) { double('EdinetClient') }
  let(:sample_documents) { sample_edinet_response }
  let(:sample_earning_docs) { sample_documents['results'] }

  before do
    # モックオブジェクトをセット
    allow(EdinetClient).to receive(:new).and_return(mock_client)

    # テスト用のディレクトリ構造を作成
    analyzer.instance_variable_set(:@data_dir, './spec/test_data')
    FileUtils.mkdir_p('./spec/test_data/json')
    FileUtils.mkdir_p('./spec/test_data/pdf')
    FileUtils.mkdir_p('./spec/test_data/xbrl')
  end

  describe '#initialize' do
    it 'インスタンスが正常に作成される' do
      expect(analyzer).to be_an_instance_of(described_class)
    end

    it 'EdinetClientインスタンスが作成される' do
      expect(EdinetClient).to have_received(:new)
    end

    it '必要なディレクトリが作成される' do
      new_analyzer = described_class.new
      data_dir = new_analyzer.instance_variable_get(:@data_dir)

      expect(Dir.exist?(data_dir)).to be true
      expect(Dir.exist?("#{data_dir}/json")).to be true
      expect(Dir.exist?("#{data_dir}/pdf")).to be true
      expect(Dir.exist?("#{data_dir}/xbrl")).to be true
    end
  end

  describe '#analyze_earning_reports' do
    context '正常なケース' do
      before do
        # モック設定
        allow(mock_client).to receive(:fetch_documents).with(test_date).and_return(sample_documents)
        allow(mock_client).to receive(:filter_earning_reports).with(sample_documents).and_return(sample_earning_docs)

        # process_documentのモック
        allow(analyzer).to receive(:process_document).and_return({
                                                                   company_info: {
                                                                     name: 'テスト株式会社',
                                                                     sec_code: '12340',
                                                                     doc_id: 'S100TEST'
                                                                   },
                                                                   financial_data: {
                                                                     current_period: { revenue: 50_000_000_000 }
                                                                   },
                                                                   analysis: { growth: { level: '高成長', comment: '売上高成長率 11.11%' } }
                                                                 })

        allow(analyzer).to receive(:display_summary)
        allow(analyzer).to receive(:save_results)
        allow(analyzer).to receive(:sleep) # sleepをモック化
      end

      it '分析が正常に実行される' do
        expect { analyzer.analyze_earning_reports(test_date) }.to output(/決算短信分析システム/).to_stdout

        expect(mock_client).to have_received(:fetch_documents).with(test_date)
        expect(mock_client).to have_received(:filter_earning_reports).with(sample_documents)
      end

      it 'process_documentが各書類に対して呼ばれる' do
        analyzer.analyze_earning_reports(test_date)

        expect(analyzer).to have_received(:process_document).exactly(sample_earning_docs.length).times
      end

      it 'display_summaryが呼ばれる' do
        analyzer.analyze_earning_reports(test_date)
        expect(analyzer).to have_received(:display_summary)
      end

      it 'save_resultsが呼ばれる' do
        analyzer.analyze_earning_reports(test_date)
        expect(analyzer).to have_received(:save_results)
      end
    end

    context 'API呼び出しが失敗する場合' do
      before do
        allow(mock_client).to receive(:fetch_documents).with(test_date).and_return(nil)
      end

      it 'エラーメッセージが表示されて処理が終了する' do
        expect { analyzer.analyze_earning_reports(test_date) }.to output(/書類の取得に失敗しました/).to_stdout
      end
    end

    context '決算短信が0件の場合' do
      before do
        allow(mock_client).to receive(:fetch_documents).with(test_date).and_return(sample_documents)
        allow(mock_client).to receive(:filter_earning_reports).with(sample_documents).and_return([])
        allow(analyzer).to receive(:display_summary)
        allow(analyzer).to receive(:save_results)
      end

      it '決算短信数0と表示される' do
        expect { analyzer.analyze_earning_reports(test_date) }.to output(/決算短信数: 0/).to_stdout
      end
    end
  end

  describe '#process_document (private)' do
    let(:sample_doc) do
      {
        'docID' => 'S100TEST',
        'secCode' => '12340',
        'filerName' => 'テスト株式会社',
        'submitDateTime' => '2023-12-01 15:00:00',
        'docDescription' => '第2四半期決算短信'
      }
    end

    let(:sample_financial_data) do
      {
        current_period: {
          revenue: 50_000_000_000,
          operating_profit: 5_000_000_000,
          revenue_growth: 11.11,
          operating_profit_margin: 10.0,
          roe: 12.5
        },
        previous_period: {},
        forecast: {}
      }
    end

    before do
      # XBRLダウンロードとパース処理をモック
      allow(mock_client).to receive(:download_xbrl).and_return(true)
      allow(File).to receive(:exist?).and_return(false) # 最初は存在しない

      mock_parser = double('XbrlParser')
      allow(XbrlParser).to receive(:new).and_return(mock_parser)
      allow(mock_parser).to receive(:parse_from_zip).and_return(sample_financial_data)
    end

    it '書類が正常に処理される' do
      result = analyzer.send(:process_document, sample_doc)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:company_info)
      expect(result).to have_key(:financial_data)
      expect(result).to have_key(:analysis)

      expect(result[:company_info][:name]).to eq('テスト株式会社')
      expect(result[:company_info][:sec_code]).to eq('12340')
    end

    it 'XBRLダウンロードが呼ばれる' do
      analyzer.send(:process_document, sample_doc)
      expect(mock_client).to have_received(:download_xbrl).with('S100TEST', 'xbrl/12340_S100TEST.xbrl')
    end

    context 'XBRLダウンロードが失敗する場合' do
      before do
        allow(mock_client).to receive(:download_xbrl).and_return(false)
      end

      it 'nilが返される' do
        result = analyzer.send(:process_document, sample_doc)
        expect(result).to be_nil
      end

      it 'エラーメッセージが出力される' do
        expect { analyzer.send(:process_document, sample_doc) }.to output(/XBRLダウンロード失敗/).to_stdout
      end
    end

    context 'XBRL解析が失敗する場合' do
      before do
        mock_parser = double('XbrlParser')
        allow(XbrlParser).to receive(:new).and_return(mock_parser)
        allow(mock_parser).to receive(:parse_from_zip).and_return(nil)
      end

      it 'nilが返される' do
        result = analyzer.send(:process_document, sample_doc)
        expect(result).to be_nil
      end

      it 'エラーメッセージが出力される' do
        expect { analyzer.send(:process_document, sample_doc) }.to output(/データ抽出失敗/).to_stdout
      end
    end

    context '例外が発生する場合' do
      before do
        allow(mock_client).to receive(:download_xbrl).and_raise(StandardError.new('Network error'))
      end

      it 'nilが返される' do
        result = analyzer.send(:process_document, sample_doc)
        expect(result).to be_nil
      end

      it 'エラーメッセージが出力される' do
        expect { analyzer.send(:process_document, sample_doc) }.to output(/エラー: Network error/).to_stdout
      end
    end
  end

  describe '#perform_analysis (private)' do
    context '成長率データがある場合' do
      let(:data_with_growth) { { revenue_growth: 15.0 } }

      it '高成長と判定される' do
        result = analyzer.send(:perform_analysis, data_with_growth)
        expect(result[:growth][:level]).to eq('高成長')
        expect(result[:growth][:comment]).to include('15.0%')
      end
    end

    context '成長率が低い場合' do
      let(:data_with_low_growth) { { revenue_growth: 5.0 } }

      it '安定成長と判定される' do
        result = analyzer.send(:perform_analysis, data_with_low_growth)
        expect(result[:growth][:level]).to eq('安定成長')
      end
    end

    context 'マイナス成長の場合' do
      let(:data_with_negative_growth) { { revenue_growth: -5.0 } }

      it '減収と判定される' do
        result = analyzer.send(:perform_analysis, data_with_negative_growth)
        expect(result[:growth][:level]).to eq('減収')
      end
    end

    context '営業利益率データがある場合' do
      let(:data_with_margin) { { operating_profit_margin: 20.0 } }

      it '高収益と判定される' do
        result = analyzer.send(:perform_analysis, data_with_margin)
        expect(result[:profitability][:level]).to eq('高収益')
        expect(result[:profitability][:comment]).to include('20.0%')
      end
    end

    context 'ROEデータがある場合' do
      let(:data_with_roe) { { roe: 18.0 } }

      it '優良と判定される' do
        result = analyzer.send(:perform_analysis, data_with_roe)
        expect(result[:roe][:level]).to eq('優良')
        expect(result[:roe][:comment]).to include('18.0%')
      end
    end

    context 'データがない場合' do
      let(:empty_data) { {} }

      it '空のハッシュが返される' do
        result = analyzer.send(:perform_analysis, empty_data)
        expect(result).to eq({})
      end
    end
  end

  describe '#save_results (private)' do
    let(:sample_results) do
      [
        {
          company_info: { name: 'テスト株式会社', sec_code: '12340' },
          financial_data: { current_period: { revenue: 50_000_000_000 } },
          analysis: { growth: { level: '高成長' } }
        }
      ]
    end

    it 'JSONファイルが保存される' do
      analyzer.send(:save_results, sample_results, test_date)

      expected_filename = "./spec/test_data/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
      expect(File.exist?(expected_filename)).to be true

      saved_data = JSON.parse(File.read(expected_filename))
      expect(saved_data['total_count']).to eq(1)
      expect(saved_data['results']).to be_an(Array)
    end

    it '保存成功メッセージが出力される' do
      expected_filename = "./spec/test_data/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
      expect { analyzer.send(:save_results, sample_results, test_date) }.to output(/結果を保存しました: #{expected_filename}/).to_stdout
    end
  end

  describe '#display_summary (private)' do
    let(:sample_results) do
      [
        {
          company_info: {
            name: 'テスト株式会社',
            sec_code: '12340',
            doc_description: '第2四半期決算短信'
          },
          financial_data: {
            current_period: {
              revenue: 50_000_000_000,
              operating_profit: 5_000_000_000,
              net_profit: 3_000_000_000
            }
          },
          analysis: {
            growth: { level: '高成長', comment: '売上高成長率 11.11%' },
            profitability: { level: '標準的', comment: '営業利益率 10.0%' }
          }
        }
      ]
    end

    it 'サマリーが正しく表示される' do
      output = capture_stdout { analyzer.send(:display_summary, sample_results) }

      expect(output).to include('分析結果サマリー')
      expect(output).to include('テスト株式会社')
      expect(output).to include('12340')
      expect(output).to include('第2四半期決算短信')
      expect(output).to include('高成長')
      expect(output).to include('標準的')
    end
  end

  # テストヘルパーメソッド
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end

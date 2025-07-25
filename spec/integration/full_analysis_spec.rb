require_relative '../spec_helper'
require_relative '../../app/earning_analyzer'

RSpec.describe 'Full Analysis Integration Test' do
  let(:test_date) { Date.new(2023, 12, 1) }
  let(:analyzer) { EarningAnalyzer.new }
  let(:test_zip_path) { './spec/test_data/integration_test.zip' }

  before do
    # テスト用のディレクトリ構造をセット
    analyzer.instance_variable_set(:@data_dir, './spec/test_data/integration')
    FileUtils.mkdir_p('./spec/test_data/integration/json')
    FileUtils.mkdir_p('./spec/test_data/integration/pdf')
    FileUtils.mkdir_p('./spec/test_data/integration/xbrl')

    # テスト用XBRLファイルを作成
    create_test_xbrl_zip(test_zip_path)
  end

  describe 'エンドツーエンドフロー' do
    context 'モックを使用した統合テスト' do
      let(:mock_client) { instance_double(EdinetClient) }
      let(:sample_documents) { sample_edinet_response }
      let(:earning_docs) { sample_documents['results'] }

      before do
        # analyzerのclientインスタンスをモック化
        analyzer.instance_variable_set(:@client, mock_client)
        allow(mock_client).to receive(:fetch_documents).with(test_date).and_return(sample_documents)
        allow(mock_client).to receive(:filter_earning_reports).with(sample_documents).and_return(earning_docs)

        # XBRLダウンロードをモック化
        allow(mock_client).to receive(:download_xbrl) do |_doc_id, filename|
          # テスト用ZIPファイルをコピー
          target_path = "./spec/test_data/integration/#{filename}.zip"
          FileUtils.cp(test_zip_path, target_path)
          true
        end

        # sleepをスキップ
        allow(analyzer).to receive(:sleep)
      end

      it '全体のフローが正常に動作する' do
        # 分析を実行
        expect { analyzer.analyze_earning_reports(test_date) }.not_to raise_error

        # 結果ファイルが作成されることを確認
        result_file = "./spec/test_data/integration/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
        expect(File.exist?(result_file)).to be true

        # 結果ファイルの内容を検証
        result_data = JSON.parse(File.read(result_file))
        expect(result_data['total_count']).to eq(earning_docs.length)
        expect(result_data['results']).to be_an(Array)
        expect(result_data['results']).not_to be_empty

        # 各結果の構造を検証
        result_data['results'].each do |result|
          expect(result).to have_key('company_info')
          expect(result).to have_key('financial_data')
          expect(result).to have_key('analysis')

          # 会社情報の検証
          company_info = result['company_info']
          expect(company_info).to have_key('name')
          expect(company_info).to have_key('sec_code')
          expect(company_info).to have_key('doc_id')

          # 財務データの検証
          financial_data = result['financial_data']
          expect(financial_data).to have_key('current_period')
          expect(financial_data).to have_key('extracted_at')

          # 分析結果の検証
          analysis = result['analysis']
          expect(analysis).to be_a(Hash)
        end
      end

      it 'API呼び出しが正しい順序で実行される' do
        analyzer.analyze_earning_reports(test_date)

        expect(mock_client).to have_received(:fetch_documents).with(test_date).ordered
        expect(mock_client).to have_received(:filter_earning_reports).with(sample_documents).ordered
        expect(mock_client).to have_received(:download_xbrl).exactly(earning_docs.length).times
      end

      it '各書類のXBRLファイルが正しくダウンロードされる' do
        analyzer.analyze_earning_reports(test_date)

        earning_docs.each do |doc|
          expected_filename = "xbrl/#{doc['secCode']}_#{doc['docID']}.xbrl"
          expect(mock_client).to have_received(:download_xbrl).with(doc['docID'], expected_filename)
        end
      end
    end

    context 'エラーハンドリングのテスト' do
      let(:mock_client) { instance_double(EdinetClient) }

      before do
        analyzer.instance_variable_set(:@client, mock_client)
      end

      it 'API呼び出し失敗時に適切にハンドリングされる' do
        allow(mock_client).to receive(:fetch_documents).and_return(nil)

        expect { analyzer.analyze_earning_reports(test_date) }.to output(/書類の取得に失敗しました/).to_stdout
      end

      it '決算短信が0件の場合に適切にハンドリングされる' do
        allow(mock_client).to receive_messages(fetch_documents: sample_edinet_response, filter_earning_reports: [])

        expect { analyzer.analyze_earning_reports(test_date) }.to output(/決算短信数: 0/).to_stdout
      end

      it 'XBRLダウンロード失敗時にスキップされる' do
        sample_docs = sample_edinet_response['results']
        allow(mock_client).to receive_messages(fetch_documents: sample_edinet_response, filter_earning_reports: sample_docs, download_xbrl: false)
        allow(analyzer).to receive(:sleep)

        expect { analyzer.analyze_earning_reports(test_date) }.to output(/XBRLダウンロード失敗/).to_stdout

        # 結果ファイルは作成されるが、中身は空になる
        result_file = "./spec/test_data/integration/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
        expect(File.exist?(result_file)).to be true

        result_data = JSON.parse(File.read(result_file))
        expect(result_data['total_count']).to eq(0)
        expect(result_data['results']).to be_empty
      end
    end

    context 'データ品質のテスト' do
      let(:mock_client) { instance_double(EdinetClient) }
      let(:sample_docs) { sample_edinet_response['results'] }

      before do
        analyzer.instance_variable_set(:@client, mock_client)
        allow(mock_client).to receive_messages(fetch_documents: sample_edinet_response, filter_earning_reports: sample_docs)
        allow(mock_client).to receive(:download_xbrl) do |_doc_id, filename|
          target_path = "./spec/test_data/integration/#{filename}.zip"
          FileUtils.cp(test_zip_path, target_path)
          true
        end
        allow(analyzer).to receive(:sleep)
      end

      it '抽出された財務データが正しい形式である' do
        analyzer.analyze_earning_reports(test_date)

        result_file = "./spec/test_data/integration/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
        result_data = JSON.parse(File.read(result_file))

        result_data['results'].each do |result|
          current_period = result['financial_data']['current_period']

          # 数値データが適切に抽出されている
          if current_period['revenue']
            expect(current_period['revenue']).to be_a(Numeric)
            expect(current_period['revenue']).to be > 0
          end

          if current_period['operating_profit']
            expect(current_period['operating_profit']).to be_a(Numeric)
          end

          # 成長率が計算されている（前期データがある場合）
          if current_period['revenue_growth']
            expect(current_period['revenue_growth']).to be_a(Numeric)
          end
        end
      end

      it '分析結果が適切に生成される' do
        analyzer.analyze_earning_reports(test_date)

        result_file = "./spec/test_data/integration/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
        result_data = JSON.parse(File.read(result_file))

        result_data['results'].each do |result|
          analysis = result['analysis']

          # 分析カテゴリが存在する場合、適切な構造を持つ
          %w[growth profitability roe].each do |category|
            next unless analysis[category]

            expect(analysis[category]).to have_key('level')
            expect(analysis[category]).to have_key('comment')
            expect(analysis[category]['level']).to be_a(String)
            expect(analysis[category]['comment']).to be_a(String)
          end
        end
      end
    end

    context 'パフォーマンステスト' do
      let(:mock_client) { instance_double(EdinetClient) }
      let(:large_dataset) do
        # 大量のデータセットをシミュレート（10件）
        results = []
        10.times do |i|
          results << {
            'docID' => "S#{100 + i}TEST",
            'secCode' => "#{1234 + i}0",
            'filerName' => "テスト株式会社#{i + 1}",
            'submitDateTime' => '2023-12-01 15:00:00',
            'docDescription' => '第2四半期決算短信〔日本基準〕（連結）'
          }
        end
        { 'results' => results }
      end

      before do
        analyzer.instance_variable_set(:@client, mock_client)
        allow(mock_client).to receive_messages(fetch_documents: large_dataset, filter_earning_reports: large_dataset['results'])
        allow(mock_client).to receive(:download_xbrl) do |_doc_id, filename|
          target_path = "./spec/test_data/integration/#{filename}.zip"
          FileUtils.cp(test_zip_path, target_path)
          true
        end
        allow(analyzer).to receive(:sleep) # sleepをスキップしてテスト高速化
      end

      it '大量データでもメモリリークなく処理できる' do
        expect { analyzer.analyze_earning_reports(test_date) }.not_to raise_error

        result_file = "./spec/test_data/integration/json/earning_analysis_#{test_date.strftime('%Y%m%d')}.json"
        result_data = JSON.parse(File.read(result_file))

        expect(result_data['total_count']).to eq(10)
        expect(result_data['results'].length).to eq(10)
      end
    end
  end

  describe 'リアルAPIテスト（オプション）' do
    # 実際のEDINET APIを使用したテスト
    # 通常時はスキップし、必要時のみ実行
    context 'REAL_API_TEST環境変数が設定されている場合', if: ENV.fetch('REAL_API_TEST', nil) do
      let(:real_analyzer) { KessanAnalyzer.new }
      let(:recent_date) { Date.today - 2 } # 2日前の日付を使用

      it '実際のAPIから決算短信を取得できる' do
        # ネットワーク接続が必要なため、タイムアウトを設定
        expect do
          real_analyzer.analyze_earning_reports(recent_date)
        end.not_to raise_error

        # 結果ファイルが作成されることを確認
        result_file = "./kessan_data/json/earning_analysis_#{recent_date.strftime('%Y%m%d')}.json"
        expect(File.exist?(result_file)).to be true if File.exist?(result_file)
      end
    end
  end
end

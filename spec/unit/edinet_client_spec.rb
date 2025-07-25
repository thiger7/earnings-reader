require_relative '../spec_helper'
require_relative '../../app/edinet_client'

RSpec.describe EdinetClient do
  let(:client) { described_class.new }
  let(:test_date) { Date.new(2023, 12, 1) }
  let(:sample_response) { sample_edinet_response }

  let(:mock_faraday_client) { double('Faraday::Connection') }

  before do
    # テスト用ディレクトリをセットアップ
    @original_output_dir = client.instance_variable_get(:@output_dir)
    client.instance_variable_set(:@output_dir, './spec/test_data')

    # Faradayクライアントをモック化
    client.instance_variable_set(:@client, mock_faraday_client)
  end

  after do
    # 元のディレクトリに戻す
    client.instance_variable_set(:@output_dir, @original_output_dir)
  end

  describe '#initialize' do
    it 'インスタンスが正常に作成される' do
      expect(client).to be_instance_of(described_class)
    end

    it '出力ディレクトリが作成される' do
      new_client = described_class.new
      output_dir = new_client.instance_variable_get(:@output_dir)
      expect(Dir.exist?(output_dir)).to be true
    end
  end

  describe '#fetch_documents' do
    context 'API呼び出しが成功する場合' do
      before do
        response_body = sample_response.to_json
        mock_response = mock_faraday_response(200, response_body)
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it '書類一覧が正常に取得される' do
        result = client.fetch_documents(test_date)

        expect(result).to be_a(Hash)
        expect(result).to have_key('results')
        expect(result['results']).to be_an(Array)
        expect(result['results'].length).to eq(2)
      end

      it '正しいAPIエンドポイントが呼ばれる' do
        expected_params = {
          date: test_date.strftime('%Y-%m-%d'),
          type: 1
        }
        # テスト環境ではsettingsから自動設定されたAPIキーが使用される
        expected_headers = { 'Ocp-Apim-Subscription-Key' => 'test_api_key_for_rspec' }

        expect(mock_faraday_client).to receive(:get).with('/api/v2/documents.json', expected_params, expected_headers)
        client.fetch_documents(test_date)
      end
    end

    context 'API呼び出しが失敗する場合' do
      before do
        mock_response = mock_faraday_response(404, 'Not Found', 'Not Found')
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it 'nilが返される' do
        result = client.fetch_documents(test_date)
        expect(result).to be_nil
      end

      it 'エラーメッセージが出力される' do
        expect { client.fetch_documents(test_date) }.to output(/Error: 404/).to_stdout
      end
    end
  end

  describe '#filter_earning_reports' do
    context '有効な書類データが渡される場合' do
      it '決算短信のみがフィルタリングされる' do
        documents = sample_response
        result = client.filter_earning_reports(documents)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        result.each do |doc|
          expect(doc['docDescription']).to include('決算短信')
        end
      end
    end

    context '決算短信が含まれていない場合' do
      let(:non_earning_response) do
        {
          'results' => [
            {
              'docID' => 'S300TEST',
              'filerName' => 'テスト株式会社',
              'docDescription' => '有価証券報告書'
            }
          ]
        }
      end

      it '空の配列が返される' do
        result = client.filter_earning_reports(non_earning_response)
        expect(result).to eq([])
      end
    end

    context 'nilが渡される場合' do
      it '空の配列が返される' do
        result = client.filter_earning_reports(nil)
        expect(result).to eq([])
      end
    end

    context 'resultsキーがない場合' do
      it '空の配列が返される' do
        result = client.filter_earning_reports({})
        expect(result).to eq([])
      end
    end
  end

  describe '#download_document' do
    let(:doc_id) { 'S100TEST' }
    let(:filename) { 'test_document.pdf' }
    let(:pdf_content) { 'dummy pdf content' }

    context 'ダウンロードが成功する場合' do
      before do
        mock_response = mock_faraday_response(200, pdf_content)
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it 'ファイルが正常にダウンロードされる' do
        result = client.download_document(doc_id, filename)

        expect(result).to be true
        expect(File.exist?("./spec/test_data/#{filename}")).to be true
        expect(File.read("./spec/test_data/#{filename}")).to eq(pdf_content)
      end

      it 'ダウンロード成功メッセージが出力される' do
        expect { client.download_document(doc_id, filename) }.to output(/Downloaded: #{filename}/).to_stdout
      end
    end

    context 'ダウンロードが失敗する場合' do
      before do
        mock_response = mock_faraday_response(404, 'Not Found', 'Not Found')
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it 'falseが返される' do
        result = client.download_document(doc_id, filename)
        expect(result).to be false
      end

      it 'ダウンロード失敗メッセージが出力される' do
        expect { client.download_document(doc_id, filename) }.to output(/PDF download failed: 404/).to_stdout
      end
    end
  end

  describe '#download_xbrl' do
    let(:doc_id) { 'S100TEST' }
    let(:filename) { 'test_xbrl' }
    let(:xbrl_content) { 'dummy xbrl zip content' }

    context 'XBRLダウンロードが成功する場合' do
      before do
        mock_response = mock_faraday_response(200, xbrl_content)
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it 'XBRLファイルが正常にダウンロードされる' do
        result = client.download_xbrl(doc_id, filename)

        expect(result).to be true
        expect(File.exist?("./spec/test_data/#{filename}.zip")).to be true
        expect(File.read("./spec/test_data/#{filename}.zip")).to eq(xbrl_content)
      end

      it '正しいAPIパラメータでリクエストされる' do
        expected_params = { type: 2 }
        expected_headers = { 'Ocp-Apim-Subscription-Key' => 'test_api_key_for_rspec' }

        expect(mock_faraday_client).to receive(:get).with("/api/v2/documents/#{doc_id}", expected_params, expected_headers)
        client.download_xbrl(doc_id, filename)
      end
    end

    context 'XBRLダウンロードが失敗する場合' do
      before do
        mock_response = mock_faraday_response(500, 'Internal Server Error', 'Internal Server Error')
        allow(mock_faraday_client).to receive(:get).and_return(mock_response)
      end

      it 'falseが返される' do
        result = client.download_xbrl(doc_id, filename)
        expect(result).to be false
      end

      it 'エラーメッセージが出力される' do
        expect { client.download_xbrl(doc_id, filename) }.to output(/XBRL download failed: 500/).to_stdout
      end
    end
  end
end

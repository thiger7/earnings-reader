require 'rspec'
require 'json'
require 'date'
require 'faraday'
require 'fileutils'
require 'stringio'

# テストヘルパー関数を定義
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # フォーマッター設定
  config.default_formatter = 'doc' if config.files_to_run.one?

  # テスト前後の処理
  config.before do
    # テスト用のディレクトリを作成
    @test_data_dir = './spec/test_data'
    FileUtils.mkdir_p(@test_data_dir)
  end

  config.after do
    # テスト後のクリーンアップ
    FileUtils.rm_rf(@test_data_dir)
  end
end

# モック用のヘルパーメソッド
def mock_faraday_response(status_code, body, reason_phrase = 'OK', content_type = 'application/json')
  response = double('response')
  headers = { 'content-type' => content_type }

  allow(response).to receive_messages(status: status_code, body: body, success?: status_code == 200, reason_phrase: reason_phrase, headers: headers)
  response
end

# EDINET API レスポンスのサンプルデータ
def sample_edinet_response
  {
    'metadata' => {
      'title' => '金融庁 EDINET API',
      'parameter' => {
        'date' => '2023-12-01',
        'type' => '2'
      }
    },
    'results' => [
      {
        'seqNumber' => 1,
        'docID' => 'S100TEST',
        'edinetCode' => 'E12345',
        'secCode' => '12340',
        'JCN' => '1234567890123',
        'filerName' => 'テスト株式会社',
        'fundCode' => nil,
        'ordinanceCode' => '010',
        'formCode' => '030000',
        'docTypeCode' => '120',
        'periodStart' => '2023-04-01',
        'periodEnd' => '2023-09-30',
        'submitDateTime' => '2023-12-01 15:00:00',
        'docDescription' => '第2四半期決算短信〔日本基準〕（連結）',
        'issuerEdinetCode' => nil,
        'subjectEdinetCode' => nil,
        'subsidiaryEdinetCode' => nil,
        'currentReportReason' => nil,
        'parentDocID' => nil,
        'opeDateTime' => '2023-12-01 15:05:00',
        'withdrawalStatus' => '0',
        'docInfoEditStatus' => '0',
        'disclosureStatus' => '0',
        'xbrlFlag' => '1',
        'pdfFlag' => '1',
        'attachDocFlag' => '0',
        'englishDocFlag' => '0'
      },
      {
        'seqNumber' => 2,
        'docID' => 'S200TEST',
        'edinetCode' => 'E67890',
        'secCode' => '67890',
        'JCN' => '9876543210987',
        'filerName' => 'サンプル株式会社',
        'fundCode' => nil,
        'ordinanceCode' => '010',
        'formCode' => '030000',
        'docTypeCode' => '120',
        'periodStart' => '2023-01-01',
        'periodEnd' => '2023-12-31',
        'submitDateTime' => '2023-12-01 16:00:00',
        'docDescription' => '決算短信〔日本基準〕（連結）',
        'issuerEdinetCode' => nil,
        'subjectEdinetCode' => nil,
        'subsidiaryEdinetCode' => nil,
        'currentReportReason' => nil,
        'parentDocID' => nil,
        'opeDateTime' => '2023-12-01 16:05:00',
        'withdrawalStatus' => '0',
        'docInfoEditStatus' => '0',
        'disclosureStatus' => '0',
        'xbrlFlag' => '1',
        'pdfFlag' => '1',
        'attachDocFlag' => '0',
        'englishDocFlag' => '0'
      }
    ]
  }
end

# サンプルXBRLコンテンツを生成
def sample_xbrl_content
  <<~XBRL
    <?xml version="1.0" encoding="UTF-8"?>
    <xbrl xmlns="http://www.xbrl.org/2003/instance"#{' '}
          xmlns:xbrli="http://www.xbrl.org/2003/instance"
          xmlns:jpcrp="http://disclosure.edinet-fsa.go.jp/taxonomy/jpcrp/2020-02-28"
          xmlns:link="http://www.xbrl.org/2003/linkbase"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          xmlns:iso4217="http://www.xbrl.org/2003/iso4217">
    #{'  '}
      <xbrli:context id="CurrentYearInstant">
        <xbrli:entity>
          <xbrli:identifier scheme="http://disclosure.edinet-fsa.go.jp">E12345</xbrli:identifier>
        </xbrli:entity>
        <xbrli:period>
          <xbrli:instant>2023-09-30</xbrli:instant>
        </xbrli:period>
      </xbrli:context>
    #{'  '}
      <xbrli:context id="CurrentYearDuration">
        <xbrli:entity>
          <xbrli:identifier scheme="http://disclosure.edinet-fsa.go.jp">E12345</xbrli:identifier>
        </xbrli:entity>
        <xbrli:period>
          <xbrli:startDate>2023-04-01</xbrli:startDate>
          <xbrli:endDate>2023-09-30</xbrli:endDate>
        </xbrli:period>
      </xbrli:context>

      <xbrli:context id="PreviousYearDuration">
        <xbrli:entity>
          <xbrli:identifier scheme="http://disclosure.edinet-fsa.go.jp">E12345</xbrli:identifier>
        </xbrli:entity>
        <xbrli:period>
          <xbrli:startDate>2022-04-01</xbrli:startDate>
          <xbrli:endDate>2022-09-30</xbrli:endDate>
        </xbrli:period>
      </xbrli:context>

      <xbrli:unit id="JPY">
        <isoMeasure:measure xmlns:isoMeasure="http://www.xbrl.org/2003/iso4217">JPY</isoMeasure:measure>
      </xbrli:unit>

      <!-- 売上高 -->
      <jpcrp:NetSales contextRef="CurrentYearDuration" unitRef="JPY" scale="6">50000</jpcrp:NetSales>
      <jpcrp:NetSales contextRef="PreviousYearDuration" unitRef="JPY" scale="6">45000</jpcrp:NetSales>

      <!-- 営業利益 -->#{'  '}
      <jpcrp:OperatingProfit contextRef="CurrentYearDuration" unitRef="JPY" scale="6">5000</jpcrp:OperatingProfit>
      <jpcrp:OperatingProfit contextRef="PreviousYearDuration" unitRef="JPY" scale="6">4500</jpcrp:OperatingProfit>

      <!-- 当期純利益 -->
      <jpcrp:NetIncome contextRef="CurrentYearDuration" unitRef="JPY" scale="6">3000</jpcrp:NetIncome>
      <jpcrp:NetIncome contextRef="PreviousYearDuration" unitRef="JPY" scale="6">2800</jpcrp:NetIncome>

      <!-- EPS -->
      <jpcrp:EarningsPerShare contextRef="CurrentYearDuration" unitRef="JPY">300</jpcrp:EarningsPerShare>

      <!-- ROE -->
      <jpcrp:ReturnOnEquity contextRef="CurrentYearDuration" unitRef="percent">12.5</jpcrp:ReturnOnEquity>

    </xbrl>
  XBRL
end

# ZIP形式のテストファイルを作成するヘルパー
def create_test_xbrl_zip(path)
  require 'zip'

  Zip::File.open(path, Zip::File::CREATE) do |zipfile|
    zipfile.get_output_stream('PublicDoc/test.xbrl') { |f| f.write(sample_xbrl_content) }
  end
end

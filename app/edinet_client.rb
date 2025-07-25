#!/usr/bin/env ruby
require 'dotenv/load'
require_relative '../config/settings'
require 'faraday'
require 'faraday/follow_redirects'
require 'json'
require 'date'
require 'fileutils'

class EdinetClient
  def initialize
    @output_dir = './edinet_data'
    @api_key = Settings.edinet.api_key
    @base_url = Settings.edinet.base_url
    FileUtils.mkdir_p(@output_dir)

    unless @api_key
      puts '警告: EDINET APIキーが設定されていません'
      puts 'EDINET APIキーを取得して設定してください'
    end

    @client = Faraday.new(url: @base_url) do |config|
      config.adapter :net_http
      config.headers['User-Agent'] = 'EdinetClient/1.0'
      config.headers['Accept'] = 'application/json'
    end
  end

  def fetch_documents(date)
    params = build_documents_params(date)
    headers = build_api_headers

    response = @client.get('/api/v2/documents.json', params, headers)
    process_api_response(response)
  rescue Faraday::Error => e
    puts "Network Error: #{e.message}"
    nil
  end

  private

  def build_documents_params(date)
    {
      date: date.strftime('%Y-%m-%d'),
      type: 1 # 書類一覧を取得
    }
  end

  def build_api_headers
    headers = {}
    headers['Ocp-Apim-Subscription-Key'] = @api_key if @api_key
    headers
  end

  def process_api_response(response)
    return parse_successful_response(response) if response.success?

    handle_error_response(response)
    nil
  end

  def parse_successful_response(response)
    return JSON.parse(response.body) if response.body.start_with?('{')

    puts 'Error: JSONではないレスポンスが返されました'
    puts "Content-Type: #{response.headers['content-type']}"
    puts "Body preview: #{response.body[0..200]}"
    nil
  end

  def handle_error_response(response)
    puts "Error: #{response.status} - #{response.reason_phrase}"
    handle_auth_error(response) if response.status == 401
  end

  def handle_auth_error(response)
    content_type = response.headers['content-type']
    return unless content_type&.include?('application/json')

    error_data = parse_error_json(response.body)
    puts "API認証エラー: #{error_data['message']}" if error_data
    puts 'EDINET APIキーが必要です。APIキーを取得して環境変数EDINET_API_KEYに設定してください。'
  end

  def parse_error_json(body)
    JSON.parse(body)
  rescue StandardError
    nil
  end

  public

  def filter_kessan_tanshin(documents)
    return [] unless documents && documents['results']

    documents['results'].select do |doc|
      doc['docDescription'] &&
        (doc['docDescription'].include?('決算短信') ||
         doc['docDescription'].include?('四半期決算短信'))
    end
  end

  def download_document(doc_id, filename)
    download_file(doc_id, filename, type: 1, format: 'pdf')
  end

  def download_xbrl(doc_id, filename)
    download_file(doc_id, "#{filename}.zip", type: 2, format: 'xbrl')
  end

  private

  def download_file(doc_id, filename, type:, format:)
    params = { type: type }
    headers = build_api_headers

    response = @client.get("/api/v2/documents/#{doc_id}", params, headers)
    process_download_response(response, filename, format)
  rescue Faraday::Error => e
    puts "#{format.upcase} download error: #{e.message}"
    false
  end

  def process_download_response(response, filename, format)
    if response.success?
      save_downloaded_file(filename, response.body, format)
      true
    else
      puts "#{format.upcase} download failed: #{response.status}"
      false
    end
  end

  def save_downloaded_file(filename, content, format)
    safe_filename = sanitize_filename(filename)
    file_path = File.join(@output_dir, safe_filename)
    File.binwrite(file_path, content)
    case format
    when 'xbrl'
      puts "Downloaded XBRL: #{safe_filename}"
    else
      puts "Downloaded: #{safe_filename}"
    end
  end

  def sanitize_filename(filename)
    basename = File.basename(filename)
    basename.gsub(/[^\w\.\-]/, '_')
  end

end

if __FILE__ == $PROGRAM_NAME
  client = EdinetClient.new

  target_date = Date.new(2024, 12, 27)
  puts "Fetching documents for: #{target_date}"

  documents = client.fetch_documents(target_date)
  if documents
    kessan_docs = client.filter_kessan_tanshin(documents)

    puts "\n決算短信の数: #{kessan_docs.length}"

    kessan_docs.first(3).each_with_index do |doc, index|
      puts "\n--- Document #{index + 1} ---"
      puts "企業名: #{doc['filerName']}"
      puts "書類名: #{doc['docDescription']}"
      puts "証券コード: #{doc['secCode']}"
      puts "提出日時: #{doc['submitDateTime']}"
      puts "書類ID: #{doc['docID']}"

    end
  end
end

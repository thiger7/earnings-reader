#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'edinet_client'
require_relative 'xbrl_parser'
require_relative 'financial_metrics'
require 'json'
require 'fileutils'

class KessanAnalyzer
  def initialize
    @client = EdinetClient.new
    @data_dir = './kessan_data'
    FileUtils.mkdir_p(@data_dir)
    FileUtils.mkdir_p("#{@data_dir}/json")
    FileUtils.mkdir_p("#{@data_dir}/pdf")
    FileUtils.mkdir_p("#{@data_dir}/xbrl")
  end

  def analyze_kessan_tanshin(date = Date.today - 1)
    puts '=== 決算短信分析システム ==='
    puts "対象日付: #{date}"
    puts '=' * 50

    documents = @client.fetch_documents(date)
    unless documents
      puts '書類の取得に失敗しました'
      return
    end

    kessan_docs = @client.filter_kessan_tanshin(documents)
    puts "\n決算短信数: #{kessan_docs.length}"

    results = []
    kessan_docs.each_with_index do |doc, index|
      puts "\n[#{index + 1}/#{kessan_docs.length}] 処理中: #{doc['filerName']} (#{doc['secCode']})"

      result = process_document(doc)
      results << result if result

      sleep(1)
    end

    display_summary(results)

    save_results(results, date)
  end

  private

  def process_document(doc)
    xbrl_path = download_xbrl_file(doc)
    return nil unless xbrl_path

    financial_data = extract_financial_data(xbrl_path)
    return nil unless financial_data&.dig(:current_period)

    build_analysis_result(doc, financial_data)
  rescue StandardError => e
    puts "  → エラー: #{e.message}"
    nil
  end

  def download_xbrl_file(doc)
    doc_id = doc['docID']
    sec_code = doc['secCode']
    xbrl_filename = "#{sec_code}_#{doc_id}.xbrl"
    xbrl_path = "#{@data_dir}/xbrl/#{xbrl_filename}.zip"

    return xbrl_path if File.exist?(xbrl_path)

    success = @client.download_xbrl(doc_id, "xbrl/#{xbrl_filename}")
    return xbrl_path if success

    puts '  → XBRLダウンロード失敗'
    nil
  end

  def extract_financial_data(xbrl_path)
    parser = XbrlParser.new
    financial_data = parser.parse_from_zip(xbrl_path)

    return financial_data if financial_data&.dig(:current_period)

    puts '  → データ抽出失敗'
    nil
  end

  def build_analysis_result(doc, financial_data)
    {
      company_info: build_company_info(doc),
      financial_data: financial_data,
      analysis: perform_analysis(financial_data[:current_period])
    }.tap { puts '  → 分析完了' }
  end

  def build_company_info(doc)
    {
      name: doc['filerName'],
      sec_code: doc['secCode'],
      doc_id: doc['docID'],
      submit_date: doc['submitDateTime'],
      doc_description: doc['docDescription']
    }
  end

  def perform_analysis(data)
    {}.tap do |analysis|
      analysis[:growth] = analyze_growth(data[:revenue_growth]) if data[:revenue_growth]
      analysis[:profitability] = analyze_profitability(data[:operating_profit_margin]) if data[:operating_profit_margin]
      analysis[:roe] = analyze_roe(data[:roe]) if data[:roe]
    end
  end

  def analyze_growth(revenue_growth)
    case revenue_growth
    when 10..Float::INFINITY
      { level: '高成長', comment: "売上高成長率 #{revenue_growth}%" }
    when 0..10
      { level: '安定成長', comment: "売上高成長率 #{revenue_growth}%" }
    else
      { level: '減収', comment: "売上高成長率 #{revenue_growth}%" }
    end
  end

  def analyze_profitability(operating_profit_margin)
    case operating_profit_margin
    when 15..Float::INFINITY
      { level: '高収益', comment: "営業利益率 #{operating_profit_margin}%" }
    when 5..15
      { level: '標準的', comment: "営業利益率 #{operating_profit_margin}%" }
    else
      { level: '低収益', comment: "営業利益率 #{operating_profit_margin}%" }
    end
  end

  def analyze_roe(roe)
    case roe
    when 15..Float::INFINITY
      { level: '優良', comment: "ROE #{roe}%" }
    when 8..15
      { level: '良好', comment: "ROE #{roe}%" }
    else
      { level: '要改善', comment: "ROE #{roe}%" }
    end
  end

  def display_summary(results)
    print_summary_header
    results.each { |result| display_company_summary(result) }
  end

  def print_summary_header
    puts "\n#{'=' * 70}"
    puts '分析結果サマリー'
    puts '=' * 70
  end

  def display_company_summary(result)
    info = result[:company_info]
    data = result[:financial_data][:current_period]
    analysis = result[:analysis]

    puts "\n【#{info[:name]}】(#{info[:sec_code]})"
    puts "  書類: #{info[:doc_description]}"

    display_financial_metrics(data)
    display_analysis_results(analysis)
  end

  def display_financial_metrics(data)
    puts "  売上高: #{format_number(data[:revenue])}" if data[:revenue]
    puts "  営業利益: #{format_number(data[:operating_profit])}" if data[:operating_profit]
    puts "  純利益: #{format_number(data[:net_profit])}" if data[:net_profit]
  end

  def display_analysis_results(analysis)
    analysis.each do |key, value|
      puts "  #{key}: #{value[:level]} - #{value[:comment]}"
    end
  end

  def save_results(results, date)
    filename = "#{@data_dir}/json/kessan_analysis_#{date.strftime('%Y%m%d')}.json"

    File.write(filename, JSON.pretty_generate({
                                                analysis_date: date.strftime('%Y-%m-%d'),
                                                total_count: results.length,
                                                results: results
                                              }))

    puts "\n結果を保存しました: #{filename}"
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV[0]
    begin
      target_date = Date.parse(ARGV[0])
    rescue StandardError
      puts '日付の形式が正しくありません。YYYY-MM-DD形式で指定してください。'
      exit 1
    end
  else
    target_date = Date.today - 1
  end

  analyzer = KessanAnalyzer.new
  analyzer.analyze_kessan_tanshin(target_date)
end

#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'config/settings'
require 'faraday'
require 'json'

class GeminiClient
  def initialize
    @api_key = Settings.gemini.api_key
    @base_url = 'https://generativelanguage.googleapis.com'

    unless @api_key && !@api_key.empty? && @api_key != 'test_gemini_api_key'
      puts 'Gemini API key is not configured properly'
      @client = nil
      return
    end

    @client = Faraday.new(url: @base_url) do |config|
      config.request :json
      config.response :json
      config.adapter :net_http
    end
  rescue StandardError => e
    puts "Gemini Client初期化エラー: #{e.message}"
    @client = nil
  end

  def analyze_financial_data(financial_data)
    return nil unless @client

    prompt = build_analysis_prompt(financial_data)

    payload = {
      contents: [{
        parts: [{ text: prompt }]
      }]
    }

    response = @client.post("/v1/models/gemini-1.5-flash:generateContent?key=#{@api_key}") do |req|
      req.body = payload
    end

    if response.success?
      result = response.body
      result.dig('candidates', 0, 'content', 'parts', 0, 'text')
    else
      puts "Gemini API エラー: #{response.status} - #{response.body}"
      nil
    end
  rescue StandardError => e
    puts "Gemini API エラー: #{e.message}"
    nil
  end

  private

  def build_analysis_prompt(data)
    current = data[:current_period]
    previous = data[:previous_period]

    prompt = "以下の財務データを分析してください：\n\n"
    prompt += "【当期】\n"
    prompt += "売上高: #{format_number(current[:revenue])}\n" if current[:revenue]
    prompt += "営業利益: #{format_number(current[:operating_profit])}\n" if current[:operating_profit]
    prompt += "純利益: #{format_number(current[:net_profit])}\n" if current[:net_profit]

    if previous && previous[:revenue]
      prompt += "\n【前期】\n"
      prompt += "売上高: #{format_number(previous[:revenue])}\n"
      prompt += "営業利益: #{format_number(previous[:operating_profit])}\n" if previous[:operating_profit]
      prompt += "純利益: #{format_number(previous[:net_profit])}\n" if previous[:net_profit]
    end

    prompt += "\n企業の財務状況について、成長性、収益性、安全性の観点から分析し、"
    prompt += '投資判断に有用な洞察を200文字以内で簡潔に提供してください。'

    prompt
  end

  def format_number(value)
    return 'N/A' unless value

    if value >= 100_000_000
      "#{(value / 100_000_000).round(1)}億円"
    elsif value >= 10_000
      "#{(value / 10_000).round(1)}万円"
    else
      "#{value.to_i}円"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  client = GeminiClient.new

  sample_data = {
    current_period: {
      revenue: 5_000_000_000,
      operating_profit: 500_000_000,
      net_profit: 300_000_000
    },
    previous_period: {
      revenue: 4_500_000_000,
      operating_profit: 400_000_000,
      net_profit: 250_000_000
    }
  }

  puts '=== Gemini AI 財務分析デモ ==='
  analysis = client.analyze_financial_data(sample_data)

  if analysis
    puts "\n【AI分析結果】"
    puts analysis
  else
    puts "\nGemini APIキーが設定されていないか、エラーが発生しました。"
    puts '環境変数GEMINI_API_KEYを設定してください。'
  end
end

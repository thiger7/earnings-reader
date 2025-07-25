require 'rexml/document'
require 'zip'
require 'json'
require_relative 'financial_metrics'

class XbrlParser
  attr_reader :financial_data

  def initialize
    @financial_data = {}
    @namespaces = {}
  end

  def parse_from_zip(zip_path)
    Zip::File.open(zip_path) do |zip_file|
      xbrl_entry = zip_file.glob('**/PublicDoc/*.xbrl').first ||
                   zip_file.glob('**/*.xbrl').first

      if xbrl_entry
        xbrl_content = zip_file.read(xbrl_entry)
        parse_xbrl(xbrl_content)
      else
        puts 'XBRLファイルが見つかりません'
        nil
      end
    end
  end

  def parse_xbrl(xbrl_content)
    doc = REXML::Document.new(xbrl_content)
    root = doc.root

    extract_namespaces(root)

    contexts = extract_contexts(doc)

    extract_financial_data(doc, contexts)

    calculate_additional_metrics

    @financial_data
  end

  private

  def extract_namespaces(root)
    root.attributes.each do |name, value|
      if name.start_with?('xmlns:')
        prefix = name.sub('xmlns:', '')
        @namespaces[prefix] = value
      end
    end
  end

  def extract_contexts(doc)
    contexts = {}

    doc.elements.each('//xbrli:context') do |context|
      context_id = context.attributes['id']
      period_info = {}

      if (instant = context.elements['xbrli:period/xbrli:instant'])
        period_info[:type] = 'instant'
        period_info[:date] = instant.text
      elsif context.elements['xbrli:period/xbrli:startDate']
        period_info[:type] = 'duration'
        period_info[:start_date] = context.elements['xbrli:period/xbrli:startDate'].text
        period_info[:end_date] = context.elements['xbrli:period/xbrli:endDate'].text
      end

      contexts[context_id] = period_info
    end

    contexts
  end

  def extract_financial_data(doc, contexts)
    current_period = {}
    previous_period = {}
    forecast_data = {}

    doc.elements.each('//*') do |element|
      next if element.namespace == 'http://www.xbrl.org/2003/instance'

      metric_key = find_metric_key(element.name)
      next unless metric_key

      context_id = element.attributes['contextRef']
      next unless context_id && contexts[context_id]

      value = parse_value(element)
      next unless value

      context = contexts[context_id]
      if current_period?(context)
        current_period[metric_key] = value
      elsif previous_period?(context)
        previous_period[metric_key] = value
      elsif forecast?(context_id)
        forecast_data[metric_key] = value
      end
    end

    @financial_data = {
      current_period: current_period,
      previous_period: previous_period,
      forecast: forecast_data,
      extracted_at: Time.now.strftime('%Y-%m-%d %H:%M:%S')
    }
  end

  def find_metric_key(element_name)
    FinancialMetrics::METRICS.each do |key, metric|
      metric[:xbrl_names].each do |xbrl_name|
        return key if element_name.include?(xbrl_name)
      end
    end

    FinancialMetrics::FORECAST_METRICS.each do |key, metric|
      metric[:xbrl_names].each do |xbrl_name|
        return key if element_name.include?(xbrl_name)
      end
    end

    nil
  end

  def parse_value(element)
    return nil if element.text.nil? || element.text.strip.empty?

    text = element.text.strip.gsub(',', '')

    if text =~ /^-?\d+(\.\d+)?$/
      scale = element.attributes['scale']
      value = text.to_f

      if scale
        value *= (10**scale.to_i)
      end

      unit = element.attributes['unitRef']
      if unit&.include?('Millions')
        value *= 1_000_000
      end

      value
    end
  end

  def current_period?(context)
    return false unless context[:end_date]

    end_date = Date.parse(context[:end_date])
    end_date >= Date.new(2023, 4, 1)
  rescue StandardError
    false
  end

  def previous_period?(context)
    return false unless context[:end_date]

    end_date = Date.parse(context[:end_date])
    end_date >= Date.new(2022, 4, 1) && end_date < Date.new(2023, 4, 1)
  rescue StandardError
    false
  end

  def forecast?(context_id)
    context_id.include?('Forecast') || context_id.include?('forecast')
  end

  def calculate_additional_metrics
    current = @financial_data[:current_period]
    previous = @financial_data[:previous_period]

    calculate_growth_rates(current, previous)
    calculate_profitability_ratios(current)
    calculate_payout_ratio(current)
  end

  def calculate_growth_rates(current, previous)
    calculate_revenue_growth(current, previous)
    calculate_profit_growth(current, previous)
  end

  def calculate_revenue_growth(current, previous)
    return unless current[:revenue] && previous[:revenue]&.positive?

    growth_rate = ((current[:revenue].to_f - previous[:revenue].to_f) / previous[:revenue].to_f) * 100
    current[:revenue_growth] = growth_rate.round(2)
  end

  def calculate_profit_growth(current, previous)
    return unless current[:net_profit] && previous[:net_profit]&.positive?

    growth_rate = ((current[:net_profit].to_f - previous[:net_profit].to_f) / previous[:net_profit].to_f) * 100
    current[:profit_growth] = growth_rate.round(2)
  end

  def calculate_profitability_ratios(current)
    return unless current[:operating_profit] && current[:revenue]&.positive?

    margin = (current[:operating_profit].to_f / current[:revenue]) * 100
    current[:operating_profit_margin] = margin.round(2)
  end

  def calculate_payout_ratio(current)
    return unless current[:dividend] && current[:eps]&.positive?

    ratio = (current[:dividend] / current[:eps]) * 100
    current[:payout_ratio] = ratio.round(2)
  end
end

def format_number(value, unit = '百万円')
  return 'N/A' unless value

  if unit == '百万円'
    "#{(value / 1_000_000).round(0).to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')}#{unit}"
  elsif unit == '%'
    "#{value}#{unit}"
  else
    "#{value.round(2)}#{unit}"
  end
end

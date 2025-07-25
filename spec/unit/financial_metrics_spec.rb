require_relative '../spec_helper'
require_relative '../../app/financial_metrics'

RSpec.describe FinancialMetrics do
  describe 'METRICS定数' do
    it '必要な指標が定義されている' do
      expect(FinancialMetrics::METRICS).to be_a(Hash)
      expect(FinancialMetrics::METRICS).not_to be_empty
    end

    it '売上高の定義が正しい' do
      revenue = FinancialMetrics::METRICS[:revenue]

      expect(revenue[:name]).to eq('売上高')
      expect(revenue[:unit]).to eq('百万円')
      expect(revenue[:xbrl_names]).to include('NetSales', 'OperatingRevenue', 'Sales', 'Revenue')
    end

    it '営業利益の定義が正しい' do
      operating_profit = FinancialMetrics::METRICS[:operating_profit]

      expect(operating_profit[:name]).to eq('営業利益')
      expect(operating_profit[:unit]).to eq('百万円')
      expect(operating_profit[:xbrl_names]).to include('OperatingProfit', 'OperatingIncome')
    end

    it '経常利益の定義が正しい' do
      ordinary_profit = FinancialMetrics::METRICS[:ordinary_profit]

      expect(ordinary_profit[:name]).to eq('経常利益')
      expect(ordinary_profit[:unit]).to eq('百万円')
      expect(ordinary_profit[:xbrl_names]).to include('OrdinaryProfit', 'OrdinaryIncome')
    end

    it '当期純利益の定義が正しい' do
      net_profit = FinancialMetrics::METRICS[:net_profit]

      expect(net_profit[:name]).to eq('当期純利益')
      expect(net_profit[:unit]).to eq('百万円')
      expect(net_profit[:xbrl_names]).to include('NetIncome', 'ProfitAttributableToOwnersOfParent', 'NetProfitLoss')
    end

    it 'EPSの定義が正しい' do
      eps = FinancialMetrics::METRICS[:eps]

      expect(eps[:name]).to eq('一株当たり当期純利益(EPS)')
      expect(eps[:unit]).to eq('円')
      expect(eps[:xbrl_names]).to include('EarningsPerShare', 'BasicEarningsPerShare')
    end

    it 'BPSの定義が正しい' do
      bps = FinancialMetrics::METRICS[:bps]

      expect(bps[:name]).to eq('一株当たり純資産(BPS)')
      expect(bps[:unit]).to eq('円')
      expect(bps[:xbrl_names]).to include('BookValuePerShare', 'NetAssetsPerShare')
    end

    it '配当金の定義が正しい' do
      dividend = FinancialMetrics::METRICS[:dividend]

      expect(dividend[:name]).to eq('一株当たり配当金')
      expect(dividend[:unit]).to eq('円')
      expect(dividend[:xbrl_names]).to include('DividendPerShare', 'AnnualDividendsPerShare')
    end

    it 'ROEの定義が正しい' do
      roe = FinancialMetrics::METRICS[:roe]

      expect(roe[:name]).to eq('自己資本利益率(ROE)')
      expect(roe[:unit]).to eq('%')
      expect(roe[:xbrl_names]).to include('ReturnOnEquity', 'ROE')
    end

    it 'ROAの定義が正しい' do
      roa = FinancialMetrics::METRICS[:roa]

      expect(roa[:name]).to eq('総資産利益率(ROA)')
      expect(roa[:unit]).to eq('%')
      expect(roa[:xbrl_names]).to include('ReturnOnAssets', 'ROA')
    end

    it '自己資本比率の定義が正しい' do
      equity_ratio = FinancialMetrics::METRICS[:equity_ratio]

      expect(equity_ratio[:name]).to eq('自己資本比率')
      expect(equity_ratio[:unit]).to eq('%')
      expect(equity_ratio[:xbrl_names]).to include('EquityRatio', 'EquityToAssetRatio')
    end

    it '成長率指標の定義が正しい' do
      revenue_growth = FinancialMetrics::METRICS[:revenue_growth]
      profit_growth = FinancialMetrics::METRICS[:profit_growth]

      expect(revenue_growth[:name]).to eq('売上高成長率')
      expect(revenue_growth[:unit]).to eq('%')

      expect(profit_growth[:name]).to eq('利益成長率')
      expect(profit_growth[:unit]).to eq('%')
    end
  end

  describe 'FORECAST_METRICS定数' do
    it '業績予想指標が定義されている' do
      expect(FinancialMetrics::FORECAST_METRICS).to be_a(Hash)
      expect(FinancialMetrics::FORECAST_METRICS).not_to be_empty
    end

    it '売上高予想の定義が正しい' do
      forecast_revenue = FinancialMetrics::FORECAST_METRICS[:forecast_revenue]

      expect(forecast_revenue[:name]).to eq('売上高予想')
      expect(forecast_revenue[:unit]).to eq('百万円')
      expect(forecast_revenue[:xbrl_names]).to include('ForecastNetSales', 'ForecastOperatingRevenue')
    end

    it '営業利益予想の定義が正しい' do
      forecast_operating_profit = FinancialMetrics::FORECAST_METRICS[:forecast_operating_profit]

      expect(forecast_operating_profit[:name]).to eq('営業利益予想')
      expect(forecast_operating_profit[:unit]).to eq('百万円')
      expect(forecast_operating_profit[:xbrl_names]).to include('ForecastOperatingProfit', 'ForecastOperatingIncome')
    end

    it '経常利益予想の定義が正しい' do
      forecast_ordinary_profit = FinancialMetrics::FORECAST_METRICS[:forecast_ordinary_profit]

      expect(forecast_ordinary_profit[:name]).to eq('経常利益予想')
      expect(forecast_ordinary_profit[:unit]).to eq('百万円')
      expect(forecast_ordinary_profit[:xbrl_names]).to include('ForecastOrdinaryProfit', 'ForecastOrdinaryIncome')
    end

    it '当期純利益予想の定義が正しい' do
      forecast_net_profit = FinancialMetrics::FORECAST_METRICS[:forecast_net_profit]

      expect(forecast_net_profit[:name]).to eq('当期純利益予想')
      expect(forecast_net_profit[:unit]).to eq('百万円')
      expect(forecast_net_profit[:xbrl_names]).to include('ForecastNetIncome', 'ForecastProfitAttributableToOwnersOfParent')
    end
  end

  describe 'SEGMENT_INFO定数' do
    it 'セグメント情報が定義されている' do
      expect(FinancialMetrics::SEGMENT_INFO).to be_a(Hash)
      expect(FinancialMetrics::SEGMENT_INFO).to include(
        segment_name: '事業セグメント名',
        segment_revenue: 'セグメント売上高',
        segment_profit: 'セグメント利益'
      )
    end
  end

  describe 'PERIOD_TYPES定数' do
    it '期間タイプが定義されている' do
      expect(FinancialMetrics::PERIOD_TYPES).to be_a(Hash)
      expect(FinancialMetrics::PERIOD_TYPES).to include(
        q1: '第1四半期',
        q2: '第2四半期',
        q3: '第3四半期',
        q4: '第4四半期',
        annual: '通期'
      )
    end
  end

  # 各指標に必要なキーが含まれているかのテスト
  describe '指標の構造テスト' do
    FinancialMetrics::METRICS.each do |key, metric|
      context "#{key}指標" do
        it 'name, xbrl_names, unitキーを持つ' do
          expect(metric).to have_key(:name)
          expect(metric).to have_key(:xbrl_names)
          expect(metric).to have_key(:unit)
        end

        it 'nameが文字列である' do
          expect(metric[:name]).to be_a(String)
          expect(metric[:name]).not_to be_empty
        end

        it 'xbrl_namesが配列である' do
          expect(metric[:xbrl_names]).to be_an(Array)
          expect(metric[:xbrl_names]).not_to be_empty
        end

        it 'unitが文字列である' do
          expect(metric[:unit]).to be_a(String)
          expect(metric[:unit]).not_to be_empty
        end

        it 'xbrl_names内の各要素が文字列である' do
          metric[:xbrl_names].each do |xbrl_name|
            expect(xbrl_name).to be_a(String)
            expect(xbrl_name).not_to be_empty
          end
        end
      end
    end
  end

  # FORECAST_METRICSについても同様のテスト
  describe '予想指標の構造テスト' do
    FinancialMetrics::FORECAST_METRICS.each do |key, metric|
      context "#{key}指標" do
        it 'name, xbrl_names, unitキーを持つ' do
          expect(metric).to have_key(:name)
          expect(metric).to have_key(:xbrl_names)
          expect(metric).to have_key(:unit)
        end

        it 'nameが予想を含む' do
          expect(metric[:name]).to include('予想')
        end

        it 'xbrl_namesがForecastを含む' do
          metric[:xbrl_names].each do |xbrl_name|
            expect(xbrl_name).to include('Forecast')
          end
        end
      end
    end
  end
end

RSpec.describe AnalysisPatterns do
  describe 'PATTERNS定数' do
    it '分析パターンが定義されている' do
      expect(AnalysisPatterns::PATTERNS).to be_a(Hash)
      expect(AnalysisPatterns::PATTERNS).not_to be_empty
    end

    it '成長性分析パターンが定義されている' do
      growth_analysis = AnalysisPatterns::PATTERNS[:growth_analysis]

      expect(growth_analysis[:name]).to eq('成長性分析')
      expect(growth_analysis[:required_metrics]).to include(:revenue, :operating_profit, :net_profit)
      expect(growth_analysis[:conditions]).to have_key(:high_growth)
      expect(growth_analysis[:conditions]).to have_key(:stable_growth)
      expect(growth_analysis[:conditions]).to have_key(:declining)
    end

    it '収益性分析パターンが定義されている' do
      profitability_analysis = AnalysisPatterns::PATTERNS[:profitability_analysis]

      expect(profitability_analysis[:name]).to eq('収益性分析')
      expect(profitability_analysis[:required_metrics]).to include(:roe, :roa, :operating_profit_margin)
      expect(profitability_analysis[:conditions]).to have_key(:high_profitability)
      expect(profitability_analysis[:conditions]).to have_key(:moderate_profitability)
      expect(profitability_analysis[:conditions]).to have_key(:low_profitability)
    end

    it '安定性分析パターンが定義されている' do
      stability_analysis = AnalysisPatterns::PATTERNS[:stability_analysis]

      expect(stability_analysis[:name]).to eq('安定性分析')
      expect(stability_analysis[:required_metrics]).to include(:equity_ratio)
      expect(stability_analysis[:conditions]).to have_key(:high_stability)
      expect(stability_analysis[:conditions]).to have_key(:moderate_stability)
      expect(stability_analysis[:conditions]).to have_key(:low_stability)
    end

    it '株主還元分析パターンが定義されている' do
      shareholder_return_analysis = AnalysisPatterns::PATTERNS[:shareholder_return_analysis]

      expect(shareholder_return_analysis[:name]).to eq('株主還元分析')
      expect(shareholder_return_analysis[:required_metrics]).to include(:dividend, :eps)
      expect(shareholder_return_analysis[:conditions]).to have_key(:high_return)
      expect(shareholder_return_analysis[:conditions]).to have_key(:moderate_return)
      expect(shareholder_return_analysis[:conditions]).to have_key(:low_return)
    end
  end

  # 各分析パターンの構造テスト
  describe '分析パターンの構造テスト' do
    AnalysisPatterns::PATTERNS.each do |key, pattern|
      context "#{key}パターン" do
        it 'name, required_metrics, conditionsキーを持つ' do
          expect(pattern).to have_key(:name)
          expect(pattern).to have_key(:required_metrics)
          expect(pattern).to have_key(:conditions)
        end

        it 'nameが文字列である' do
          expect(pattern[:name]).to be_a(String)
          expect(pattern[:name]).not_to be_empty
        end

        it 'required_metricsが配列である' do
          expect(pattern[:required_metrics]).to be_an(Array)
          expect(pattern[:required_metrics]).not_to be_empty
        end

        it 'conditionsがハッシュである' do
          expect(pattern[:conditions]).to be_a(Hash)
          expect(pattern[:conditions]).not_to be_empty
        end

        it 'conditions内の各値が文字列である' do
          pattern[:conditions].each_value do |condition_value|
            expect(condition_value).to be_a(String)
            expect(condition_value).not_to be_empty
          end
        end
      end
    end
  end
end

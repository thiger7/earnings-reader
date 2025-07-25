class FinancialMetrics
  METRICS = {
    revenue: {
      name: '売上高',
      xbrl_names: %w[
        NetSales
        OperatingRevenue
        Sales
        Revenue
      ],
      unit: '百万円'
    },

    operating_profit: {
      name: '営業利益',
      xbrl_names: %w[
        OperatingProfit
        OperatingIncome
      ],
      unit: '百万円'
    },

    ordinary_profit: {
      name: '経常利益',
      xbrl_names: %w[
        OrdinaryProfit
        OrdinaryIncome
      ],
      unit: '百万円'
    },

    net_profit: {
      name: '当期純利益',
      xbrl_names: %w[
        NetIncome
        ProfitAttributableToOwnersOfParent
        NetProfitLoss
      ],
      unit: '百万円'
    },

    eps: {
      name: '一株当たり当期純利益(EPS)',
      xbrl_names: %w[
        EarningsPerShare
        BasicEarningsPerShare
      ],
      unit: '円'
    },

    bps: {
      name: '一株当たり純資産(BPS)',
      xbrl_names: %w[
        BookValuePerShare
        NetAssetsPerShare
      ],
      unit: '円'
    },

    dividend: {
      name: '一株当たり配当金',
      xbrl_names: %w[
        DividendPerShare
        AnnualDividendsPerShare
      ],
      unit: '円'
    },

    roe: {
      name: '自己資本利益率(ROE)',
      xbrl_names: %w[
        ReturnOnEquity
        ROE
      ],
      unit: '%'
    },

    roa: {
      name: '総資産利益率(ROA)',
      xbrl_names: %w[
        ReturnOnAssets
        ROA
      ],
      unit: '%'
    },

    equity_ratio: {
      name: '自己資本比率',
      xbrl_names: %w[
        EquityRatio
        EquityToAssetRatio
      ],
      unit: '%'
    },

    revenue_growth: {
      name: '売上高成長率',
      xbrl_names: %w[
        RevenueGrowthRate
        SalesGrowthRate
      ],
      unit: '%'
    },

    profit_growth: {
      name: '利益成長率',
      xbrl_names: %w[
        ProfitGrowthRate
        NetIncomeGrowthRate
      ],
      unit: '%'
    }
  }.freeze

  FORECAST_METRICS = {
    forecast_revenue: {
      name: '売上高予想',
      xbrl_names: %w[
        ForecastNetSales
        ForecastOperatingRevenue
      ],
      unit: '百万円'
    },

    forecast_operating_profit: {
      name: '営業利益予想',
      xbrl_names: %w[
        ForecastOperatingProfit
        ForecastOperatingIncome
      ],
      unit: '百万円'
    },

    forecast_ordinary_profit: {
      name: '経常利益予想',
      xbrl_names: %w[
        ForecastOrdinaryProfit
        ForecastOrdinaryIncome
      ],
      unit: '百万円'
    },

    forecast_net_profit: {
      name: '当期純利益予想',
      xbrl_names: %w[
        ForecastNetIncome
        ForecastProfitAttributableToOwnersOfParent
      ],
      unit: '百万円'
    }
  }.freeze

  SEGMENT_INFO = {
    segment_name: '事業セグメント名',
    segment_revenue: 'セグメント売上高',
    segment_profit: 'セグメント利益'
  }.freeze

  PERIOD_TYPES = {
    q1: '第1四半期',
    q2: '第2四半期',
    q3: '第3四半期',
    q4: '第4四半期',
    annual: '通期'
  }.freeze
end

class AnalysisPatterns
  PATTERNS = {
    growth_analysis: {
      name: '成長性分析',
      required_metrics: %i[revenue operating_profit net_profit],
      conditions: {
        high_growth: 'revenue_growth > 10% AND operating_profit_growth > 15%',
        stable_growth: 'revenue_growth > 0% AND operating_profit_growth > 0%',
        declining: 'revenue_growth < 0% OR operating_profit_growth < 0%'
      }
    },

    profitability_analysis: {
      name: '収益性分析',
      required_metrics: %i[roe roa operating_profit_margin],
      conditions: {
        high_profitability: 'roe > 15% AND roa > 5%',
        moderate_profitability: 'roe > 8% AND roa > 3%',
        low_profitability: 'roe < 8% OR roa < 3%'
      }
    },

    stability_analysis: {
      name: '安定性分析',
      required_metrics: [:equity_ratio],
      conditions: {
        high_stability: 'equity_ratio > 50%',
        moderate_stability: 'equity_ratio > 30%',
        low_stability: 'equity_ratio < 30%'
      }
    },

    shareholder_return_analysis: {
      name: '株主還元分析',
      required_metrics: %i[dividend eps],
      conditions: {
        high_return: 'payout_ratio > 30%',
        moderate_return: 'payout_ratio > 20%',
        low_return: 'payout_ratio < 20%'
      }
    }
  }.freeze
end

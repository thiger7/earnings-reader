require_relative '../spec_helper'
require_relative '../../app/xbrl_parser'

RSpec.describe XbrlParser do
  let(:parser) { described_class.new }
  let(:test_zip_path) { './spec/test_data/test_xbrl.zip' }

  before do
    # テスト用のXBRLファイルを作成
    create_test_xbrl_zip(test_zip_path)
  end

  describe '#initialize' do
    it 'インスタンスが正常に作成される' do
      expect(parser).to be_instance_of(described_class)
      expect(parser.financial_data).to eq({})
    end
  end

  describe '#parse_from_zip' do
    context '有効なXBRLファイルが含まれる場合' do
      it 'ZIPファイルからXBRLを解析できる' do
        result = parser.parse_from_zip(test_zip_path)

        expect(result).to be_a(Hash)
        expect(result).to have_key(:current_period)
        expect(result).to have_key(:previous_period)
        expect(result).to have_key(:forecast)
        expect(result).to have_key(:extracted_at)
      end

      it '財務データが正しく抽出される' do
        result = parser.parse_from_zip(test_zip_path)
        current = result[:current_period]
        previous = result[:previous_period]

        # 現在期間の売上高が正しく抽出されることを確認
        expect(current[:revenue]).to eq(50_000 * 1_000_000) # 50000百万円

        # 現在期間の営業利益が正しく抽出されることを確認
        expect(current[:operating_profit]).to eq(5000 * 1_000_000) # 5000百万円

        # 現在期間の当期純利益が正しく抽出されることを確認
        expect(current[:net_profit]).to eq(3000 * 1_000_000) # 3000百万円

        # 前期データも抽出されることを確認
        expect(previous[:revenue]).to eq(45_000 * 1_000_000) # 45000百万円
        expect(previous[:operating_profit]).to eq(4500 * 1_000_000) # 4500百万円
        expect(previous[:net_profit]).to eq(2800 * 1_000_000) # 2800百万円
      end

      it '成長率が計算される' do
        result = parser.parse_from_zip(test_zip_path)
        current = result[:current_period]

        # 売上高成長率: (50000 - 45000) / 45000 * 100 = 11.11%
        expect(current[:revenue_growth]).to be_within(0.01).of(11.11)

        # 利益成長率: (3000 - 2800) / 2800 * 100 = 7.14%
        expect(current[:profit_growth]).to be_within(0.01).of(7.14)
      end

      it '営業利益率が計算される' do
        result = parser.parse_from_zip(test_zip_path)
        current = result[:current_period]

        # 営業利益率: 5000 / 50000 * 100 = 10%
        expect(current[:operating_profit_margin]).to eq(10.0)
      end
    end

    context 'XBRLファイルが見つからない場合' do
      let(:empty_zip_path) { './spec/test_data/empty.zip' }

      before do
        require 'zip'
        Zip::File.open(empty_zip_path, Zip::File::CREATE) do |zipfile|
          zipfile.get_output_stream('dummy.txt') { |f| f.write('dummy') }
        end
      end

      it 'nilが返される' do
        expect { parser.parse_from_zip(empty_zip_path) }.to output(/XBRLファイルが見つかりません/).to_stdout
        result = parser.parse_from_zip(empty_zip_path)
        expect(result).to be_nil
      end
    end

    context 'ファイルが存在しない場合' do
      it '例外が発生する' do
        expect { parser.parse_from_zip('nonexistent.zip') }.to raise_error(Zip::Error)
      end
    end
  end

  describe '#parse_xbrl' do
    let(:xbrl_content) { sample_xbrl_content }

    it 'XBRL文字列を直接解析できる' do
      result = parser.parse_xbrl(xbrl_content)

      expect(result).to be_a(Hash)
      expect(result).to have_key(:current_period)
      expect(result[:current_period]).to have_key(:revenue)
    end

    it '不正なXML形式の場合は例外が発生する' do
      invalid_xml = '<invalid><xml'
      expect { parser.parse_xbrl(invalid_xml) }.to raise_error(REXML::ParseException)
    end
  end

  describe 'private methods' do
    let(:xbrl_content) { sample_xbrl_content }

    before do
      parser.parse_xbrl(xbrl_content)
    end

    describe '#find_metric_key' do
      it '売上高要素を正しく識別する' do
        key = parser.send(:find_metric_key, 'jpcrp:NetSales')
        expect(key).to eq(:revenue)
      end

      it '営業利益要素を正しく識別する' do
        key = parser.send(:find_metric_key, 'jpcrp:OperatingProfit')
        expect(key).to eq(:operating_profit)
      end

      it '存在しない要素はnilを返す' do
        key = parser.send(:find_metric_key, 'unknown:Element')
        expect(key).to be_nil
      end
    end

    describe '#parse_value' do
      let(:mock_element) do
        element = double('element')
        allow(element).to receive_messages(text: '1000', attributes: {})
        element
      end

      it '数値文字列を正しく変換する' do
        value = parser.send(:parse_value, mock_element)
        expect(value).to eq(1000.0)
      end

      it 'スケール属性を考慮して変換する' do
        allow(mock_element).to receive(:attributes).and_return({ 'scale' => '6' })
        value = parser.send(:parse_value, mock_element)
        expect(value).to eq(1000.0 * 1_000_000)
      end

      it 'カンマ区切りの数値を処理する' do
        allow(mock_element).to receive(:text).and_return('1,000,000')
        value = parser.send(:parse_value, mock_element)
        expect(value).to eq(1_000_000.0)
      end

      it '空文字やnilの場合はnilを返す' do
        allow(mock_element).to receive(:text).and_return('')
        value = parser.send(:parse_value, mock_element)
        expect(value).to be_nil

        allow(mock_element).to receive(:text).and_return(nil)
        value = parser.send(:parse_value, mock_element)
        expect(value).to be_nil
      end

      it '非数値文字列の場合はnilを返す' do
        allow(mock_element).to receive(:text).and_return('not a number')
        value = parser.send(:parse_value, mock_element)
        expect(value).to be_nil
      end
    end

    describe '#forecast?' do
      it '予想データのコンテキストIDを正しく判定する' do
        expect(parser.send(:forecast?, 'ForecastData')).to be true
        expect(parser.send(:forecast?, 'forecast_2024')).to be true
        expect(parser.send(:forecast?, 'CurrentYear')).to be false
      end
    end
  end

  describe '#calculate_additional_metrics' do
    let(:parser_with_data) do
      p = described_class.new
      p.instance_variable_set(:@financial_data, {
                                current_period: {
                                  revenue: 100_000_000,
                                  operating_profit: 10_000_000,
                                  net_profit: 6_000_000,
                                  eps: 60.0,
                                  dividend: 30.0
                                },
                                previous_period: {
                                  revenue: 90_000_000,
                                  operating_profit: 8_000_000,
                                  net_profit: 5_000_000
                                }
                              })
      p
    end

    before do
      parser_with_data.send(:calculate_additional_metrics)
    end

    it '売上高成長率が計算される' do
      current = parser_with_data.financial_data[:current_period]
      # (100M - 90M) / 90M * 100 = 11.11%
      expect(current[:revenue_growth]).to be_within(0.01).of(11.11)
    end

    it '利益成長率が計算される' do
      current = parser_with_data.financial_data[:current_period]
      # (6M - 5M) / 5M * 100 = 20%
      expect(current[:profit_growth]).to eq(20.0)
    end

    it '営業利益率が計算される' do
      current = parser_with_data.financial_data[:current_period]
      # 10M / 100M * 100 = 10%
      expect(current[:operating_profit_margin]).to eq(10.0)
    end

    it '配当性向が計算される' do
      current = parser_with_data.financial_data[:current_period]
      # 30 / 60 * 100 = 50%
      expect(current[:payout_ratio]).to eq(50.0)
    end
  end
end

# format_number関数のテスト（xbrl_parser.rbに定義されているヘルパー関数）
RSpec.describe 'format_number' do
  it '百万円単位の数値を正しくフォーマットする' do
    result = format_number(1_000_000_000, '百万円')
    expect(result).to eq('1,000百万円')
  end

  it 'パーセント値を正しくフォーマットする' do
    result = format_number(12.5, '%')
    expect(result).to eq('12.5%')
  end

  it 'その他の単位を正しくフォーマットする' do
    result = format_number(123.456, '円')
    expect(result).to eq('123.46円')
  end

  it 'nilの場合はN/Aを返す' do
    result = format_number(nil)
    expect(result).to eq('N/A')
  end
end

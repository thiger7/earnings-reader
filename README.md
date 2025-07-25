# 決算短信分析ツール - ローカル実行手順

## 環境準備

### 1. 必要なソフトウェア
- Ruby 3.0以上
- Bundler

### 2. セットアップ
```bash
# プロジェクトディレクトリに移動
cd /Users/tastuyahigashi/test/earnings_reader

# Gemをインストール
bundle install
```

### 3. 設定ファイルの準備

#### 設定ファイルの作成

```bash
# 設定ファイルの例をコピーして実際の設定ファイルを作成
cp config/settings.yml.example config/settings.yml
```

#### EDINET APIキーの設定

EDINET APIを利用するには、APIキーが必要です：

1. [EDINET API](https://disclosure.edinet-fsa.go.jp/) にアクセス
2. APIキーを取得
3. 環境変数を設定：

##### 方法1: .envファイルを使用（推奨）

```bash
# .env.exampleをコピーして.envファイルを作成
cp .env.example .env

# .envファイルを編集してAPIキーを設定
# EDINET_API_KEY=your_actual_api_key_here
```

##### 方法2: 環境変数として直接設定

```bash
export EDINET_API_KEY="your_api_key_here"
```

**注意：** 
- APIキーなしでもテストは実行できます（テスト環境用の値が自動設定されます）
- 実際のデータ取得には有効なAPIキーが必要です
- .envファイルとconfig/settings.ymlは自動的にGitignoreされ、リポジトリにコミットされません

## テスト実行

### RSpec テスト

```bash
# 全テストを実行
bundle exec rspec

# 特定のファイルをテスト
bundle exec rspec spec/unit/edinet_client_spec.rb

# テスト構造のみを表示（dry-run）
bundle exec rspec --dry-run

# テスト構造表示スクリプト
./bin/rspec-tree                           # 全ファイルの構造
./bin/rspec-tree spec/unit/edinet_client_spec.rb  # 特定ファイルの構造
```

### コード品質チェック

```bash
# RuboCop実行
bundle exec rubocop

# 自動修正
bundle exec rubocop -a
```

## 実行方法

### 基本的な実行
```bash
# 昨日の決算短信を分析
ruby app/earning_analyzer.rb

# 特定の日付を指定
ruby app/earning_analyzer.rb 2025-07-24
```

### 個別機能のテスト

#### EDINET APIのテスト
```bash
ruby app/edinet_client.rb
```

#### 特定企業のXBRL解析
```ruby
# IRBで実行
require_relative 'xbrl_parser'

parser = XbrlParser.new
data = parser.parse_from_zip('./edinet_data/xbrl/7203_S100XXXX.xbrl.zip')
puts JSON.pretty_generate(data)
```

## 出力ファイル

### ディレクトリ構造
```
earning_data/
├── json/          # 分析結果JSON
├── pdf/           # PDFファイル（オプション）
└── xbrl/          # XBRLファイル
```

### 分析結果JSON形式
```json
{
  "analysis_date": "2025-07-24",
  "total_count": 5,
  "results": [
    {
      "company_info": {
        "name": "株式会社○○",
        "sec_code": "1234",
        "doc_id": "S100XXXX"
      },
      "financial_data": {
        "current_period": {
          "revenue": 1000000000,
          "operating_profit": 100000000,
          "net_profit": 80000000
        }
      },
      "analysis": {
        "growth": {
          "level": "高成長",
          "comment": "売上高成長率 15.2%"
        }
      }
    }
  ]
}
```

## トラブルシューティング

### よくある問題

1. **EDINET APIのレート制限**
   - 1秒間隔でアクセスするよう実装済み
   - 大量取得時は適宜待機時間を調整

2. **XBRL解析エラー**
   - 企業によってXBRLの構造が異なる
   - エラーログを確認し、必要に応じて`xbrl_parser.rb`を調整

3. **文字コードエラー**
   - EDINETのデータはUTF-8
   - 必要に応じて文字コード変換を追加

## 次のステップ（AWS移行準備）

### 1. AWS Lambda用にコードを調整
- 各機能を個別のLambda関数に分割
- タイムアウト対策（15分制限）

### 2. データ保存先の変更
- ファイル保存 → S3
- JSON保存 → DynamoDB

### 3. AI分析の追加
- Gemini APIの組み込み
- 分析パターンの拡充

### 4. React UIの開発
- API Gateway経由でのデータ取得
- グラフ表示機能

## 注意事項

- EDINETの利用規約を遵守すること
- 商用利用の場合は適切なライセンスを確認
- 個人情報・機密情報の取り扱いに注意

## 参考リンク

- [EDINET API仕様書](https://disclosure2dl.edinet-fsa.go.jp/guide/static/disclosure/WCUEDS02.html)
- [XBRL Japan](https://www.xbrl.org/jp/)

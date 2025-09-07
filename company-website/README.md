# 株式会社サンプル - 企業ウェブサイト

このプロジェクトは、AWS S3でホストする静的な企業ウェブサイトです。

## プロジェクト構造

```
company-website/
├── index.html          # メインページ
├── error.html          # 404エラーページ
├── css/
│   └── style.css       # スタイルシート
├── js/
│   └── main.js         # JavaScriptファイル
├── images/             # 画像ファイル用ディレクトリ
├── deploy-to-s3.sh     # S3デプロイスクリプト
└── README.md           # このファイル
```

## 機能

- レスポンシブデザイン
- スムーススクロール
- ハンバーガーメニュー（モバイル対応）
- お問い合わせフォーム（デモ）
- スクロールアニメーション

## セットアップ

### 前提条件

- AWS CLI がインストールされていること
- AWS アカウントとアクセスキーが設定されていること
- S3バケットを作成する権限があること

### AWS CLIのインストール

```bash
# macOS (Homebrew)
brew install awscli

# または公式インストーラー
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

### AWS認証情報の設定

```bash
aws configure
# 以下の情報を入力:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name (例: ap-northeast-1)
# - Default output format (例: json)
```

## デプロイ方法

### 1. デプロイスクリプトを使用する方法（推奨）

```bash
# スクリプトに実行権限を付与（初回のみ）
chmod +x deploy-to-s3.sh

# デプロイ実行
./deploy-to-s3.sh <バケット名>

# 例：
./deploy-to-s3.sh my-company-website

# 特定のAWSプロファイルを使用する場合
./deploy-to-s3.sh my-company-website myprofile
```

スクリプトは以下を自動的に実行します：
- S3バケットの作成（存在しない場合）
- 静的ウェブサイトホスティングの設定
- パブリックアクセスの設定
- ファイルのアップロード

### 2. 手動でデプロイする方法

```bash
# バケットの作成
aws s3api create-bucket --bucket <バケット名> --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

# 静的ウェブサイトホスティングを有効化
aws s3 website s3://<バケット名>/ --index-document index.html --error-document error.html

# パブリックアクセスブロックを無効化
aws s3api put-public-access-block --bucket <バケット名> \
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# バケットポリシーを設定
aws s3api put-bucket-policy --bucket <バケット名> --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::<バケット名>/*"
        }
    ]
}'

# ファイルをアップロード
aws s3 sync . s3://<バケット名>/ --exclude "*.sh" --exclude ".git/*" --delete
```

## アクセス方法

デプロイ後、以下のURLでウェブサイトにアクセスできます：

```
http://<バケット名>.s3-website-<リージョン>.amazonaws.com
```

例：`http://my-company-website.s3-website-ap-northeast-1.amazonaws.com`

## カスタマイズ

### 内容の変更

1. `index.html` - 会社情報やサービス内容を編集
2. `css/style.css` - デザインやカラーテーマを変更
3. `js/main.js` - インタラクティブ機能を追加・修正

### 画像の追加

画像ファイルは `images/` ディレクトリに配置し、HTMLから相対パスで参照してください。

```html
<img src="images/logo.png" alt="会社ロゴ">
```

## トラブルシューティング

### アクセスが拒否される場合

- バケットポリシーが正しく設定されているか確認
- パブリックアクセスブロックが無効になっているか確認

### ページが表示されない場合

- `index.html` がバケットのルートにあるか確認
- 静的ウェブサイトホスティングが有効になっているか確認

### AWS CLIエラー

- AWS認証情報が正しく設定されているか確認
- 必要な権限（S3フルアクセス）があるか確認

## ライセンス

このプロジェクトはサンプル用途として公開されています。
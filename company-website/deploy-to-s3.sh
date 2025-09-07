#!/bin/bash

# S3デプロイスクリプト
# 使用方法: ./deploy-to-s3.sh <bucket-name> [profile-name]

set -e

# 引数チェック
if [ $# -lt 1 ]; then
    echo "使用方法: ./deploy-to-s3.sh <bucket-name> [profile-name]"
    echo "例: ./deploy-to-s3.sh my-company-website"
    echo "例: ./deploy-to-s3.sh my-company-website myprofile"
    exit 1
fi

BUCKET_NAME=$1
PROFILE_NAME=${2:-default}

# バケット名のバリデーション
if [[ ! "$BUCKET_NAME" =~ ^[a-z0-9][a-z0-9\-]*[a-z0-9]$ ]]; then
    echo "エラー: バケット名は小文字、数字、ハイフンのみ使用可能です"
    exit 1
fi

echo "================================================"
echo "S3への静的ウェブサイトデプロイを開始します"
echo "バケット名: $BUCKET_NAME"
echo "AWSプロファイル: $PROFILE_NAME"
echo "================================================"

# AWS CLIの存在確認
if ! command -v aws &> /dev/null; then
    echo "エラー: AWS CLIがインストールされていません"
    echo "インストール方法: https://aws.amazon.com/cli/"
    exit 1
fi

# AWSの認証情報確認
echo "AWSの認証情報を確認しています..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "エラー: AWS認証情報が設定されていません"
    exit 1
fi

# バケットの存在確認
echo "S3バケットを確認しています..."
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "バケットが存在しません。新規作成しますか？ (y/n)"
    read -r response
    if [[ "$response" == "y" ]]; then
        # リージョンを取得
        REGION=$(aws configure get region)
        if [ -z "$REGION" ]; then
            echo "デフォルトリージョンを入力してください (例: ap-northeast-1):"
            read -r REGION
        fi
        
        # バケット作成
        echo "S3バケットを作成しています..."
        if [ "$REGION" == "us-east-1" ]; then
            aws s3api create-bucket --bucket "$BUCKET_NAME"
        else
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
        fi
        
        # 静的ウェブサイトホスティングを有効化
        echo "静的ウェブサイトホスティングを設定しています..."
        aws s3 website s3://"$BUCKET_NAME"/ --index-document index.html --error-document error.html
        
        # バケットポリシーを設定（パブリックアクセス）
        echo "バケットポリシーを設定しています..."
        cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF
        
        # パブリックアクセスブロックを無効化
        aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

        # ポリシーを適用
        aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/bucket-policy.json
        rm /tmp/bucket-policy.json
        
        echo "S3バケットの作成と設定が完了しました"
    else
        echo "デプロイを中止します"
        exit 1
    fi
fi

# ファイルの同期
echo "ファイルをS3にアップロードしています..."
aws s3 sync . s3://"$BUCKET_NAME"/ \
    --exclude "*.sh" \
    --exclude ".git/*" \
    --exclude ".gitignore" \
    --exclude "README.md" \
    --exclude ".env" \
    --exclude ".DS_Store" \
    --delete

# CloudFrontの無効化（オプション）
if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo "CloudFrontキャッシュを無効化しています..."
    aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*"
fi

# 完了メッセージ
echo "================================================"
echo "デプロイが完了しました！"
echo ""
echo "ウェブサイトURL:"
echo "http://${BUCKET_NAME}.s3-website-${REGION:-$(aws configure get region)}.amazonaws.com"
echo "================================================"

# エラーHTMLファイルがない場合は作成を提案
if [ ! -f "error.html" ]; then
    echo ""
    echo "注意: error.htmlが見つかりません。"
    echo "404エラーページを作成することをお勧めします。"
fi
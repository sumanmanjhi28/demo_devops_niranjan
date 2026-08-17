#!/bin/bash

# AWS S3 & Elastic Beanstalk Helper Script
# This script provides common commands for managing deployments

set -e

AWS_REGION="${AWS_REGION:-us-east-1}"
APP_NAME="${APP_NAME:-demo-devops}"
ENV_NAME="${ENV_NAME:-dev}"

echo "===================================="
echo "AWS Deployment Helper Script"
echo "===================================="
echo "App: $APP_NAME"
echo "Environment: $ENV_NAME"
echo "Region: $AWS_REGION"
echo ""

# Function to display menu
show_menu() {
    echo ""
    echo "Available commands:"
    echo "1. check-eb-status     - Check Elastic Beanstalk environment status"
    echo "2. get-eb-endpoint     - Get application endpoint URL"
    echo "3. list-s3-uploads     - List uploaded packages in S3"
    echo "4. get-app-logs        - Get recent application logs"
    echo "5. create-app-version  - Create app version from S3 file"
    echo "6. deploy-version      - Deploy a specific version to EB"
    echo "7. rollback            - Rollback to previous version"
    echo "8. get-s3-bucket       - Get S3 bucket name"
    echo "9. upload-to-s3        - Upload local ZIP to S3"
    echo "10. help              - Show this menu"
    echo ""
}

# Check EB Status
check_eb_status() {
    echo "⏳ Checking Elastic Beanstalk status..."
    aws elasticbeanstalk describe-environments \
        --environment-names "$APP_NAME-$ENV_NAME" \
        --region "$AWS_REGION" \
        --query 'Environments[0].[EnvironmentName,Status,Health,HealthStatus]' \
        --output table
}

# Get EB Endpoint
get_eb_endpoint() {
    echo "🔗 Getting application endpoint..."
    ENDPOINT=$(aws elasticbeanstalk describe-environments \
        --environment-names "$APP_NAME-$ENV_NAME" \
        --region "$AWS_REGION" \
        --query 'Environments[0].CNAME' \
        --output text)
    
    if [ -z "$ENDPOINT" ] || [ "$ENDPOINT" = "None" ]; then
        echo "❌ Environment not found or not ready"
        return 1
    fi
    
    echo "✅ Application URL: http://$ENDPOINT"
    echo "https://$ENDPOINT (if using HTTPS)"
}

# List S3 Uploads
list_s3_uploads() {
    echo "📦 Listing S3 uploads..."
    S3_BUCKET=$(get_s3_bucket_name)
    
    if [ -z "$S3_BUCKET" ]; then
        echo "❌ S3 bucket not found"
        return 1
    fi
    
    echo "Bucket: $S3_BUCKET"
    aws s3 ls "s3://$S3_BUCKET/releases/" --human-readable --summarize
}

# Get Application Logs
get_app_logs() {
    echo "📋 Fetching application logs..."
    LOG_GROUP="/aws/elasticbeanstalk/$APP_NAME-$ENV_NAME"
    
    aws logs tail "$LOG_GROUP" \
        --region "$AWS_REGION" \
        --follow \
        --max-items 50 2>/dev/null || echo "⚠️  Log group not found or no logs yet"
}

# Get S3 Bucket Name
get_s3_bucket_name() {
    aws s3api list-buckets \
        --query "Buckets[?contains(Name, '$APP_NAME-$ENV_NAME')].Name" \
        --output text | head -1
}

# Display S3 Bucket
display_s3_bucket() {
    BUCKET=$(get_s3_bucket_name)
    if [ -z "$BUCKET" ]; then
        echo "❌ S3 bucket not found"
        return 1
    fi
    echo "✅ S3 Bucket: $BUCKET"
}

# Create App Version
create_app_version() {
    if [ -z "$1" ]; then
        echo "Usage: create-app-version <s3-key> [version-label]"
        echo "Example: create-app-version releases/app-abc123.zip v1-2024-01-15"
        return 1
    fi
    
    S3_KEY="$1"
    VERSION_LABEL="${2:-v$(date +%s)}"
    BUCKET=$(get_s3_bucket_name)
    
    echo "📝 Creating app version: $VERSION_LABEL"
    echo "Source: s3://$BUCKET/$S3_KEY"
    
    aws elasticbeanstalk create-app-version \
        --application-name "$APP_NAME" \
        --version-label "$VERSION_LABEL" \
        --source-bundle "S3Bucket=$BUCKET,S3Key=$S3_KEY" \
        --region "$AWS_REGION"
    
    echo "✅ App version created: $VERSION_LABEL"
}

# Deploy Version
deploy_version() {
    if [ -z "$1" ]; then
        echo "Usage: deploy-version <version-label>"
        echo "Example: deploy-version v1-2024-01-15"
        return 1
    fi
    
    VERSION_LABEL="$1"
    
    echo "🚀 Deploying version: $VERSION_LABEL"
    
    aws elasticbeanstalk update-environment \
        --environment-name "$APP_NAME-$ENV_NAME" \
        --version-label "$VERSION_LABEL" \
        --region "$AWS_REGION" \
        --query 'EnvironmentId' \
        --output text
    
    echo "✅ Deployment initiated"
    echo "⏳ Waiting for deployment to complete..."
    
    # Wait for deployment
    for i in {1..120}; do
        STATUS=$(aws elasticbeanstalk describe-environments \
            --environment-names "$APP_NAME-$ENV_NAME" \
            --region "$AWS_REGION" \
            --query 'Environments[0].Status' \
            --output text)
        
        if [ "$STATUS" = "Ready" ]; then
            echo "✅ Deployment successful!"
            get_eb_endpoint
            return 0
        fi
        
        echo "Status: $STATUS (attempt $i/120)"
        sleep 5
    done
    
    echo "⚠️  Deployment timeout - check EB console for details"
    return 1
}

# Rollback
rollback() {
    echo "🔄 Rolling back to previous version..."
    
    PREVIOUS=$(aws elasticbeanstalk describe-application-versions \
        --application-name "$APP_NAME" \
        --region "$AWS_REGION" \
        --max-items 2 \
        --query 'ApplicationVersions[1].VersionLabel' \
        --output text)
    
    if [ -z "$PREVIOUS" ] || [ "$PREVIOUS" = "None" ]; then
        echo "❌ No previous version found"
        return 1
    fi
    
    echo "Rolling back to: $PREVIOUS"
    deploy_version "$PREVIOUS"
}

# Upload to S3
upload_to_s3() {
    if [ -z "$1" ]; then
        echo "Usage: upload-to-s3 <local-file>"
        echo "Example: upload-to-s3 app.zip"
        return 1
    fi
    
    FILE="$1"
    
    if [ ! -f "$FILE" ]; then
        echo "❌ File not found: $FILE"
        return 1
    fi
    
    BUCKET=$(get_s3_bucket_name)
    if [ -z "$BUCKET" ]; then
        echo "❌ S3 bucket not found"
        return 1
    fi
    
    FILENAME=$(basename "$FILE")
    S3_KEY="releases/$FILENAME"
    
    echo "📤 Uploading $FILE to S3..."
    aws s3 cp "$FILE" "s3://$BUCKET/$S3_KEY" \
        --region "$AWS_REGION" \
        --metadata "uploaded-at=$(date -Iseconds),local-file=$FILENAME"
    
    echo "✅ Uploaded to: s3://$BUCKET/$S3_KEY"
    echo ""
    echo "Next steps:"
    echo "1. create-app-version $S3_KEY"
    echo "2. deploy-version <version-label>"
}

# Main
case "${1:-help}" in
    check-eb-status)
        check_eb_status
        ;;
    get-eb-endpoint)
        get_eb_endpoint
        ;;
    list-s3-uploads)
        list_s3_uploads
        ;;
    get-app-logs)
        get_app_logs
        ;;
    create-app-version)
        create_app_version "$2" "$3"
        ;;
    deploy-version)
        deploy_version "$2"
        ;;
    rollback)
        rollback
        ;;
    get-s3-bucket)
        display_s3_bucket
        ;;
    upload-to-s3)
        upload_to_s3 "$2"
        ;;
    help|--help|-h|"")
        show_menu
        ;;
    *)
        echo "Unknown command: $1"
        show_menu
        exit 1
        ;;
esac

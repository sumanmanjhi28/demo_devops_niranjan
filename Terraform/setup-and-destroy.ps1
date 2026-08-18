# PowerShell script to setup AWS credentials and destroy resources
# Run this script to clean up all AWS resources

param(
    [string]$AccessKeyId = "",
    [string]$SecretAccessKey = "",
    [string]$Region = "us-east-1"
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "AWS Resource Destruction Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for credentials if not provided
if ([string]::IsNullOrEmpty($AccessKeyId)) {
    $AccessKeyId = Read-Host "Enter AWS Access Key ID"
}

if ([string]::IsNullOrEmpty($SecretAccessKey)) {
    $SecretAccessKey = Read-Host "Enter AWS Secret Access Key" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecretAccessKey)
    $SecretAccessKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

# Set environment variables
$env:AWS_ACCESS_KEY_ID = $AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $SecretAccessKey
$env:AWS_DEFAULT_REGION = $Region

Write-Host "Testing AWS credentials..." -ForegroundColor Yellow

# Test credentials
$identity = aws sts get-caller-identity 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ AWS credentials are invalid or AWS CLI is not working" -ForegroundColor Red
    Write-Host "Error: $identity" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please verify:" -ForegroundColor Yellow
    Write-Host "1. AWS CLI is installed: aws --version" -ForegroundColor White
    Write-Host "2. Credentials are correct" -ForegroundColor White
    Write-Host "3. User has necessary permissions" -ForegroundColor White
    exit 1
}

Write-Host "✓ AWS credentials validated" -ForegroundColor Green
Write-Host "Account info: $identity" -ForegroundColor Gray
Write-Host ""

# Check if Terraform is initialized
if (-not (Test-Path ".\.terraform")) {
    Write-Host "Terraform not initialized. Running terraform init..." -ForegroundColor Yellow
    terraform init
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Terraform init failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Current Terraform State:" -ForegroundColor Cyan
terraform state list 2>&1

if ($LASTEXITCODE -ne 0 -or -not (Test-Path ".\terraform.tfstate")) {
    Write-Host ""
    Write-Host "⚠️  No Terraform state file found!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This means Terraform doesn't know about the existing resources." -ForegroundColor Yellow
    Write-Host "You have two options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Use the cleanup script (recommended)" -ForegroundColor Cyan
    Write-Host "  .\cleanup-aws-resources.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 2: Manually delete resources from AWS Console" -ForegroundColor Cyan
    Write-Host "  See CLEANUP_GUIDE.md for details" -ForegroundColor White
    Write-Host ""
    
    $choice = Read-Host "Do you want to run the cleanup script now? (yes/no)"
    if ($choice -eq "yes") {
        Write-Host ""
        Write-Host "Running cleanup script..." -ForegroundColor Green
        & ".\cleanup-aws-resources.ps1"
    }
    exit 0
}

Write-Host ""
Write-Host "⚠️  WARNING: This will destroy all resources managed by Terraform!" -ForegroundColor Red
Write-Host ""

$confirmation = Read-Host "Are you sure you want to destroy all resources? Type 'yes' to confirm"

if ($confirmation -ne "yes") {
    Write-Host "Destruction cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Running terraform destroy..." -ForegroundColor Green
Write-Host ""

terraform destroy -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "✓ All resources destroyed successfully!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "State file has been updated." -ForegroundColor Gray
    Write-Host "You can now run 'terraform apply' to create fresh resources." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "✗ Terraform destroy encountered errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try running the cleanup script instead:" -ForegroundColor Yellow
    Write-Host "  .\cleanup-aws-resources.ps1" -ForegroundColor White
}

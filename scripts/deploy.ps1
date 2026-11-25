<#
.SYNOPSIS  Uploads the website to a private S3 bucket and invalidates the CloudFront cache.
.EXAMPLE   .\scripts\deploy.ps1 -BucketName my-bucket -DistributionId E123ABC
.EXAMPLE   .\scripts\deploy.ps1            # uses scripts\config.ps1
.EXAMPLE   .\scripts\deploy.ps1 -SkipInvalidation   # before the distribution exists
#>
[CmdletBinding()]
param(
    [string]$BucketName,
    [string]$DistributionId,
    [string]$Profile,
    [switch]$SkipInvalidation
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$site = Join-Path $root 'website'

# Defaults come from scripts\config.ps1, then environment variables.
$cfg = Join-Path $PSScriptRoot 'config.ps1'
if (Test-Path $cfg) { . $cfg }
if (-not $BucketName)     { $BucketName     = if ($BUCKET_NAME) { $BUCKET_NAME } else { $env:S3_BUCKET_NAME } }
if (-not $DistributionId) { $DistributionId = if ($DISTRIBUTION_ID) { $DISTRIBUTION_ID } else { $env:CLOUDFRONT_DISTRIBUTION_ID } }
if (-not $Profile)        { $Profile        = if ($AWS_PROFILE) { $AWS_PROFILE } else { $env:AWS_PROFILE } }

function Fail($m) { Write-Host "DEPLOYMENT FAILED: $m" -ForegroundColor Red; exit 1 }

# 1. AWS CLI installed?
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Fail 'AWS CLI not found. Install it from https://aws.amazon.com/cli/ and reopen PowerShell.'
}
Write-Host "AWS CLI: $(aws --version 2>&1)"

# 2. Inputs valid?
if (-not $BucketName -or $BucketName -like 'YOUR-*') { Fail 'Bucket name missing. Set it in scripts\config.ps1 or pass -BucketName.' }
if (-not $SkipInvalidation -and (-not $DistributionId -or $DistributionId -like 'YOUR-*')) {
    Fail 'Distribution ID missing. Set it in scripts\config.ps1, pass -DistributionId, or use -SkipInvalidation.'
}
if (-not (Test-Path (Join-Path $site 'index.html'))) { Fail "index.html not found in $site" }

$awsArgs = @()
if ($Profile) { $awsArgs += @('--profile', $Profile) }

# 3. AWS CLI configured with working credentials?
$identity = aws sts get-caller-identity --query Arn --output text @awsArgs 2>&1
if ($LASTEXITCODE -ne 0) { Fail "AWS CLI is not configured or credentials are invalid. Run 'aws configure'. Details: $identity" }
Write-Host "Signed in as: $identity"

# 4. Bucket reachable?
aws s3api head-bucket --bucket $BucketName @awsArgs 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Cannot access bucket '$BucketName'. Check the name, Region and IAM permissions." }

# 5. Upload per file type so every object gets the correct Content-Type.
$types = [ordered]@{
    '*.html' = 'text/html; charset=utf-8';        '*.css'  = 'text/css; charset=utf-8'
    '*.js'   = 'application/javascript; charset=utf-8'; '*.svg' = 'image/svg+xml'
    '*.png'  = 'image/png';  '*.jpg' = 'image/jpeg'; '*.jpeg' = 'image/jpeg'
    '*.webp' = 'image/webp'; '*.ico' = 'image/x-icon'; '*.json' = 'application/json'
    '*.txt'  = 'text/plain; charset=utf-8'
}
Write-Host "Uploading $site to s3://$BucketName ..."
foreach ($pattern in $types.Keys) {
    $cache = if ($pattern -eq '*.html') { 'no-cache' } else { 'public, max-age=86400' }
    aws s3 sync $site "s3://$BucketName" --exclude '*' --include $pattern `
        --content-type $types[$pattern] --cache-control $cache --delete @awsArgs
    if ($LASTEXITCODE -ne 0) { Fail "Upload failed for $pattern files." }
}
Write-Host 'Upload complete.' -ForegroundColor Green

# 6. Invalidate the CloudFront cache.
if ($SkipInvalidation) {
    Write-Host 'Cache invalidation skipped.' -ForegroundColor Yellow
} else {
    $inv = aws cloudfront create-invalidation --distribution-id $DistributionId --paths '/*' --query 'Invalidation.Id' --output text @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "Cache invalidation failed: $inv" }
    Write-Host "Invalidation started: $inv (usually finishes within a few minutes)" -ForegroundColor Green
    $domain = aws cloudfront get-distribution --id $DistributionId --query 'Distribution.DomainName' --output text @awsArgs 2>$null
    if ($LASTEXITCODE -eq 0 -and $domain) { Write-Host "Site URL: https://$domain" -ForegroundColor Cyan }
}
Write-Host 'DEPLOYMENT SUCCEEDED' -ForegroundColor Green

<#
.SYNOPSIS  Helps remove AWS resources so you stop paying for them.
.DESCRIPTION
  By default this script only PRINTS the safe removal order (nothing is deleted).
  With -EmptyBucket it deletes every object in your bucket after you type the bucket name to confirm.
  CloudFront, OAC and the bucket itself are removed in the console (steps below).
.EXAMPLE   .\scripts\cleanup.ps1
.EXAMPLE   .\scripts\cleanup.ps1 -EmptyBucket
#>
[CmdletBinding()]
param([string]$BucketName, [string]$Profile, [switch]$EmptyBucket)
$ErrorActionPreference = 'Stop'
$cfg = Join-Path $PSScriptRoot 'config.ps1'
if (Test-Path $cfg) { . $cfg }
if (-not $BucketName) { $BucketName = if ($BUCKET_NAME) { $BUCKET_NAME } else { $env:S3_BUCKET_NAME } }
if (-not $Profile)    { $Profile    = if ($AWS_PROFILE) { $AWS_PROFILE } else { $env:AWS_PROFILE } }

Write-Host @"

SAFE REMOVAL ORDER
  1. CloudFront console > Distributions > select yours > Disable. Wait until Last modified shows a date.
  2. Select it again > Delete.  (A distribution must be disabled before it can be deleted.)
  3. CloudFront > Security > Origin access > select the OAC > Delete.
  4. Empty the bucket:  .\scripts\cleanup.ps1 -EmptyBucket   (or S3 console > bucket > Empty)
  5. S3 console > select the bucket > Delete.
  6. IAM > Users > your deploy user > Security credentials > Delete the access key, then delete the user.
  7. Billing and Cost Management > Bills: confirm no new charges next day.
"@ -ForegroundColor Yellow

if (-not $EmptyBucket) { exit 0 }
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { Write-Host 'AWS CLI not found.' -ForegroundColor Red; exit 1 }
if (-not $BucketName -or $BucketName -like 'YOUR-*') { Write-Host 'Bucket name missing.' -ForegroundColor Red; exit 1 }
$awsArgs = @(); if ($Profile) { $awsArgs += @('--profile', $Profile) }

$answer = Read-Host "This permanently deletes ALL objects in s3://$BucketName. Type the bucket name to confirm"
if ($answer -ne $BucketName) { Write-Host 'Cancelled. Nothing was deleted.'; exit 0 }
aws s3 rm "s3://$BucketName" --recursive @awsArgs
if ($LASTEXITCODE -ne 0) { Write-Host 'Emptying failed.' -ForegroundColor Red; exit 1 }
Write-Host 'Bucket emptied. If versioning was enabled, use S3 console > Empty to remove old versions too.' -ForegroundColor Green

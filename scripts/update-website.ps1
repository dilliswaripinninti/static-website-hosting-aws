<#
.SYNOPSIS  Everyday update command: shows what changed locally, then runs deploy.ps1.
.EXAMPLE   .\scripts\update-website.ps1
.EXAMPLE   .\scripts\update-website.ps1 -Profile static-site
#>
[CmdletBinding()]
param([string]$BucketName, [string]$DistributionId, [string]$Profile)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host 'Local changes in website/:' -ForegroundColor Cyan
    git -C $root status --short -- website
}
& (Join-Path $PSScriptRoot 'deploy.ps1') @PSBoundParameters
exit $LASTEXITCODE

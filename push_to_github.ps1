# Script for pushing to GitHub
param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryName = "hiddify-agent-traffic-manager"
)

Write-Host "🚀 Pushing to GitHub..." -ForegroundColor Green

# Change to repository directory
Set-Location $PSScriptRoot

# Check if remote already exists
$remoteExists = git remote get-url origin 2>$null
if ($remoteExists) {
    Write-Host "⚠️  Remote 'origin' already exists: $remoteExists" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (y/n)"
    if ($overwrite -eq "y") {
        git remote remove origin
    } else {
        Write-Host "❌ Aborted" -ForegroundColor Red
        exit 1
    }
}

# Add remote
$remoteUrl = "https://github.com/$GitHubUsername/$RepositoryName.git"
Write-Host "📡 Adding remote: $remoteUrl" -ForegroundColor Cyan
git remote add origin $remoteUrl

# Check if repository exists on GitHub
Write-Host "🔍 Checking if repository exists on GitHub..." -ForegroundColor Cyan
$repoExists = git ls-remote --heads origin main 2>$null

if (-not $repoExists) {
    Write-Host "⚠️  Repository does not exist on GitHub!" -ForegroundColor Yellow
    Write-Host "Please create the repository first at: https://github.com/new" -ForegroundColor Yellow
    Write-Host "Repository name: $RepositoryName" -ForegroundColor Yellow
    Write-Host ""
    $create = Read-Host "Have you created the repository? (y/n)"
    if ($create -ne "y") {
        Write-Host "❌ Please create the repository first and run this script again" -ForegroundColor Red
        exit 1
    }
}

# Push to GitHub
Write-Host "📤 Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "🌐 Repository URL: https://github.com/$GitHubUsername/$RepositoryName" -ForegroundColor Cyan
} else {
    Write-Host "❌ Failed to push. Please check the error above." -ForegroundColor Red
    exit 1
}


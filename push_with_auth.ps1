# Script for pushing with authentication
Write-Host "Pushing to GitHub..." -ForegroundColor Green
Write-Host ""

# Change to repository directory
Set-Location $PSScriptRoot

# Check if repository exists
Write-Host "Checking remote..." -ForegroundColor Cyan
$remoteUrl = git remote get-url origin
Write-Host "Remote: $remoteUrl" -ForegroundColor Gray

# Get credentials
Write-Host ""
Write-Host "Please enter your GitHub credentials:" -ForegroundColor Yellow
$username = Read-Host "GitHub Username"
$securePassword = Read-Host "GitHub Password or Personal Access Token" -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword))

# Set credential in URL temporarily
$originalUrl = git remote get-url origin
$urlWithAuth = $originalUrl -replace 'https://', "https://${username}:${password}@"

Write-Host ""
Write-Host "Pushing to GitHub..." -ForegroundColor Cyan

# Try to push
try {
    git remote set-url origin $urlWithAuth
    $pushResult = git push -u origin main 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Successfully pushed to GitHub!" -ForegroundColor Green
        Write-Host "Repository URL: https://github.com/smmnouri/hiddify-agent-traffic-manager" -ForegroundColor Cyan
        
        # Restore original URL (without password)
        git remote set-url origin $originalUrl
    } else {
        Write-Host ""
        Write-Host "Failed to push. Please check:" -ForegroundColor Red
        Write-Host "  1. Repository exists on GitHub" -ForegroundColor Yellow
        Write-Host "  2. You have access to the repository" -ForegroundColor Yellow
        Write-Host "  3. You are using Personal Access Token (not password)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Error output:" -ForegroundColor Red
        Write-Host $pushResult
        
        # Restore original URL
        git remote set-url origin $originalUrl
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "Error occurred" -ForegroundColor Red
    git remote set-url origin $originalUrl
    exit 1
}

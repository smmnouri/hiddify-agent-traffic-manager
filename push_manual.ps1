# Manual push script with token
$token = "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"
$username = "smmnouri"

Write-Host "Setting up remote with token..." -ForegroundColor Cyan
git remote set-url origin "https://${username}:${token}@github.com/${username}/hiddify-agent-traffic-manager.git"

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "Repository URL: https://github.com/smmnouri/hiddify-agent-traffic-manager" -ForegroundColor Cyan
    
    # Remove token from URL for security
    git remote set-url origin "https://github.com/smmnouri/hiddify-agent-traffic-manager.git"
} else {
    Write-Host ""
    Write-Host "Failed to push. Error code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "1. Token does not have 'repo' scope" -ForegroundColor Yellow
    Write-Host "2. Repository does not exist or you don't have access" -ForegroundColor Yellow
    Write-Host "3. Token is expired or invalid" -ForegroundColor Yellow
}


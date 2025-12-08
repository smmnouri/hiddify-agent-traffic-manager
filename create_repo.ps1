$token = "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"
$headers = @{
    Authorization = "token $token"
    Accept = "application/vnd.github.v3+json"
}

$body = @{
    name = "hiddify-agent-traffic-manager"
    description = "Agent Traffic Manager module for HiddifyPanel - Traffic limit management for agents"
    private = $false
} | ConvertTo-Json

try {
    Write-Host "Creating repository on GitHub..." -ForegroundColor Cyan
    $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "Repository created successfully!" -ForegroundColor Green
    Write-Host "URL: $($response.html_url)" -ForegroundColor Cyan
    return $true
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "Repository might already exist" -ForegroundColor Yellow
    }
    return $false
}


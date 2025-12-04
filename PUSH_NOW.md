# دستورات سریع برای Push

## روش 1: استفاده از اسکریپت PowerShell

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
.\push_to_github.ps1 -GitHubUsername YOUR_GITHUB_USERNAME
```

## روش 2: دستی

ابتدا repository را در GitHub بسازید:
https://github.com/new

سپس:

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git remote add origin https://github.com/YOUR_USERNAME/hiddify-agent-traffic-manager.git
git push -u origin main
```

## روش 3: اگر GitHub CLI دارید

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
gh repo create hiddify-agent-traffic-manager --public --source=. --remote=origin --push
```


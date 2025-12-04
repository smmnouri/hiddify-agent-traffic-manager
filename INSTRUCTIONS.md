# دستورالعمل Push به GitHub

## ✅ Remote اضافه شد
Remote با آدرس زیر اضافه شده است:
```
https://github.com/smmnouri/hiddify-agent-traffic-manager.git
```

## 📋 مراحل بعدی

### مرحله 1: ایجاد Repository در GitHub
1. به آدرس زیر بروید:
   https://github.com/new

2. اطلاعات را وارد کنید:
   - **Repository name**: `hiddify-agent-traffic-manager`
   - **Description**: `ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel`
   - **Public** یا **Private** را انتخاب کنید
   - ⚠️ **مهم**: README, .gitignore, license را اضافه **نکنید** (ما قبلاً داریم)

3. روی **"Create repository"** کلیک کنید

### مرحله 2: احراز هویت

#### روش 1: استفاده از Personal Access Token (توصیه می‌شود)

1. یک Personal Access Token بسازید:
   - به https://github.com/settings/tokens بروید
   - روی "Generate new token" > "Generate new token (classic)" کلیک کنید
   - نام: `hiddify-agent-traffic-manager`
   - Scope: `repo` را انتخاب کنید
   - روی "Generate token" کلیک کنید
   - Token را کپی کنید (فقط یکبار نمایش داده می‌شود!)

2. Push کنید:
```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git push -u origin main
```
وقتی Username خواست: `smmnouri`
وقتی Password خواست: **Token را paste کنید** (نه password!)

#### روش 2: استفاده از GitHub CLI

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
gh auth login
gh repo create hiddify-agent-traffic-manager --public --source=. --remote=origin --push
```

#### روش 3: استفاده از SSH

اگر SSH key دارید:
```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git remote set-url origin git@github.com:smmnouri/hiddify-agent-traffic-manager.git
git push -u origin main
```

## ✅ بعد از Push

بعد از push موفق، repository شما در آدرس زیر خواهد بود:
https://github.com/smmnouri/hiddify-agent-traffic-manager

## 🔍 بررسی وضعیت

برای بررسی وضعیت:
```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git remote -v
git status
```


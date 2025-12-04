# دستورات سریع برای Push به GitHub

## 1. ایجاد Repository در GitHub

بروید به: https://github.com/new

- Repository name: `hiddify-agent-traffic-manager`
- Description: `ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel`
- Public یا Private
- **توجه**: README, .gitignore, license را اضافه نکنید

## 2. Push کردن

بعد از ایجاد repository، این دستورات را در PowerShell اجرا کنید:

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager

# اضافه کردن remote (USERNAME را جایگزین کنید)
git remote add origin https://github.com/USERNAME/hiddify-agent-traffic-manager.git

# Push کردن
git push -u origin main
```

## یا یک خطی:

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager; git remote add origin https://github.com/USERNAME/hiddify-agent-traffic-manager.git; git push -u origin main
```

## اگر از SSH استفاده می‌کنید:

```powershell
git remote add origin git@github.com:USERNAME/hiddify-agent-traffic-manager.git
git push -u origin main
```

## بررسی

بعد از push، به آدرس زیر بروید:
`https://github.com/USERNAME/hiddify-agent-traffic-manager`

تمام فایل‌ها باید نمایش داده شوند! ✅


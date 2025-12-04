# راهنمای Push به GitHub

## مرحله 1: ایجاد Repository در GitHub

1. به GitHub بروید: https://github.com/new
2. نام repository را وارد کنید (مثلاً: `hiddify-agent-traffic-manager`)
3. Description: "ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel"
4. Public یا Private را انتخاب کنید
5. **توجه**: README, .gitignore, license را اضافه نکنید (ما قبلاً داریم)
6. روی "Create repository" کلیک کنید

## مرحله 2: اضافه کردن Remote و Push

بعد از ایجاد repository، دستورات زیر را اجرا کنید:

```bash
cd hiddify-agent-traffic-manager

# اضافه کردن remote (USERNAME را با نام کاربری GitHub خود جایگزین کنید)
git remote add origin https://github.com/USERNAME/hiddify-agent-traffic-manager.git

# یا اگر از SSH استفاده می‌کنید:
# git remote add origin git@github.com:USERNAME/hiddify-agent-traffic-manager.git

# تغییر نام branch به main (اگر GitHub از main استفاده می‌کند)
git branch -M main

# Push کردن به GitHub
git push -u origin main
```

## یا استفاده از دستورات GitHub CLI

اگر GitHub CLI نصب دارید:

```bash
cd hiddify-agent-traffic-manager
gh repo create hiddify-agent-traffic-manager --public --source=. --remote=origin --push
```

## بررسی

بعد از push، به آدرس زیر بروید:
`https://github.com/USERNAME/hiddify-agent-traffic-manager`

باید تمام فایل‌ها را ببینید!


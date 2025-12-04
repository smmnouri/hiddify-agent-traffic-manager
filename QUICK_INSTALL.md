# نصب سریع - یک خطی

## نصب HiddifyPanel با قابلیت‌های مدیریت ترافیک ایجنت

### مرحله 1: ایجاد Repository سفارشی (یک بار)

ابتدا باید repository سفارشی خودتان را بسازید:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash setup_custom_repo.sh
```

این کار یک repository در GitHub شما می‌سازد با نام `hiddify-panel-custom` (یا نامی که انتخاب کنید).

### مرحله 2: نصب یک خطی

بعد از اینکه repository شما آماده شد، برای نصب در سرورهای دیگر:

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
```

یا اگر می‌خواهید URL کوتاه‌تری داشته باشید، می‌توانید از یک URL shortener استفاده کنید.

## تنظیمات

اگر می‌خواهید repository دیگری استفاده کنید، فایل `install.sh` را ویرایش کنید:

```bash
GITHUB_USER="YOUR_USERNAME"
CUSTOM_REPO="YOUR_REPO_NAME"
```

یا می‌توانید مستقیماً repository را مشخص کنید:

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh) YOUR_USERNAME YOUR_REPO_NAME
```

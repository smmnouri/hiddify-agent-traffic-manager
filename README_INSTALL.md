# راهنمای نصب

## نصب HiddifyPanel + سیستم Agent

### روش 1: استفاده از Repository اصلی HiddifyPanel (پیش‌فرض)

```bash
cd /root
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x install_hiddify_with_agent.sh
sudo ./install_hiddify_with_agent.sh
```

این روش از repository اصلی HiddifyPanel استفاده می‌کند: `https://github.com/hiddify/HiddifyPanel.git`

### روش 2: استفاده از Repository خودتان

اگر repository HiddifyPanel خودتان را دارید:

```bash
# تنظیم repository
export HIDDIFY_REPO_HTTPS="https://github.com/YOUR_USERNAME/YOUR_REPO.git"
export HIDDIFY_BRANCH="main"  # یا branch مورد نظر

# اجرای نصب
cd /root/hiddify-agent-traffic-manager
sudo ./install_hiddify_with_agent.sh
```

### روش 3: استفاده از SSH

اگر SSH key setup کرده‌اید:

```bash
export HIDDIFY_REPO_SSH="git@github.com:YOUR_USERNAME/YOUR_REPO.git"
sudo ./install_hiddify_with_agent.sh
```

### روش 4: استفاده از Token (برای Private Repos)

```bash
export HIDDIFY_REPO_HTTPS="https://USERNAME:TOKEN@github.com/YOUR_USERNAME/YOUR_REPO.git"
sudo ./install_hiddify_with_agent.sh
```

## سوالات متداول

**Q: Repository من چیست؟**
A: اگر repository HiddifyPanel خودتان را دارید، URL آن را در GitHub پیدا کنید و در `HIDDIFY_REPO_HTTPS` قرار دهید.

**Q: آیا باید repository خودم را بسازم؟**
A: خیر! می‌توانید از repository اصلی استفاده کنید. سیستم Agent به صورت خودکار اضافه می‌شود.

**Q: چگونه repository خودم را بسازم؟**
A: می‌توانید HiddifyPanel را fork کنید یا از repository اصلی clone کنید و تغییرات Agent را اضافه کنید.

## نکات مهم

1. **Repository پیش‌فرض**: اسکریپت از `https://github.com/hiddify/HiddifyPanel.git` استفاده می‌کند
2. **سیستم Agent**: به صورت خودکار اضافه می‌شود
3. **Migration**: به صورت خودکار اجرا می‌شود


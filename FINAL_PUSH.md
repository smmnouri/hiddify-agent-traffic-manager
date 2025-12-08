# دستور نهایی برای Push

## مرحله 1: ساخت Repository در GitHub

1. به این آدرس بروید:
   **https://github.com/new**

2. اطلاعات را وارد کنید:
   - **Repository name**: `hiddify-agent-traffic-manager`
   - **Description**: `Agent Traffic Manager module for HiddifyPanel`
   - **Public** یا **Private** را انتخاب کنید
   - ⚠️ **مهم**: README, .gitignore, license را اضافه **نکنید**

3. روی **"Create repository"** کلیک کنید

## مرحله 2: Push کردن

بعد از ساخت repository، این دستور را اجرا کنید:

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git push -u origin main
```

وقتی از شما خواست:
- **Username**: `smmnouri`
- **Password**: Token را paste کنید:
  ```
  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
  ```

## یا از اسکریپت استفاده کنید:

```powershell
.\push_with_auth.ps1
```

Username: `smmnouri`
Password: Token را paste کنید

---

**بعد از ساخت repository، به من بگویید تا push کنم!** 🚀


# ساخت Personal Access Token برای GitHub

GitHub دیگر از password authentication پشتیبانی نمی‌کند. باید Personal Access Token بسازید.

## مراحل:

### 1. ساخت Token
1. به این آدرس بروید:
   https://github.com/settings/tokens/new

2. اطلاعات را وارد کنید:
   - **Note**: `hiddify-agent-traffic-manager`
   - **Expiration**: مدت زمان (مثلاً 90 روز)
   - **Select scopes**: ✅ **repo** را انتخاب کنید (تمام موارد زیر آن هم انتخاب می‌شود)

3. روی **"Generate token"** کلیک کنید

4. **Token را کپی کنید** (فقط یکبار نمایش داده می‌شود!)

### 2. Push کردن با Token

بعد از ساخت Token، این دستورات را اجرا کنید:

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git push -u origin main
```

وقتی از شما خواست:
- **Username**: `smmnouri`
- **Password**: **Token را paste کنید** (نه password!)

یا می‌توانید از اسکریپت استفاده کنید:

```powershell
.\push_with_auth.ps1
```

وقتی Username خواست: `smmnouri`
وقتی Password خواست: **Token را paste کنید**

## نکته مهم:
⚠️ Token را در جایی امن نگه دارید. اگر گم شد، باید دوباره بسازید.


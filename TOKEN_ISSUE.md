# مشکل با Token

خطای 403 نشان می‌دهد که token دسترسی write ندارد.

## راه‌حل‌ها:

### 1. بررسی Token Scope
مطمئن شوید که token شما scope **"repo"** دارد:
- به https://github.com/settings/tokens بروید
- token خود را پیدا کنید
- مطمئن شوید که **repo** scope انتخاب شده است

### 2. ساخت Token جدید
اگر scope کافی نیست، token جدید بسازید:

1. به https://github.com/settings/tokens/new بروید
2. **Note**: `hiddify-agent-traffic-manager`
3. **Expiration**: مدت زمان
4. **Select scopes**: ✅ **repo** (تمام موارد زیر آن)
5. Generate token
6. Token جدید را کپی کنید

### 3. استفاده از GitHub CLI (توصیه می‌شود)

```powershell
# نصب GitHub CLI (اگر نصب نیست)
winget install --id GitHub.cli

# لاگین
gh auth login

# ساخت repository و push
cd C:\Projects\vpn\hiddify-agent-traffic-manager
gh repo create hiddify-agent-traffic-manager --public --source=. --remote=origin --push
```

### 4. استفاده از SSH (اگر SSH key دارید)

```powershell
cd C:\Projects\vpn\hiddify-agent-traffic-manager
git remote set-url origin git@github.com:smmnouri/hiddify-agent-traffic-manager.git
git push -u origin main
```

---

**لطفاً token را بررسی کنید یا token جدید بسازید و به من بدهید.**


# Admin Dashboard

RBAC: only users with `profiles.role = 'admin'` can access admin features.

## Features
- **Overview**: Total ANCODEs, blacklist count, discount codes
- **Codes**: View all with code, type, Comune, clicks, owner, status; edit, blacklist
- **Subscriptions**: List Stripe subscriptions, user, plan, status
- **Blacklist**: CRUD; blacklisted codes cannot be created
- **Discount codes**: Scaffolding (percent, quantity, expiry)
- **Bulk email**: Scaffolding (region filters, audit logs)

## Access
Admin area at `/admin` (or separate route). Main app shows Admin link when `profile.isAdmin`.

# Auth Foundation v2 Reset Runbook

日期：2026-05-13

## Impact

Changing `APP_SECRET` invalidates:

```text
access tokens
refresh tokens
Redis token/session caches
encrypted AI provider API keys
encrypted upload driver secrets
encrypted payment private keys
```

This project is not online yet, so Auth Foundation v2 intentionally does not keep a compatibility window for the old split-secret runtime config.

## SQL

Revoke all active sessions before or immediately after changing `APP_SECRET`:

```sql
UPDATE user_sessions
SET revoked_at = NOW()
WHERE revoked_at IS NULL;
```

## Redis

Clear token/session cache keys from the token Redis DB. The default DB is `TOKEN_REDIS_DB=2` and the default prefix is `token:`.

```powershell
redis-cli -n 2 --scan --pattern "token:*" | ForEach-Object { redis-cli -n 2 DEL $_ }
```

If production changes `TOKEN_REDIS_DB`, use that DB instead of `2`. The `token:` prefix is code-owned; only change the scan pattern if the code-owned prefix changes in a reviewed runtime change.

## Manual re-entry

Re-enter these secrets through the admin UI after changing `APP_SECRET`:

```text
AI provider API keys
upload driver secret_id / secret_key
payment private keys
client-version/export COS secrets if configured through encrypted rows
```

Do not copy old encrypted database blobs. They were encrypted under the old derived secretbox key and are intentionally incompatible.

# Login

## Sub-features

- Reader shortcut `以读者身份进入` for `reader@lowpass.test` (`Identity::DevelopmentAccounts::READER_EMAIL`).
- `使用其他账号` opens the name and email fields and GETs the same callback.
- Account menu `账户` then `账户信息` opens `/settings`.
- `登出` sends `DELETE /session` and returns to `/login`.

## How to get to it (user POV)

Any signed-out GET of a reader page redirects to `/login`, with `next` set to the path they asked for. The login card heading is `登录`. The reader button is on the card. Google and GitHub buttons are absent unless that provider's client id and secret are both set.

## Driving it with Chrome

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive login
```

1. Open `http://127.0.0.1:3000/login`.
2. Click `//button[normalize-space()='以读者身份进入']`. The form method is GET and the action is `/auth/developer/callback`, with hidden `name` `普通读者` and `email` `reader@lowpass.test`.
3. Wait until the URL matches `/daily/\d{4}-\d{2}-\d{2}`.
4. Click `button[aria-label="账户"]`, then the menuitem `账户信息`.
5. Click `账户` again, then the menuitem `登出`.

Observable end state of steps 1–4: the URL is `/settings`, `h1[aria-label="账户信息"]` reads `账户信息`, and the page shows `reader@lowpass.test`. `AuthIdentity` for `developer` / `reader@lowpass.test` exists and that user has a `sessions` row (`Identity::Resolution` creates the user on the first success and reuses it after). Step 5 lands on `/login` with heading `登录`. The script then signs in again and saves the cookie, so a later doctor still gets Inertia `Settings/Show` for that email.

## Gotchas

- `以管理员身份进入` is rendered only when `ADMIN_EMAILS` contains the chosen address (`DEV_LOGIN_ADMIN_EMAIL` or the first whitelist entry). With no whitelist the reader button is the only shortcut. Do not claim `/admin` works, and do not put the reader email on the whitelist to force the admin button.
- Production does not mount the `developer` strategy. A login page without `reader@lowpass.test` is the wrong environment; doctor fails that case.
- The callback is a real OmniAuth request. Do not POST credentials to a test-only route.

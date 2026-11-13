# Login

## Sub-features

- Reader shortcut `以读者身份进入` for `reader@lowpass.test` (`Identity::DevelopmentAccounts::READER_EMAIL`).
- `使用其他账号` opens the name and email fields and GETs the same callback.
- Account menu `账户` then `账户信息` opens `/settings`.
- `登出` sends `DELETE /session` and returns to `/login`.

## How to get to it (user POV)

Any signed-out GET of a reader page redirects to `/login`, with `next` set to the path they asked for. The login card heading is `登录`. The reader button is on the card. Google and GitHub buttons are absent unless that provider's client id and secret are both set.

## Driving it with Chrome

Same Chrome session as `scripts/drive` (headless Chrome, `http://127.0.0.1:3000`).

1. Open `http://127.0.0.1:3000/login`.
2. Click `//button[normalize-space()='以读者身份进入']`. The form method is GET and the action is `/auth/developer/callback`, with hidden `name` `普通读者` and `email` `reader@lowpass.test`.
3. Wait until the URL matches `/daily/\d{4}-\d{2}-\d{2}`.
4. Click `button[aria-label="账户"]`, then the menuitem whose text is `账户信息`.

Observable end state: the URL is `/settings`, `h1[aria-label="账户信息"]` is present, and the page shows `reader@lowpass.test`. The first successful click inserts a `users` row, an `auth_identities` row (`provider` `developer`, `provider_uid` `reader@lowpass.test`), and a `sessions` row. Confirm those with `bin/rails runner`, not by inserting them. A later doctor with the saved cookie must get Inertia `Settings/Show` for that email.

## Gotchas

- `以管理员身份进入` is rendered only when `ADMIN_EMAILS` contains the chosen address (`DEV_LOGIN_ADMIN_EMAIL` or the first whitelist entry). With no whitelist the reader button is the only shortcut. Do not claim `/admin` works, and do not put the reader email on the whitelist to force the admin button.
- Production does not mount the `developer` strategy. A login page without `reader@lowpass.test` is the wrong environment; doctor fails that case.
- The callback is a real OmniAuth request. Do not POST credentials to a test-only route.

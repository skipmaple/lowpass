# Favorites

## Sub-features

- `/favorites` lists the signed-in reader's bookmarks, newest first, 20 per page.
- The bookmark on an item is `button[aria-label^="收藏："]`. It POSTs `/favorites` and the response is JSON, not a new page.
- Cancelling is a real delete of that `url_hash`. The row then offers `恢复`.

## How to get to it (user POV)

Sign in, then click `收藏` in the masthead (`nav[aria-label="主导航"] a[href="/favorites"]`), or open `账户` and choose `收藏`. The heading is `收藏`.

## Driving it with Chrome

```bash
bundle exec .cursor/skills/verify-lowpass/scripts/drive favorites
```

Sign in the same way as [login](login.md). Click `nav[aria-label="主导航"] a[href="/favorites"]`. Wait until the URL path is `/favorites`.

`p.collection-count` reads `<n> 条收藏`, and `n` equals `favorites.count` for the developer identity `reader@lowpass.test`.

On a reader who has never bookmarked (the user created by the reader shortcut; seed creates no `favorites` rows) the observable end state is all of:

- `h1[aria-label="收藏"]`
- `p.collection-count` text `0 条收藏`
- `.state-line` text `还没有收藏。`
- a link whose text is `阅读最新日刊`

If the count is not zero, the empty copy above is the wrong expectation; the proof is the count plus one `[id^="favorite-"]` row. Do not delete rows to recover the empty sentence.

Then open the latest daily issue (`nav[aria-label="主导航"] a[href="/"]`). If `button[aria-label^="收藏："]` is present, click the first one and wait until that control's label starts with `取消收藏：`. The favorites count becomes the previous count plus 1, and `/favorites` shows a `favorite-` row. If the issue has only `取消收藏：` buttons, the links are already saved and the count on `/favorites` is the proof. If the issue has neither button, bookmarking is unreachable: the route attempted is that `/daily/YYYY-MM-DD` page and the missing control is `FavoriteButton`.

## Gotchas

- Bookmarking needs a visible item. `db:seed` does not create items. If the issue page has no `button[aria-label^="收藏："]`, the bookmark sub-feature fails because there is nothing to save. Do not insert an item to produce the button.
- `POST /favorites` and `DELETE /favorites/:url_hash` are the bookmark's fetch calls. Driving them without the button, or with a fixture id, is not this journey. An unsigned POST returns 401, not a redirect.
- The collection is private to the reader. Another developer login is a different user and will not see these rows.

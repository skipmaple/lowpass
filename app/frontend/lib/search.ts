import { SEARCH_CLICKS } from '@/lib/paths'

// 9.1 search_click：点标题或原文时打一枪，fetch 带 keepalive，页面跳走也能发完。
// CSRF 令牌从布局的 <meta name="csrf-token"> 读（app/views/layouts/application.html.erb 的 csrf_meta_tags）。
// 失败就算了：埋点不影响读者。
export type ClickPayload = { item_id: string; rank: number; q: string }

export function reportClick(payload: ClickPayload): void {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
  void fetch(SEARCH_CLICKS, {
    method: 'POST',
    keepalive: true,
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': token },
    body: JSON.stringify(payload),
  }).catch(() => undefined)
}

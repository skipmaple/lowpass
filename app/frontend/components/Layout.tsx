import { usePage } from '@inertiajs/react'
import { Toasts } from '@/components/Toast'
import type { SharedProps } from '@/types/lowpass'
import type * as React from 'react'

import Footer, { type FooterProps } from '@/components/Footer'
import Masthead, { type MastheadProps } from '@/components/Masthead'

// 暖纸铺满窗口；报头与内容共用 1240px 容器，手机保持 24px 边距。
// 报头黑带整宽贴边，其余内容与页脚在留边的 .sheet-body 里。
export type LayoutProps = React.PropsWithChildren<{
  masthead?: MastheadProps
  footer?: FooterProps | false
}>

export default function Layout({ children, masthead, footer }: LayoutProps) {
  const { flash } = usePage<Partial<SharedProps>>().props
  return (
    <div className="paper sheet">
      <a className="skip-link" href="#main-content">跳到正文</a>
      <Masthead {...masthead} />
      <div className="sheet-body">
        <main id="main-content" tabIndex={-1}>
          <Toasts flash={flash} />
          {children}
        </main>
        {footer === false ? null : <Footer {...footer} />}
      </div>
    </div>
  )
}

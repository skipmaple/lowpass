import type * as React from 'react'

import Footer, { type FooterProps } from '@/components/Footer'
import Masthead, { type MastheadProps } from '@/components/Masthead'

// 一张纸：桌面 1240px 居中（.sheet），手机整宽 24px 边距（tokens.css 的 @media）。
// 报头黑带整宽贴边，其余内容与页脚在留边的 .sheet-body 里。
export type LayoutProps = React.PropsWithChildren<{
  masthead?: MastheadProps
  footer?: FooterProps
}>

export default function Layout({ children, masthead, footer }: LayoutProps) {
  return (
    <div className="paper sheet">
      <Masthead {...masthead} />
      <div className="sheet-body">
        {children}
        <Footer {...footer} />
      </div>
    </div>
  )
}

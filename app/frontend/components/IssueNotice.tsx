import type * as React from 'react'

// 期级状态的事实句：列表区顶上一条 1px 墨线，一句文楷 20（设计 skill「状态」）。
// 文案是服务端定稿的附录 B 原句（没有开 SSR，页面上读得到的字符串都得先进 props）。
// 画布：docs/design/src/pages_front3.py 的 message()。
export default function IssueNotice({ text, children }: React.PropsWithChildren<{ text: string }>) {
  return (
    <div className="issue-body">
      <div className="source-state">
        <span className="state-line">{text}</span>
        {/* 附加的一条外链（周刊降级的原文）另起一行，与画布 degraded_section 的纵向排布一致 */}
        {children ? <div>{children}</div> : null}
      </div>
    </div>
  )
}

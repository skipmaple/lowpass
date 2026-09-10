import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import IssueHead, { StatusTag } from '@/components/IssueHead'
import { DAILY_ARCHIVE, dailyHref } from '@/lib/paths'
import { dailyIssue } from '../support/props'

// 日刊期头：日期是 h1，右侧叠发布时间与星期，状态标签挂在右上，右端是期导航。
// 期导航在桌面与手机各排一次（同一份 DOM，tokens.css 里换位），所以都用 getAllByRole 取。

function head(issue = dailyIssue()) {
  return render(<IssueHead issue={issue} archiveHref={DAILY_ARCHIVE} hrefFor={dailyHref} />)
}

describe('StatusTag', () => {
  it('把附录 B 的原句原样摆出来（中文与时间分两个字体角色）', () => {
    const { container } = render(<StatusTag text="已于 06:42 修订" />)

    expect(container.firstElementChild).toHaveTextContent('已于 06:42 修订')
  })
})

describe('IssueHead', () => {
  it('日期是 h1，星期与发布时间在右侧', () => {
    const { container } = head()

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('9月8日')
    expect(screen.getByText('星期二')).toBeInTheDocument()
    expect(container.querySelector('.issue-head-time')).toHaveTextContent('06:12 发布')
  })

  it('有状态才挂标签', () => {
    const { container, unmount } = head()
    expect(container.querySelector('.issue-head-tag')).toBeNull()
    unmount()

    const withTag = head(dailyIssue({ status: '昨日日刊，今日将于 06:00 生成' }))
    expect(withTag.container.querySelector('.issue-head-tag')).toHaveTextContent('昨日日刊，今日将于 06:00 生成')
  })

  it('前一期与归档按周期键拼地址', () => {
    head()

    for (const link of screen.getAllByRole('link', { name: '前一期' })) {
      expect(link).toHaveAttribute('href', '/daily/2026-09-07')
    }
    for (const link of screen.getAllByRole('link', { name: '归档' })) {
      expect(link).toHaveAttribute('href', '/daily')
    }
  })

  // 最新一期没有「后一期」：退成不可点的记号，不是一个点了 404 的链接
  it('没有后一期时按钮不可点', () => {
    head()

    const next = screen.getAllByRole('link', { name: '后一期' })
    expect(next).toHaveLength(2)
    for (const control of next) {
      expect(control).toHaveAttribute('aria-disabled', 'true')
      expect(control).not.toHaveAttribute('href')
      expect(control).toHaveClass('ctrl-off')
    }
  })

  it('有后一期时是真的链接', () => {
    head(dailyIssue({ next_key: '2026-09-09' }))

    for (const link of screen.getAllByRole('link', { name: '后一期' })) {
      expect(link).toHaveAttribute('href', '/daily/2026-09-09')
      expect(link).not.toHaveAttribute('aria-disabled')
    }
  })

  it('第一期没有「前一期」', () => {
    head(dailyIssue({ prev_key: null }))

    for (const control of screen.getAllByRole('link', { name: '前一期' })) {
      expect(control).toHaveAttribute('aria-disabled', 'true')
    }
  })
})

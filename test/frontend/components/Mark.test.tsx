import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Mark from '@/components/Mark'

// 归档的状态记号：形状给眼睛，名字给读屏，别的地方不重复说这件事。

describe('Mark', () => {
  it('已发布是实心方块', () => {
    render(<Mark state="published" />)

    const mark = screen.getByRole('img', { name: '已发布' })
    expect(mark.getAttribute('style')).toContain('background: var(--ink)')
  })

  it('空刊是描边方块', () => {
    render(<Mark state="empty" />)

    const mark = screen.getByRole('img', { name: '空刊' })
    expect(mark.getAttribute('style')).toContain('border: 1px solid var(--ink)')
    expect(mark.getAttribute('style')).toContain('background: transparent')
  })

  it('生成中是时钟', () => {
    render(<Mark state="generating" />)

    expect(screen.getByRole('img', { name: '生成中' }).tagName.toLowerCase()).toBe('svg')
  })

  it('缺期是叉', () => {
    render(<Mark state="missing" />)

    expect(screen.getByRole('img', { name: '缺期' }).tagName.toLowerCase()).toBe('svg')
  })

  // 周刊归档没有期的那一周视觉上跟空刊一样，读屏该念「无内容」——同一份记号，文案按页面语境走
  it('label 覆盖默认名字', () => {
    render(<Mark state="empty" label="无内容" />)

    expect(screen.getByRole('img', { name: '无内容' })).toBeInTheDocument()
    expect(screen.queryByRole('img', { name: '空刊' })).toBeNull()
  })

  it('label 也覆盖得了图标那两个', () => {
    render(<Mark state="missing" label="还没到" />)

    expect(screen.getByRole('img', { name: '还没到' })).toBeInTheDocument()
  })
})

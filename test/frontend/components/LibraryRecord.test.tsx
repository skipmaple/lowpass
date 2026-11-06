import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, expect, it, vi } from 'vitest'

import LibraryRecord from '@/components/LibraryRecord'

afterEach(() => {
  delete document.documentElement.dataset.theme
  vi.unstubAllGlobals()
})

function show(wide: boolean) {
  document.documentElement.dataset.theme = 'duet'
  vi.stubGlobal('matchMedia', vi.fn().mockReturnValue({ matches: wide }))
  return render(<LibraryRecord id="saved-uv" rank={1} title="astral-sh / uv" href="https://example.com/uv" meta="GitHub Trending" detailTitle="值得关注" detail={<p>可分享带依赖声明的脚本。</p>} actions={<button type="button">已收藏</button>} />)
}

it('B 手机收藏先显示识别信息，理由按需展开并保留用户选择', async () => {
  const { container, rerender } = show(false)
  const detail = container.querySelector('details')!
  expect(detail).not.toHaveAttribute('open')
  expect(screen.getByRole('link', { name: 'astral-sh / uv' })).toBeVisible()
  await userEvent.click(screen.getByText('值得关注'))
  expect(detail).toHaveAttribute('open')
  rerender(<LibraryRecord id="saved-uv" rank={1} title="astral-sh / uv" href="https://example.com/uv" meta="GitHub Trending" detailTitle="值得关注" detail={<p>可分享带依赖声明的脚本。</p>} actions={<button type="button">已收藏</button>} />)
  expect(detail).toHaveAttribute('open')
})

it('B 桌面默认呈现第二声部', () => {
  const { container } = show(true)
  expect(container.querySelector('details')).toHaveAttribute('open')
})

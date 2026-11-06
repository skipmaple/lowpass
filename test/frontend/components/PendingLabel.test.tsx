import { render, screen } from '@testing-library/react'
import { expect, it } from 'vitest'

import PendingLabel from '@/components/PendingLabel'

it('为两种文案保留尺寸，只把当前文案暴露为按钮名称', () => {
  const { rerender } = render(<button><PendingLabel idle="保存" pending="正在保存…" busy={false} reserve="更长的状态文案" /></button>)
  expect(screen.getByRole('button', { name: '保存' })).toBeInTheDocument()
  expect(screen.getByText('正在保存…')).toHaveAttribute('aria-hidden', 'true')
  expect(screen.getByText('更长的状态文案')).toHaveAttribute('aria-hidden', 'true')

  rerender(<button><PendingLabel idle="保存" pending="正在保存…" busy reserve="更长的状态文案" /></button>)
  expect(screen.getByRole('button', { name: '正在保存…' })).toBeInTheDocument()
  expect(screen.getByText('保存')).toHaveAttribute('aria-hidden', 'true')
})

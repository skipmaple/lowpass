import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import Table from '@/components/Table'

describe('Table', () => {
  it('表头与行', () => {
    render(<Table headers={['名称', '状态']} widths={['1fr', '80px']} rows={[{ key: 'a', cells: ['Hacker News', '启用'] }]} />)

    expect(screen.getByRole('table')).toBeInTheDocument()
    expect(screen.getAllByRole('columnheader').map((h) => h.textContent)).toEqual(['名称', '状态'])
    expect(screen.getAllByRole('row')).toHaveLength(2)
    expect(screen.getByText('Hacker News')).toBeInTheDocument()
  })

  it('空表显示一句', () => {
    render(<Table headers={['名称']} widths={['1fr']} rows={[]} empty="还没有来源" />)

    expect(screen.getByText('还没有来源')).toBeInTheDocument()
    expect(screen.getAllByRole('row')).toHaveLength(1)
  })
})

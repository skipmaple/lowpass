import type * as React from 'react'
import { useEffect, useState } from 'react'

// 表格（画布 pages_site.py 的 table()）：CSS grid，表头文楷 12 次墨 + 1px 墨线，行间 35% 线；单元格按角色选字体由调用方决定。
// Management pages reuse the same cells in a compact list on narrow screens, without mounting duplicate controls.
export type TableRow = { key: string; cells: React.ReactNode[] }
type MobileLayout = { primary: number[]; detailsLabel: string }

export default function Table({ headers, widths, rows, empty, className = '', mobile }: { headers: string[]; widths: string[]; rows: TableRow[]; empty?: string; className?: string; mobile?: MobileLayout }) {
  const columns = widths.join(' ')
  const [compact, setCompact] = useState(() => typeof window !== 'undefined' && window.matchMedia?.('(max-width: 1024px)').matches === true)

  useEffect(() => {
    const media = window.matchMedia?.('(max-width: 1024px)')
    if (!media) return
    const update = (event: MediaQueryListEvent) => setCompact(event.matches)
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [])

  function content(cell: React.ReactNode) {
    return cell ?? <span className="data">—</span>
  }

  if (mobile && compact) {
    return rows.length > 0 ? (
      <ul className={`management-list ${className}`}>
        {rows.map((row) => (
          <li key={row.key} className="management-row">
            <div className="management-row-primary">
              {mobile.primary.map((index) => (
                <div key={index} className="management-primary-field" data-column={index}>{content(row.cells[index])}</div>
              ))}
            </div>
            <details className="management-row-details">
              <summary>{mobile.detailsLabel}</summary>
              <dl className="management-secondary-fields">
                {row.cells.map((cell, index) => mobile.primary.includes(index) ? null : (
                  <div key={index}>
                    <dt className="management-field-label">{headers[index]}</dt>
                    <dd className="management-field-content">{content(cell)}</dd>
                  </div>
                ))}
              </dl>
            </details>
          </li>
        ))}
      </ul>
    ) : <p className="table-empty cjk">{empty}</p>
  }

  return (
    <div className="table-wrap">
      <div className={`table ${className}`} role="table">
        <div className="table-head" role="row" style={{ '--table-columns': columns } as React.CSSProperties}>
          {headers.map((header) => (
            <span key={header} role="columnheader" className="table-th">
              {header}
            </span>
          ))}
        </div>
        {rows.map((row) => (
          <div key={row.key} className="table-row" role="row" style={{ '--table-columns': columns } as React.CSSProperties}>
            {row.cells.map((cell, index) => (
              <div key={index} role="cell" className="table-td">
                <span className="table-cell-label" aria-hidden="true">{headers[index]}</span>
                <div className="table-cell-content">{content(cell)}</div>
              </div>
            ))}
          </div>
        ))}
        {/* 空表的提示不是数据行：不标 role="row"/"cell"，否则表头行 + 这一条会数成 2 个 role="row"，
            与「空表只有一句」的验收（只数出 1 个 row）矛盾。 */}
        {rows.length === 0 && empty ? (
          <div className="table-empty">
            <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: 'var(--ink2)' }}>
              {empty}
            </span>
          </div>
        ) : null}
      </div>
    </div>
  )
}

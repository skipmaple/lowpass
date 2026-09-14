import type * as React from 'react'

// 表格（画布 pages_site.py 的 table()）：CSS grid，表头文楷 12 次墨 + 1px 墨线，行间 35% 线；单元格按角色选字体由调用方决定。
// 外层 overflow-x: auto，手机横向滚而不是挤（PRD 6.4）。
export type TableRow = { key: string; cells: React.ReactNode[] }

export default function Table({ headers, widths, rows, empty }: { headers: string[]; widths: string[]; rows: TableRow[]; empty?: string }) {
  const columns = widths.join(' ')

  return (
    <div className="table-wrap">
      <div className="table" role="table">
        <div className="table-head" role="row" style={{ gridTemplateColumns: columns }}>
          {headers.map((header) => (
            <span key={header} role="columnheader" className="table-th">
              {header}
            </span>
          ))}
        </div>
        {rows.map((row) => (
          <div key={row.key} className="table-row" role="row" style={{ gridTemplateColumns: columns }}>
            {row.cells.map((cell, index) => (
              <span key={index} role="cell" className="table-td">
                {cell}
              </span>
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

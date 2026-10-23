import type * as React from 'react'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'

// 表格（画布 pages_site.py 的 table()）：CSS grid，表头文楷 12 次墨 + 1px 墨线，行间 35% 线；单元格按角色选字体由调用方决定。
// Management pages reuse the same cells in a compact list on narrow screens, without mounting duplicate controls.
export type TableRow = { key: string; cells: React.ReactNode[] }
type MobileLayout = { primary: number[]; detailsLabel: string }
type FocusPosition = { row: string | null; control: string | null; expanded: boolean | null; from: HTMLElement }
const CONTROLS = 'a[href], button, input:not([type="hidden"]), select, textarea, summary, [tabindex]'

export default function Table({ headers, widths, rows, empty, className = '', mobile }: { headers: string[]; widths: string[]; rows: TableRow[]; empty?: string; className?: string; mobile?: MobileLayout }) {
  const columns = widths.join(' ')
  const [compact, setCompact] = useState(() => typeof window !== 'undefined' && window.matchMedia?.('(max-width: 1024px)').matches === true)
  const root = useRef<HTMLElement | null>(null)
  const renderedCompact = useRef(compact)
  const pendingFocus = useRef<FocusPosition | null>(null)
  const responsive = mobile !== undefined

  useEffect(() => {
    if (!responsive) return
    const media = window.matchMedia?.('(max-width: 1024px)')
    if (!media) return
    const update = (event: MediaQueryListEvent) => {
      pendingFocus.current = event.matches === renderedCompact.current ? null : focusPosition(root.current, document.activeElement)
      setCompact(event.matches)
    }
    media.addEventListener('change', update)
    return () => media.removeEventListener('change', update)
  }, [responsive])

  useLayoutEffect(() => {
    renderedCompact.current = compact
    const position = pendingFocus.current
    pendingFocus.current = null
    if (position && root.current && (document.activeElement === document.body || document.activeElement === position.from)) {
      restoreFocus(root.current, position)
    }
  }, [compact])

  const focusEvents = {
    onFocusCapture(event: React.FocusEvent<HTMLElement>) {
      if (pendingFocus.current) pendingFocus.current = focusPosition(root.current, event.target)
    },
    onBlurCapture(event: React.FocusEvent<HTMLElement>) {
      if (event.relatedTarget instanceof Node && !root.current?.contains(event.relatedTarget)) pendingFocus.current = null
    },
  }

  function content(cell: React.ReactNode) {
    return cell ?? <span className="data">—</span>
  }

  if (mobile && compact) {
    return rows.length > 0 ? (
      <ul ref={(node) => { root.current = node }} tabIndex={-1} {...focusEvents} className={`management-list ${className}`}>
        {rows.map((row) => (
          <li key={row.key} data-table-row-key={row.key} tabIndex={-1} className="management-row">
            <div className="management-row-primary">
              {mobile.primary.map((index) => (
                <div key={index} className="management-primary-field" data-column={index}>{content(row.cells[index])}</div>
              ))}
            </div>
            <details className="management-row-details">
              <summary data-table-focus="table-details">{mobile.detailsLabel}</summary>
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
    ) : <p ref={(node) => { root.current = node }} tabIndex={-1} {...focusEvents} className="table-empty cjk">{empty}</p>
  }

  return (
    <div className="table-wrap">
      <div ref={(node) => { root.current = node }} tabIndex={-1} {...focusEvents} className={`table ${className}`} role="table">
        <div className="table-head" role="row" style={{ '--table-columns': columns } as React.CSSProperties}>
          {headers.map((header) => (
            <span key={header} role="columnheader" className="table-th">
              {header}
            </span>
          ))}
        </div>
        {rows.map((row) => (
          <div key={row.key} data-table-row-key={row.key} tabIndex={-1} className="table-row" role="row" style={{ '--table-columns': columns } as React.CSSProperties}>
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

function focusPosition(root: HTMLElement | null, active: Element | null): FocusPosition | null {
  if (root && active instanceof HTMLElement && root.contains(active)) {
    return { row: active.closest<HTMLElement>('[data-table-row-key]')?.dataset.tableRowKey ?? null, control: active.dataset.tableFocus ?? null, expanded: active.tagName === 'SUMMARY' && active.parentElement instanceof HTMLDetailsElement ? active.parentElement.open : null, from: active }
  }
  return null
}

function restoreFocus(root: HTMLElement, position: FocusPosition) {
  const row = [...root.querySelectorAll<HTMLElement>('[data-table-row-key]')].find((node) => node.dataset.tableRowKey === position.row)
  if (!row) {
    root.focus()
    return
  }

  // Callers give actions stable keys: busy labels, disabled controls and row reordering must not change their identity.
  const target = [...row.querySelectorAll<HTMLElement>('[data-table-focus]')].find((node) => node.dataset.tableFocus === position.control)
  if (target && available(target, row, true)) {
    for (let parent = target.parentElement; parent && parent !== row; parent = parent.parentElement) {
      if (parent instanceof HTMLDetailsElement && !parent.querySelector('summary')?.contains(target)) parent.open = true
    }
    if (position.expanded !== null && target.tagName === 'SUMMARY' && target.parentElement instanceof HTMLDetailsElement) target.parentElement.open = position.expanded
    target.focus()
  }
  if (document.activeElement === target) return
  // A focus handler may deliberately send focus elsewhere; only recover while the replacement left it on BODY.
  if (document.activeElement !== document.body && document.activeElement !== position.from) return
  for (const control of row.querySelectorAll<HTMLElement>(CONTROLS)) {
    if (available(control, row)) {
      control.focus()
      if (document.activeElement !== document.body && document.activeElement !== position.from) return
    }
  }
  row.focus()
}

function available(control: HTMLElement, row: HTMLElement, openAncestors = false) {
  if (control.matches(':disabled') || (control.tabIndex < 0 && control.tagName !== 'SUMMARY') || control.closest('[hidden], [inert]')) return false
  for (let node: HTMLElement | null = control; node; node = node.parentElement) {
    const style = getComputedStyle(node)
    if (style.display === 'none' || style.visibility === 'hidden' || style.visibility === 'collapse') return false
    if (!openAncestors && node instanceof HTMLDetailsElement && !node.open && !node.querySelector('summary')?.contains(control)) return false
    if (node === row) break
  }
  return true
}

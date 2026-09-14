// 表单里的分段选择（画布 seg()）：与 Seg 同样的描边块，但每项是按钮不是链接，aria-pressed 标当前项
export type SegButtonOption = { value: string; label: string; disabled?: boolean }

export default function SegButtons({ label, options, value, onChange }: { label: string; options: SegButtonOption[]; value: string; onChange: (value: string) => void }) {
  return (
    <div className="seg" role="group" aria-label={label}>
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          className="seg-item seg-button"
          aria-pressed={option.value === value}
          aria-current={option.value === value ? 'true' : undefined}
          disabled={option.disabled}
          onClick={() => onChange(option.value)}
        >
          <span className="cjk" style={{ fontSize: 'var(--fs-15)', color: option.value === value ? 'var(--paper)' : 'var(--ink)' }}>
            {option.label}
          </span>
        </button>
      ))}
    </div>
  )
}

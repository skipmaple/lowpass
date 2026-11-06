// 表单里的分段选择：与 Seg 共用主题外观，按钮用 aria-pressed 标当前项。
export type SegButtonOption = { value: string; label: string; disabled?: boolean }

export default function SegButtons({ label, options, value, onChange }: { label: string; options: SegButtonOption[]; value: string; onChange: (value: string) => void }) {
  return (
    <div className="seg seg-buttons" role="group" aria-label={label}>
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
          <span className="cjk" style={{ fontSize: 'var(--fs-15)' }}>
            {option.label}
          </span>
        </button>
      ))}
    </div>
  )
}

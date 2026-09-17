import { useId } from 'react'

import Icon from '@/components/Icon'

// 表单字段（画布 field()）：文楷 13 标签在上，至少 44px 描边框，Maple 值（mono）或文楷值，说明与错误文楷 13 次墨
export type FieldProps = {
  label: string
  name: string
  value: string
  onChange: (value: string) => void
  note?: string
  error?: string
  mono?: boolean
  type?: 'text' | 'url' | 'number' | 'time'
  min?: number
  max?: number
  step?: number | 'any'
  readOnly?: boolean
  required?: boolean
  width?: number | string
  placeholder?: string
}

export default function Field({ label, name, value, onChange, note, error, mono = false, type = 'text', required = false, width, placeholder, min, max, step, readOnly }: FieldProps) {
  const id = useId()

  return (
    <div className="field" style={width ? { width } : undefined}>
      <label className="field-label" htmlFor={id}>
        {label}{required ? <span className="field-note" aria-hidden="true">（必填）</span> : null}
      </label>
      <input
        id={id}
        aria-label={label}
        className={mono ? 'field-input' : 'field-input field-input-cjk'}
        name={name}
        type={type}
        value={value}
        required={required}
        min={min}
        max={max}
        step={step}
        readOnly={readOnly}
        inputMode={type === 'number' ? (step === 'any' ? 'decimal' : 'numeric') : undefined}
        placeholder={placeholder}
        aria-invalid={error ? true : undefined}
        aria-describedby={error || note ? `${id}-note` : undefined}
        onChange={(event) => onChange(event.target.value)}
      />
      {error ? (
        <span id={`${id}-note`} className="notice-line">
          <Icon name="triangle-alert" size={14} color="var(--ink2)" />
          <span>{error}</span>
        </span>
      ) : note ? (
        <span id={`${id}-note`} className="field-note">
          {note}
        </span>
      ) : null}
    </div>
  )
}

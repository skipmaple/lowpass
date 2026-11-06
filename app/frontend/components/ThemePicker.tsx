import { useId } from 'react'
import { THEMES, useTheme } from '@/lib/theme'

export default function ThemePicker({ compact = false }: { compact?: boolean }) {
  const { theme, setTheme } = useTheme()
  const group = useId()
  return (
    <fieldset className="theme-picker" data-compact={compact || undefined}>
      <legend>{compact ? '阅读外观' : '阅读主题'}</legend>
      <div className="theme-choices">
        {THEMES.map((option) => (
          <label key={option.id} className="theme-choice" data-preview={option.id}>
            <input type="radio" name={group} value={option.id} checked={theme === option.id} onChange={() => setTheme(option.id)} />
            {compact ? null : (
              <span className="theme-swatch" aria-hidden="true">
                <span className="theme-swatch-brand">{option.letter}</span>
                <span className="theme-swatch-lines"><span /><span /></span>
                <span className="theme-swatch-rail" />
              </span>
            )}
            <span><strong>{option.name}</strong>{compact ? null : <small>{option.description}</small>}</span>
          </label>
        ))}
      </div>
    </fieldset>
  )
}

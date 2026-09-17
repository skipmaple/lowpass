import type { FormDataType } from '@inertiajs/core'
import { router, useForm, usePage } from '@inertiajs/react'
import { useCallback, useEffect, useRef, useState } from 'react'

import type { SharedProps } from '@/types/lowpass'

export function useDraftAccount() {
  // Administrators are identified by their allowlisted email. Never restore a
  // shared anonymous draft when the authenticated identity is unavailable.
  return usePage<SharedProps>().props.current_user?.email ?? null
}

function readDraft<T>(key: string | null, initial: T): { data: T; conflicted: boolean } {
  const clean = { data: initial, conflicted: false }
  if (!key) return clean
  try {
    const saved = JSON.parse(sessionStorage.getItem(key) ?? 'null')
    if (saved?.data && typeof saved.data === 'object') {
      const changed = JSON.stringify(saved.baseline) !== JSON.stringify(initial)
      const alreadySaved = JSON.stringify(saved.data) === JSON.stringify(initial)
      return { data: saved.data as T, conflicted: !alreadySaved && (changed || saved.conflicted === true) }
    }
  } catch { /* Storage can be unavailable; editing and leave protection still work. */ }
  return clean
}

export function useDraftForm<T extends FormDataType<T>>(resource: string, initial: T) {
  const account = useDraftAccount()
  const key = account ? `lowpass:draft:${account}:${resource}` : null
  const [restored] = useState(() => readDraft(key, initial))
  const form = useForm<T>(restored.data)
  const [conflicted, setConflicted] = useState(restored.conflicted)
  const [baseline, setBaseline] = useState(initial)
  const isDirty = JSON.stringify(form.data) !== JSON.stringify(baseline)

  useEffect(() => {
    if (!key) return
    try {
      if (isDirty) sessionStorage.setItem(key, JSON.stringify({ baseline, data: form.data, conflicted }))
      else sessionStorage.removeItem(key)
    } catch { /* Disabled or full browser storage must not break a form. */ }
  }, [key, baseline, form.data, isDirty, conflicted])

  function accept(data: T = form.data) {
    setBaseline(data)
    setConflicted(false)
    form.setDefaults(data)
    if (key) {
      try { sessionStorage.removeItem(key) } catch { /* See above. */ }
    }
  }

  return { ...form, isDirty, conflicted, accept }
}

// One listener for the whole page: multiple dirty rows produce one confirmation.
// Only the synchronous dispatch of our own mutation/reload bypasses it. A user
// navigation while that request is pending must still protect the other drafts.
export function useUnsavedChanges(dirty: boolean) {
  const internal = useRef(false)
  useEffect(() => {
    if (!dirty) return
    function unload(event: BeforeUnloadEvent) {
      event.preventDefault()
      event.returnValue = ''
    }
    window.addEventListener('beforeunload', unload)
    const remove = router.on('before', (event) => {
      if (!internal.current && !window.confirm('更改尚未保存，确认离开？')) event.preventDefault()
    })
    return () => { window.removeEventListener('beforeunload', unload); remove() }
  }, [dirty])

  return useCallback((action: () => void) => {
    internal.current = true
    try { action() } finally { internal.current = false }
  }, [])
}

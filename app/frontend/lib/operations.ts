import type { VisitOptions } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'

// Requests are independent by operation and target. A redirect only acknowledges
// submission; background completion remains the responsibility of useManualRuns.
export function useAdminOperations(reloadOnly: string[] = []) {
  const mounted = useRef(true)
  const refresh = useRef<{ cancel: () => void } | null>(null)
  useEffect(() => {
    mounted.current = true
    return () => { mounted.current = false; refresh.current?.cancel() }
  }, [])
  const pending = useRef(new Set<string>())
  const [states, setStates] = useState<Record<string, { busy: boolean; error?: string }>>({})

  function submit(method: 'post' | 'delete', key: string, target: string, url: string, data: Record<string, string> = {}) {
    if (pending.current.has(key)) return
    refresh.current?.cancel()
    refresh.current = null
    pending.current.add(key)
    setStates((current) => ({ ...current, [key]: { busy: true } }))
    const fail = (message: string) => setStates((current) => ({ ...current, [key]: { busy: false, error: `${target} · ${message}` } }))
    const options: VisitOptions = {
      preserveScroll: true,
      preserveState: true,
      async: true,
      // A delayed mutation response must not restore another row's old state.
      // Refresh the list once all outstanding mutations have settled.
      only: ['flash', 'errors'],
      onError: (errors) => fail(Object.values(errors).join('；') || '请求失败，请重试。'),
      onHttpException: () => { fail('请求失败，请重试。'); return false },
      onNetworkError: () => { fail('网络连接失败，请重试。'); return false },
      onCancel: () => fail('请求已取消，请重试。'),
      onFinish: () => {
        pending.current.delete(key)
        setStates((current) => ({ ...current, [key]: { ...current[key], busy: false } }))
        if (pending.current.size === 0 && mounted.current) {
          router.reload({ only: reloadOnly, onCancelToken: (token) => { refresh.current = token } })
        }
      },
    }
    if (method === 'post') router.post(url, data, options)
    else router.delete(url, options)
  }

  const post = (key: string, target: string, url: string, data: Record<string, string> = {}) => submit('post', key, target, url, data)
  const remove = (key: string, target: string, url: string) => submit('delete', key, target, url)

  return { post, remove, busy: (key: string) => states[key]?.busy ?? false, errors: Object.entries(states).filter(([, state]) => state.error).map(([key, state]) => ({ key, text: state.error! })) }
}

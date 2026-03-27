import { useState, useEffect, useCallback, useRef } from 'react'
import { useJacClient } from './context'

// ─── useWalker ──────────────────────────────────────────────

export interface UseWalkerOptions<T = any> {
  /** Arguments to pass to the walker */
  args?: Record<string, any>
  /** Run the walker immediately on mount (default: true) */
  immediate?: boolean
  /** Re-run when these deps change (shallow compare) */
  deps?: any[]
  /** Transform the result before storing */
  transform?: (data: any) => T
}

export interface UseWalkerResult<T = any> {
  data: T | null
  loading: boolean
  error: string | null
  /** Manually trigger the walker (overrides args if provided) */
  run: (args?: Record<string, any>) => Promise<T>
  /** Reset to initial state */
  reset: () => void
}

/**
 * Call a Jac walker and manage its state.
 *
 * ```tsx
 * const { data, loading, error, run } = useWalker('get_dashboard')
 * const { data: agent } = useWalker('get_agent_detail', { args: { name: 'researcher' } })
 * const { run: createAgent } = useWalker('create_agent', { immediate: false })
 * ```
 */
export function useWalker<T = any>(
  name: string,
  options: UseWalkerOptions<T> = {}
): UseWalkerResult<T> {
  const { args, immediate = true, deps = [], transform } = options
  const client = useJacClient()
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(immediate)
  const [error, setError] = useState<string | null>(null)
  const mountedRef = useRef(true)

  useEffect(() => {
    mountedRef.current = true
    return () => { mountedRef.current = false }
  }, [])

  const run = useCallback(async (overrideArgs?: Record<string, any>) => {
    setLoading(true)
    setError(null)
    try {
      const result = await client.callWalker<T>(name, overrideArgs || args || {})
      const transformed = transform ? transform(result as any) : result
      if (mountedRef.current) {
        setData(transformed)
        setLoading(false)
      }
      return transformed
    } catch (e: any) {
      if (mountedRef.current) {
        setError(e.message || 'Walker call failed')
        setLoading(false)
      }
      throw e
    }
  }, [client, name, JSON.stringify(args)])

  const reset = useCallback(() => {
    setData(null)
    setLoading(false)
    setError(null)
  }, [])

  useEffect(() => {
    if (immediate) { run().catch(() => {}) }
  }, [immediate, run, ...deps])

  return { data, loading, error, run, reset }
}


// ─── useAuth ────────────────────────────────────────────────

export interface UseAuthResult {
  /** Whether a token exists */
  isAuthenticated: boolean
  /** Current token (or null) */
  token: string | null
  /** Login — returns true on success */
  login: (username: string, password: string) => Promise<boolean>
  /** Register — returns { success, error? } */
  register: (username: string, password: string) => Promise<{ success: boolean; error?: string }>
  /** Register + auto-login */
  registerAndLogin: (username: string, password: string) => Promise<boolean>
  /** Logout — clears token */
  logout: () => void
}

/**
 * Manage Jac authentication state.
 *
 * ```tsx
 * const { isAuthenticated, login, logout } = useAuth()
 *
 * if (!isAuthenticated) {
 *   return <button onClick={() => login('user', 'pass')}>Login</button>
 * }
 * ```
 */
export function useAuth(): UseAuthResult {
  const client = useJacClient()
  const [token, setToken] = useState<string | null>(client.getToken())

  const login = useCallback(async (username: string, password: string) => {
    const success = await client.login(username, password)
    if (success) setToken(client.getToken())
    return success
  }, [client])

  const register = useCallback(async (username: string, password: string) => {
    return client.register(username, password)
  }, [client])

  const registerAndLogin = useCallback(async (username: string, password: string) => {
    const reg = await client.register(username, password)
    if (!reg.success) return false
    return login(username, password)
  }, [client, login])

  const logout = useCallback(() => {
    client.logout()
    setToken(null)
  }, [client])

  return {
    isAuthenticated: !!token,
    token,
    login,
    register,
    registerAndLogin,
    logout,
  }
}


// ─── useGraph ───────────────────────────────────────────────

export interface UseGraphOptions {
  /** Walker to call for graph data (default: 'get_agent_graph') */
  walker?: string
  /** Args to pass to the walker */
  args?: Record<string, any>
  /** Auto-refresh interval in ms (0 = disabled) */
  refreshInterval?: number
}

export interface GraphData {
  nodes: any[]
  edges: any[]
}

export interface UseGraphResult {
  nodes: any[]
  edges: any[]
  loading: boolean
  error: string | null
  refresh: () => Promise<void>
}

/**
 * Fetch and manage graph data from a Jac walker.
 *
 * ```tsx
 * const { nodes, edges, loading, refresh } = useGraph()
 * const { nodes } = useGraph({ walker: 'get_workspace_graph', refreshInterval: 5000 })
 * ```
 */
export function useGraph(options: UseGraphOptions = {}): UseGraphResult {
  const { walker = 'get_agent_graph', args = {}, refreshInterval = 0 } = options
  const { data, loading, error, run } = useWalker<GraphData>(walker, {
    args,
    transform: (d: any) => ({
      nodes: d?.nodes || [],
      edges: d?.edges || [],
    }),
  })

  const refresh = useCallback(async () => { await run(args) }, [run, args])

  useEffect(() => {
    if (!refreshInterval) return
    const id = setInterval(refresh, refreshInterval)
    return () => clearInterval(id)
  }, [refresh, refreshInterval])

  return {
    nodes: data?.nodes || [],
    edges: data?.edges || [],
    loading,
    error,
    refresh,
  }
}


// ─── useStream ──────────────────────────────────────────────

export interface UseStreamOptions {
  /** Base URL for the streaming API (default: same as JacProvider url) */
  url?: string
}

export interface StreamEvent {
  type: string
  step?: number
  data?: any
}

export interface UseStreamResult {
  /** Whether a stream is currently active */
  streaming: boolean
  /** Accumulated trace events */
  trace: any[]
  /** Final result (set when stream completes) */
  result: any | null
  /** Error message if stream failed */
  error: string | null
  /** Start a streaming workflow run */
  start: (inputName: string, payload?: Record<string, any>) => Promise<void>
  /** Abort the current stream */
  abort: () => void
}

/**
 * Subscribe to streaming workflow execution via SSE.
 *
 * ```tsx
 * const { streaming, trace, result, start } = useStream()
 *
 * <button onClick={() => start('content-pipeline', { topic: 'AI' })}>
 *   Run Workflow
 * </button>
 * ```
 */
export function useStream(options: UseStreamOptions = {}): UseStreamResult {
  const client = useJacClient()
  const [streaming, setStreaming] = useState(false)
  const [trace, setTrace] = useState<any[]>([])
  const [result, setResult] = useState<any>(null)
  const [error, setError] = useState<string | null>(null)
  const esRef = useRef<EventSource | null>(null)

  const abort = useCallback(() => {
    esRef.current?.close()
    esRef.current = null
    setStreaming(false)
  }, [])

  const start = useCallback(async (inputName: string, payload: Record<string, any> = {}) => {
    abort()
    setTrace([])
    setResult(null)
    setError(null)
    setStreaming(true)

    const baseUrl = options.url || ''

    try {
      // Start the run
      const res = await fetch(`${baseUrl}/api/workflow/run`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ input_name: inputName, payload }),
      })
      const { run_id } = await res.json()

      // Connect SSE
      const es = new EventSource(`${baseUrl}/api/workflow/stream/${run_id}`)
      esRef.current = es

      es.addEventListener('trace', (e) => {
        const data = JSON.parse(e.data)
        setTrace(prev => [...prev, data.data || data])
      })

      es.addEventListener('complete', (e) => {
        const data = JSON.parse(e.data)
        setResult(data)
        setStreaming(false)
        es.close()
        esRef.current = null
      })

      es.addEventListener('error', () => {
        setError('Stream connection lost')
        setStreaming(false)
        es.close()
        esRef.current = null
      })
    } catch (e: any) {
      setError(e.message || 'Failed to start stream')
      setStreaming(false)
    }
  }, [abort, options.url])

  // Cleanup on unmount
  useEffect(() => () => { esRef.current?.close() }, [])

  return { streaming, trace, result, error, start, abort }
}

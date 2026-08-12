/**
 * Jac API client — handles auth, walker calls, and response unwrapping.
 *
 * Zero-config by default:
 * - URL defaults to same-origin (works behind jac start or any proxy)
 * - Token auto-picked from localStorage (same key as jac-client: 'jac_token')
 * - Auth auto-handled on 401 responses
 */

export interface JacClientConfig {
  /** Base URL of the Jac server. Defaults to '' (same-origin — works with jac start) */
  url?: string
  /** localStorage key for auth token. Defaults to 'jac_token' (same as jac-client) */
  tokenKey?: string
}

const DEFAULT_TOKEN_KEY = 'jac_token'

export class JacClient {
  private url: string
  private tokenKey: string
  private token: string | null = null

  constructor(config: JacClientConfig = {}) {
    this.url = (config.url || '').replace(/\/$/, '')
    this.tokenKey = config.tokenKey || DEFAULT_TOKEN_KEY
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem(this.tokenKey)
    }
  }

  getToken(): string | null { return this.token }

  setToken(token: string | null) {
    this.token = token
    if (typeof window !== 'undefined') {
      if (token) localStorage.setItem(this.tokenKey, token)
      else localStorage.removeItem(this.tokenKey)
    }
  }

  isAuthenticated(): boolean { return !!this.token }

  async login(username: string, password: string): Promise<boolean> {
    const res = await fetch(`${this.url}/user/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    })
    const data = await res.json()
    if (data.ok && data.data?.token) {
      this.setToken(data.data.token)
      return true
    }
    return false
  }

  async register(username: string, password: string): Promise<{ success: boolean; error?: string }> {
    const res = await fetch(`${this.url}/user/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    })
    const data = await res.json()
    if (data.ok || res.ok) return { success: true }
    return { success: false, error: data.error?.message || 'Registration failed' }
  }

  logout() { this.setToken(null) }

  /** Call a walker. Auto-attaches auth, unwraps reports. */
  async callWalker<T = any>(name: string, body: Record<string, any> = {}): Promise<T> {
    const res = await fetch(`${this.url}/walker/${name}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
      },
      body: JSON.stringify(body),
    })
    if (res.status === 401) {
      this.setToken(null)
      throw new Error('Authentication expired. Please login again.')
    }
    const data = await res.json()
    if (!data.ok) throw new Error(data.error?.message || `Walker '${name}' failed`)
    const reports = data.data?.reports || []
    return (reports.length === 1 ? reports[0] : reports) as T
  }

  /** Spawn a walker on a specific node by anchor ID. */
  async spawnWalker<T = any>(walkerName: string, nodeId: string, body: Record<string, any> = {}): Promise<T> {
    const res = await fetch(`${this.url}/walker/${walkerName}/${nodeId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
      },
      body: JSON.stringify(body),
    })
    if (res.status === 401) {
      this.setToken(null)
      throw new Error('Authentication expired. Please login again.')
    }
    const data = await res.json()
    if (!data.ok) throw new Error(data.error?.message || `Walker '${walkerName}' failed`)
    const reports = data.data?.reports || []
    return (reports.length === 1 ? reports[0] : reports) as T
  }
}

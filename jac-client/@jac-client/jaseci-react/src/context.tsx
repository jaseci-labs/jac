import { createContext, useContext, useMemo, type ReactNode } from 'react'
import { JacClient, type JacClientConfig } from './client'

/** Global default client — zero-config, same-origin, same token key as jac-client */
let _defaultClient: JacClient | null = null

function getDefaultClient(): JacClient {
  if (!_defaultClient) _defaultClient = new JacClient()
  return _defaultClient
}

const JacContext = createContext<JacClient | null>(null)

export interface JacProviderProps extends JacClientConfig {
  children: ReactNode
}

/**
 * Optional provider — only needed to customize server URL or token key.
 * Without it, hooks auto-connect to same-origin (works with jac start).
 *
 * ```tsx
 * // Zero-config — no provider needed
 * function App() {
 *   const { data } = useWalker('get_dashboard')
 * }
 *
 * // Custom server
 * <JacProvider url="https://api.myapp.com">
 *   <App />
 * </JacProvider>
 * ```
 */
export function JacProvider({ children, ...config }: JacProviderProps) {
  const client = useMemo(() => new JacClient(config), [config.url, config.tokenKey])
  return <JacContext.Provider value={client}>{children}</JacContext.Provider>
}

/**
 * Get the JacClient. Uses provider if available, otherwise
 * falls back to default same-origin client (zero-config).
 */
export function useJacClient(): JacClient {
  const fromContext = useContext(JacContext)
  return fromContext || getDefaultClient()
}

// Core client
export { JacClient, type JacClientConfig } from './client'

// React context provider
export { JacProvider, useJacClient, type JacProviderProps } from './context'

// Hooks
export {
  useWalker,
  useAuth,
  useGraph,
  useStream,
  type UseWalkerOptions,
  type UseWalkerResult,
  type UseAuthResult,
  type UseGraphOptions,
  type UseGraphResult,
  type UseStreamOptions,
  type UseStreamResult,
  type StreamEvent,
  type GraphData,
} from './hooks'

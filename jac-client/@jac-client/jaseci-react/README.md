# @jaseci/react

React hooks for Jac backends. Zero config - just import and use.

## Install

```bash
npm install @jaseci/react
```

## Quick Start

No provider, no URL, no setup. Works instantly with `jac start` (same-origin):

```tsx
import { useWalker } from '@jaseci/react'

function Dashboard() {
  const { data, loading } = useWalker('get_dashboard')
  if (loading) return <p>Loading...</p>
  return <pre>{JSON.stringify(data, null, 2)}</pre>
}
```

That's it. The hooks auto-connect to the Jac server on the same origin and share the same auth token as jac-client (`jac_token` in localStorage).

## Hooks

### `useWalker(name, options?)`

Call any Jac walker and manage its state.

```tsx
// Fetch on mount
const { data, loading, error } = useWalker('get_agents')

// With arguments
const { data } = useWalker('get_agent_detail', { args: { name: 'researcher' } })

// Manual trigger (don't fetch on mount)
const { run } = useWalker('create_agent', { immediate: false })
await run({ name: 'my-agent', model: 'claude-sonnet-4-20250514' })

// Transform result
const { data: names } = useWalker('get_agents', {
  transform: (agents) => agents.map(a => a.name)
})
```

### `useAuth()`

Manage Jac authentication.

```tsx
const { isAuthenticated, login, logout, register, registerAndLogin } = useAuth()

await login('username', 'password')
await registerAndLogin('newuser', 'password')
logout()
```

### `useGraph(options?)`

Fetch graph data (nodes + edges).

```tsx
const { nodes, edges, loading, refresh } = useGraph()

// Custom walker + auto-refresh
const { nodes } = useGraph({ walker: 'get_workspace_graph', refreshInterval: 5000 })
```

### `useStream(options?)`

Subscribe to streaming workflow execution via SSE.

```tsx
const { streaming, trace, result, start, abort } = useStream()

await start('content-pipeline', { topic: 'AI agents' })
// trace updates in real-time as nodes execute
```

## Full Example

```tsx
import { useWalker, useAuth, useGraph, useStream } from '@jaseci/react'

function App() {
  const { isAuthenticated, login } = useAuth()

  if (!isAuthenticated) {
    return <LoginForm onLogin={login} />
  }

  return <AgentDashboard />
}

function AgentDashboard() {
  const { data: dashboard, loading } = useWalker('get_dashboard')
  const { nodes, edges } = useGraph()
  const { run: createAgent } = useWalker('create_agent', { immediate: false })
  const { streaming, trace, start } = useStream()

  if (loading) return <p>Loading...</p>

  return (
    <div>
      <h1>Agents: {dashboard?.agents?.length || 0}</h1>
      <h2>Graph: {nodes.length} nodes, {edges.length} edges</h2>

      <button onClick={() => createAgent({ name: 'new-agent', model: 'gpt-4o' })}>
        Create Agent
      </button>

      <button onClick={() => start('content-pipeline', { topic: 'AI' })}>
        Run Workflow {streaming && '(running...)'}
      </button>

      {trace.map((t, i) => <div key={i}>{t.node}: {t.status}</div>)}
    </div>
  )
}
```

## Advanced: Custom Server URL

Only needed when the Jac server is on a different origin:

```tsx
import { JacProvider, useWalker } from '@jaseci/react'

function App() {
  return (
    <JacProvider url="https://api.myapp.com">
      <Dashboard />
    </JacProvider>
  )
}
```

## How It Works

- **Zero-config**: Hooks auto-create a client pointing at same-origin (`/walker/*`, `/user/*`)
- **Shared auth**: Uses `jac_token` in localStorage - same key as jac-client, so auth is shared
- **Auto-unwrap**: Walker responses are unwrapped from `data.reports[]` automatically
- **Token refresh**: 401 responses clear the token and surface an error

## License

MIT

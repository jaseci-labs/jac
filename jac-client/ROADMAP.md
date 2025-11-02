1. Relative path resolving - @Jason
2. Bundler Plugin - Done

4. Dev mode with HRM
5. OSP in FE

----Runtime---
[DONE]
1. Basic JSX factory and React.createElement integration - Done
    a.(supports spread props, fragments) - Done
2. React 18 createRoot rendering - Done
3. Custom signal-based state management (createSignal, createState) - [Improvement needed: computed signals, deep updates]
4. Effects system (createEffect with dependency tracking) - [Improvement needed: cleanup functions, explicit deps]
5. Hash-based routing with initRouter and navigation - [Improvement needed: history taps routing, route params]
6. Link component for declarative navigation - [Improvement needed: active state, CSS classes]
7. Server communication (walker spawning, function calls) - [Improvement needed: retry logic, timeouts]
8. Authentication helpers (login, logout, signup) - [Improvement needed: token refresh, error handling]
9. Local storage utilities - Done
10. Module registration and hydration system - Done
11. Basic event handling (onClick in props) - [Improvement needed: all event types, synthetic events]
12. Batched re-rendering with requestAnimationFrame - Done

[TO DO - High-Level Features for Python Devs]
13. Global state management (simple shared state across components)
14. Component composition and props system (easy prop passing like Python kwargs)
15. Form handling and validation (high-level form state)
16. Data fetching/loading states (simple async data management)
17. Error handling patterns (try-catch style for components)
18. Component lifecycle helpers (onMount, onUnmount convenience functions)
19. List rendering utilities (map over arrays easily)
20. Event handling helpers (simplified click, change, submit events)
21. Computed/derived values (like Python properties)
22. Context/scope helpers (share data without prop drilling)
23. Conditional rendering utilities (if-else for components)
24. Fragment shorthand for list rendering
25. Component memoization (auto-optimization where needed)
26. Async component support (await in components)
27. Server-side state sync (seamless backend integration)
28. Dev tools and debugging helpers (inspect state, trace renders)

----CLI-----
1.  CLI as a plugin - Done

---
3. Library agnostic - Low prio
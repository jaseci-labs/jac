"""Jac client devtools overlay runtime.

Injected on top of the running app in dev only. The overlay renders in its own
React root inside a Shadow DOM, so it is fully isolated from the host app in
both directions: the app's stylesheet cannot restyle the overlay, the overlay's
styles cannot leak into the app, and a crash in either React tree cannot take
down the other.

This module is only bundled when the devtools overlay is enabled
(see `JacClientConfig.is_devtools_enabled`); a production `jac build` omits it
entirely.

The overlay is a small panel framework: a draggable, dismissible shell with a
tab bar driven by a panel registry. New panels are added by extending the
registry in `DevtoolsPanelShell`. The first panel is `EnvPanel`.
"""

import from 'react' { * as React }
import from 'react' {
    useState as reactUseState,
    useEffect as reactUseEffect,
    useRef as reactUseRef
}
import from 'react-dom/client' { * as ReactDOM }

"""Jac brand palette (orange / white / black) shared across the overlay.

Returned from a function rather than a module `glob` because a standalone
client runtime module does not emit `glob` values into its compiled output.
"""
def _jacColors -> dict;

"""Mount the devtools overlay in an isolated Shadow-DOM React root on `document.body`.

Idempotent: a second call is a no-op (guards on a `window` flag) so an HMR
re-run of the entry script does not stack multiple overlays.
"""
def:pub mountDevtools -> None;

"""Top-level overlay: a floating toggle button that opens the panel shell."""
def:pub DevtoolsOverlay -> JsxElement;

"""The panel shell: a draggable, minimizable, tabbed container.

`props.onClose` closes the shell. Panels come from an in-component registry.
"""
def:pub DevtoolsPanelShell(props: dict) -> JsxElement;

"""Environment panel: route, mounted module/entry, viewport, and runtime info."""
def:pub EnvPanel -> JsxElement;

"""Network panel: passively captured walker/function HTTP calls (newest first)."""
def:pub NetworkPanel -> JsxElement;

"""Install a passive `window.fetch` wrapper that records Jac walker/function calls.

The wrapper is pure pass-through: it returns the original fetch promise unchanged
and only records via side-effect handlers, so it can never alter call behavior.
Idempotent (guards on a `window` flag).
"""
def _installNetworkCapture -> None;

"""The fetch wrapper installed by `_installNetworkCapture`."""
def _jacDevtoolsFetch(input: any, opts: any = None) -> any;

"""Runtime hook: records a cached endpoint call (a cache hit does not fetch).

Installed as `window.__jacDevtoolsOnCall` and invoked by the client runtime's
`__cachedEndpointCall`, so repeat calls served from cache still show up.
"""
def _jacDevtoolsOnCall(info: dict) -> None;

"""Extract a friendly call name (the segment after /walker/ or /function/)."""
def _jacCallName(url: str) -> str;

"""Append a captured request to the (capped) ring buffer and notify listeners."""
def _recordNetworkEntry(rec: dict) -> None;

"""Dispatch the event the Network panel listens on to refresh."""
def _dispatchNetworkUpdate -> None;

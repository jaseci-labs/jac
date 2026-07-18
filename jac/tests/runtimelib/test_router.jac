"""Test the canonical `@jac/runtime` routing surface.

Routing is React Router v6-shaped and backed by react-router-dom in the single
canonical client runtime (`jaclang/runtimelib/client_runtime.cl.jac`). The old
bare-serve DOM router (popstate/pushState/createSignal path-signal) has been
removed in favour of one React-backed runtime, so these tests verify the
runtime exposes the routing surface the compiler emits against rather than
inspecting a hand-rolled bundle.
"""

import from pathlib { Path }
import jaclang;

glob RUNTIME_SRC = (
         Path(jaclang.__file__).resolve().parent / "runtimelib" / "client_runtime.cl.jac"
     ).read_text();

test "runtime exposes the React Router v6 routing surface" {
    routing_surface = [
        "Router",
        "Routes",
        "Route",
        "Link",
        "Navigate",
        "Outlet",
        "useNavigate",
        "useLocation",
        "useParams",
        "useRouter",
        "navigate"
    ];
    for sym in routing_surface {
        assert sym in RUNTIME_SRC , f"routing surface symbol '{sym}' missing from @jac/runtime";
    }
}

test "runtime routing is react-router-backed" {
    assert "react-router-dom" in RUNTIME_SRC , "routing should be backed by react-router-dom";
    # The removed bare-serve DOM-router internals must not reappear.
    assert "__jacGetHashPath" not in RUNTIME_SRC;
    assert "__jacGetPath" not in RUNTIME_SRC;
}

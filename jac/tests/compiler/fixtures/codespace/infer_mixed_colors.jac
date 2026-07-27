"""Two inference colors in one markerless module.

The npm import and JSX seed client; the extern-decl import seeds native;
each side pulls its own dependencies. A declaration referenced by BOTH
sides is a conflict and stays on the server, where the existing bridges
(auto-RPC for client, py-interop for native) can reach it from either side.
"""

import from "clsx" { clsx }

import from fastlib { def fast_mix(a: i64, b: i64) -> i64;  }

def shared_const -> int {
    return 7;
}

def native_calc -> int {
    return fast_mix(shared_const(), 2);
}

def:pub app -> JsxElement {
    return <div class={clsx(["x"])}>{shared_const()}</div>;
}

def styled_len -> int {
    return len(clsx(["a", "b"]));
}

def render_mixed -> int {
    return int(fast_mix(styled_len(), 1));
}

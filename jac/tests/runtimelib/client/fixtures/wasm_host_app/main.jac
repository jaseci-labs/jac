# Regression fixture for issue #7189: a fullstack app whose client code imports
# the versioned `jac_host1` provider from `@jac/wasm_host` (added in #7136). The
# vite client build must resolve that specifier to the runtime's provider
# (`runtimelib/wasm_host.cl.jac`); before the fix it was left a bare specifier
# and the build failed with a Rollup "failed to resolve import" error.
#
# There is deliberately no `na {}` block here: the resolution failure happens at
# the vite bundle step, before any na->wasm emission, so the fixture reproduces
# the bug without needing the wasm toolchain.
walker:pub ping_server {
    can ping with Root entry {
        report "pong";
    }
}

cl {
    import from "@jac/wasm_host" { instantiate_na_wasm }

    def:pub app -> JsxElement {
        has status: str = "idle";

        # References instantiate_na_wasm so the `@jac/wasm_host` import survives
        # tree-shaking and reaches the vite resolve step.
        async def boot {
            sh = {};
            await instantiate_na_wasm("/static/app.wasm", sh);
            status = "booted";
        }

        return
            <div style={{"padding": "1rem", "fontFamily": "system-ui, sans-serif"}}>
                <button data-testid="boot" onClick={lambda (e: any) { boot(); }}>
                    Boot wasm
                </button>
                <span data-testid="status">{status}</span>
            </div>;
    }
}

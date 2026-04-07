"""Regression: an `Any`-typed callee must emit a plain call, not `new`.

Background: `Any` is internally represented as a `ClassType` with the
`Instance` flag (not `Instantiable`). Before the fix, the ES codegen
emitted `new handler(payload)` for any callee whose type was a
`ClassType`, which broke async callbacks typed as `Any`.
"""

import from typing { Any }

cl {
    async def invoke_any_async(handler: Any, payload: dict) {
        await handler(payload);
    }

    def invoke_any_sync(handler: Any, payload: dict) {
        handler(payload);
    }
}

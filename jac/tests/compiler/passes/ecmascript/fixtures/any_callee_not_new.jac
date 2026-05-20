"""Regression: an `Any`-typed callee must emit a plain call, not `new`.

Background: `Any` is internally represented as a `ClassType` with the
`Instance` flag (not `Instantiable`). Before the fix, the ES codegen
emitted `new handler(payload)` for any callee whose type was a
`ClassType`, which broke async callbacks typed as `Any`.
"""


cl {
    async def invoke_any_async(handler: any, payload: dict) {
        await handler(payload);
    }

    def invoke_any_sync(handler: any, payload: dict) {
        handler(payload);
    }
}

"""Implementation for MTP constructs."""

"""Convert to runtime context."""
@ property
impl MTIR.runtime(self: MTIR) -> MTRuntime {
    return MTRuntime.factory(self.caller, self.args, self.call_params);
}

impl ClassInfo.postinit(self: ClassInfo) -> object {
    if (self.fields is None) {
        self.fields = [];
    }
    if (self.base_classes is None) {
        self.base_classes = [];
    }
    if (self.methods is None) {
        self.methods = [];
    }
}

impl FunctionInfo.postinit(self: FunctionInfo) -> object {
    if (self.params is None) {
        self.params = [];
    }
    if (self.tools is None) {
        self.tools = [];
    }
}

impl IntrinsicEntry.arity -> int {
    return len(self.param_specs);
}

impl IntrinsicRegistry.get(name: str) -> IntrinsicEntry | None {
    return self._entries.get(name, None);
}

impl IntrinsicRegistry.is_intrinsic(name: str) -> bool {
    return name in self._entries;
}

impl IntrinsicRegistry.entries -> list[IntrinsicEntry] {
    return list(self._entries.values());
}

"""Implementation for helpers."""

"""Initialize the Jac debugger."""
impl Jdb.init(self: Jdb, *args: Any, **kwargs: Any) -> None {
    super.init(*args, **kwargs);
    self.prompt = 'Jdb > ';
}

"""Check for breakpoint."""
impl Jdb.has_breakpoint(self: Jdb, bytecode: bytes) -> bool {
    code = marshal.loads(bytecode);
    instructions = dis.get_instructions(code);
    return `any(
        (
            (instruction.opname in ('LOAD_GLOBAL', 'LOAD_NAME', 'LOAD_FAST'))
            and (instruction.argval == 'breakpoint')
        ) for instruction in instructions
    );
}

"""Get the distribution/package name."""
impl DistFacade.project_name(self: DistFacade) -> str {
    return self._dist.name if (self._dist and self._dist?.name) else 'unknown';
}

"""Get the distribution version."""
impl DistFacade.version(self: DistFacade) -> str {
    return self._dist.version if (self._dist and self._dist?.version) else '0.0.0';
}

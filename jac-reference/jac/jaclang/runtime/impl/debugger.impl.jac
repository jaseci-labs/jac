impl Jdb.init(self: Jdb, *args: any, **kwargs: any) -> None {
    super.init(*args, **kwargs);
    self.prompt = 'Jdb > ';
}

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

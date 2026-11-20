obj Anchor(ArchetypeProtocol) {
    has ob: object,
        ds_entry_funcs: list[DSFunc],
        ds_exit_funcs: list[DSFunc],
        jid: UUID = :> uuid4(),
        timestamp: datetime = :> datetime.now,
        persist: bool = False,
        access_mode: AccessMode = AccessMode.PRIVATE,
        rw_access: set = :> set(),
        ro_access: set = :> set(),
        owner_id: UUID = exec_ctx.master,
        mem: Memory = exec_ctx.memory;
}

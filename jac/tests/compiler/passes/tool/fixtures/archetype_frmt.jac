obj Anchor(ArchetypeProtocol) {
    static def on_entry(cls: type, triggers: list[type]);
    static def on_exit(cls: type, triggers: list[type]);
    def make_public_ro;
    def make_public_rw;
    def make_private;
    def is_public_ro -> bool;
    def is_public_rw -> bool;
    def is_private -> bool;
    def is_readable(caller_id: UUID) -> bool;
    def is_writable(caller_id: UUID) -> bool;
    def give_access(caller_id: UUID, read_write: bool = False);
    def revoke_access(caller_id: UUID);
}

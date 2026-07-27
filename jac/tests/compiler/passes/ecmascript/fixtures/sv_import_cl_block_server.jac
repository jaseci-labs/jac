"""Server provider for `sv_import_cl_block_client.jac`:
`say_hi` is called from the client and never compiles to client JS."""

walker:pub say_hi {
    has name: str;

    can g with Root entry {
        report {"msg": "hi " + self.name};
    }
}

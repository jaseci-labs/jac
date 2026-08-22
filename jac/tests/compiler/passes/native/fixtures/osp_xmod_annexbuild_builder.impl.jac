"""Impl annex for the builder. The `++>` connect on the imported `Area` lives
HERE, in a separate module hung off the head decl's `body` (an ImplDef), not its
`kid`. Before the fix, the OSP construct scan (now `OspAnalysis._uses_construct`)
swept only the head module's kid tree, classified this module as a non-OSP user,
and never materialized the imported
`Hub`/`Area` type-tags into its native compile -- so the `++>` failed with
E5090 ('not materialized') / mis-codegen SIGSEGV."""

impl build(hub: Hub) {
    hub ++> Area(tag=1);
    hub ++> Area(tag=2);
}

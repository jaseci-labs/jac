# Native fused-build driver (na_concat: objects.jac + ceval_slice.jac).
# Proves ceval-side types override objects-side virtual slots in the fused unit.
# Expected stdout: 7834 then 1 (override marker + PyNoOpInit.tp_call).
with entry {
    # PyModule.tp_getattro overrides PyObj.tp_getattro (ceval module over objects leaf).
    m: PyModule = PyModule(
        t="module", name="driver_test", attrs={"marker": PyInt(t="int", val=7834)}
    );
    got = m.tp_getattro("marker");
    print(expect_int(got));

    # ceval-side tp_call override (PyNoOpInit over PyObj.tp_call).
    init: PyNoOpInit = PyNoOpInit(t="noop_init");
    r = init.tp_call([PyInt(t="int", val=1)], {});
    if isinstance(r, PyNoneType) {
        print(1);
    } else {
        print(0);
    }
}

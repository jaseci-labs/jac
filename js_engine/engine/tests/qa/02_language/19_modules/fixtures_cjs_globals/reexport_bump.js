// NODE_COMMONJS_PSEUDO_GLOBALS_COMPREHENSIVE_TEST_PLAN.md — NCJS-EXP-103 / NCJS-EXP-004
module.exports = {
    tag: "first",
    bump: function () {
        module.exports = { tag: "second" };
    },
};

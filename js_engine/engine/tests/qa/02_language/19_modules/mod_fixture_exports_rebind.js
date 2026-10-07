// Reassigning exports breaks the reference; module.exports stays {}
exports = { brokenProp: "should-not-appear" };

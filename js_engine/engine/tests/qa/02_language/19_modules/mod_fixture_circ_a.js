// Circular: A requires B, B requires A (gets partial exports of A)
exports.fromA = "a-value";
var b = require("./mod_fixture_circ_b.js");
exports.fromB = b.fromB;

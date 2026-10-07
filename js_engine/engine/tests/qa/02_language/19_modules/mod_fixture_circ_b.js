// Circular: B requires A (gets partial exports, only fromA is set so far)
var a = require("./mod_fixture_circ_a.js");
exports.fromB = "b-value";
exports.sawFromA = a.fromA; // may be "a-value" or undefined depending on timing

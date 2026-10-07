// EPG: UNBOUND CJS pseudo-globals in ESM must still throw ReferenceError
// ("... is not defined"; js_engine appends "in ES module scope", Node may not),
// and `typeof` must stay tolerant ("undefined").
if (typeof module !== "undefined") console.log("FAIL: typeof unbound module should be undefined");
if (typeof exports !== "undefined") console.log("FAIL: typeof unbound exports should be undefined");
let threw = false, msg = "";
try { require("fs"); } catch (e) { threw = e instanceof ReferenceError; msg = String(e.message || ""); }
if (!threw) console.log("FAIL: unbound require should throw ReferenceError");
if (msg.indexOf("is not defined") === -1) console.log("FAIL: unexpected require error: " + msg);
let threw2 = false, msg2 = "";
try { module.id; } catch (e) { threw2 = e instanceof ReferenceError; msg2 = String(e.message || ""); }
if (!threw2) console.log("FAIL: unbound module should throw ReferenceError");
if (msg2.indexOf("is not defined") === -1) console.log("FAIL: unexpected module error: " + msg2);
console.log("EPG-UNBOUND OK");

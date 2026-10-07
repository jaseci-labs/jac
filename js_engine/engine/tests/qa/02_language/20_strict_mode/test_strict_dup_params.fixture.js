"use strict";
// STRICT-005: duplicate parameter names are a SyntaxError in strict mode
function dupParams(a, a) { return a; }

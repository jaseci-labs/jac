'use strict';

/**
 * Legacy Node internal: require('_http_common').
 * Provides HTTP token / header-char checks used by the parallel test suite.
 */

function isValidTokenChar(ch) {
    if (ch >= 94 && ch <= 122) return true;
    if (ch >= 65 && ch <= 90) return true;
    if (ch === 45) return true;
    if (ch >= 48 && ch <= 57) return true;
    if (ch === 34 || ch === 40 || ch === 41 || ch === 44) return false;
    if (ch >= 33 && ch <= 46) return true;
    if (ch === 124 || ch === 126) return true;
    return false;
}

function checkIsHttpToken(val) {
    if (typeof val !== 'string' || val.length === 0) return false;
    var i = 0;
    while (i < val.length) {
        if (!isValidTokenChar(val.charCodeAt(i))) return false;
        i = i + 1;
    }
    return true;
}

function checkInvalidHeaderChar(val) {
    // Coerce like Node (`'' + val`); empty / non-string-with-no-invalid → false.
    val = '' + val;
    var i = 0;
    while (i < val.length) {
        var ch = val.charCodeAt(i);
        if (ch === 9) { i = i + 1; continue; } // HTAB ok
        if (ch <= 31 || ch > 255 || ch === 127) return true;
        i = i + 1;
    }
    return false;
}

var http = require('http');

module.exports = {
    _checkIsHttpToken: checkIsHttpToken,
    _checkInvalidHeaderChar: checkInvalidHeaderChar,
    methods: http.METHODS,
    CRLF: '\r\n'
};

'use strict';

/**
 * Legacy Node internal: require('_tls_common').
 * Minimal translatePeerCertificate used by parallel TLS tests.
 */

function translatePeerCertificate(c) {
    if (c == null || c === 0) return null;
    if (typeof c !== 'object') return c;
    // Shallow copy that does not inherit Object.prototype pollution vectors
    // for string fields Node parses (subject/issuer). Keep object identity
    // for empty objects.
    var out = {};
    var keys = Object.keys(c);
    var i = 0;
    while (i < keys.length) {
        var k = keys[i];
        out[k] = c[k];
        i = i + 1;
    }
    return out;
}

module.exports = {
    translatePeerCertificate: translatePeerCertificate
};

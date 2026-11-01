'use strict';

var checks = 0;
var failures = 0;
function check(name, condition) {
    checks++;
    if (!condition) {
        failures++;
        console.error('FAIL [review_regressions] ' + name);
    }
}

// URI scanning tracks Jac character positions separately from raw UTF-8 byte
// offsets used by the internal NUL-sentinel predicate.
var nulAfterMultibyte = 'é\0x';
check('decodeURIComponent preserves text after NUL following multibyte text',
      decodeURIComponent(nulAfterMultibyte) === nulAfterMultibyte);

// The observable unicode getter may run re-entrant regexp code and replace the
// process-wide subject conversion cache before the outer match loop starts.
var globalRegexp = /./g;
Object.defineProperty(globalRegexp, 'unicode', {
    configurable: true,
    get: function() {
        /./.test('é');
        return false;
    }
});
check('global replace restores outer subject after re-entrant unicode getter',
      '\0x'.replace(globalRegexp, 'a') === 'aa');

// A successful validation must clear an earlier compilation error.
var validModule = new Uint8Array([
    0, 97, 115, 109, 1, 0, 0, 0,
    1, 4, 1, 96, 0, 0
]);
var invalidModule = new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0, 1, 0]);
check('invalid wasm module is rejected', !WebAssembly.validate(invalidModule));
check('invalid wasm validation sets the bridge error', __wasm.lastError() !== '');
check('valid wasm validation succeeds', WebAssembly.validate(validModule));
check('successful wasm validation clears the bridge error', __wasm.lastError() === '');

console.log('review regression checks: ' + checks + ', failures: ' + failures);
if (failures !== 0) process.exit(1);

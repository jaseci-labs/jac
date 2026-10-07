// Test: 02_string — reverseStr, wordCount, capitalize
var m = require('./addon.node');

function assert(cond, msg) {
    if (!cond) { console.error('FAIL: ' + msg); process.exit(1); }
}

// reverseStr
assert(m.reverseStr('hello') === 'olleh',       'reverseStr hello');
assert(m.reverseStr('abcd') === 'dcba',         'reverseStr abcd');
assert(m.reverseStr('a') === 'a',               'reverseStr single char');
assert(m.reverseStr('') === '',                 'reverseStr empty');
assert(m.reverseStr('racecar') === 'racecar',   'reverseStr palindrome');

// wordCount
assert(m.wordCount('hello world') === 2,            'wordCount 2 words');
assert(m.wordCount('  spaces  between  words  ') === 3, 'wordCount with leading/trailing spaces');
assert(m.wordCount('') === 0,                       'wordCount empty');
assert(m.wordCount('one') === 1,                    'wordCount 1 word');
assert(m.wordCount('a b c d e') === 5,              'wordCount 5 words');

// capitalize
assert(m.capitalize('hello') === 'Hello',           'capitalize hello');
assert(m.capitalize('WORLD') === 'World',           'capitalize WORLD → World');
assert(m.capitalize('jAvAsCrIpT') === 'Javascript', 'capitalize mixed case');
assert(m.capitalize('a') === 'A',                   'capitalize single char');
assert(m.capitalize('hello world') === 'Hello world','capitalize sentence');

console.log('OK: 02_string');

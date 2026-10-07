// Repro: a STRONG napi_create_reference (refcount>=1) must keep its target
// alive across GC. Discriminating run is WITH --gc:
//     js_engine --gc test.js   -> should stay "ok"; if the ref table isn't a
//                                  GC root, the target is swept -> FAIL
//     js_engine       test.js   -> control (GC off): always ok
var m = require('./addon.node');
function fail(msg){ console.error('FAIL: ' + msg); process.exit(1); }

// 1. Stash a distinctive sentinel via a STRONG ref; keep NO JS reference.
function stashSentinel() {
    var sentinel = { tag: 'SENTINEL_ABC123', n: 42, arr: [1, 2, 3] };
    m.stash(sentinel);
    // sentinel leaves scope on return -> only the napi strong ref remains
}
stashSentinel();

// 2. Churn ~800k allocations to drive GC and reuse the swept object slot.
var keep = null;
for (var round = 0; round < 40; round++) {
    var tmp = [];
    for (var i = 0; i < 20000; i++) tmp.push({ a: i, b: 'x' + i, c: [i, i + 1] });
    keep = tmp[0];           // retain almost nothing; keep churning
}

// 3. The strong-ref target MUST still be the original sentinel.
var back = m.fetch();
if (back === undefined || back === null)
    fail('strong-ref target was COLLECTED (fetch returned ' + back + ')');
if (typeof back !== 'object')
    fail('strong-ref target corrupted: typeof=' + typeof back);
if (back.tag !== 'SENTINEL_ABC123')
    fail('strong-ref target reused/wrong object: tag=' + JSON.stringify(back.tag) +
         ' keys=' + JSON.stringify(Object.keys(back)));
if (back.n !== 42 || !Array.isArray(back.arr) || back.arr.length !== 3)
    fail('strong-ref target fields corrupted: n=' + JSON.stringify(back.n) +
         ' arr=' + JSON.stringify(back.arr));
console.log('ok: strong napi reference survived GC (tag=' + back.tag + ', n=' + back.n + ')');

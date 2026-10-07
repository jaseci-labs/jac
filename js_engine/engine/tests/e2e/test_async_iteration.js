// ════════════════════════════════════════════════════════════════════════════
// test_async_iteration.js — Tests for Symbol.asyncIterator, async generators,
//                           and for-await-of loops
//
// Covers:
//   - Symbol.asyncIterator existence and type
//   - async function* (async generators)
//   - async generator .next() returns Promise<{value, done}>
//   - async generator .return() and .throw()
//   - for await (const x of asyncIterable) { ... }
//   - Custom async iterables via [Symbol.asyncIterator]
//   - Sync-to-async fallback in for-await-of
//   - yield* delegation in async generators
// ════════════════════════════════════════════════════════════════════════════

var passed = 0;
var failed = 0;

function assert(condition, msg) {
    if (condition) {
        passed++;
    } else {
        failed++;
        console.log("FAIL: " + msg);
    }
}

// ── Symbol.asyncIterator ────────────────────────────────────────────────────

assert(typeof Symbol.asyncIterator === "symbol", "Symbol.asyncIterator is a symbol");
assert(Symbol.asyncIterator !== undefined, "Symbol.asyncIterator is not undefined");
assert(Symbol.asyncIterator !== Symbol.iterator, "asyncIterator !== iterator");

// Consistent identity
assert(Symbol.asyncIterator === Symbol.asyncIterator, "Symbol.asyncIterator is stable");

// ── async function* basics ──────────────────────────────────────────────────

async function* simpleGen() {
    yield 1;
    yield 2;
    yield 3;
}

var gen = simpleGen();
assert(typeof gen === "object", "async generator is an object");
assert(typeof gen.next === "function", "async generator has .next()");
assert(typeof gen.return === "function", "async generator has .return()");
assert(typeof gen.throw === "function", "async generator has .throw()");

// ── async generator .next() returns Promise ─────────────────────────────────

var p1 = gen.next();
assert(p1 instanceof Promise, ".next() returns a Promise");

// In our synchronous model, the promise resolves immediately
p1.then(function(result) {
    assert(result.value === 1, "first yield value is 1");
    assert(result.done === false, "first yield done is false");
});

var p2 = gen.next();
p2.then(function(result) {
    assert(result.value === 2, "second yield value is 2");
    assert(result.done === false, "second yield done is false");
});

var p3 = gen.next();
p3.then(function(result) {
    assert(result.value === 3, "third yield value is 3");
    assert(result.done === false, "third yield done is false");
});

var p4 = gen.next();
p4.then(function(result) {
    assert(result.value === undefined, "after last yield value is undefined");
    assert(result.done === true, "after last yield done is true");
});

// ── async generator .return() ───────────────────────────────────────────────

async function* retGen() {
    yield 10;
    yield 20;
}

var rg = retGen();
rg.next();  // consume first

var retP = rg.return(42);
retP.then(function(result) {
    assert(result.value === 42, ".return(42) value is 42");
    assert(result.done === true, ".return(42) done is true");
});

// After return, next should give done
var retP2 = rg.next();
retP2.then(function(result) {
    assert(result.done === true, "next after .return() is done");
});

// ── async generator .throw() ────────────────────────────────────────────────

async function* throwGen() {
    try {
        yield 100;
        yield 200;
    } catch (e) {
        yield e;
    }
}

var tg = throwGen();
tg.next();  // starts the generator, yields 100

var throwP = tg.throw("error!");
throwP.then(function(result) {
    assert(result.value === "error!", ".throw() caught value is 'error!'");
    assert(result.done === false, ".throw() caught done is false");
});

// ── for await...of with async generator ─────────────────────────────────────

async function* countGen() {
    yield 10;
    yield 20;
    yield 30;
}

var collected = [];
async function testForAwait() {
    for await (var x of countGen()) {
        collected.push(x);
    }
}
testForAwait();
assert(collected.length === 3, "for-await-of collected 3 items (got " + collected.length + ")");
assert(collected[0] === 10, "for-await-of item 0 is 10");
assert(collected[1] === 20, "for-await-of item 1 is 20");
assert(collected[2] === 30, "for-await-of item 2 is 30");

// ── for await...of with custom async iterable ───────────────────────────────

var customIterable = {};
customIterable[Symbol.asyncIterator] = function() {
    var i = 0;
    var vals = ["a", "b", "c"];
    return {
        next: function() {
            if (i < vals.length) {
                var result = { value: vals[i], done: false };
                i++;
                return Promise.resolve(result);
            }
            return Promise.resolve({ value: undefined, done: true });
        }
    };
};

var customCollected = [];
async function testCustomAsync() {
    for await (var item of customIterable) {
        customCollected.push(item);
    }
}
testCustomAsync();
assert(customCollected.length === 3, "custom async iterable collected 3 items (got " + customCollected.length + ")");
assert(customCollected[0] === "a", "custom item 0 is 'a'");
assert(customCollected[1] === "b", "custom item 1 is 'b'");
assert(customCollected[2] === "c", "custom item 2 is 'c'");

// ── for await...of with sync iterable (fallback) ────────────────────────────

var syncArr = [100, 200, 300];
var syncCollected = [];
async function testSyncFallback() {
    for await (var v of syncArr) {
        syncCollected.push(v);
    }
}
testSyncFallback();
assert(syncCollected.length === 3, "sync fallback collected 3 items (got " + syncCollected.length + ")");
assert(syncCollected[0] === 100, "sync fallback item 0 is 100");
assert(syncCollected[1] === 200, "sync fallback item 1 is 200");
assert(syncCollected[2] === 300, "sync fallback item 2 is 300");

// ── yield* delegation in async generator ────────────────────────────────────

function* innerGen() {
    yield "x";
    yield "y";
}

async function* outerGen() {
    yield "start";
    yield* innerGen();
    yield "end";
}

var delegated = [];
async function testDelegate() {
    for await (var v of outerGen()) {
        delegated.push(v);
    }
}
testDelegate();
assert(delegated.length === 4, "yield* delegation collected 4 items (got " + delegated.length + ")");
assert(delegated[0] === "start", "delegate item 0 is 'start'");
assert(delegated[1] === "x", "delegate item 1 is 'x'");
assert(delegated[2] === "y", "delegate item 2 is 'y'");
assert(delegated[3] === "end", "delegate item 3 is 'end'");

// ── async generator with await inside ───────────────────────────────────────

async function* awaitInside() {
    var a = await Promise.resolve(42);
    yield a;
    var b = await Promise.resolve(84);
    yield b;
}

var awaitValues = [];
async function testAwaitInside() {
    for await (var v of awaitInside()) {
        awaitValues.push(v);
    }
}
testAwaitInside();
assert(awaitValues.length === 2, "await-inside collected 2 items (got " + awaitValues.length + ")");
assert(awaitValues[0] === 42, "await-inside item 0 is 42");
assert(awaitValues[1] === 84, "await-inside item 1 is 84");

// ── for await with let/const declarations ───────────────────────────────────

async function* letterGen() {
    yield "p";
    yield "q";
}

var letCollected = [];
async function testLetDecl() {
    for await (let ch of letterGen()) {
        letCollected.push(ch);
    }
}
testLetDecl();
assert(letCollected.length === 2, "let decl for-await collected 2 (got " + letCollected.length + ")");
assert(letCollected[0] === "p", "let decl item 0 is 'p'");
assert(letCollected[1] === "q", "let decl item 1 is 'q'");

var constCollected = [];
async function testConstDecl() {
    for await (const ch of letterGen()) {
        constCollected.push(ch);
    }
}
testConstDecl();
assert(constCollected.length === 2, "const decl for-await collected 2 (got " + constCollected.length + ")");
assert(constCollected[0] === "p", "const decl item 0 is 'p'");
assert(constCollected[1] === "q", "const decl item 1 is 'q'");

// ── Summary ─────────────────────────────────────────────────────────────────

console.log("=== Async iteration tests: " + passed + " passed, " + failed + " failed ===");

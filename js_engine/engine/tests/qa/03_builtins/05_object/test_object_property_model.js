// OBJECTS_AND_PROPERTY_MODEL_COMPREHENSIVE_TEST_PLAN.md — OBJ-* scenario coverage

var __jacHarness = require("../../_harness/regression_case.cjs");
var __reg = __jacHarness.createTestCase("regression/03_builtins/05_object/test_object_property_model.js");
var __jacOrigExit = process.exit.bind(process);
function __jacDone() { __reg.finalize(__jacOrigExit); }

function assert(cond, msg) { __reg.assert(cond, msg); }
function assertEq(actual, expected, msg) { __reg.assertEq(actual, expected, msg); }
function assertThrows(fn, Ctor, id, detail) {
    try {
        fn();
        console.error("FAIL: " + id + ": expected " + Ctor.name + " — " + detail);
        __reg.bump(); return;
    } catch (err) {
        if (!(err instanceof Ctor)) {
            console.error(
                "FAIL: " + id + ": wrong error | expected " + Ctor.name + " | got " + err
            );
            __reg.bump(); return;
        }
    }
}

// ═══ §1 Object literals (OBJ-L-*) ═══

(function obj_l001() {
    var o = { a: 1, b: 2 };
    assertEq(o.a, 1, "OBJ-L-001: read literal property a");
    o.a = 3;
    assertEq(o.a, 3, "OBJ-L-001: write literal property a");
})();

(function obj_l002() {
    var x = 10;
    var y = 20;
    var o = { x: x, y: y };
    var p = { x, y };
    assertEq(p.x, 10, "OBJ-L-002: shorthand property x");
    assertEq(p.y, 20, "OBJ-L-002: shorthand property y");
    assertEq(o.x, p.x, "OBJ-L-002: shorthand matches long form");
})();

(function obj_l003() {
    var k = "dyn";
    var o = {
        [k]: 1,
        [1 + 1]: "two"
    };
    assertEq(o.dyn, 1, "OBJ-L-003: computed string key");
    assertEq(o[2], "two", "OBJ-L-003: computed numeric expression ToPropertyKey");
})();

(function obj_l004() {
    var o = {
        m: function () {
            return 40;
        },
        n() {
            return this.m() + 2;
        },
        get g() {
            return 1;
        },
        set g(v) {
            this._g = v;
        }
    };
    assertEq(o.m(), 40, "OBJ-L-004: method definition m()");
    assertEq(o.n(), 42, "OBJ-L-004: concise method n()");
    assertEq(o.g, 1, "OBJ-L-004: getter g");
    o.g = 5;
    assertEq(o._g, 5, "OBJ-L-004: setter g");
})();

(function obj_l005() {
    var o = { a: 1, a: 2, b: 3 };
    assertEq(o.a, 2, "OBJ-L-005: duplicate keys last wins");
})();

(function obj_l006() {
    var gCalls = 0;
    var src = {};
    Object.defineProperty(src, "x", {
        enumerable: true,
        get: function () {
            gCalls++;
            return 7;
        }
    });
    var o = { ...src, y: 1 };
    assertEq(gCalls, 1, "OBJ-L-006: spread invokes enumerable getter");
    assertEq(o.x, 7, "OBJ-L-006: spread copies getter result");
    assertEq(o.y, 1, "OBJ-L-006: spread with own props");
    var merged = { ...null, ...undefined, z: 2 };
    assertEq(merged.z, 2, "OBJ-L-006: null/undefined spread no-op in object literal (Node)");
})();

(function obj_l007() {
    var proto = { inherited: 1 };
    var viaProto = { __proto__: proto };
    assertEq(Object.getPrototypeOf(viaProto), proto, "OBJ-L-007: legacy __proto__ initializer sets prototype");
    assertEq(viaProto.inherited, 1, "OBJ-L-007: inherits via __proto__ initializer");
    var asKey = { ["__proto__"]: 99 };
    assertEq(asKey["__proto__"], 99, "OBJ-L-007: computed __proto__ name is ordinary data key");
    assertEq(
        Object.getPrototypeOf(asKey) === Object.prototype,
        true,
        "OBJ-L-007: computed __proto__ does not change [[Prototype]]"
    );
})();

(function obj_l008() {
    var o = { proto: 123 };
    assertEq(o.proto, 123, "OBJ-L-008: proto without underscores is normal key");
})();

// ═══ §2 Object constructor (OBJ-C-*) ═══

(function obj_c001() {
    function isOrdinaryEmpty(o) {
        return typeof o === "object" && o !== null && Object.getPrototypeOf(o) === Object.prototype;
    }
    assert(isOrdinaryEmpty(Object()), "OBJ-C-001: Object() empty ordinary object");
    assert(isOrdinaryEmpty(Object(undefined)), "OBJ-C-001: Object(undefined)");
    assert(isOrdinaryEmpty(Object(null)), "OBJ-C-001: Object(null) not null");
})();

(function obj_c002() {
    var obj = { a: 1 };
    var arr = [1, 2];
    function fn() {}
    assertEq(Object(obj), obj, "OBJ-C-002: Object(obj) same reference");
    assertEq(Object(arr), arr, "OBJ-C-002: Object(array) same reference");
    assertEq(Object(fn), fn, "OBJ-C-002: Object(fn) same reference");
})();

(function obj_c003() {
    var n = Object(42);
    assertEq(n.valueOf(), 42, "OBJ-C-003: Object(number) boxing");
    var s = Object("ab");
    assertEq(s.valueOf(), "ab", "OBJ-C-003: Object(string) boxing");
    var b = Object(false);
    assertEq(b.valueOf(), false, "OBJ-C-003: Object(boolean) boxing");
    if (typeof Symbol === "function") {
        var sy = Symbol("c");
        var so = Object(sy);
        assertEq(typeof so, "object", "OBJ-C-003: Object(symbol) typeof object");
    }
    if (typeof BigInt === "function") {
        var bo = Object(BigInt(0));
        assertEq(typeof bo, "object", "OBJ-C-003: Object(bigint) typeof object");
    }
})();

(function obj_c004() {
    var ref = { k: 1 };
    assertEq(Object(ref), new Object(ref), "OBJ-C-004: Object vs new Object same ref for object");
    assertEq(Object(3).valueOf(), new Object(3).valueOf(), "OBJ-C-004: number wrapper equivalence");
})();

// ═══ §3 Property access (OBJ-A-*) ═══

assertThrows(
    function () {
        null.x;
    },
    TypeError,
    "OBJ-A-001",
    "dot access on null"
);
assertThrows(
    function () {
        undefined["a"];
    },
    TypeError,
    "OBJ-A-001",
    "bracket access on undefined"
);

(function obj_a002() {
    var o = {};
    var sym = typeof Symbol === "function" ? Symbol("k") : null;
    o["a"] = 1;
    o[2] = "n2";
    if (sym) {
        o[sym] = "sym";
    }
    assertEq(o.a, 1, "OBJ-A-002: dot equivalent string key");
    assertEq(o[2], "n2", "OBJ-A-002: numeric key ToPropertyKey");
    if (sym) {
        assertEq(o[sym], "sym", "OBJ-A-002: Symbol key");
    }
})();

(function obj_a003() {
    var plain = {};
    plain[5] = "p";
    assertEq(plain[5], "p", "OBJ-A-003: numeric index on plain object");
    var arr = [];
    arr[5] = "a";
    assertEq(arr[5], "a", "OBJ-A-003: out-of-range index on Array (value only; length plan elsewhere)");
})();

// ═══ §4 Prototype chain (OBJ-P-*) ═══

(function obj_p001() {
    var proto = { p: 1 };
    var o = Object.create(proto);
    assertEq(Object.getPrototypeOf(o), proto, "OBJ-P-001: Object.create(proto) link");
    if (typeof Object.create === "function") {
        var o2 = Object.create(null, {
            z: { value: 3, writable: true, enumerable: true, configurable: true }
        });
        assertEq(o2.z, 3, "OBJ-P-001: second-argument descriptors when supported");
    }
})();

(function obj_p002() {
    var o = Object.create(null);
    assertEq(Object.getPrototypeOf(o), null, "OBJ-P-002: create(null) has null prototype");
    assertEq(typeof o.toString, "undefined", "OBJ-P-002: no inherited toString");
})();

(function obj_p003() {
    function C() {}
    var inst = new C();
    assertEq(Object.getPrototypeOf({}), Object.prototype, "OBJ-P-003: plain object proto");
    assertEq(Object.getPrototypeOf(Object.create(null)), null, "OBJ-P-003: null-prototype");
    assertEq(Object.getPrototypeOf(inst), C.prototype, "OBJ-P-003: constructor instance");
})();

(function obj_p004() {
    var o = { x: 1 };
    var p = { y: 2 };
    var ret = Object.setPrototypeOf(o, p);
    assertEq(ret, o, "OBJ-P-004: setPrototypeOf returns object");
    assertEq(o.y, 2, "OBJ-P-004: chain updated");
    var a = {};
    var b = Object.create(a);
    assertThrows(
        function () {
            Object.setPrototypeOf(a, b);
        },
        TypeError,
        "OBJ-P-004",
        "circular prototype chain"
    );
})();

(function obj_p005() {
    var o = {};
    Object.preventExtensions(o);
    assertThrows(
        function () {
            Object.setPrototypeOf(o, {});
        },
        TypeError,
        "OBJ-P-005",
        "setPrototypeOf on non-extensible object"
    );
})();

// ═══ §5 defineProperty / defineProperties (OBJ-D-*) ═══

(function obj_d001() {
    var o = {};
    Object.defineProperty(o, "x", { value: 1 });
    var d = Object.getOwnPropertyDescriptor(o, "x");
    assertEq(d.writable, false, "OBJ-D-001: default writable false");
    assertEq(d.enumerable, false, "OBJ-D-001: default enumerable false");
    assertEq(d.configurable, false, "OBJ-D-001: default configurable false");
})();

(function obj_d002() {
    var o = {};
    Object.defineProperty(o, "z", {
        get: function () {
            return 4;
        },
        configurable: true,
        enumerable: true
    });
    var d = Object.getOwnPropertyDescriptor(o, "z");
    assertEq(d.value, undefined, "OBJ-D-002: accessor descriptor has no value");
    assertEq(d.writable, undefined, "OBJ-D-002: accessor descriptor has no writable");
    assertEq(typeof d.get, "function", "OBJ-D-002: get present");
})();

assertThrows(
    function () {
        Object.defineProperty({}, "bad", { value: 1, get: function () {} });
    },
    TypeError,
    "OBJ-D-003",
    "invalid descriptor value + get"
);

(function obj_d004() {
    var o = {};
    Object.defineProperty(o, "ro", { value: 10, writable: false, configurable: true });
    o.ro = 20;
    assertEq(o.ro, 10, "OBJ-D-004: sloppy assignment silent no-op on non-writable");
    assertThrows(
        function () {
            (function () {
                "use strict";
                o.ro = 30;
            })();
        },
        TypeError,
        "OBJ-D-004",
        "strict assignment TypeError on non-writable data property"
    );
})();

(function obj_d005() {
    var o = {};
    Object.defineProperty(o, "k", { value: 1, writable: false, configurable: false });
    assertEq(delete o.k, false, "OBJ-D-005: cannot delete non-configurable");
    var threw = false;
    try {
        Object.defineProperty(o, "k", { value: 2, writable: false, configurable: false });
    } catch (e) {
        threw = e instanceof TypeError;
    }
    assert(threw, "OBJ-D-005: incompatible redefine throws TypeError");
})();

(function obj_d006() {
    var o = {};
    Object.defineProperties(o, {
        a: { value: 1, writable: true, enumerable: true, configurable: true },
        b: {
            enumerable: true,
            configurable: true,
            get: function () {
                return this.a + 10;
            }
        }
    });
    assertEq(o.b, 11, "OBJ-D-006: defineProperties batch sees earlier defined key");
})();

(function obj_d007() {
    var t = {};
    assertEq(Object.defineProperty(t, "q", { value: 1 }), t, "OBJ-D-007: defineProperty returns target");
})();

assertThrows(
    function () {
        Object.defineProperty(1, "x", { value: 1 });
    },
    TypeError,
    "OBJ-D-008",
    "non-object target"
);

(function obj_d009() {
    var o = { existing: 1 };
    Object.preventExtensions(o);
    assertThrows(
        function () {
            Object.defineProperty(o, "nope", { value: 1 });
        },
        TypeError,
        "OBJ-D-009",
        "new property on non-extensible"
    );
    Object.defineProperty(o, "existing", { value: 2, writable: true, enumerable: true, configurable: true });
    assertEq(o.existing, 2, "OBJ-D-009: compatible update of existing on non-extensible object");
})();

// ═══ §6 Introspection (OBJ-I-*) ═══

(function obj_i001() {
    var o = { d: 1 };
    Object.defineProperty(o, "a", {
        get: function () {
            return 2;
        },
        configurable: true,
        enumerable: true
    });
    assertEq(Object.getOwnPropertyDescriptor(o, "d").value, 1, "OBJ-I-001: own data descriptor");
    assertEq(Object.getOwnPropertyDescriptor(o, "a").get !== undefined, true, "OBJ-I-001: own accessor");
    assertEq(Object.getOwnPropertyDescriptor(o, "missing"), undefined, "OBJ-I-001: missing → undefined");
})();

(function obj_i002() {
    var o = Object.create({ inh: 1 });
    assertEq(Object.getOwnPropertyDescriptor(o, "inh"), undefined, "OBJ-I-002: inherited no own descriptor");
})();

if (typeof Object.getOwnPropertyDescriptors === "function") {
    (function obj_i003() {
        var o = { x: 1 };
        Object.defineProperty(o, "y", {
            get: function () {
                return 2;
            },
            enumerable: true,
            configurable: true
        });
        var all = Object.getOwnPropertyDescriptors(o);
        assertEq(all.x.value, 1, "OBJ-I-003: descriptor map data entry");
        assertEq(typeof all.y.get, "function", "OBJ-I-003: descriptor map accessor entry");
        assertEq(all.inherited, undefined, "OBJ-I-003: own keys only in map");
    })();
}

(function obj_i004() {
    var o = {};
    Object.defineProperty(o, "ne", { value: 1, enumerable: false, configurable: true });
    var names = Object.getOwnPropertyNames(o);
    assert(names.indexOf("ne") >= 0, "OBJ-I-004: non-enumerable string in getOwnPropertyNames");
})();

if (typeof Symbol === "function" && typeof Object.getOwnPropertySymbols === "function") {
    (function obj_i005() {
        var s = Symbol("s");
        var o = {};
        Object.defineProperty(o, s, { value: 1, enumerable: false, configurable: true });
        var syms = Object.getOwnPropertySymbols(o);
        assertEq(syms.length, 1, "OBJ-I-005: own symbol regardless of enumerable");
        assertEq(syms[0], s, "OBJ-I-005: symbol key listed");
    })();
}

// ═══ §7 Enumeration helpers (OBJ-E-*) ═══

(function obj_e001() {
    var o = { foo: 1, 2: "b", 10: "c", 1: "a" };
    var keys = Object.keys(o);
    assertEq(keys[0], "1", "OBJ-E-001: integer-like keys sorted ascending first");
    assertEq(keys[1], "2", "OBJ-E-001: then next index");
    assertEq(keys[2], "10", "OBJ-E-001: then non-array-index numeric string");
    assertEq(keys[3], "foo", "OBJ-E-001: then other string keys insertion order");
})();

(function obj_e002() {
    var got = 0;
    var src = {};
    Object.defineProperty(src, "g", {
        enumerable: true,
        get: function () {
            got++;
            return 5;
        }
    });
    Object.defineProperty(src, "h", { value: 9, enumerable: false, configurable: true });
    var tgt = {};
    var ret = Object.assign(tgt, src);
    assertEq(got, 1, "OBJ-E-002: assign invokes source getter");
    assertEq(tgt.g, 5, "OBJ-E-002: enumerable own from getter copied");
    assertEq(tgt.h, undefined, "OBJ-E-002: non-enumerable not copied");
    assertEq(ret, tgt, "OBJ-E-002: assign returns target");
    if (typeof Symbol === "function") {
        var sym = Symbol("s");
        var s1 = {};
        s1[sym] = 7;
        var s2 = Object.assign({}, s1);
        assertEq(s2[sym], 7, "OBJ-E-002: Symbol own enumerable copied");
    }
})();

(function obj_e003() {
    var frozen = Object.freeze({});
    assertThrows(
        function () {
            Object.assign(frozen, { a: 1 });
        },
        TypeError,
        "OBJ-E-003",
        "assign to non-extensible / failed [[Set]]"
    );
})();

if (typeof Object.fromEntries === "function") {
    (function obj_e004() {
        var fe = Object.fromEntries([
            ["k", 1],
            ["k", 2]
        ]);
        assertEq(fe.k, 2, "OBJ-E-004: fromEntries duplicate keys last wins");
        var closed = false;
        var iterable = {};
        iterable[Symbol.iterator] = function () {
            return {
                i: 0,
                next: function () {
                    if (this.i++ === 0) {
                        return { value: ["a", 1], done: false };
                    }
                    throw new Error("boom");
                },
                return: function () {
                    closed = true;
                    return { done: true };
                }
            };
        };
        var feThrew = false;
        try {
            Object.fromEntries(iterable);
        } catch (e) {
            feThrew = String(e.message) === "boom";
        }
        assert(feThrew, "OBJ-E-004: throwing next() propagates to the caller's catch");
        // Spec (and test262 iterator-not-closed-for-throwing-next): an abrupt
        // completion from next() does NOT trigger IteratorClose. V8 diverges
        // and calls return(); js_engine follows the spec, Node follows V8.
        if (__jacHarness.isJacEngineRunner()) {
            assert(!closed, "OBJ-E-004: iterator NOT closed when next() throws (spec)");
        } else {
            assert(closed, "OBJ-E-004: iterator closed when next() throws (V8)");
        }
    })();
}

// ═══ §8 hasOwn / in (OBJ-H-*) ═══

(function obj_h001() {
    var o = {};
    o.a = 1;
    Object.defineProperty(o, "ne", { value: 2, enumerable: false, configurable: true });
    if (typeof Object.hasOwn === "function") {
        assertEq(Object.hasOwn(o, "a"), true, "OBJ-H-001: hasOwn string own");
        assertEq(Object.hasOwn(o, "ne"), true, "OBJ-H-001: hasOwn non-enumerable own");
    }
    assertEq(o.hasOwnProperty("a"), true, "OBJ-H-001: hasOwnProperty own");
})();

(function obj_h002() {
    var o = Object.create(null);
    o.x = 1;
    if (typeof Object.hasOwn === "function") {
        assertEq(Object.hasOwn(o, "x"), true, "OBJ-H-002: hasOwn on null-proto object");
    }
    assertEq(typeof o.hasOwnProperty, "undefined", "OBJ-H-002: no inherited hasOwnProperty");
    assertEq(Object.prototype.hasOwnProperty.call(o, "x"), true, "OBJ-H-002: call works");
})();

(function obj_h003() {
    var o = {};
    Object.defineProperty(o, "ne", { value: 1, enumerable: false, configurable: true });
    assertEq(o.propertyIsEnumerable("ne"), false, "OBJ-H-003: non-enumerable own → false");
    var base = { inh: 1 };
    var child = Object.create(base);
    assertEq(child.propertyIsEnumerable("inh"), false, "OBJ-H-003: inherited enumerable → false");
})();

(function obj_h004() {
    var base = {};
    Object.defineProperty(base, "x", { value: 1, enumerable: false, configurable: true });
    var o = Object.create(base);
    assertEq("x" in o, true, "OBJ-H-004: in sees inherited non-enumerable");
})();

// ═══ §9 Integrity (OBJ-S-*) ═══

if (typeof Object.preventExtensions === "function") {
    (function obj_s001() {
        var o = { x: 1 };
        Object.preventExtensions(o);
        o.y = 2;
        assertEq(o.y, undefined, "OBJ-S-001: preventExtensions blocks new property");
        o.x = 3;
        assertEq(o.x, 3, "OBJ-S-001: existing may still change");
    })();
}

if (typeof Object.seal === "function") {
    (function obj_s002() {
        var o = { x: 1 };
        Object.seal(o);
        o.x = 9;
        assertEq(o.x, 9, "OBJ-S-002: seal allows value change on writable data");
        assertEq(delete o.x, false, "OBJ-S-002: seal non-configurable cannot delete");
    })();
}

if (typeof Object.freeze === "function") {
    (function obj_s003() {
        var o = { inner: { v: 1 } };
        Object.freeze(o);
        o.inner.v = 5;
        assertEq(o.inner.v, 5, "OBJ-S-003: freeze is shallow nested still mutable");
    })();
}

if (typeof Object.isFrozen === "function" && typeof Object.isSealed === "function" && typeof Object.isExtensible === "function") {
    (function obj_s004() {
        assertEq(Object.isFrozen({}), false, "OBJ-S-004: ordinary object not frozen");
        var empty = {};
        Object.preventExtensions(empty);
        assertEq(Object.isFrozen(empty), true, "OBJ-S-004: empty non-extensible is frozen");
        assertEq(Object.isFrozen(1), true, "OBJ-S-004: primitive number treated frozen");
        assertEq(Object.isSealed(Object.seal({ a: 1 })), true, "OBJ-S-004: sealed predicate");
        assertEq(Object.isExtensible({}), true, "OBJ-S-004: extensible ordinary");
    })();
}

if (typeof Object.freeze === "function" && typeof Object.seal === "function") {
    (function obj_s005() {
        var f = Object.freeze({ a: 1 });
        Object.freeze(f);
        assertEq(f.a, 1, "OBJ-S-005: freeze idempotent");
        var s = Object.seal({ b: 2 });
        Object.seal(s);
        assertEq(s.b, 2, "OBJ-S-005: seal idempotent");
    })();
}

// ═══ §10 delete (OBJ-X-*) ═══

(function obj_x001() {
    var o = { a: 1 };
    assertEq(delete o.a, true, "OBJ-X-001: delete configurable own");
    var o2 = {};
    Object.defineProperty(o2, "k", { value: 1, configurable: false });
    assertEq(delete o2.k, false, "OBJ-X-001: delete non-configurable returns false");
})();

(function obj_x002() {
    var proto = { inherited: 1 };
    var o = Object.create(proto);
    assertEq(delete o.inherited, true, "OBJ-X-002: delete inherited returns true");
    assertEq(proto.inherited, 1, "OBJ-X-002: prototype unchanged");
    assertEq("inherited" in o, true, "OBJ-X-002: inherited still visible");
})();

// ═══ §11 Reflect (OBJ-R-*) ═══

if (typeof Reflect === "undefined") {
    assert(true, "OBJ-R-skip: Reflect undefined — skipping OBJ-R-* (see GAP-007)");
} else {
    (function obj_r001() {
        var o = {};
        Object.defineProperty(o, "x", { value: 1, writable: false, configurable: false });
        assertEq(Reflect.defineProperty(o, "x", { value: 1 }), true, "OBJ-R-001: Reflect compatible define returns true");
        assertEq(Reflect.defineProperty(o, "x", { value: 2 }), false, "OBJ-R-001: Reflect failed define returns false");
        var threw = false;
        try {
            Object.defineProperty(o, "x", { value: 2 });
        } catch (e) {
            threw = e instanceof TypeError;
        }
        assert(threw, "OBJ-R-001: Object.defineProperty throws on same failure");
    })();

    (function obj_r002() {
        var sym = typeof Symbol === "function" ? Symbol("s") : null;
        var o = { z: 1, 2: "b", a: 2 };
        if (sym) {
            o[sym] = 3;
        }
        var keys = Reflect.ownKeys(o);
        assertEq(keys[0], "2", "OBJ-R-002: ownKeys integer indices first");
        if (sym) {
            assertEq(keys[keys.length - 1], sym, "OBJ-R-002: symbols after string keys");
        }
    })();

    (function obj_r003() {
        var target = {
            _v: 0,
            get x() {
                return this._v;
            },
            set x(v) {
                this._v = v;
            }
        };
        var receiver = { _v: 100 };
        assertEq(Reflect.get(target, "x", receiver), 100, "OBJ-R-003: Reflect.get uses receiver for accessor this");
        Reflect.set(target, "x", 5, receiver);
        assertEq(receiver._v, 5, "OBJ-R-003: Reflect.set uses receiver for accessor this");
    })();
}

// ═══ §12 Proxy (OBJ-Y-*) ═══

if (typeof Proxy === "undefined") {
    assert(true, "OBJ-Y-001: Proxy undefined — skipping OBJ-Y-002+ (see GAP-007)");
} else {
    assertEq(typeof Proxy, "function", "OBJ-Y-001: Proxy supported");

    (function obj_y002() {
        var t = {};
        Object.defineProperty(t, "x", { value: 1, writable: false, configurable: false });
        var p = new Proxy(t, {
            get: function () {
                return 9;
            }
        });
        assertThrows(
            function () {
                return p.x;
            },
            TypeError,
            "OBJ-Y-002",
            "get trap cannot violate non-writable non-configurable data descriptor"
        );
    })();

    (function obj_y003() {
        var t = {};
        var p = new Proxy(t, {
            set: function () {
                return false;
            }
        });
        assertThrows(
            function () {
                (function () {
                    "use strict";
                    p.a = 1;
                })();
            },
            TypeError,
            "OBJ-Y-003",
            "set trap false in strict mode"
        );
    })();

    (function obj_y004() {
        var t = {};
        Object.defineProperty(t, "a", { value: 1, configurable: false });
        var p = new Proxy(t, {
            has: function () {
                return false;
            }
        });
        assertThrows(
            function () {
                return "a" in p;
            },
            TypeError,
            "OBJ-Y-004",
            "has trap cannot hide non-configurable property"
        );
    })();

    (function obj_y005() {
        var t = {};
        Object.defineProperty(t, "a", { value: 1, configurable: false });
        var p = new Proxy(t, {
            deleteProperty: function () {
                return true;
            }
        });
        assertThrows(
            function () {
                delete p.a;
            },
            TypeError,
            "OBJ-Y-005",
            "deleteProperty cannot report success for non-configurable"
        );
    })();

    (function obj_y006() {
        var t = {};
        Object.defineProperty(t, "a", { value: 1, configurable: false });
        var p = new Proxy(t, {
            ownKeys: function () {
                return [];
            }
        });
        assertThrows(
            function () {
                Object.keys(p);
            },
            TypeError,
            "OBJ-Y-006",
            "ownKeys must include non-configurable keys"
        );
    })();

    (function obj_y007() {
        var t = {};
        Object.defineProperty(t, "x", { value: 1, writable: true, enumerable: true, configurable: false });
        var bad = new Proxy(t, {
            getOwnPropertyDescriptor: function () {
                return { value: 1, writable: true, enumerable: true, configurable: true };
            }
        });
        assertThrows(
            function () {
                Object.getOwnPropertyDescriptor(bad, "x");
            },
            TypeError,
            "OBJ-Y-007",
            "getOwnPropertyDescriptor trap incompatible with target"
        );
    })();

    (function obj_y008() {
        function sum(a, b) {
            return a + b;
        }
        var pa = new Proxy(sum, {
            apply: function (target, thisArg, args) {
                return args[0] + args[1] + 1;
            }
        });
        assertEq(pa(2, 3), 6, "OBJ-Y-008: apply trap for callable");
        function C(x) {
            this.x = x;
        }
        var pc = new Proxy(C, {
            construct: function (target, args, newTarget) {
                var o = Object.create(newTarget.prototype);
                o.x = args[0] + 10;
                return o;
            }
        });
        var inst = new pc(5);
        assertEq(inst.x, 15, "OBJ-Y-008: construct trap");
    })();

    (function obj_y009() {
        var rev = Proxy.revocable({ a: 1 }, {});
        rev.revoke();
        assertThrows(
            function () {
                return rev.proxy.a;
            },
            TypeError,
            "OBJ-Y-009",
            "revoked proxy get throws TypeError"
        );
    })();

    (function obj_y010() {
        var proto = {};
        var target = Object.create(proto);
        Object.preventExtensions(target);
        var p = new Proxy(target, {
            getPrototypeOf: function () {
                return {};
            }
        });
        assertThrows(
            function () {
                Object.getPrototypeOf(p);
            },
            TypeError,
            "OBJ-Y-010",
            "getPrototypeOf trap must match invariant when target non-extensible"
        );
    })();
}

__jacDone();

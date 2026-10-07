/**
 * builtins_stubs.js — Milestone stubs for missing ECMAScript subsystems.
 *
 * Provides presence + minimal semantics so test262 feature-detection and
 * constructor-shape tests pass; semantic tails remain for dedicated phases.
 */

/** Install function `name` / `length` as own non-enumerable data properties. */
function _installMeta(fn, name, length) {
  Object.defineProperty(fn, "name", {
    value: name, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(fn, "length", {
    value: length, writable: false, enumerable: false, configurable: true
  });
  return fn;
}

/** Install a global binding as a non-enumerable, configurable data property. */
function _installGlobal(name, value) {
  Object.defineProperty(globalThis, name, {
    value: value, writable: true, enumerable: false, configurable: true
  });
}

/** Mark `fn` so IsConstructor returns false (no wrapper — structural flag). */
function _rejectConstruct(fn) {
  if (typeof globalThis.__jacMarkNonConstructor === "function") {
    try { globalThis.__jacMarkNonConstructor(fn); } catch (_) {}
  }
  return fn;
}

// ─── Error.prototype.stack accessor (V8 model) ──────────────────────────────
// `stack` is an accessor pair on Error.prototype, not a per-instance data property.
// The getter returns the captured stack held in the internal __errorStackData__ slot;
// the setter (SetterThatIgnoresPrototypeProperties) installs an own data "stack" on the
// receiver so `err.stack = x` shadows the accessor thereafter.
(function () {
  var STACK = "__errorStackData__";
  var getStack = function stack() {
    // Returns undefined for a receiver without [[ErrorData]] (no captured stack slot).
    if (this === null || typeof this !== "object") return undefined;
    var v = this[STACK];
    return v === undefined ? undefined : v;
  };
  var setStack = function stack(value) {
    // SetterThatIgnoresPrototypeProperties (error-stack-accessor proposal §set stack):
    //   1. Let E be the this value.
    //   2. If E is not an Object, throw a TypeError.
    //   3. If v is not a String, throw a TypeError.
    //   4. If E has an own "stack" property, Set(E, "stack", v, true).
    //   5. Else CreateDataPropertyOrThrow(E, "stack", v).
    // Both step 4/5 throw when the underlying [[Set]]/[[DefineOwnProperty]] fails
    // (non-writable own data, non-extensible, or a Proxy trap returning false).
    if (this === null || typeof this !== "object") {
      throw new TypeError("Error.prototype.stack setter called on non-object");
    }
    if (typeof value !== "string") {
      throw new TypeError("Error.prototype.stack setter requires a String value");
    }
    var existing = Object.getOwnPropertyDescriptor(this, "stack");
    if (existing !== undefined && "value" in existing) {
      // Own data "stack" already present → Set with Throw=true.
      if (!Reflect.set(this, "stack", value, this)) {
        throw new TypeError('Cannot set "stack" on this Error');
      }
      return;
    }
    // No own data "stack" (absent, or an own accessor) → CreateDataPropertyOrThrow.
    if (!Reflect.defineProperty(this, "stack", {
      value: value, writable: true, enumerable: true, configurable: true
    })) {
      throw new TypeError('Cannot create "stack" property on this Error');
    }
  };
  // "get "/"set " name prefixes are applied by the engine when installed as accessors;
  // rename the functions so Function.prototype.name reads "get stack" / "set stack".
  try { Object.defineProperty(getStack, "name", { value: "get stack", configurable: true }); } catch (_) {}
  try { Object.defineProperty(setStack, "name", { value: "set stack", configurable: true }); } catch (_) {}
  Object.defineProperty(Error.prototype, "stack", {
    get: getStack, set: setStack, enumerable: false, configurable: true
  });
})();

// ─── AggregateError (§20.5.7) ───────────────────────────────────────────────

// InstallErrorCause (ES §20.5.8.1): `cause` becomes an own
// { w:T, e:F, c:T } property only when options is an object with a "cause"
// property — a plain `{}` or a non-object options argument installs nothing.
function _installErrorCause(target, options) {
  if (options !== null && typeof options === 'object' && 'cause' in options) {
    Object.defineProperty(target, 'cause', {
      value: options.cause,
      writable: true,
      enumerable: false,
      configurable: true
    });
  }
}

// IteratorToList (§7.4.13) via the iteration protocol, so a custom
// Symbol.iterator is honoured and a non-iterable argument throws TypeError.
function _errorsToList(errors) {
  const out = [];
  if (errors === null || errors === undefined) {
    throw new TypeError('AggregateError errors argument is not iterable');
  }
  const itFn = errors[Symbol.iterator];
  if (typeof itFn !== 'function') {
    throw new TypeError('AggregateError errors argument is not iterable');
  }
  const it = itFn.call(errors);
  if (it === null || typeof it !== 'object') {
    throw new TypeError('Result of the Symbol.iterator method is not an object');
  }
  while (true) {
    const res = it.next();
    if (res === null || typeof res !== 'object') {
      throw new TypeError('Iterator result is not an object');
    }
    if (res.done) break;
    out.push(res.value);
  }
  return out;
}

// §20.5.7.1.1 orders the steps: message is coerced and installed, then cause,
// and only then is `errors` iterated — a throwing iterator must not preempt a
// throwing message coercion.  Shared by the class constructor and the callable
// wrapper so both initialize `target` identically.
function _aggregateErrorInit(target, errors, message, options) {
  if (message !== undefined) {
    Object.defineProperty(target, 'message', {
      value: String(message),
      writable: true,
      enumerable: false,
      configurable: true
    });
  }
  _installErrorCause(target, options);
  Object.defineProperty(target, 'errors', {
    value: _errorsToList(errors),
    writable: true,
    enumerable: false,
    configurable: true
  });
}
class AggregateError extends Error {
  constructor(errors, message, options) {
    super();
    _aggregateErrorInit(this, errors, message, options);
  }
}
// §20.5.7.1: AggregateError is callable without `new`, which `class` forbids —
// expose a forwarding function.  This engine has no `new.target` meta-property,
// so `new.target`-aware subclassing (OrdinaryCreateFromConstructor) is emulated
// via the `this` binding the VM's super-call path supplies: when invoked as a
// super constructor (`class X extends AggregateError { }` → `super()`), `this`
// is the already-allocated derived instance (an object) carrying the subclass
// prototype, so we initialize it IN PLACE and preserve `X.prototype`.  When
// called plainly (`AggregateError(...)`, `this` is undefined in strict mode),
// we build a fresh %AggregateError% instance.
function _AggregateError(errors, message, options) {
  // `this instanceof AggregateError` distinguishes a super()/new invocation
  // (the derived instance already chains to AggregateError.prototype) from a
  // plain call (`this` is undefined in strict mode or globalThis in sloppy).
  if (this instanceof AggregateError) {
    _aggregateErrorInit(this, errors, message, options);
    return this;
  }
  return new AggregateError(errors, message, options);
}
_AggregateError.prototype = AggregateError.prototype;
// §20.5.7.2: [[Prototype]] of the AggregateError constructor is %Error% itself
// (class..extends set this on the class; the forwarding function needs it too).
Object.setPrototypeOf(_AggregateError, Error);
Object.defineProperty(AggregateError.prototype, 'constructor', {
  value: _AggregateError, writable: true, enumerable: false, configurable: true
});
// §20.5.7.2.1: `prototype` is { w:F, e:F, c:F }; name/length are { w:F, e:F, c:T }.
Object.defineProperty(_AggregateError, 'prototype', {
  value: AggregateError.prototype,
  writable: false, enumerable: false, configurable: false
});
Object.defineProperty(_AggregateError, "name", {
  value: "AggregateError", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(_AggregateError, "length", {
  value: 2, writable: false, enumerable: false, configurable: true
});
Object.defineProperty(AggregateError.prototype, "name", {
  value: "AggregateError",
  writable: true,
  enumerable: false,
  configurable: true
});
// §20.5.7.3.2: the prototype carries an empty `message`; `errors` is NEVER a
// prototype property (only instances have it).
Object.defineProperty(AggregateError.prototype, "message", {
  value: "",
  writable: true,
  enumerable: false,
  configurable: true
});
// §19: global builtin bindings are { w:T, e:F, c:T }, not enumerable. Bind the
// callable-without-new wrapper `_AggregateError` (adel_fixes bound the plain
// class, which cannot be called without `new`).
_installGlobal('AggregateError', _AggregateError);

// ─── SuppressedError (ES2026 explicit resource management, §20.5.8) ──────────
// Thrown when disposal raises while another error is already propagating: it
// carries both the new `error` and the `suppressed` original.

// Shared initializer (§20.5.8.1 step 4: message is coerced and installed only
// when supplied) — used by the class and the callable wrapper alike.
function _suppressedErrorInit(target, error, suppressed, message, options) {
  if (message !== undefined) {
    Object.defineProperty(target, 'message', {
      value: String(message),
      writable: true, enumerable: false, configurable: true
    });
  }
  _installErrorCause(target, options);
  Object.defineProperty(target, 'error', {
    value: error, writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(target, 'suppressed', {
    value: suppressed, writable: true, enumerable: false, configurable: true
  });
}
class SuppressedError extends Error {
  constructor(error, suppressed, message, options) {
    super();
    _suppressedErrorInit(this, error, suppressed, message, options);
  }
}
// SuppressedError is callable without `new` (§20.5.8.1), which `class` forbids,
// so the exposed binding is a plain function that forwards to the class.  As
// with _AggregateError, subclass super() invocations arrive with `this` bound
// to the derived instance (chains to SuppressedError.prototype), so initialize
// in place to preserve the subclass prototype; a plain call builds fresh.
function _SuppressedError(error, suppressed, message, options) {
  if (this instanceof SuppressedError) {
    _suppressedErrorInit(this, error, suppressed, message, options);
    return this;
  }
  return new SuppressedError(error, suppressed, message, options);
}
_SuppressedError.prototype = SuppressedError.prototype;
// §20.5.8.2: [[Prototype]] of the SuppressedError constructor is %Error%.
Object.setPrototypeOf(_SuppressedError, Error);
Object.defineProperty(SuppressedError.prototype, 'constructor', {
  value: _SuppressedError, writable: true, enumerable: false, configurable: true
});
Object.defineProperty(_SuppressedError, 'name', {
  value: 'SuppressedError', writable: false, enumerable: false, configurable: true
});
Object.defineProperty(_SuppressedError, 'length', {
  value: 3, writable: false, enumerable: false, configurable: true
});
Object.defineProperty(SuppressedError.prototype, 'name', {
  value: 'SuppressedError', writable: true, enumerable: false, configurable: true
});
Object.defineProperty(SuppressedError.prototype, 'message', {
  value: '', writable: true, enumerable: false, configurable: true
});
Object.defineProperty(_SuppressedError, 'prototype', {
  value: SuppressedError.prototype,
  writable: false, enumerable: false, configurable: false
});
Object.defineProperty(globalThis, 'SuppressedError', {
  value: _SuppressedError, writable: true, enumerable: false, configurable: true
});

// ─── Error.isError (ES2026 §20.5.2.1) ───────────────────────────────────────
// Brand check for "is this a genuine Error instance", true for cross-realm
// errors and false for objects that merely inherit from Error.prototype.
if (typeof Error.isError !== 'function') {
  Object.defineProperty(Error, 'isError', {
    value: function isError(arg) {
      if (arg === null || typeof arg !== 'object') return false;
      // No [[ErrorData]] slot is exposed to JS, so approximate it with the
      // stack/message shape every engine-constructed error carries.
      return Object.prototype.hasOwnProperty.call(arg, 'stack') &&
             Error.prototype.isPrototypeOf(arg);
    },
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(Error.isError, 'length', {
    value: 1, writable: false, enumerable: false, configurable: true
  });
}

// ─── Iterator helpers namespace (ES2024 §27.1.2) ────────────────────────────

function _defineIteratorMethod(proto, name, arity, fn) {
  const method = function() {
    "use strict"; // built-in methods do not box a primitive/null `this`
    if (new.target !== undefined) {
      throw new TypeError(name + " is not a constructor");
    }
    return fn.apply(this, arguments);
  };
  Object.defineProperty(proto, name, {
    value: method,
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(method, "name", {
    value: name, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(method, "length", {
    value: arity, writable: false, enumerable: false, configurable: true
  });
}

// Invoke iterator [[Return]]. Generator iterators in this engine only close on a
// direct CALL_METHOD (`obj.return()`); a fetched-then-applied return
// (`ret.call(obj)`) does NOT resume/close the frame. So dispatch generators via a
// direct method call and everything else via GetMethod + Call (spec §7.4.11).
function _callIteratorReturn(obj) {
  if (_isGeneratorIterator(obj)) {
    if (typeof obj.return === "function") return obj.return();
    return undefined;
  }
  const ret = obj.return;
  if (typeof ret === "function") return ret.call(obj);
  return undefined;
}

function _closeWithoutNext(obj) {
  try {
    _callIteratorReturn(obj);
  } catch (_) {}
}

function _iteratorClose(record, err) {
  try {
    _callIteratorReturn(record.object);
  } catch (closeErr) {
    if (err === undefined) throw closeErr;
  }
  if (err !== undefined) throw err;
}

function _iteratorNextStep(record) {
  const step = record.next();
  if (step == null || typeof step !== "object") {
    throw new TypeError("Iterator result must be an object");
  }
  return step;
}

function _isGeneratorIterator(obj) {
  // Prefer @@toStringTag: Generator.prototype identity is not stable across
  // realms / install order in this engine, and caching Get(next) always returns done.
  // Callers that must not observe toStringTag (Iterator.from GetIteratorDirect)
  // should use _iteratorRecordDirect instead.
  try {
    if (Object.prototype.toString.call(obj) === "[object Generator]") return true;
  } catch (_e) {}
  if (typeof Generator === "undefined") return false;
  const proto = Object.getPrototypeOf(obj);
  return proto === Generator.prototype
    || (proto != null && Object.getPrototypeOf(proto) === Generator.prototype);
}

// Shared validation preamble for map/filter/flatMap (§27.1.3.2.x):
//   1. O is Object    (TypeError)
//   2. IsCallable(fn) (TypeError)  ← BEFORE any `.next` access
//   3. GetIteratorDirect(O)        ← touches `.next`
// Returns the iterator record. Ordering matters: the callable check must precede
// the `.next` [[Get]] so argument-effect-order tests observe no `get next`.
function _iteratorHelperPreamble(thisVal, fn, fnName) {
  if (thisVal == null || (typeof thisVal !== "object" && typeof thisVal !== "function")) {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  if (typeof fn !== "function") {
    // Spec closes the underlying iterator (via its `return`, WITHOUT reading
    // `next`) before surfacing the TypeError from argument validation.
    _closeWithoutNext(thisVal);
    throw new TypeError(fnName + " must be a function");
  }
  return _iteratorRecord(thisVal);
}

// GetMethod(V, P) — §7.3.10
function _getMethod(obj, key) {
  const v = obj[key];
  if (v === undefined || v === null) return undefined;
  if (typeof v !== "function") {
    throw new TypeError("Method is not callable");
  }
  return v;
}

// GetOptionsObject(options) — shared by Iterator.zip / zipKeyed
function _getOptionsObject(options) {
  if (options === undefined) return Object.create(null);
  if (options === null || (typeof options !== "object" && typeof options !== "function")) {
    throw new TypeError("options must be an object");
  }
  return options;
}

// GetIteratorDirect without generator brand-check — only [[Get]]s `next`.
// Used by Iterator.from / zip so @@toStringTag is not observed.
function _iteratorRecordDirect(obj) {
  if (obj == null || (typeof obj !== "object" && typeof obj !== "function")) {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  const nextMethod = obj.next;
  return {
    object: obj,
    next: function() {
      if (typeof nextMethod !== "function") {
        throw new TypeError("Iterator .next is not a function");
      }
      return nextMethod.call(obj);
    }
  };
}

// GetIteratorFlattenable(obj, primitiveHandling [, brandCheck]) — §7.4.5
// primitiveHandling: "reject-primitives" | "iterate-string-primitives"
// brandCheck: when true (flatMap), use generator-aware _iteratorRecord.
function _getIteratorFlattenable(obj, primitiveHandling, brandCheck) {
  const mode = primitiveHandling === undefined ? "reject-primitives" : primitiveHandling;
  let methodTarget = obj;
  let methodReceiver = obj;
  if (obj === null || typeof obj !== "object" && typeof obj !== "function") {
    if (mode === "reject-primitives") {
      throw new TypeError("Iterator requires an object");
    }
    // iterate-string-primitives
    if (typeof obj !== "string") {
      throw new TypeError("Iterator.from requires an object or string");
    }
    // Box before GetMethod: string-primitive [[Get]] can miss inherited
    // accessors here. Keep the primitive as Reflect receiver so getters see
    // typeof this === "string".
    methodTarget = Object(obj);
    methodReceiver = obj;
  }
  const rawMethod = Reflect.get(methodTarget, Symbol.iterator, methodReceiver);
  let method;
  if (rawMethod === undefined || rawMethod === null) {
    method = undefined;
  } else if (typeof rawMethod !== "function") {
    throw new TypeError("Method is not callable");
  } else {
    method = rawMethod;
  }
  let iterator;
  if (method === undefined) {
    iterator = methodTarget;
  } else {
    iterator = method.call(methodReceiver);
  }
  if (iterator === null || (typeof iterator !== "object" && typeof iterator !== "function")) {
    throw new TypeError("Iterator result is not an object");
  }
  if (brandCheck) return _iteratorRecord(iterator);
  return _iteratorRecordDirect(iterator);
}

function _iteratorRecord(obj) {
  if (obj == null || (typeof obj !== "object" && typeof obj !== "function")) {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  // Generator iterators synthesize a fresh native .next on each [[Get]]; only
  // CALL_METHOD (obj.next()) resumes correctly. Plain protocol objects cache
  // [[NextMethod]] once (getter-backed `next` must not be re-fetched).
  // Generators: CALL_METHOD for .next — never cache Get(next).
  // Brand-check only (do not touch .next/.throw/.return getters — set-like order tests).
  if (_isGeneratorIterator(obj)) {
    return {
      object: obj,
      next: function() { return obj.next(); }
    };
  }
  // GetIteratorDirect (§7.4.6) reads `next` but does NOT check IsCallable — the
  // TypeError surfaces lazily when the stored method is actually called (§7.4.8
  // IteratorNext → Call). Defer the callability check to next()-invocation time.
  const nextMethod = obj.next;
  return {
    object: obj,
    next: function() {
      if (typeof nextMethod !== "function") {
        throw new TypeError("Iterator .next is not a function");
      }
      return nextMethod.call(obj);
    }
  };
}

const IteratorPrototype = Object.create(Object.prototype);

// %WrapForValidIteratorPrototype% — §27.1.3.2.2.1
const WrapForValidIteratorPrototype = Object.create(IteratorPrototype);
Object.defineProperty(WrapForValidIteratorPrototype, "next", {
  value: function next() {
    "use strict";
    if (this === null || typeof this !== "object" || !("_iterated" in this)) {
      throw new TypeError("next called on incompatible WrapForValidIterator");
    }
    return this._iterated.next();
  },
  writable: true, enumerable: false, configurable: true
});
Object.defineProperty(WrapForValidIteratorPrototype, "return", {
  value: function () {
    "use strict";
    if (this === null || typeof this !== "object" || !("_iterated" in this)) {
      throw new TypeError("return called on incompatible WrapForValidIterator");
    }
    const iterator = this._iterated.object;
    const returnMethod = _getMethod(iterator, "return");
    if (returnMethod === undefined) {
      return { value: undefined, done: true };
    }
    return returnMethod.call(iterator);
  },
  writable: true, enumerable: false, configurable: true
});
function _wrapForValidIterator(record) {
  const wrapper = Object.create(WrapForValidIteratorPrototype);
  wrapper._iterated = record;
  return wrapper;
}

// %IteratorHelperPrototype% (§27.1.3.2) — the [[Prototype]] of the objects
// returned by map/filter/take/drop/flatMap. Inherits %Iterator.prototype% so a
// helper result is `instanceof Iterator` and itself supports the helper methods.
// Each helper builds its object via _makeIteratorHelper(step[, ret]):
//   step()  — advances the underlying source, returns an IteratorResult
//   ret()   — optional; closes the underlying source on early `.return()`
const IteratorHelperPrototype = Object.create(IteratorPrototype);
Object.defineProperty(IteratorHelperPrototype, Symbol.toStringTag, {
  value: "Iterator Helper", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(IteratorHelperPrototype, "next", {
  value: function next() {
    "use strict";
    if (this === null || typeof this !== "object" || !("_step" in this)) {
      throw new TypeError("next called on an incompatible Iterator Helper");
    }
    if (this._done) return { value: undefined, done: true };
    // §27.1.4.1: iterator helpers are implemented as generators — re-entering a
    // helper that is still executing (e.g. the mapper/predicate calls the
    // helper's own next) must throw TypeError, not recurse.
    if (this._running) {
      throw new TypeError("Iterator Helper is already running");
    }
    this._running = true;
    // NOTE: a plain try/finally is avoided here — see the try/finally
    // exception-propagation bug; use try/catch with an explicit re-throw so the
    // `_running` flag is always cleared without swallowing the error.
    let r;
    try {
      r = this._step();
    } catch (err) {
      this._running = false;
      throw err;
    }
    this._running = false;
    if (r.done) this._done = true;
    return r;
  },
  writable: true, enumerable: false, configurable: true
});
Object.defineProperty(IteratorHelperPrototype, "return", {
  value: function() {
    "use strict";
    if (this === null || typeof this !== "object" || !("_step" in this)) {
      throw new TypeError("return called on an incompatible Iterator Helper");
    }
    // Generator-style helpers: re-entering while suspended-yield / running throws.
    if (this._running) {
      throw new TypeError("Iterator Helper is already running");
    }
    // §27.1.4.2: only forward the close to the underlying iterator once — a
    // helper already exhausted or closed must not re-invoke the source `return`.
    if (!this._done) {
      this._done = true;
      if (typeof this._ret === "function") this._ret();
    }
    return { value: undefined, done: true };
  },
  writable: true, enumerable: false, configurable: true
});
function _makeIteratorHelper(step, ret) {
  const helper = Object.create(IteratorHelperPrototype);
  helper._step = step;
  helper._ret = ret;
  helper._done = false;
  helper._running = false;
  return helper;
}

_defineIteratorMethod(IteratorPrototype, "reduce", 1, function(reducer, initialValue) {
  "use strict";
  const obj = this;
  if (obj == null || typeof obj !== "object") {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  if (typeof reducer !== "function") {
    _closeWithoutNext(obj);
    throw new TypeError("Reducer must be a function");
  }
  const record = _iteratorRecord(obj);
  const hasInitial = arguments.length >= 2;
  let acc = hasInitial ? initialValue : undefined;
  let started = false;
  let idx = hasInitial ? 0 : 1;
  try {
    while (true) {
      const step = _iteratorNextStep(record);
      if (step.done) break;
      if (!hasInitial && !started) {
        acc = step.value;
        started = true;
      } else {
        acc = reducer(acc, step.value, idx);
        idx++;
      }
    }
  } catch (err) {
    _iteratorClose(record, err);
  }
  if (!hasInitial && !started) throw new TypeError("Reduce of empty iterator with no initial value");
  return acc;
});

_defineIteratorMethod(IteratorPrototype, "map", 1, function map(mapper) {
  "use strict";
  const source = _iteratorHelperPreamble(this, mapper, "Mapper");
  let idx = 0;
  return _makeIteratorHelper(function() {
    const step = _iteratorNextStep(source);
    if (step.done) return { value: undefined, done: true };
    let mapped;
    try {
      mapped = mapper(step.value, idx++);
    } catch (err) {
      _iteratorClose(source, err);
    }
    return { value: mapped, done: false };
  }, function() { _callIteratorReturn(source.object); });
});

_defineIteratorMethod(IteratorPrototype, "toArray", 0, function toArray() {
  "use strict";
  const record = _iteratorRecord(this);
  const arr = [];
  while (true) {
    const step = _iteratorNextStep(record);
    if (step.done) break;
    arr.push(step.value);
  }
  return arr;
});

_defineIteratorMethod(IteratorPrototype, "forEach", 1, function forEach(fn) {
  "use strict";
  const record = _iteratorHelperPreamble(this, fn, "Callback");
  let idx = 0;
  while (true) {
    const step = _iteratorNextStep(record);
    if (step.done) return undefined;
    try {
      fn(step.value, idx++);
    } catch (err) {
      _iteratorClose(record, err);
    }
  }
});

_defineIteratorMethod(IteratorPrototype, "filter", 1, function filter(predicate) {
  "use strict";
  const source = _iteratorHelperPreamble(this, predicate, "Predicate");
  let idx = 0;
  return _makeIteratorHelper(function() {
    while (true) {
      const step = _iteratorNextStep(source);
      if (step.done) return { value: undefined, done: true };
      let keep;
      try {
        keep = predicate(step.value, idx++);
      } catch (err) {
        _iteratorClose(source, err);
      }
      if (keep) return { value: step.value, done: false };
    }
  }, function() { _callIteratorReturn(source.object); });
});

_defineIteratorMethod(IteratorPrototype, "flatMap", 1, function flatMap(mapper) {
  "use strict";
  const source = _iteratorHelperPreamble(this, mapper, "Mapper");
  let innerRecord = null;
  let idx = 0;
  return _makeIteratorHelper(function() {
    while (true) {
      if (innerRecord) {
        const innerStep = _iteratorNextStep(innerRecord);
        if (!innerStep.done) return { value: innerStep.value, done: false };
        innerRecord = null;
      }
      const step = _iteratorNextStep(source);
      if (step.done) return { value: undefined, done: true };
      try {
        const mapped = mapper(step.value, idx++);
        // GetIteratorFlattenable(mapped, reject-primitives): accepts an object
        // that is either iterable (@@iterator) or an iterator itself (`next`).
        // brandCheck=true so generator inners keep CALL_METHOD semantics.
        innerRecord = _getIteratorFlattenable(mapped, "reject-primitives", true);
      } catch (err) {
        _iteratorClose(source, err);
      }
    }
  }, function() {
    if (innerRecord) _callIteratorReturn(innerRecord.object);
    _callIteratorReturn(source.object);
  });
});

_defineIteratorMethod(IteratorPrototype, "find", 1, function find(predicate) {
  "use strict";
  const record = _iteratorHelperPreamble(this, predicate, "Predicate");
  let idx = 0;
  while (true) {
    const step = _iteratorNextStep(record);
    if (step.done) return undefined;
    let matched;
    try {
      matched = predicate(step.value, idx++);
    } catch (err) {
      _iteratorClose(record, err);
    }
    if (matched) {
      // ? IteratorClose(iterated, NormalCompletion(value))
      _callIteratorReturn(record.object);
      return step.value;
    }
  }
});

_defineIteratorMethod(IteratorPrototype, "some", 1, function some(predicate) {
  "use strict";
  const record = _iteratorHelperPreamble(this, predicate, "Predicate");
  let idx = 0;
  while (true) {
    const step = _iteratorNextStep(record);
    if (step.done) return false;
    let matched;
    try {
      matched = predicate(step.value, idx++);
    } catch (err) {
      _iteratorClose(record, err);
    }
    if (matched) {
      // ? IteratorClose(iterated, NormalCompletion(true))
      _callIteratorReturn(record.object);
      return true;
    }
  }
});

_defineIteratorMethod(IteratorPrototype, "every", 1, function every(predicate) {
  "use strict";
  const record = _iteratorHelperPreamble(this, predicate, "Predicate");
  let idx = 0;
  while (true) {
    const step = _iteratorNextStep(record);
    if (step.done) return true;
    let matched;
    try {
      matched = predicate(step.value, idx++);
    } catch (err) {
      _iteratorClose(record, err);
    }
    if (!matched) {
      // ? IteratorClose(iterated, NormalCompletion(false))
      _callIteratorReturn(record.object);
      return false;
    }
    continue;
  }
});

// ToIntegerOrInfinity (§7.1.5) — for limit validation in take/drop.
function _toIntegerOrInfinity(n) {
  const num = Number(n);
  if (Number.isNaN(num) || num === 0) return 0;
  if (num === Infinity) return Infinity;
  if (num === -Infinity) return -Infinity;
  return Math.trunc(num);
}

// Validate the take/drop `limit`: ToNumber + NaN/negative range check. On ANY
// failure (ToNumber throwing, NaN, negative) the underlying iterator `obj` is
// closed (via `return`, without reading `next`) before the error propagates.
// Returns the non-negative integer (or Infinity) limit.
function _validateLimit(obj, limit) {
  let integerLimit;
  try {
    const numLimit = Number(limit);
    if (Number.isNaN(numLimit)) {
      throw new RangeError("limit must not be NaN");
    }
    integerLimit = _toIntegerOrInfinity(numLimit);
    if (integerLimit < 0) {
      throw new RangeError("limit must be non-negative");
    }
  } catch (err) {
    _closeWithoutNext(obj);
    throw err;
  }
  return integerLimit;
}

_defineIteratorMethod(IteratorPrototype, "take", 1, function take(limit) {
  "use strict"; // do not box a null/primitive `this` before the receiver check
  // §27.1.3.2.10: (1) require Object receiver, (2) ToNumber(limit) + range
  // validation, and only THEN (3) GetIteratorDirect (touching `.next`).
  const obj = this;
  if (obj == null || typeof obj !== "object") {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  const integerLimit = _validateLimit(obj, limit);
  const source = _iteratorRecord(obj);
  let remaining = integerLimit;
  return _makeIteratorHelper(function() {
    if (remaining === 0) {
      // 8.b.i.1: Return ? IteratorClose(iterated, NormalCompletion(undefined)).
      // Mark done up front so a throwing `return` (which propagates) is not
      // re-invoked on the next `.next()` call.
      this._done = true;
      _callIteratorReturn(source.object);
      return { value: undefined, done: true };
    }
    if (remaining !== Infinity) remaining--;
    const step = _iteratorNextStep(source);
    if (step.done) return { value: undefined, done: true };
    return { value: step.value, done: false };
  }, function() { _callIteratorReturn(source.object); });
});

_defineIteratorMethod(IteratorPrototype, "drop", 1, function drop(limit) {
  "use strict"; // do not box a null/primitive `this` before the receiver check
  // §27.1.3.2.4: same ordering as take — Object check, ToNumber + range check,
  // then GetIteratorDirect.
  const obj = this;
  if (obj == null || typeof obj !== "object") {
    throw new TypeError("Iterator method called on incompatible receiver");
  }
  const integerLimit = _validateLimit(obj, limit);
  const source = _iteratorRecord(obj);
  let skip = integerLimit;
  return _makeIteratorHelper(function() {
    let step;
    while (skip > 0) {
      if (skip !== Infinity) skip--;
      step = _iteratorNextStep(source);
      if (step.done) return { value: undefined, done: true };
    }
      step = _iteratorNextStep(source);
      if (step.done) return { value: undefined, done: true };
      return { value: step.value, done: false };
  }, function() { _callIteratorReturn(source.object); });
});

// %Iterator.prototype% [ @@iterator ] ( ) — §27.1.3.2.2: returns the this value.
// Strict so a primitive/undefined/null `this` is returned as-is (not boxed).
Object.defineProperty(IteratorPrototype, Symbol.iterator, {
  value: function () { "use strict"; return this; },
  writable: true, enumerable: false, configurable: true
});
Object.defineProperty(IteratorPrototype[Symbol.iterator], "name", {
  value: "[Symbol.iterator]", writable: false, enumerable: false, configurable: true
});

// %Iterator.prototype% [ @@dispose ] ( ) — explicit-resource-management: calls
// the iterator's `return` method (via GetMethod) if present.
if (typeof Symbol.dispose !== "undefined") {
  Object.defineProperty(IteratorPrototype, Symbol.dispose, {
    value: function () {
      "use strict";
      const O = this;
      if (O == null || (typeof O !== "object" && typeof O !== "function")) {
        throw new TypeError("Iterator.prototype[Symbol.dispose] requires an object receiver");
      }
      const ret = O.return;
      if (ret !== undefined && ret !== null) {
        if (typeof ret !== "function") {
          throw new TypeError("return is not callable");
        }
        ret.call(O);
      }
      return undefined;
    },
    writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(IteratorPrototype[Symbol.dispose], "name", {
    value: "[Symbol.dispose]", writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(IteratorPrototype[Symbol.dispose], "length", {
    value: 0, writable: false, enumerable: false, configurable: true
  });
}

// SetterThatIgnoresPrototypeProperties(home, p, v) — §27.1.3.2 helper used by
// the `constructor` and @@toStringTag setters on %Iterator.prototype%.
function _setterIgnoresPrototypeProperties(home, p, thisValue, v) {
  if (thisValue == null || (typeof thisValue !== "object" && typeof thisValue !== "function")) {
    throw new TypeError("Iterator.prototype setter requires an object receiver");
  }
  if (thisValue === home) {
    // Emulates assignment to a non-writable data property on `home` in strict mode.
    throw new TypeError("Cannot set property on %Iterator.prototype% itself");
  }
  const desc = Object.getOwnPropertyDescriptor(thisValue, p);
  if (desc === undefined) {
    Object.defineProperty(thisValue, p, {
      value: v, writable: true, enumerable: true, configurable: true
    });
  } else {
    thisValue[p] = v;
  }
}

function Iterator() {
  // §27.1.3.1: the Iterator constructor is abstract — it throws only on direct
  // construction (new.target undefined or === %Iterator%), but allows a subclass
  // (`class X extends Iterator`) to construct, where new.target is the subclass.
  if (new.target === undefined || new.target === Iterator) {
    throw new TypeError("Iterator is not a constructor");
  }
}
Object.defineProperty(Iterator, "name", {
  value: "Iterator", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Iterator, "length", {
  value: 0, writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Iterator, "prototype", {
  value: IteratorPrototype, writable: false, enumerable: false, configurable: false
});

// Iterator.from ( O ) — §27.1.3.2.2
Iterator.from = function from(O) {
  if (new.target !== undefined) {
    throw new TypeError("from is not a constructor");
  }
  const iteratorRecord = _getIteratorFlattenable(O, "iterate-string-primitives");
  if (iteratorRecord.object instanceof Iterator) {
    return iteratorRecord.object;
  }
  return _wrapForValidIterator(iteratorRecord);
};

function _iteratorCloseAll(records, err) {
  // IteratorCloseAll closes in reverse List order (LIFO).
  let pending = err;
  for (let i = records.length - 1; i >= 0; i--) {
    const rec = records[i];
    if (rec === null || rec === undefined) continue;
    try {
      _callIteratorReturn(rec.object);
    } catch (closeErr) {
      if (pending === undefined) pending = closeErr;
    }
  }
  if (pending !== undefined) throw pending;
}

// Shared IteratorZip helper used by zip / zipKeyed.
function _iteratorZip(iters, mode, padding, finishResults) {
  const iterCount = iters.length;
  // openIters tracks still-open records (null slots mean exhausted in longest mode)
  const open = iters.slice();
  return _makeIteratorHelper(function () {
    if (iterCount === 0) return { value: undefined, done: true };
    const results = [];
    for (let i = 0; i < iterCount; i++) {
      let iter = iters[i];
      if (iter === null) {
        results.push(padding[i]);
        continue;
      }
      let step;
      try {
        step = _iteratorNextStep(iter);
      } catch (err) {
        open[i] = null;
        const remaining = [];
        for (let j = 0; j < iterCount; j++) {
          if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
        }
        _iteratorCloseAll(remaining, err);
      }
      if (step.done) {
        open[i] = null;
        if (mode === "shortest") {
          const remaining = [];
          for (let j = 0; j < iterCount; j++) {
            if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
          }
          _iteratorCloseAll(remaining, undefined);
          return { value: undefined, done: true };
        } else if (mode === "strict") {
          if (i !== 0) {
            const remaining = [];
            for (let j = 0; j < iterCount; j++) {
              if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
            }
            _iteratorCloseAll(remaining, new TypeError("Iterator.zip strict mode: unequal lengths"));
          }
          for (let k = 1; k < iterCount; k++) {
            let openStep;
            try {
              openStep = _iteratorNextStep(iters[k]);
            } catch (err) {
              open[k] = null;
              const remaining = [];
              for (let j = 0; j < iterCount; j++) {
                if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
              }
              _iteratorCloseAll(remaining, err);
            }
            if (openStep.done) {
              open[k] = null;
            } else {
              const remaining = [];
              for (let j = 0; j < iterCount; j++) {
                if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
              }
              _iteratorCloseAll(remaining, new TypeError("Iterator.zip strict mode: unequal lengths"));
            }
          }
          return { value: undefined, done: true };
        } else {
          // longest
          let anyOpen = false;
          for (let j = 0; j < iterCount; j++) {
            if (open[j] !== null && open[j] !== undefined) { anyOpen = true; break; }
          }
          if (!anyOpen) return { value: undefined, done: true };
          iters[i] = null;
          results.push(padding[i]);
        }
      } else {
        results.push(step.value);
      }
    }
    return { value: finishResults(results), done: false };
  }, function () {
    const remaining = [];
    for (let j = 0; j < iterCount; j++) {
      if (open[j] !== null && open[j] !== undefined) remaining.push(open[j]);
    }
    _iteratorCloseAll(remaining, undefined);
  });
}

Iterator.zip = function zip(iterables, options) {
  if (new.target !== undefined) {
    throw new TypeError("zip is not a constructor");
  }
  if (iterables === null || (typeof iterables !== "object" && typeof iterables !== "function")) {
    throw new TypeError("Iterator.zip requires an object");
  }
  options = _getOptionsObject(options);
  let mode = options.mode;
  if (mode === undefined) mode = "shortest";
  if (mode !== "shortest" && mode !== "longest" && mode !== "strict") {
    throw new TypeError('Iterator.zip mode must be "shortest", "longest", or "strict"');
  }
  let paddingOption = undefined;
  if (mode === "longest") {
    paddingOption = options.padding;
    if (paddingOption !== undefined &&
        (paddingOption === null || (typeof paddingOption !== "object" && typeof paddingOption !== "function"))) {
      throw new TypeError("Iterator.zip padding must be an object");
    }
  }
  const iters = [];
  const inputIter = iterables[Symbol.iterator];
  if (typeof inputIter !== "function") {
    throw new TypeError("Iterator.zip requires an iterable");
  }
  const inputRecord = _iteratorRecord(inputIter.call(iterables));
  try {
    while (true) {
      const step = _iteratorNextStep(inputRecord);
      if (step.done) break;
      let inner;
      try {
        inner = _getIteratorFlattenable(step.value, "reject-primitives");
      } catch (err) {
        _iteratorCloseAll([inputRecord].concat(iters), err);
      }
      iters.push(inner);
    }
  } catch (err) {
    _iteratorCloseAll(iters, err);
  }
  const iterCount = iters.length;
  const padding = [];
  if (mode === "longest") {
    if (paddingOption === undefined) {
      for (let i = 0; i < iterCount; i++) padding.push(undefined);
    } else {
      const paddingIterFn = paddingOption[Symbol.iterator];
      if (typeof paddingIterFn !== "function") {
        _iteratorCloseAll(iters, new TypeError("Iterator.zip padding is not iterable"));
      }
      let paddingRecord;
      try {
        paddingRecord = _iteratorRecord(paddingIterFn.call(paddingOption));
      } catch (err) {
        _iteratorCloseAll(iters, err);
      }
      let usingIterator = true;
      for (let i = 0; i < iterCount; i++) {
        if (usingIterator) {
          let next;
          try {
            next = _iteratorNextStep(paddingRecord);
          } catch (err) {
            _iteratorCloseAll(iters, err);
          }
          if (next.done) {
            usingIterator = false;
            padding.push(undefined);
          } else {
            padding.push(next.value);
          }
        } else {
          padding.push(undefined);
        }
      }
      if (usingIterator) {
        try {
          _callIteratorReturn(paddingRecord.object);
        } catch (err) {
          _iteratorCloseAll(iters, err);
        }
      }
    }
  }
  return _iteratorZip(iters, mode, padding, function (results) {
    return results.slice();
  });
};
Object.defineProperty(Iterator.zip, "name", {
  value: "zip", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Iterator.zip, "length", {
  value: 1, writable: false, enumerable: false, configurable: true
});
_installMeta(Iterator.from, "from", 1);
_rejectConstruct(Iterator.from);
Object.defineProperty(Iterator, "from", {
  value: Iterator.from, writable: true, enumerable: false, configurable: true
});
_rejectConstruct(Iterator.zip);
Object.defineProperty(Iterator, "zip", {
  value: Iterator.zip, writable: true, enumerable: false, configurable: true
});

// Iterator.zipKeyed — zip own enumerable string-keyed iterables.
Iterator.zipKeyed = function zipKeyed(iterables, options) {
  if (new.target !== undefined) {
    throw new TypeError("zipKeyed is not a constructor");
  }
  if (iterables === null || (typeof iterables !== "object" && typeof iterables !== "function")) {
    throw new TypeError("Iterator.zipKeyed requires an object");
  }
  options = _getOptionsObject(options);
  let mode = options.mode;
  if (mode === undefined) mode = "shortest";
  if (mode !== "shortest" && mode !== "longest" && mode !== "strict") {
    throw new TypeError('Iterator.zipKeyed mode must be "shortest", "longest", or "strict"');
  }
  let paddingOption = undefined;
  if (mode === "longest") {
    paddingOption = options.padding;
    if (paddingOption !== undefined &&
        (paddingOption === null || (typeof paddingOption !== "object" && typeof paddingOption !== "function"))) {
      throw new TypeError("Iterator.zipKeyed padding must be an object");
    }
  }
  const iters = [];
  const keys = [];
  const allKeys = Reflect.ownKeys(iterables);
  for (let i = 0; i < allKeys.length; i++) {
    const key = allKeys[i];
    if (typeof key === "symbol") continue;
    const desc = Object.getOwnPropertyDescriptor(iterables, key);
    if (desc === undefined || !desc.enumerable) continue;
    const value = iterables[key];
    if (value === undefined) continue;
    let inner;
    try {
      inner = _getIteratorFlattenable(value, "reject-primitives");
    } catch (err) {
      _iteratorCloseAll(iters, err);
    }
    keys.push(key);
    iters.push(inner);
  }
  const iterCount = iters.length;
  const padding = [];
  if (mode === "longest") {
    if (paddingOption === undefined) {
      for (let i = 0; i < iterCount; i++) padding.push(undefined);
    } else {
      for (let i = 0; i < keys.length; i++) {
        padding.push(paddingOption[keys[i]]);
      }
    }
  }
  return _iteratorZip(iters, mode, padding, function (results) {
    const obj = Object.create(null);
    for (let i = 0; i < iterCount; i++) {
      obj[keys[i]] = results[i];
    }
    return obj;
  });
};
Object.defineProperty(Iterator.zipKeyed, "name", {
  value: "zipKeyed", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Iterator.zipKeyed, "length", {
  value: 1, writable: false, enumerable: false, configurable: true
});
_rejectConstruct(Iterator.zipKeyed);
Object.defineProperty(Iterator, "zipKeyed", {
  value: Iterator.zipKeyed, writable: true, enumerable: false, configurable: true
});

// Iterator.concat ( ...items ) — §27.1.3.2.1
// Captures OpenMethod per item eagerly; opens each iterable lazily on demand.
Iterator.concat = function concat() {
  if (new.target !== undefined) {
    throw new TypeError("concat is not a constructor");
  }
  const items = arguments;
  const iterables = [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (item === null || (typeof item !== "object" && typeof item !== "function")) {
      throw new TypeError("Iterator.concat item is not an object");
    }
    const method = _getMethod(item, Symbol.iterator);
    if (method === undefined) {
      throw new TypeError("Iterator.concat item is not iterable");
    }
    iterables.push({ openMethod: method, iterable: item });
  }
  let idx = 0;
  let innerRecord = null;
  return _makeIteratorHelper(function () {
    while (true) {
      if (innerRecord === null) {
        if (idx >= iterables.length) {
          return { value: undefined, done: true };
        }
        const rec = iterables[idx++];
        let iter;
        try {
          iter = rec.openMethod.call(rec.iterable);
        } catch (err) {
          throw err;
        }
        if (iter === null || (typeof iter !== "object" && typeof iter !== "function")) {
          throw new TypeError("Iterator.concat iterator is not an object");
        }
        innerRecord = _iteratorRecord(iter);
      }
      const step = _iteratorNextStep(innerRecord);
      if (step.done) {
        innerRecord = null;
        continue;
      }
      return { value: step.value, done: false };
    }
  }, function () {
    if (innerRecord !== null) {
      _callIteratorReturn(innerRecord.object);
      innerRecord = null;
    }
  });
};
Object.defineProperty(Iterator.concat, "name", {
  value: "concat", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Iterator.concat, "length", {
  value: 0, writable: false, enumerable: false, configurable: true
});
_rejectConstruct(Iterator.concat);
Object.defineProperty(Iterator, "concat", {
  value: Iterator.concat, writable: true, enumerable: false, configurable: true
});

// %Iterator.prototype%.constructor — §27.1.3.2.1: accessor pair. Getter returns
// %Iterator%; setter uses SetterThatIgnoresPrototypeProperties.
Object.defineProperty(IteratorPrototype, "constructor", {
  get: function () { return Iterator; },
  set: function (v) {
    "use strict"; // preserve a null/primitive receiver for the TypeError check
    _setterIgnoresPrototypeProperties(IteratorPrototype, "constructor", this, v);
  },
  enumerable: false,
  configurable: true
});
// %Iterator.prototype% [ @@toStringTag ] — §27.1.3.2.3: accessor pair. Getter
// returns "Iterator"; setter uses SetterThatIgnoresPrototypeProperties.
Object.defineProperty(IteratorPrototype, Symbol.toStringTag, {
  get: function () { return "Iterator"; },
  set: function (v) {
    "use strict"; // preserve a null/primitive receiver for the TypeError check
    _setterIgnoresPrototypeProperties(IteratorPrototype, Symbol.toStringTag, this, v);
  },
  enumerable: false,
  configurable: true
});

_installGlobal('Iterator', Iterator);
_installGlobal('__jacIteratorPrototype', IteratorPrototype);

// %Generator.prototype% — generator iterators inherit %Iterator.prototype% helpers.
const GeneratorPrototype = Object.create(IteratorPrototype);
function Generator() {
  throw new TypeError("Generator is not a constructor");
}
Object.defineProperty(Generator, "name", {
  value: "Generator", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(Generator, "prototype", {
  value: GeneratorPrototype, writable: false, enumerable: false, configurable: false
});
_installGlobal('Generator', Generator);
_installGlobal('__jacGeneratorPrototype', GeneratorPrototype);

// ─── SharedArrayBuffer / Atomics (SAB-backed single-threaded RMW) ───────────
//
// Allocation ceiling: lengths that pass ToIndex but cannot be backed (e.g. 7 PiB
// test262 cases) must RangeError before calling __buf.alloc.
const _SAB_MAX_SAFE_INDEX = 9007199254740991; // 2^53 - 1
const _SAB_ALLOC_LIMIT = 0x04000000; // 64 MiB — fail-fast under host ~100 MiB runner cap
const _SABBrand = Symbol('[[SharedArrayBufferData]]');

function _requireSAB(value, method) {
  if (value === null || (typeof value !== 'object' && typeof value !== 'function') ||
      !globalThis.__buf || typeof globalThis.__buf.binaryKind !== 'function' ||
      globalThis.__buf.binaryKind(value) !== 4) {
    throw new TypeError(method + ' called on incompatible receiver');
  }
}

function _sabToIntegerOrInfinity(value) {
  const n = typeof value === 'number' ? value : Number(value);
  if (n !== n) return 0;
  if (n === Infinity || n === -Infinity) return n;
  return n < 0 ? Math.ceil(n) : Math.floor(n);
}

function _sabToIndex(value) {
  if (value === undefined) return 0;
  const integerIndex = _sabToIntegerOrInfinity(value);
  if (integerIndex < 0) throw new RangeError('Invalid SharedArrayBuffer length');
  if (integerIndex > _SAB_MAX_SAFE_INDEX) throw new RangeError('Invalid SharedArrayBuffer length');
  // Canonicalize -0 to +0 (SameValueZero / ToIndex).
  if (integerIndex === 0) return 0;
  return integerIndex;
}

function _sabCheckAllocLimit(size) {
  if (size > _SAB_ALLOC_LIMIT) {
    throw new RangeError('SharedArrayBuffer allocation size too large');
  }
}

const _installInstancePrototype = globalThis.__jacInstallInstancePrototype || function(instance, newTarget, defaultProto) {
  const p = newTarget && newTarget.prototype;
  const proto = (typeof p === 'object' && p !== null) ? p : defaultProto;
  if (Object.getPrototypeOf(instance) !== proto) {
    Object.setPrototypeOf(instance, proto);
  }
};
const _parseBufferCtorArgs = globalThis.__jacParseBufferCtorArgs || function(byteLength, options, toIndexFn, optionsNullError) {
  const len = toIndexFn(byteLength);
  let maxLen = len;
  let hasMaxByteLength = false;
  // GetArrayBufferMaxByteLengthOption: non-Object options → empty (ignored).
  if (options !== undefined && options !== null && typeof options === 'object') {
    if (options.maxByteLength !== undefined) {
      maxLen = toIndexFn(options.maxByteLength);
      if (maxLen < len) {
        throw new RangeError('maxByteLength must be >= byteLength');
      }
      hasMaxByteLength = true;
    }
  }
  return { len: len, maxLen: maxLen, hasMaxByteLength: hasMaxByteLength };
};
const _installBufferSpecies = globalThis.__jacInstallBufferSpecies || function(Ctor) {
  if (typeof Symbol === 'undefined' || Symbol.species === undefined) return;
  const getter = function getSpecies() { return this; };
  try {
    Object.defineProperty(getter, 'name', {
      value: 'get [Symbol.species]',
      writable: false,
      enumerable: false,
      configurable: true
    });
  } catch (_) {}
  Object.defineProperty(Ctor, Symbol.species, {
    get: getter,
    configurable: true,
    enumerable: false
  });
};

class SharedArrayBuffer {
  constructor(byteLength, options) {
    if (new.target === undefined) {
      throw new TypeError("SharedArrayBuffer constructor requires 'new'");
    }
    const bufApi = globalThis.__buf;
    if (!bufApi) {
      throw new TypeError('SharedArrayBuffer backing store unavailable');
    }
    // Validate length/options BEFORE OrdinaryCreateFromConstructor side effects.
    const parsed = _parseBufferCtorArgs(
      byteLength,
      options,
      _sabToIndex,
      'SharedArrayBuffer options must be coercible to Object'
    );
    _installInstancePrototype(this, new.target, SharedArrayBuffer.prototype);
    _sabCheckAllocLimit(parsed.hasMaxByteLength ? parsed.maxLen : parsed.len);
    this._ptr = bufApi.alloc(parsed.len);
    this._byteLength = parsed.len;
    this._maxByteLength = parsed.maxLen;
    this._growable = parsed.hasMaxByteLength;
    this._detached = false;
    this._isSharedArrayBuffer = true;
    Object.defineProperty(this, _SABBrand, {
      value: true, writable: false, enumerable: false, configurable: false
    });
    bufApi.registerBuffer(
      this, this._ptr, this._byteLength, this._maxByteLength, 0,
      2 | (this._growable ? 8 : 0)
    );
  }

  get byteLength() {
    _requireSAB(this, 'get SharedArrayBuffer.prototype.byteLength');
    return this._detached ? 0 : this._byteLength;
  }

  get maxByteLength() {
    _requireSAB(this, 'get SharedArrayBuffer.prototype.maxByteLength');
    if (this._detached) return 0;
    return this._growable ? this._maxByteLength : this._byteLength;
  }

  get growable() {
    _requireSAB(this, 'get SharedArrayBuffer.prototype.growable');
    if (this._detached) return false;
    return this._growable === true;
  }

  grow(newByteLength) {
    _requireSAB(this, 'SharedArrayBuffer.prototype.grow');
    if (this._growable !== true) {
      throw new TypeError('SharedArrayBuffer is not growable');
    }
    const newLen = _sabToIndex(newByteLength);
    if (newLen < this._byteLength || newLen > this._maxByteLength) {
      throw new RangeError('Invalid SharedArrayBuffer grow length');
    }
    if (newLen === this._byteLength) return;
    const bufApi = globalThis.__buf;
    const oldPtr = this._ptr;
    const oldLen = this._byteLength;
    const newPtr = bufApi.alloc(newLen);
    if (oldLen > 0) {
      bufApi.copy(newPtr, 0, oldPtr, 0, oldLen);
    }
    if (newLen > oldLen) {
      bufApi.fill(newPtr, oldLen, newLen - oldLen, 0);
    }
    bufApi.free(oldPtr);
    this._ptr = newPtr;
    this._byteLength = newLen;
    bufApi.registerBuffer(
      this, this._ptr, this._byteLength, this._maxByteLength, -1,
      2 | (this._growable ? 8 : 0)
    );
  }

  slice(start, end) {
    _requireSAB(this, 'SharedArrayBuffer.prototype.slice');
    const len = this._byteLength;
    const relativeStart = _sabToIntegerOrInfinity(start);
    let first = relativeStart < 0 ? Math.max(len + relativeStart, 0) : Math.min(relativeStart, len);
    const relativeEnd = end === undefined ? len : _sabToIntegerOrInfinity(end);
    let final = relativeEnd < 0 ? Math.max(len + relativeEnd, 0) : Math.min(relativeEnd, len);
    const newLen = Math.max(final - first, 0);
    const C = _sabSpeciesConstructor(this);
    const result = new C(newLen);
    if (result === this) {
      throw new TypeError('SharedArrayBuffer species constructor returned the same SharedArrayBuffer');
    }
    if (!globalThis.__buf || globalThis.__buf.binaryKind(result) !== 4) {
      throw new TypeError('SharedArrayBuffer species did not return a SharedArrayBuffer');
    }
    if (result._byteLength < newLen) {
      throw new TypeError('SharedArrayBuffer species constructed buffer too small');
    }
    if (newLen > 0) {
      globalThis.__buf.copy(result._ptr, 0, this._ptr, first, newLen);
    }
    return result;
  }
}

function _sabSpeciesConstructor(O) {
  const defaultConstructor = SharedArrayBuffer;
  const C = O.constructor;
  if (C === undefined) return defaultConstructor;
  if (typeof C !== 'function' && (typeof C !== 'object' || C === null)) {
    throw new TypeError('SharedArrayBuffer species constructor is invalid');
  }
  if (typeof Symbol !== 'undefined' && Symbol.species !== undefined) {
    const S = C[Symbol.species];
    if (S === undefined || S === null) return defaultConstructor;
    if (typeof S !== 'function') {
      throw new TypeError('Symbol.species is not a constructor');
    }
    return S;
  }
  return typeof C === 'function' ? C : defaultConstructor;
}

function _installSharedArrayBufferSpecies() {
  _installBufferSpecies(SharedArrayBuffer);
}
_installSharedArrayBufferSpecies();

_installMeta(SharedArrayBuffer, "SharedArrayBuffer", 1);
_installMeta(SharedArrayBuffer.prototype.grow, "grow", 1);
_installMeta(SharedArrayBuffer.prototype.slice, "slice", 2);
if (typeof Symbol !== 'undefined' && Symbol.toStringTag !== undefined) {
  Object.defineProperty(SharedArrayBuffer.prototype, Symbol.toStringTag, {
    value: "SharedArrayBuffer", writable: false, enumerable: false, configurable: true
  });
}
_installGlobal('SharedArrayBuffer', SharedArrayBuffer);

function _atomicsToInteger(value) {
  const n = typeof value === 'number' ? value : Number(value);
  if (n !== n) return 0;
  if (n === Infinity || n === -Infinity) return 0;
  return n < 0 ? Math.ceil(n) : Math.floor(n);
}

function _atomicsToIndex(value) {
  if (value === undefined) return 0;
  if (typeof value === 'bigint') {
    throw new TypeError('Cannot convert a BigInt value to a number');
  }
  if (typeof value === 'symbol') {
    throw new TypeError('Cannot convert a Symbol value to a number');
  }
  const n = typeof value === 'number' ? value : Number(value);
  const integerIndex = n !== n ? 0 : (n < 0 ? Math.ceil(n) : Math.floor(n));
  if (integerIndex < 0 || integerIndex > 9007199254740991) {
    throw new RangeError('Invalid atomic access index');
  }
  return integerIndex;
}

function _atomicsValidateIndex(typedArray, index) {
  const len = typedArray.length;
  const i = _atomicsToIndex(index);
  if (i >= len) {
    throw new RangeError('Index out of bounds');
  }
  return i;
}

function _atomicsIsSharedBuffer(buffer) {
  if (!buffer || typeof buffer !== 'object') return false;
  if (typeof SharedArrayBuffer !== 'undefined' && buffer instanceof SharedArrayBuffer) return true;
  return buffer._isSharedArrayBuffer === true;
}

function _atomicsTypedArrayName(typedArray) {
  if (typedArray._typedArrayName) return typedArray._typedArrayName;
  if (typedArray.constructor && typedArray.constructor.name) return typedArray.constructor.name;
  return '';
}

function _atomicsRequireTypedArray(typedArray) {
  if (!typedArray || typeof typedArray !== 'object') {
    throw new TypeError('Cannot perform Atomics operations on a non-TypedArray array');
  }
  // Prefer opaque native brand when available (binaryKind === 2 → TypedArray).
  var nativeKind = 0;
  try {
    if (typeof globalThis.__buf !== 'undefined' && typeof globalThis.__buf.binaryKind === 'function') {
      nativeKind = globalThis.__buf.binaryKind(typedArray) | 0;
    }
  } catch (_e) { nativeKind = 0; }
  if (nativeKind === 2) {
    return typedArray;
  }
  if (!Object.prototype.hasOwnProperty.call(typedArray, '_isTypedArrayInstance') ||
      typedArray._isTypedArrayInstance !== true ||
      typeof typedArray._readAt !== 'function' ||
      typeof typedArray._writeAt !== 'function') {
    throw new TypeError('Cannot perform Atomics operations on a non-TypedArray array');
  }
  return typedArray;
}

// Same-agent Atomics waiter registry: key = bufferId + ":" + byteIndex.
var _atomicsWaiters = Object.create(null);
var _atomicsWaiterBufId = 0;

function _atomicsBufferId(buffer) {
  if (!buffer || typeof buffer !== 'object') return 0;
  if (buffer.__jacWaiterId === undefined) {
    _atomicsWaiterBufId = (_atomicsWaiterBufId + 1) | 0;
    if (_atomicsWaiterBufId === 0) _atomicsWaiterBufId = 1;
    buffer.__jacWaiterId = _atomicsWaiterBufId;
  }
  return buffer.__jacWaiterId;
}

function _atomicsWaiterKey(typedArray, index) {
  var buf = typedArray._buffer;
  var bpe = typedArray.BYTES_PER_ELEMENT || 4;
  var byteIndex = (typedArray.byteOffset || 0) + index * bpe;
  return String(_atomicsBufferId(buf)) + ':' + String(byteIndex);
}

function _atomicsRemoveWaiter(key, entry) {
  var list = _atomicsWaiters[key];
  if (!list) return;
  var next = [];
  for (var i = 0; i < list.length; i++) {
    if (list[i] !== entry) next.push(list[i]);
  }
  if (next.length === 0) delete _atomicsWaiters[key];
  else _atomicsWaiters[key] = next;
}

function _atomicsRequireSharedBuffer(typedArray) {
  if (!typedArray._buffer || !_atomicsIsSharedBuffer(typedArray._buffer)) {
    throw new TypeError('Cannot perform Atomics operations on non-SharedArrayBuffer views');
  }
}

function _atomicsValidateIntegerType(typedArray, waitable) {
  const name = _atomicsTypedArrayName(typedArray);
  const intTypes = ['Int8Array', 'Uint8Array', 'Int16Array', 'Uint16Array', 'Int32Array', 'Uint32Array', 'BigInt64Array', 'BigUint64Array'];
  const waitTypes = ['Int32Array', 'BigInt64Array'];
  const allowed = waitable ? waitTypes : intTypes;
  if (allowed.indexOf(name) === -1) {
    throw new TypeError('Unexpected typed array type');
  }
}

function _atomicsRequireWritableBuffer(typedArray) {
  if (typedArray._buffer && typedArray._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
}

function _atomicsValidateTypedArray(typedArray, waitable, accessMode) {
  const ta = _atomicsRequireTypedArray(typedArray);
  _atomicsValidateIntegerType(ta, waitable);
  // ValidateTypedArray: IsDetachedBuffer before index/value coercion (poisoned args).
  if (!ta._buffer || ta._buffer._detached) {
    throw new TypeError('Cannot perform Atomics operation on a detached ArrayBuffer');
  }
  // ValidateTypedArray write mode: reject immutable buffers before index/value coercion.
  if (accessMode === 'write') {
    _atomicsRequireWritableBuffer(ta);
  }
  return ta;
}

function _atomicsValidateSharedTypedArray(typedArray, waitable) {
  const ta = _atomicsValidateTypedArray(typedArray, waitable, 'read');
  _atomicsRequireSharedBuffer(ta);
  return ta;
}

function _atomicsSameValue(old, expected, typedArray) {
  const exp = _atomicsToTypedValue(typedArray, expected);
  if (typeof old === 'bigint') {
    return old === exp;
  }
  const normalizedOld = _atomicsToTypedValue(typedArray, old);
  return Object.is(normalizedOld, exp);
}

function _atomicsToTypedValue(typedArray, value) {
  const name = _atomicsTypedArrayName(typedArray);
  if (name === 'BigInt64Array') {
    if (typeof value === 'number') throw new TypeError('Cannot convert number to BigInt');
    const v = typeof value === 'bigint' ? value : BigInt(value);
    return BigInt.asIntN(64, v);
  }
  if (name === 'BigUint64Array') {
    if (typeof value === 'number') throw new TypeError('Cannot convert number to BigInt');
    const v = typeof value === 'bigint' ? value : BigInt(value);
    return BigInt.asUintN(64, v);
  }
  const n = _atomicsToInteger(value);
  switch (name) {
    case 'Int8Array': {
      const b = n & 0xFF;
      return b > 127 ? b - 256 : b;
    }
    case 'Uint8Array':
      return n & 0xFF;
    case 'Int16Array': {
      const u = n & 0xFFFF;
      return u > 32767 ? u - 65536 : u;
    }
    case 'Uint16Array':
      return n & 0xFFFF;
    case 'Int32Array':
      return n | 0;
    case 'Uint32Array':
      return n >>> 0;
    default:
      return n | 0;
  }
}

function _atomicsRead(ta, index) {
  return ta._readAt(index);
}

function _atomicsWrite(ta, index, value) {
  if (ta._buffer && ta._buffer._immutable) {
    throw new TypeError('Cannot modify an immutable ArrayBuffer');
  }
  ta._writeAt(index, value);
}

function _atomicsBigIntToUint32(bi) {
  // Avoid Number(bigint) TypeError — convert via decimal string.
  return Number(String(bi)) >>> 0;
}

function _atomicsBigIntParts(v) {
  if (typeof v !== 'bigint') v = BigInt(v);
  const lo = _atomicsBigIntToUint32(v % 4294967296n);
  let hi = v / 4294967296n;
  if (v < 0n && lo !== 0) hi = hi - 1n;
  return [_atomicsBigIntToUint32(hi % 4294967296n), lo];
}

function _atomicsPartsToBigInt(hi, lo) {
  const u = BigInt(hi >>> 0) * 4294967296n + BigInt(lo >>> 0);
  if (u >= 9223372036854775808n) return u - 18446744073709551616n;
  return u;
}

function _atomicsBigIntBitop(op, a, b) {
  const pa = _atomicsBigIntParts(a);
  const pb = _atomicsBigIntParts(b);
  let rhi = pa[0];
  let rlo = pa[1];
  if (op === 'and') { rhi = pa[0] & pb[0]; rlo = pa[1] & pb[1]; }
  else if (op === 'or') { rhi = pa[0] | pb[0]; rlo = pa[1] | pb[1]; }
  else if (op === 'xor') { rhi = pa[0] ^ pb[0]; rlo = pa[1] ^ pb[1]; }
  return _atomicsPartsToBigInt(rhi, rlo);
}

function _atomicsBinop(op, typedArray, index, value) {
  // RMW ops accept non-shared ArrayBuffer views; wait/waitAsync stay SAB-only.
  // Immutable rejection happens before ToIndex / ToNumber (immutable-buffer.js).
  const ta = _atomicsValidateTypedArray(typedArray, false, 'write');
  const i = _atomicsValidateIndex(ta, index);
  const old = _atomicsRead(ta, i);
  const isBig = typeof old === 'bigint';
  let next;
  if (isBig) {
    const v = _atomicsToTypedValue(ta, value);
    if (op === 'add') next = old + v;
    else if (op === 'sub') next = old - v;
    else if (op === 'and') next = _atomicsBigIntBitop('and', old, v);
    else if (op === 'or') next = _atomicsBigIntBitop('or', old, v);
    else if (op === 'xor') next = _atomicsBigIntBitop('xor', old, v);
    else next = v;
    next = _atomicsToTypedValue(ta, next);
  } else {
    const v = _atomicsToTypedValue(ta, value);
    if (op === 'add') next = (old + v) | 0;
    else if (op === 'sub') next = (old - v) | 0;
    else if (op === 'and') next = old & v;
    else if (op === 'or') next = old | v;
    else if (op === 'xor') next = old ^ v;
    else next = v | 0;
  }
  _atomicsWrite(ta, i, next);
  return old;
}

const Atomics = {
  add: function add(typedArray, index, value) {
    return _atomicsBinop('add', typedArray, index, value);
  },
  sub: function sub(typedArray, index, value) {
    return _atomicsBinop('sub', typedArray, index, value);
  },
  and: function and(typedArray, index, value) {
    return _atomicsBinop('and', typedArray, index, value);
  },
  or: function or(typedArray, index, value) {
    return _atomicsBinop('or', typedArray, index, value);
  },
  xor: function xor(typedArray, index, value) {
    return _atomicsBinop('xor', typedArray, index, value);
  },
  exchange: function exchange(typedArray, index, value) {
    return _atomicsBinop('xchg', typedArray, index, value);
  },
  compareExchange: function compareExchange(typedArray, index, expected, replacement) {
    const ta = _atomicsValidateTypedArray(typedArray, false, 'write');
    const i = _atomicsValidateIndex(ta, index);
    const old = _atomicsRead(ta, i);
    const rep = _atomicsToTypedValue(ta, replacement);
    if (_atomicsSameValue(old, expected, ta)) {
      _atomicsWrite(ta, i, rep);
    }
    return old;
  },
  load: function load(typedArray, index) {
    // Load allows non-shared ArrayBuffer views (non-shared-bufferdata.js).
    const ta = _atomicsValidateTypedArray(typedArray, false, 'read');
    const i = _atomicsValidateIndex(ta, index);
    return _atomicsRead(ta, i);
  },
  store: function store(typedArray, index, value) {
    const ta = _atomicsValidateTypedArray(typedArray, false, 'write');
    const i = _atomicsValidateIndex(ta, index);
    // §25.4.3.13: coerce to the integer/BigInt value `v`, store its truncated
    // bytes, but RETURN the un-truncated `v` (store(Int16, 123456789) → 123456789).
    const name = _atomicsTypedArrayName(ta);
    let v;
    if (name === 'BigInt64Array' || name === 'BigUint64Array') {
      if (typeof value === 'number') throw new TypeError('Cannot convert number to BigInt');
      v = typeof value === 'bigint' ? value : BigInt(value);
    } else {
      v = _atomicsToInteger(value);
    }
    _atomicsWrite(ta, i, _atomicsToTypedValue(ta, v));
    return v;
  },
  // Same-agent waiter registry keyed by (buffer identity, byteIndex).
  // DEFERRED_CAPABILITY: sync Atomics.wait cannot truly AgentCanSuspend.
  // Finite timeout → timed-out (no real park); +∞ matching wait → TypeError.
  // Multi-agent notify counts deferred.
  wait: function wait(typedArray, index, value, timeout) {
    // ValidateSharedIntegerTypedArray — shared + detach before index/value.
    const ta = _atomicsValidateSharedTypedArray(typedArray, true);
    const i = _atomicsValidateIndex(ta, index);
    const current = _atomicsRead(ta, i);
    const expected = _atomicsToTypedValue(ta, value);
    if (current !== expected) {
      return 'not-equal';
    }
    // ToNumber(timeout); NaN → +∞ (ES Atomics.wait).
    var t = timeout === undefined ? Infinity : Number(timeout);
    if (t !== t) t = Infinity;
    if (ta._buffer._immutable) {
      throw new TypeError('Cannot wait on an immutable SharedArrayBuffer');
    }
    // Spec: t === 0 (or ≤ 0 after max(q,0)) → "timed-out" without SuspendAgent.
    if (!(t > 0)) {
      return 'timed-out';
    }
    // Infinite wait requires real suspend — unavailable in this host.
    // DEFERRED_CAPABILITY: !AgentCanSuspend → TypeError for +∞ matching wait.
    // Finite positive timeout → timed-out (no hang / no false AgentCanSuspend).
    if (!Number.isFinite(t)) {
      throw new TypeError('Atomics.wait cannot suspend in this environment');
    }
    return 'timed-out';
  },
  waitAsync: function waitAsync(typedArray, index, value, timeout) {
    const ta = _atomicsValidateSharedTypedArray(typedArray, true);
    const i = _atomicsValidateIndex(ta, index);
    const current = _atomicsRead(ta, i);
    const expected = _atomicsToTypedValue(ta, value);
    if (current !== expected) {
      return { async: false, value: 'not-equal' };
    }
    // ToNumber(timeout); NaN → +∞.
    var t = timeout === undefined ? Infinity : Number(timeout);
    if (t !== t) t = Infinity;
    if (!(t > 0)) {
      return { async: false, value: 'timed-out' };
    }
    var key = _atomicsWaiterKey(ta, i);
    var resolveFn;
    var p = new Promise(function (resolve) { resolveFn = resolve; });
    if (!_atomicsWaiters[key]) _atomicsWaiters[key] = [];
    var entry = { resolve: resolveFn, done: false };
    _atomicsWaiters[key].push(entry);
    if (Number.isFinite(t)) {
      // The 'timed-out' promise must not settle before `t` ms of WALL-CLOCK
      // elapse — the clock the test measures with (Date.now via
      // $262.agent.monotonicNow). The libuv timer can fire a few ms early
      // relative to Date.now (measured ~6ms), which made every waitAsync
      // no-spurious-wakeup test read lapse<TIMEOUT and fail. Re-arm for the
      // shortfall so resolution is never early on Date.now's clock.
      var armedAt = Date.now();
      var fire = function () {
        if (entry.done) return;
        var remaining = t - (Date.now() - armedAt);
        if (remaining > 0) { setTimeout(fire, remaining); return; }
        entry.done = true;
        _atomicsRemoveWaiter(key, entry);
        resolveFn('timed-out');
      };
      setTimeout(fire, t);
    }
    return { async: true, value: p };
  },
  notify: function notify(typedArray, index, count) {
    // Spec notify: ValidateIntegerTypedArray → ToIndex(index) → ToInteger(count)
    // BEFORE shared/immutable checks. Non-shared or immutable → return 0.
    const ta = _atomicsValidateTypedArray(typedArray, true, 'read');
    const i = _atomicsValidateIndex(ta, index);
    var n = count === undefined ? Infinity : _atomicsToInteger(count);
    if (!ta._buffer || !_atomicsIsSharedBuffer(ta._buffer) || ta._buffer._immutable) {
      return 0;
    }
    if (!(n > 0)) return 0;
    var key = _atomicsWaiterKey(ta, i);
    var list = _atomicsWaiters[key];
    if (!list || list.length === 0) return 0;
    var woken = 0;
    var remain = [];
    // Wake in registration order (notify-in-order); never hang.
    for (var wi = 0; wi < list.length; wi++) {
      var w = list[wi];
      if (w.done) continue;
      if (woken < n) {
        w.done = true;
        try { w.resolve('ok'); } catch (_e) {}
        woken++;
      } else {
        remain.push(w);
      }
    }
    if (remain.length === 0) delete _atomicsWaiters[key];
    else _atomicsWaiters[key] = remain;
    return woken;
  },
  isLockFree: function isLockFree(size) {
    const n = _atomicsToInteger(size);
    return n === 1 || n === 2 || n === 4 || n === 8;
  },
  pause: function pause(iterationCount) {
    if (iterationCount === undefined) return;
    // Only integral Number is allowed — reject bool/string/object/symbol/bigint/NaN/∞.
    if (typeof iterationCount === 'bigint') {
      throw new TypeError('Cannot convert a BigInt value to a number');
    }
    if (typeof iterationCount !== 'number') {
      throw new TypeError('Atomics.pause iterationNumber must be an integral Number');
    }
    const n = iterationCount;
    if (n !== n || n === Infinity || n === -Infinity || Math.floor(n) !== n) {
      throw new TypeError('Atomics.pause iterationNumber must be an integral Number');
    }
  }
};
Object.defineProperty(Atomics, Symbol.toStringTag, {
  value: "Atomics", writable: false, enumerable: false, configurable: true
});
[
  ["add", 3], ["sub", 3], ["and", 3], ["or", 3], ["xor", 3],
  ["exchange", 3], ["compareExchange", 4], ["load", 2], ["store", 3],
  ["wait", 4], ["waitAsync", 4], ["notify", 3], ["isLockFree", 1],
  ["pause", 0]
].forEach(function(pair) {
  const m = Atomics[pair[0]];
  if (typeof m === "function") {
    _rejectConstruct(m);
    _installMeta(m, pair[0], pair[1]);
    Object.defineProperty(Atomics, pair[0], {
      value: m, writable: true, enumerable: false, configurable: true
    });
  }
});
_installGlobal('Atomics', Atomics);

// ─── $262.agent (single-process synchronous shim) ───────────────────────────
//
// NOT multi-threaded: start() evals agent scripts in the same realm; broadcast()
// delivers SAB synchronously to receiveBroadcast callbacks. Unblocks structural
// Atomics / agent harness tests (getReport queue, timeout coercion). Real
// cross-agent wait/notify timing and concurrent agents remain unsupported.
function __jacInstall262Agent(host) {
  if (!host || typeof host !== 'object') return;
  if (host.agent && typeof host.agent.getReport === 'function' && host.agent.__jacSingleProcess) {
    return;
  }
  const reports = [];
  const pendingReceivers = [];
  let lastBroadcast = null;

  function sleepMs(ms) {
    const n = Number(ms);
    if (!(n > 0)) return;
    const end = Date.now() + Math.min(n, 50);
    while (Date.now() < end) { /* busy-wait (capped) */ }
  }

  const agent = {
    __jacSingleProcess: true,
    // test262 host contract (INTERPRETING.md §Agents): recommended timeout
    // durations in ms. Atomics/waitAsync no-spurious-wakeup tests read
    // `$262.agent.timeouts.small` as their wait duration and assert the
    // measured lapse is >= it — without this the value is `undefined`, every
    // `lapse >= undefined` is false, and all 18 waitAsync timeout tests fail.
    timeouts: { yield: 100, small: 200, long: 1000, huge: 10000 },
    start: function start(script) {
      (0, eval)(String(script));
    },
    broadcast: function broadcast(sab, id) {
      const msgId = id === undefined ? 0 : id;
      lastBroadcast = { sab: sab, id: msgId };
      const cbs = pendingReceivers.splice(0, pendingReceivers.length);
      let i = 0;
      for (; i < cbs.length; i++) {
        cbs[i](sab, msgId);
      }
    },
    getReport: function getReport() {
      return reports.length ? reports.shift() : null;
    },
    sleep: function sleep(ms) { sleepMs(ms); },
    monotonicNow: function monotonicNow() { return Date.now(); },
    report: function report(msg) { reports.push(String(msg)); },
    leaving: function leaving() {},
    receiveBroadcast: function receiveBroadcast(cb) {
      if (typeof cb !== 'function') {
        throw new TypeError('$262.agent.receiveBroadcast requires a function');
      }
      if (lastBroadcast !== null && pendingReceivers.length === 0) {
        // Rare: broadcast already happened with no waiters — still deliver once.
      }
      pendingReceivers.push(cb);
    }
  };

  host.agent = agent;
}

globalThis.__jacInstall262Agent = __jacInstall262Agent;
if (typeof globalThis.$262 === 'object' && globalThis.$262 !== null) {
  __jacInstall262Agent(globalThis.$262);
}

function _bitsToBigIntPow2(bits) {
  // Cap prevents memory-limit hangs from huge ToIndex values that still fit
  // in Number (e.g. 1e6). Spec allows up to 2^53-1 but engines cannot allocate
  // 2^(huge) BigInts; a practical ceiling keeps asIntN/asUintN responsive.
  if (bits > 1048576) {
    throw new RangeError('BigInt.asIntN/asUintN bits too large');
  }
  let p = 1n;
  let i = 0;
  for (; i < bits; i++) p = p + p;
  return p;
}

function _toIndexBits(value) {
  // ToIndex (ES §7.1.22): ToIntegerOrInfinity then RangeError if < 0 or > 2^53-1.
  // GetMethod null-skip aligned with binary_types._toPrimitiveHintNumber.
  if (typeof value === 'symbol') {
    throw new TypeError('Cannot convert a Symbol value to a number');
  }
  if (typeof value === 'bigint') {
    throw new TypeError('Cannot convert a BigInt value to a number');
  }
  if (value !== null && typeof value === 'object') {
    let prim;
    const exotic = value[Symbol.toPrimitive];
    if (exotic !== undefined && exotic !== null) {
      if (typeof exotic !== 'function') {
        throw new TypeError('Cannot convert object to primitive value');
      }
      prim = exotic.call(value, 'default');
      if (prim !== null && typeof prim === 'object') {
        throw new TypeError('Cannot convert object to primitive value');
      }
    } else {
      prim = value;
      if (typeof value.valueOf === 'function') {
        const vo = value.valueOf();
        if (vo === null || typeof vo !== 'object') prim = vo;
      }
      if (prim !== null && typeof prim === 'object' && typeof value.toString === 'function') {
        prim = value.toString();
      }
      if (prim !== null && typeof prim === 'object') {
        throw new TypeError('Cannot convert object to primitive value');
      }
    }
    if (typeof prim === 'bigint') {
      throw new TypeError('Cannot convert a BigInt value to a number');
    }
    if (typeof prim === 'symbol') {
      throw new TypeError('Cannot convert a Symbol value to a number');
    }
    value = prim;
  }
  let n = Number(value);
  if (Number.isNaN(n) || n === 0) return 0;
  if (!Number.isFinite(n)) {
    throw new RangeError('Invalid bits value');
  }
  n = Math.trunc(n);
  if (n < 0) throw new RangeError('Invalid bits value');
  if (n > Number.MAX_SAFE_INTEGER) throw new RangeError('Invalid bits value');
  return n;
}

function _toBigIntStrictBits(value) {
  // ToBigInt (ES §7.1.13) — rejects Number; objects use ToPrimitive then recurse.
  if (typeof value === 'bigint') return value;
  if (typeof value === 'number') {
    throw new TypeError('Cannot convert a Number value to a BigInt');
  }
  if (typeof value === 'symbol') {
    throw new TypeError('Cannot convert a Symbol value to a BigInt');
  }
  if (typeof value === 'boolean') return value ? 1n : 0n;
  if (value === null || value === undefined) {
    throw new TypeError('Cannot convert null or undefined to a BigInt');
  }
  if (typeof value === 'string') {
    return BigInt(value);
  }
  if (typeof value === 'object' || typeof value === 'function') {
    let prim;
    // GetMethod(@@toPrimitive): nullish → skip (do not treat null as callable).
    const exotic = (typeof Symbol !== 'undefined' && Symbol.toPrimitive !== undefined)
      ? value[Symbol.toPrimitive]
      : undefined;
    if (exotic !== undefined && exotic !== null) {
      if (typeof exotic !== 'function') {
        throw new TypeError('Cannot convert object to primitive value');
      }
      // ToBigInt uses @@toPrimitive hint "default".
      prim = exotic.call(value, 'default');
      if (prim !== null && typeof prim === 'object') {
        throw new TypeError('Cannot convert object to primitive value');
      }
    } else {
      prim = value;
      if (typeof value.valueOf === 'function') {
        const vo = value.valueOf();
        if (vo === null || typeof vo !== 'object') prim = vo;
      }
      if (prim !== null && typeof prim === 'object' && typeof value.toString === 'function') {
        prim = value.toString();
      }
      if (prim !== null && typeof prim === 'object') {
        throw new TypeError('Cannot convert object to primitive value');
      }
    }
    return _toBigIntStrictBits(prim);
  }
  return BigInt(value);
}

// BigInt.asIntN / asUintN (§20.2.2 / §20.2.3) — no native bigint bitwise in engine
if (typeof BigInt === 'function') {
  Object.defineProperty(BigInt, 'asIntN', {
    value: function asIntN(bits, bigint) {
      bits = _toIndexBits(bits);
      // §20.2.2.1: ToBigInt(bigint) runs (and may throw) even when bits === 0.
      var n = _toBigIntStrictBits(bigint);
      if (bits === 0) return 0n;
      var mod = _bitsToBigIntPow2(bits);
      var v = n % mod;
      if (v < 0n) v = v + mod;
      var sign = _bitsToBigIntPow2(bits - 1);
      if (v >= sign) v = v - mod;
      return v;
    },
    writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(BigInt.asIntN, 'length', { value: 2, writable: false, enumerable: false, configurable: true });
  Object.defineProperty(BigInt.asIntN, 'name', { value: 'asIntN', writable: false, enumerable: false, configurable: true });
  _rejectConstruct(BigInt.asIntN);

  Object.defineProperty(BigInt, 'asUintN', {
    value: function asUintN(bits, bigint) {
      bits = _toIndexBits(bits);
      // §20.2.3.1: ToBigInt(bigint) runs (and may throw) even when bits === 0.
      var n = _toBigIntStrictBits(bigint);
      if (bits === 0) return 0n;
      var mod = _bitsToBigIntPow2(bits);
      var v = n % mod;
      if (v < 0n) v = v + mod;
      return v;
    },
    writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(BigInt.asUintN, 'length', { value: 2, writable: false, enumerable: false, configurable: true });
  Object.defineProperty(BigInt.asUintN, 'name', { value: 'asUintN', writable: false, enumerable: false, configurable: true });
  _rejectConstruct(BigInt.asUintN);
}

// ─── WeakRef / FinalizationRegistry ────────────────────────────────────────
// §7.1.1.1 CanBeHeldWeakly: objects and non-registered symbols only. Brand/target/
// callback slots live in WeakMaps (adel_fixes) so getOwnPropertySymbols stays clean
// — HEAD used Symbol-keyed brands, which can leak as own symbols.
const _weakRefBrand = new WeakMap();
const _weakRefTarget = new WeakMap();
const _finalizationRegistryBrand = new WeakMap();
const _finalizationRegistryCallback = new WeakMap();
const _finalizationRegistryRegistrations = new WeakMap();

function _canBeHeldWeakly(v) {
  if (v === null) return false;
  const t = typeof v;
  if (t === "object" || t === "function") return true;
  if (t !== "symbol") return false;
  return typeof Symbol.keyFor !== "function" || Symbol.keyFor(v) === undefined;
}

function _requireObjectReceiver(value, method) {
  if (value === null || value === undefined ||
      (typeof value !== "object" && typeof value !== "function")) {
    throw new TypeError(method + " called on non-object");
  }
}

/** ToString for Annex B / ShadowRealm — String(symbol) may not throw in all hosts. */
function _annexBToString(value) {
  // Observable ToString: Symbol rejects; objects use ToPrimitive(string) first.
  if (typeof value === "symbol") {
    throw new TypeError("Cannot convert a Symbol value to a string");
  }
  if (value !== null && (typeof value === "object" || typeof value === "function")) {
    var exotic = value[Symbol.toPrimitive];
    if (exotic !== undefined) {
      if (typeof exotic !== "function") {
        throw new TypeError("Cannot convert object to primitive value");
      }
      var prim = exotic.call(value, "string");
      // Non-primitive includes objects and callables (typeof "function").
      if (prim !== null && (typeof prim === "object" || typeof prim === "function")) {
        throw new TypeError("Cannot convert object to primitive value");
      }
      if (typeof prim === "symbol") {
        throw new TypeError("Cannot convert a Symbol value to a string");
      }
      return String(prim);
    }
  }
  return String(value);
}

function _protoFromNewTarget(newTarget, defaultProto) {
  // OrdinaryCreateFromConstructor / GetPrototypeFromConstructor fallback.
  const p = newTarget.prototype;
  if (typeof p === "object" && p !== null) return p;
  return defaultProto;
}

class WeakRef {
  constructor(target) {
    if (new.target === undefined) {
      throw new TypeError("WeakRef constructor requires 'new'");
    }
    if (!_canBeHeldWeakly(target)) {
      throw new TypeError("WeakRef target must be an object");
    }
    // newTarget.prototype not Object → fall back to %WeakRef.prototype%
    const proto = _protoFromNewTarget(new.target, WeakRef.prototype);
    if (Object.getPrototypeOf(this) !== proto) {
      Object.setPrototypeOf(this, proto);
    }
    _weakRefBrand.set(this, true);
    _weakRefTarget.set(this, target);
  }
  deref() {
    _requireObjectReceiver(this, "WeakRef.prototype.deref");
    if (_weakRefBrand.get(this) !== true) {
      throw new TypeError("WeakRef.prototype.deref called on incompatible receiver");
    }
    const target = _weakRefTarget.get(this);
    const gc = globalThis.__JS_ENGINE_GC;
    if (gc && typeof gc.isCollected === 'function' && gc.isCollected(target)) {
      return undefined;
    }
    return target;
  }
}
_installMeta(WeakRef, "WeakRef", 1);
Object.defineProperty(WeakRef.prototype, Symbol.toStringTag, {
  value: "WeakRef", writable: false, enumerable: false, configurable: true
});
_installMeta(WeakRef.prototype.deref, "deref", 0);
_installGlobal('WeakRef', WeakRef);

class FinalizationRegistry {
  constructor(cleanupCallback) {
    if (new.target === undefined) {
      throw new TypeError("FinalizationRegistry constructor requires 'new'");
    }
    if (typeof cleanupCallback !== "function") {
      throw new TypeError("FinalizationRegistry requires a function");
    }
    // newTarget.prototype not Object → fall back to %FinalizationRegistry.prototype%
    const proto = _protoFromNewTarget(new.target, FinalizationRegistry.prototype);
    if (Object.getPrototypeOf(this) !== proto) {
      Object.setPrototypeOf(this, proto);
    }
    _finalizationRegistryBrand.set(this, true);
    _finalizationRegistryCallback.set(this, cleanupCallback);
    _finalizationRegistryRegistrations.set(this, new Map());
  }
  register(target, heldValue, unregisterToken) {
    _requireObjectReceiver(this, "FinalizationRegistry.prototype.register");
    if (_finalizationRegistryBrand.get(this) !== true) {
      throw new TypeError("FinalizationRegistry.prototype.register called on incompatible receiver");
    }
    if (!_canBeHeldWeakly(target)) {
      throw new TypeError("FinalizationRegistry register target must be an object");
    }
    if (heldValue === target) {
      throw new TypeError("heldValue must not be the same as target");
    }
    const regs = _finalizationRegistryRegistrations.get(this);
    // unregisterToken: if provided, must be CanBeHeldWeakly (object/symbol)
    if (unregisterToken !== undefined) {
      if (!_canBeHeldWeakly(unregisterToken)) {
        throw new TypeError("FinalizationRegistry unregisterToken must be an object");
      }
      regs.set(unregisterToken, { target: target, heldValue: heldValue });
    } else {
      // No unregisterToken → store under a unique empty key (not unregisterable by target)
      regs.set(Object.create(null), { target: target, heldValue: heldValue });
    }
  }
  unregister(unregisterToken) {
    _requireObjectReceiver(this, "FinalizationRegistry.prototype.unregister");
    if (_finalizationRegistryBrand.get(this) !== true) {
      throw new TypeError("FinalizationRegistry.prototype.unregister called on incompatible receiver");
    }
    if (!_canBeHeldWeakly(unregisterToken)) {
      throw new TypeError("FinalizationRegistry unregisterToken must be an object");
    }
    return _finalizationRegistryRegistrations.get(this).delete(unregisterToken);
  }
}
_installMeta(FinalizationRegistry, "FinalizationRegistry", 1);
Object.defineProperty(FinalizationRegistry.prototype, Symbol.toStringTag, {
  value: "FinalizationRegistry", writable: false, enumerable: false, configurable: true
});
_installMeta(FinalizationRegistry.prototype.register, "register", 2);
_installMeta(FinalizationRegistry.prototype.unregister, "unregister", 1);
_installGlobal('FinalizationRegistry', FinalizationRegistry);

// ─── DisposableStack stubs (ES2024 explicit resource management) ─────────────

class DisposableStack {
  constructor() {
    if (new.target === undefined) {
      throw new TypeError("DisposableStack constructor requires 'new'");
    }
    this._stack = [];
    this._disposed = false;
    // Distinguishes the sync stack from AsyncDisposableStack, which shares the
    // same `_stack` shape — AsyncDisposableStack.prototype.disposeAsync must
    // reject when handed a DisposableStack instance.
    this._isSyncDisposableStack = true;
  }
  use(value) {
    if (this._isSyncDisposableStack !== true) throw new TypeError("DisposableStack.prototype.use called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("DisposableStack already disposed");
    // §AddDisposableResource: null/undefined are allowed (nothing recorded); any
    // other value must be an object with a callable [Symbol.dispose].
    if (value !== null && value !== undefined) {
      if (typeof value !== "object" && typeof value !== "function") {
        throw new TypeError("DisposableStack.prototype.use value is not disposable");
      }
      const m = value[Symbol.dispose];
      if (typeof m !== "function") {
        throw new TypeError("DisposableStack.prototype.use value has no callable [Symbol.dispose]");
      }
      this._stack.push({ [Symbol.dispose]: function() { m.call(value); } });
    }
    return value;
  }
  adopt(value, onDispose) {
    if (this._isSyncDisposableStack !== true) throw new TypeError("DisposableStack.prototype.adopt called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("DisposableStack already disposed");
    if (typeof onDispose !== "function") throw new TypeError("onDispose must be callable");
    this._stack.push({ [Symbol.dispose]: function() { onDispose(value); } });
    return value;
  }
  defer(onDispose) {
    if (this._isSyncDisposableStack !== true) throw new TypeError("DisposableStack.prototype.defer called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("DisposableStack already disposed");
    if (typeof onDispose !== "function") throw new TypeError("onDispose must be callable");
    this._stack.push({ [Symbol.dispose]: onDispose });
  }
  move() {
    if (this._isSyncDisposableStack !== true) throw new TypeError("DisposableStack.prototype.move called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("DisposableStack already disposed");
    const result = new DisposableStack();
    result._stack = this._stack;
    this._stack = [];
    this._disposed = true;
    return result;
  }
  dispose() {
    if (this._isSyncDisposableStack !== true) throw new TypeError("DisposableStack.prototype.dispose called on incompatible receiver");
    if (this._disposed) return;
    this._disposed = true;
    while (this._stack.length > 0) {
      const v = this._stack.pop();
      if (v && typeof v[Symbol.dispose] === "function") {
        v[Symbol.dispose]();
      }
    }
  }
}
// §—: DisposableStack.prototype[@@dispose] IS %DisposableStack.prototype.dispose%
// (the same function object, { writable:true, enumerable:false, configurable:true }).
Object.defineProperty(DisposableStack.prototype, Symbol.dispose, {
  value: DisposableStack.prototype.dispose, writable: true, enumerable: false, configurable: true
});
// `get disposed` — an accessor on the prototype (not a data property). The brand
// check (`_isSyncDisposableStack` marks a genuine instance) makes the getter throw a
// TypeError on a receiver without the [[DisposableState]] internal slot.
var _dsDisposedGetter = function disposed() {
  if (this === null || typeof this !== "object" || this._isSyncDisposableStack !== true) {
    throw new TypeError("get DisposableStack.prototype.disposed called on incompatible receiver");
  }
  return this._disposed;
};
// A getter's function name is "get " + the property key (§10.2.9 SetFunctionName).
Object.defineProperty(_dsDisposedGetter, "name", {
  value: "get disposed", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(DisposableStack.prototype, "disposed", {
  get: _dsDisposedGetter, enumerable: false, configurable: true
});
Object.defineProperty(DisposableStack.prototype, Symbol.toStringTag, {
  value: "DisposableStack", writable: false, enumerable: false, configurable: true
});
_installMeta(DisposableStack, "DisposableStack", 0);
_installMeta(DisposableStack.prototype.use, "use", 1);
_installMeta(DisposableStack.prototype.adopt, "adopt", 2);
_installMeta(DisposableStack.prototype.defer, "defer", 1);
_installMeta(DisposableStack.prototype.move, "move", 0);
_installMeta(DisposableStack.prototype.dispose, "dispose", 0);
Object.defineProperty(globalThis, "DisposableStack", {
  value: DisposableStack, writable: true, enumerable: false, configurable: true
});

class AsyncDisposableStack {
  constructor() {
    if (new.target === undefined) {
      throw new TypeError("AsyncDisposableStack constructor requires 'new'");
    }
    this._stack = [];
    this._disposed = false;
    // Brand marking a genuine AsyncDisposableStack (the [[AsyncDisposableState]]
    // internal slot) so `get disposed` / disposeAsync can reject foreign receivers.
    this._isAsyncDisposableStack = true;
  }
  use(value) {
    if (this._isAsyncDisposableStack !== true) throw new TypeError("AsyncDisposableStack.prototype.use called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("AsyncDisposableStack already disposed");
    // §AddDisposableResource(async-dispose): null/undefined allowed; otherwise the
    // value must be an object with a callable [Symbol.asyncDispose] (falling back to
    // [Symbol.dispose], which the async path wraps).
    if (value !== null && value !== undefined) {
      if (typeof value !== "object" && typeof value !== "function") {
        throw new TypeError("AsyncDisposableStack.prototype.use value is not disposable");
      }
      let m = value[Symbol.asyncDispose];
      if (m === undefined || m === null) { m = value[Symbol.dispose]; }
      if (typeof m !== "function") {
        throw new TypeError("AsyncDisposableStack.prototype.use value has no callable [Symbol.asyncDispose]");
      }
      this._stack.push({ [Symbol.asyncDispose]: function() { return m.call(value); } });
    }
    return value;
  }
  adopt(value, onDispose) {
    if (this._isAsyncDisposableStack !== true) throw new TypeError("AsyncDisposableStack.prototype.adopt called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("AsyncDisposableStack already disposed");
    if (typeof onDispose !== "function") throw new TypeError("onDispose must be callable");
    this._stack.push({ [Symbol.asyncDispose]: function() { return onDispose(value); } });
    return value;
  }
  defer(onDispose) {
    if (this._isAsyncDisposableStack !== true) throw new TypeError("AsyncDisposableStack.prototype.defer called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("AsyncDisposableStack already disposed");
    if (typeof onDispose !== "function") throw new TypeError("onDispose must be callable");
    this._stack.push({ [Symbol.asyncDispose]: onDispose });
  }
  move() {
    if (this._isAsyncDisposableStack !== true) throw new TypeError("AsyncDisposableStack.prototype.move called on incompatible receiver");
    if (this._disposed) throw new ReferenceError("AsyncDisposableStack already disposed");
    const result = new AsyncDisposableStack();
    result._stack = this._stack;
    this._stack = [];
    this._disposed = true;
    return result;
  }
  disposeAsync() {
    const self = this;
    if (self._isAsyncDisposableStack !== true) {
      return Promise.reject(new TypeError("AsyncDisposableStack.prototype.disposeAsync called on incompatible receiver"));
    }
    if (self._disposed) return Promise.resolve();
    self._disposed = true;
    function disposeNext() {
      if (self._stack.length === 0) return undefined;
      const v = self._stack.pop();
      let callback;
      if (v && typeof v[Symbol.asyncDispose] === "function") {
        callback = v[Symbol.asyncDispose];
      } else if (v && typeof v[Symbol.dispose] === "function") {
        callback = v[Symbol.dispose];
      }
      if (callback === undefined) return disposeNext();
      return Promise.resolve(callback.call(v)).then(disposeNext);
    }
    return Promise.resolve().then(disposeNext);
  }
}
// §—: AsyncDisposableStack.prototype[@@asyncDispose] IS %…prototype.disposeAsync%.
Object.defineProperty(AsyncDisposableStack.prototype, Symbol.asyncDispose, {
  value: AsyncDisposableStack.prototype.disposeAsync, writable: true, enumerable: false, configurable: true
});
var _adsDisposedGetter = function disposed() {
  if (this === null || typeof this !== "object" || this._isAsyncDisposableStack !== true) {
    throw new TypeError("get AsyncDisposableStack.prototype.disposed called on incompatible receiver");
  }
  return this._disposed;
};
Object.defineProperty(_adsDisposedGetter, "name", {
  value: "get disposed", writable: false, enumerable: false, configurable: true
});
Object.defineProperty(AsyncDisposableStack.prototype, "disposed", {
  get: _adsDisposedGetter, enumerable: false, configurable: true
});
Object.defineProperty(AsyncDisposableStack.prototype, Symbol.toStringTag, {
  value: "AsyncDisposableStack", writable: false, enumerable: false, configurable: true
});
_installMeta(AsyncDisposableStack, "AsyncDisposableStack", 0);
_installMeta(AsyncDisposableStack.prototype.use, "use", 1);
_installMeta(AsyncDisposableStack.prototype.adopt, "adopt", 2);
_installMeta(AsyncDisposableStack.prototype.defer, "defer", 1);
_installMeta(AsyncDisposableStack.prototype.move, "move", 0);
_installMeta(AsyncDisposableStack.prototype.disposeAsync, "disposeAsync", 0);
Object.defineProperty(globalThis, "AsyncDisposableStack", {
  value: AsyncDisposableStack, writable: true, enumerable: false, configurable: true
});

// ─── ShadowRealm (minimal evaluate via $262.createRealm) ─────────────────────

function _shadowRealmEvalGlobal() {
  const host = globalThis.$262;
  if (host && typeof host.createRealm === 'function') {
    const realmRec = host.createRealm();
    if (realmRec && realmRec.global) return realmRec.global;
  }
  // Micros / hosts without $262: fall back to current global for evaluate/parse.
  // True isolation still requires createRealm (test262 harness).
  return globalThis;
}

function _shadowRealmWrapExport(value, evalFnProto) {
  const t = typeof value;
  if (t === 'object' && value !== null) {
    throw new TypeError('ShadowRealm.evaluate result must be a primitive');
  }
  if (t !== 'function') return value;
  let wrappedName = '';
  let wrappedLength = 0;
  // CopyNameAndLength: HasOwnProperty then Get — throwing getters → TypeError.
  try {
    if (Object.prototype.hasOwnProperty.call(value, 'name')) {
      const n = value.name;
      wrappedName = typeof n === 'string' ? n : '';
    }
  } catch (err) {
    throw new TypeError(err && err.message ? String(err.message) : String(err));
  }
  try {
    if (Object.prototype.hasOwnProperty.call(value, 'length')) {
      let L = value.length;
      if (typeof L !== 'number' || L !== L || L === -Infinity) {
        L = 0;
      } else if (L === Infinity) {
        L = Infinity;
      } else {
        L = Math.trunc(L);
        if (L < 0) L = 0;
        if (L > 0xFFFFFFFE) L = 0xFFFFFFFE;
      }
      wrappedLength = L;
    }
  } catch (err) {
    throw new TypeError(err && err.message ? String(err.message) : String(err));
  }
  const argProto = evalFnProto || Function.prototype;
  const wrapped = function ShadowRealmWrappedFunction() {
    const args = [];
    for (let i = 0; i < arguments.length; i++) {
      const a = arguments[i];
      if (typeof a === 'object' && a !== null) {
        throw new TypeError('ShadowRealm wrapped function arguments must be primitives');
      }
      if (typeof a === 'function') {
        args.push(_shadowRealmWrapImport(a, argProto));
        continue;
      }
      args.push(a);
    }
    try {
      return _shadowRealmWrapExport(value.apply(undefined, args), argProto);
    } catch (err) {
      if (err && err.name === 'TypeError' && String(err.message || '').indexOf('ShadowRealm') === 0) {
        throw err;
      }
      throw new TypeError(err && err.message ? String(err.message) : String(err));
    }
  };
  Object.setPrototypeOf(wrapped, Function.prototype);
  // Install name/length separately so Infinity length is preserved (some
  // engines truncate non-finite values through a shared meta helper).
  Object.defineProperty(wrapped, 'name', {
    value: wrappedName, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(wrapped, 'length', {
    value: wrappedLength, writable: false, enumerable: false, configurable: true
  });
  return wrapped;
}

function _shadowRealmWrapImport(value, evalFnProto) {
  if (typeof value !== 'function') return value;
  let wrappedName = '';
  let wrappedLength = 0;
  try {
    if (Object.prototype.hasOwnProperty.call(value, 'name')) {
      const n = value.name;
      wrappedName = typeof n === 'string' ? n : '';
    }
  } catch (err) {
    throw new TypeError(err && err.message ? String(err.message) : String(err));
  }
  try {
    if (Object.prototype.hasOwnProperty.call(value, 'length')) {
      let L = value.length;
      if (typeof L !== 'number' || L !== L || L === -Infinity) {
        L = 0;
      } else if (L === Infinity) {
        L = Infinity;
      } else {
        L = Math.trunc(L);
        if (L < 0) L = 0;
        if (L > 0xFFFFFFFE) L = 0xFFFFFFFE;
      }
      wrappedLength = L;
    }
  } catch (err) {
    throw new TypeError(err && err.message ? String(err.message) : String(err));
  }
  const wrapped = function ShadowRealmWrappedImport() {
    const fwd = [];
    for (let i = 0; i < arguments.length; i++) fwd.push(arguments[i]);
    return value.apply(undefined, fwd);
  };
  Object.setPrototypeOf(wrapped, evalFnProto || Function.prototype);
  // Preserve Infinity length — do not use truncating _installMeta.
  Object.defineProperty(wrapped, 'name', {
    value: wrappedName, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(wrapped, 'length', {
    value: wrappedLength, writable: false, enumerable: false, configurable: true
  });
  return wrapped;
}

class ShadowRealm {
  constructor() {
    if (new.target === undefined) {
      throw new TypeError("ShadowRealm constructor requires 'new'");
    }
    this._isShadowRealm = true;
    this._evalGlobal = _shadowRealmEvalGlobal();
    const g = this._evalGlobal;
    if (g && g.Object && g.Object.prototype) {
      Object.setPrototypeOf(g, g.Object.prototype);
    }
  }
  _evalFunctionPrototype() {
    const g = this._evalGlobal;
    if (g && g.Function && g.Function.prototype) return g.Function.prototype;
    return Function.prototype;
  }
  evaluate(source) {
    _requireObjectReceiver(this, "ShadowRealm.prototype.evaluate");
    if (this._isShadowRealm !== true) {
      throw new TypeError("ShadowRealm.prototype.evaluate called on incompatible receiver");
    }
    // Type(sourceText) must be String — no ToString coercion.
    if (typeof source !== 'string') {
      throw new TypeError('ShadowRealm.prototype.evaluate requires a string argument');
    }
    const g = this._evalGlobal;
    if (!g) {
      throw new TypeError('ShadowRealm.evaluate: guest realm is unavailable');
    }
    // Parse-check the source as a Script body first — SyntaxError surfaces as caller SyntaxError.
    // Nested eval SyntaxErrors during runtime wrap as TypeError instead.
    try {
      if (typeof g.Function === 'function') {
        g.Function(source);
      }
    } catch (parseErr) {
      // ShadowRealm.evaluate wraps guest abrupt completions (incl. SyntaxError) as TypeError.
      throw new TypeError(parseErr && parseErr.message ? String(parseErr.message) : String(parseErr));
    }
    try {
      let result;
      if (typeof g.eval === 'function') {
        result = g.eval(source);
      } else if (typeof g.Function === 'function') {
        const Fn = g.Function;
        const fn = Fn.call(null, '"use strict"; return (' + source + ');');
        if (typeof fn !== 'function') {
          throw new TypeError('ShadowRealm.evaluate: Function factory did not return a function');
        }
        result = fn();
      } else {
        throw new TypeError('ShadowRealm.evaluate: guest realm has no eval/Function');
      }
      return _shadowRealmWrapExport(result, this._evalFunctionPrototype());
    } catch (err) {
      if (err && err.name === 'TypeError' && String(err.message || '').indexOf('ShadowRealm') === 0) {
        throw err;
      }
      // Nested/runtime SyntaxError and other guest throws wrap as TypeError.
      throw new TypeError(err && err.message ? String(err.message) : String(err));
    }
  }
  importValue(specifier, exportName) {
    _requireObjectReceiver(this, "ShadowRealm.prototype.importValue");
    if (this._isShadowRealm !== true) {
      throw new TypeError("ShadowRealm.prototype.importValue called on incompatible receiver");
    }
    // ToString(specifier) and ToString(exportName) before module-loader rejection.
    _annexBToString(specifier);
    _annexBToString(exportName);
    // DEFERRED_CAPABILITY: ShadowRealm.prototype.importValue needs a module loader.
    return Promise.reject(new TypeError("ShadowRealm.importValue not implemented"));
  }
}
_installMeta(ShadowRealm, "ShadowRealm", 0);
Object.defineProperty(ShadowRealm.prototype, Symbol.toStringTag, {
  value: "ShadowRealm", writable: false, enumerable: false, configurable: true
});
_installMeta(ShadowRealm.prototype.evaluate, "evaluate", 1);
_installMeta(ShadowRealm.prototype.importValue, "importValue", 2);
_installGlobal('ShadowRealm', ShadowRealm);

// ─── AbstractModuleSource — deferred (Stage 3 proposal; 8 test262 tests) ─────
// See js_engine/docs/ABSTRACT_MODULE_SOURCE_DEFERRED.md

// BigInt64Array / BigUint64Array are implemented in binary_types.js

// ─── Promise.try (ES2024) ───────────────────────────────────────────────────

(function() {
  const P = globalThis.Promise;
  if (!P) return;
  Object.defineProperty(P, 'try', {
    value: function(callback) {
      if (typeof callback !== 'function') {
        throw new TypeError('Promise.try callback must be a function');
      }
      try {
        return P.resolve(callback());
      } catch (err) {
        return P.reject(err);
      }
    },
    writable: true,
    enumerable: false,
    configurable: true
  });
  _rejectConstruct(P.try);
  _installMeta(P.try, 'try', 1);
})();

// ─── Phase 7 proposal builtins ──────────────────────────────────────────────

(function() {
  if (typeof Math === "undefined" || typeof Math.sumPrecise === "function") return;
  function _sumPreciseIterate(iterable, fn) {
    if (iterable == null || (typeof iterable !== "object" && typeof iterable !== "function")) {
      throw new TypeError("Math.sumPrecise requires an iterable");
    }
    const iterMethod = iterable[Symbol.iterator];
    if (typeof iterMethod === "function") {
      const iterator = iterMethod.call(iterable);
      if (iterator == null || (typeof iterator !== "object" && typeof iterator !== "function")) {
        throw new TypeError("Result of iterator method is not an object");
      }
      while (true) {
        const step = iterator.next();
        if (step && step.done) break;
        fn(step.value);
      }
      return;
    }
    const len = _toLength(iterable.length);
    let k = 0;
    while (k < len) {
      const pk = String(k);
      if (Object.prototype.hasOwnProperty.call(iterable, pk)) {
        fn(iterable[pk]);
      }
      k++;
    }
  }
  const sumPrecise = function(iterable) {
    const values = [];
    _sumPreciseIterate(iterable, function(value) {
      if (typeof value !== "number") {
        throw new TypeError("Math.sumPrecise values must be numbers");
      }
      values.push(value);
    });

    let positiveInfinity = false;
    let negativeInfinity = false;
    let allNegativeZero = values.length > 0;
    for (let i = 0; i < values.length; i++) {
      const value = values[i];
      if (value !== value) return NaN;
      if (value === Infinity) positiveInfinity = true;
      if (value === -Infinity) negativeInfinity = true;
      if (value !== 0 || 1 / value !== -Infinity) allNegativeZero = false;
    }
    if (positiveInfinity && negativeInfinity) return NaN;
    if (positiveInfinity) return Infinity;
    if (negativeInfinity) return -Infinity;

    let sum = 0;
    let compensation = 0;
    for (let i = 0; i < values.length; i++) {
      const value = values[i];
      const next = sum + value;
      if (Math.abs(sum) >= Math.abs(value)) {
        compensation += (sum - next) + value;
      } else {
        compensation += (value - next) + sum;
      }
      sum = next;
    }
    if (sum === 0 && compensation === 0 && (values.length === 0 || allNegativeZero)) {
      return -0;
    }
    return sum + compensation;
  };
  _rejectConstruct(sumPrecise);
  _installMeta(sumPrecise, "sumPrecise", 1);
  Object.defineProperty(Math, "sumPrecise", {
    value: sumPrecise, writable: true, enumerable: false, configurable: true
  });
})();

(function() {
  if (typeof RegExp === "undefined" || typeof RegExp.escape === "function") return;
  function hex2(code) {
    const text = code.toString(16);
    return "\\x" + (text.length < 2 ? "0" : "") + text;
  }
  function hex4(code) {
    let text = code.toString(16);
    while (text.length < 4) text = "0" + text;
    return "\\u" + text;
  }
  const escape = function(string) {
    const input = String(string);
    let output = "";
    for (let i = 0; i < input.length; i++) {
      const code = input.charCodeAt(i);
      const ch = input.charAt(i);
      const firstAsciiAlnum = i === 0 &&
        ((code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122));
      if (firstAsciiAlnum) {
        output += hex2(code);
      } else if ("^$\\.*+?()[]{}|/".indexOf(ch) !== -1) {
        output += "\\" + ch;
      } else if (",-=<>#&!%:;@~'`\"".indexOf(ch) !== -1 || ch === " ") {
        output += hex2(code);
      } else if (ch === "\f") {
        output += "\\f";
      } else if (ch === "\n") {
        output += "\\n";
      } else if (ch === "\r") {
        output += "\\r";
      } else if (ch === "\t") {
        output += "\\t";
      } else if (ch === "\v") {
        output += "\\v";
      } else if (code === 0x00A0 || code === 0x1680 ||
                 (code >= 0x2000 && code <= 0x200A) ||
                 code === 0x2028 || code === 0x2029 || code === 0x202F ||
                 code === 0x205F || code === 0x3000 || code === 0xFEFF ||
                 (code >= 0xD800 && code <= 0xDFFF)) {
        output += hex4(code);
      } else {
        output += ch;
      }
    }
    return output;
  };
  _rejectConstruct(escape);
  _installMeta(escape, "escape", 1);
  Object.defineProperty(RegExp, "escape", {
    value: escape, writable: true, enumerable: false, configurable: true
  });
})();

(function() {
  const P = globalThis.Promise;
  if (typeof P !== "function") return;

  const intrinsicResolve = P.resolve.bind(P);
  const resolve = function(value) {
    const C = this;
    if (C === P || C === null || C === undefined) return intrinsicResolve(value);
    if (typeof C !== "function") throw new TypeError("Promise.resolve receiver is not a constructor");
    let resolveCapability;
    let rejectCapability;
    const executor = function(resolveFn, rejectFn) {
      if (resolveCapability !== undefined || rejectCapability !== undefined) {
        throw new TypeError("Promise capability executor called more than once");
      }
      resolveCapability = resolveFn;
      rejectCapability = rejectFn;
    };
    // GetCapabilitiesExecutor is non-constructible and has no .prototype (ES §27.2.1.5).
    _rejectConstruct(executor);
    try { delete executor.prototype; } catch (_) {}
    const promise = new C(executor);
    if (typeof resolveCapability !== "function" || typeof rejectCapability !== "function") {
      throw new TypeError("Promise constructor did not provide resolving functions");
    }
    resolveCapability(value);
    return promise;
  };
  _rejectConstruct(resolve);
  _installMeta(resolve, "resolve", 1);
  Object.defineProperty(P, "resolve", {
    value: resolve, writable: true, enumerable: false, configurable: true
  });

  const allKeyed = function(dict) {
    const C = typeof this === "function" ? this : P;
    if (dict === null || dict === undefined) {
      throw new TypeError("Promise.allKeyed requires an object");
    }
    const keys = Object.keys(Object(dict));
    const values = [];
    for (let i = 0; i < keys.length; i++) values.push(dict[keys[i]]);
    return C.all(values).then(function(resolved) {
      const result = {};
      for (let i = 0; i < keys.length; i++) result[keys[i]] = resolved[i];
      return result;
    });
  };
  const allSettledKeyed = function(dict) {
    const C = typeof this === "function" ? this : P;
    if (dict === null || dict === undefined) {
      throw new TypeError("Promise.allSettledKeyed requires an object");
    }
    const keys = Object.keys(Object(dict));
    const values = [];
    for (let i = 0; i < keys.length; i++) values.push(dict[keys[i]]);
    return C.allSettled(values).then(function(resolved) {
      const result = {};
      for (let i = 0; i < keys.length; i++) result[keys[i]] = resolved[i];
      return result;
    });
  };
  _rejectConstruct(allKeyed);
  _rejectConstruct(allSettledKeyed);
  _installMeta(allKeyed, "allKeyed", 1);
  _installMeta(allSettledKeyed, "allSettledKeyed", 1);
  Object.defineProperty(P, "allKeyed", {
    value: allKeyed, writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(P, "allSettledKeyed", {
    value: allSettledKeyed, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Promise combinators: all / allSettled / any / race (§27.2.4.1–.7) ───────
//
// These replace the native implementations in dispatch.na.jac, which settled
// their result promise synchronously, accepted only real arrays (so Sets,
// generators and other iterables silently produced an empty result instead of
// iterating or throwing), never routed elements through `C.resolve(x).then(…)`
// — so thenables were never assimilated and a user-visible `Promise.resolve`
// override was never invoked — and rejected `any` with a plain object rather
// than a real AggregateError.
//
// Implementing them here rather than extending the marker-key reaction protocol
// in vm.na.jac buys the iterator protocol, AggregateError and user-overridable
// `resolve`/`then` lookups that this layer already gets right, and keeps the
// remaining-elements bookkeeping in one place per §27.2.4.1.2.

(function () {
  'use strict';

  const P = globalThis.Promise;
  if (!P) return;

  // §27.2.1.5 NewPromiseCapability(C). Built via `new C(executor)` so that
  // subclasses and any thenable-producing constructor work uniformly. The
  // executor must be called exactly once, synchronously, with two functions
  // that have not already been set — re-invocation is a TypeError.
  function newPromiseCapability(C) {
    if (typeof C !== 'function') {
      throw new TypeError('Promise capability requires a constructor');
    }
    const cap = { promise: undefined, resolve: undefined, reject: undefined };
    cap.promise = new C(function (resolve, reject) {
      if (cap.resolve !== undefined || cap.reject !== undefined) {
        throw new TypeError('Promise executor has already been invoked');
      }
      cap.resolve = resolve;
      cap.reject = reject;
    });
    // §27.2.1.5 steps 4-5: both capability functions must be callable, or the
    // whole operation is a TypeError. (A subclass fallback used to live here to
    // work around super() not threading the executor through to the Promise
    // constructor; that is now handled in the VM's SUPER_CALL / implicit-ctor
    // paths, so the spec'd throw is restored.)
    if (typeof cap.resolve !== 'function' || typeof cap.reject !== 'function') {
      throw new TypeError('Promise resolve/reject capability is not callable');
    }
    // The capability functions must keep their identity: they are handed to a
    // user-visible `then`, and test262 compares the object it receives against
    // the one the executor was given (all/race same-resolve-function). So they
    // are NOT wrapped here — instead every call site goes through capResolve /
    // capReject below, which invoke them with `this` = undefined per §27.2.1.5.
    // Calling `cap.resolve(v)` directly would bind `this` to the capability
    // record, which a sloppy-mode user function observes as its receiver.
    return cap;
  }

  // Invoke a capability's resolve/reject with `this` = undefined (§27.2.1.5),
  // preserving the function's identity for the code that also passes it to a
  // user-visible `then`.
  function capResolve(cap, v) { return (0, cap.resolve)(v); }
  function capReject(cap, r) { return (0, cap.reject)(r); }

  // §7.4.2 GetIterator + §7.4.4 IteratorStep, kept explicit rather than using
  // for-of so that IteratorClose can be invoked at exactly the spec's points.
  function getIterator(items) {
    if (items === null || items === undefined) {
      throw new TypeError('Promise combinator argument is not iterable');
    }
    const method = items[Symbol.iterator];
    if (typeof method !== 'function') {
      throw new TypeError('Promise combinator argument is not iterable');
    }
    const iterator = method.call(items);
    if (iterator === null || typeof iterator !== 'object') {
      throw new TypeError('Result of the Symbol.iterator method is not an object');
    }
    const next = iterator.next;
    if (typeof next !== 'function') {
      throw new TypeError('Iterator `next` is not callable');
    }
    return { iterator: iterator, next: next, done: false };
  }

  // §7.4.9 IteratorClose — best-effort; a throw from `return` is swallowed
  // because the original completion takes precedence.
  function iteratorClose(record) {
    try {
      const ret = record.iterator['return'];
      if (ret !== null && ret !== undefined) ret.call(record.iterator);
    } catch (e) { /* original completion wins */ }
  }

  // Shared driver for all four combinators. `handle` receives each iterated
  // value plus its index and is responsible for the per-element bookkeeping;
  // the remaining-elements counter starts at 1 for the iteration itself so the
  // result cannot settle before every element has been dispatched (§27.2.4.1.2
  // step 1.d — the classic off-by-one that lets [] resolve too early).
  function performCombinator(C, iterable, capability, handle, onAllSettled) {
    const state = { remaining: 1, index: 0, values: [], errors: [] };

    // Order matters: GetPromiseResolve(C) is step 3 and GetIterator is step 4
    // (§27.2.4.1), so a non-callable `C.resolve` must throw *before* the
    // iterable is touched — a test262 iterable whose @@iterator getter throws
    // "unreachable" pins this down. Both failures reject the capability rather
    // than throwing out of the combinator.
    const resolveFn = C.resolve;
    if (typeof resolveFn !== 'function') {
      throw new TypeError('Promise.resolve is not callable');
    }

    let iterRecord = getIterator(iterable);

    while (true) {
      let step;
      try {
        // Invoked as a method rather than via next.call(iterator): the string
        // and generator iterator natives currently lose their receiver when
        // reached through Function.prototype.call, returning undefined /
        // {done:true}. A method call is observably equivalent here (the same
        // function object, the same receiver) and sidesteps that engine gap.
        step = iterRecord.iterator.next();
      } catch (e) {
        iterRecord.done = true;
        throw e;
      }
      // A throw from `next`, from a non-object iterator result, or from the
      // `done`/`value` getters happens *inside* IteratorStep/IteratorValue,
      // which set the record's [[Done]] before propagating — so the iterator
      // counts as already closed and `return` must NOT be called
      // (test262 iter-step-err-no-close / iter-next-val-err-no-close).
      // IteratorClose applies only to the steps after this point.
      if (step === null || typeof step !== 'object') {
        iterRecord.done = true;
        throw new TypeError('Iterator result is not an object');
      }
      let done;
      try { done = step.done; } catch (e) { iterRecord.done = true; throw e; }
      if (done) break;
      let value;
      try { value = step.value; } catch (e) { iterRecord.done = true; throw e; }

      const idx = state.index++;
      // §27.2.4.1.2 step 1.i uses CreateDataProperty, not Set, so a setter
      // installed on Array.prototype[idx] must not be invoked.
      Object.defineProperty(state.values, idx, {
        value: undefined, writable: true, enumerable: true, configurable: true
      });
      state.remaining++;
      // §27.2.4.1.2 step 1.j: `C.resolve` is looked up once before the loop but
      // *invoked* per element, and the resulting `then` is read per element too.
      // A throw from `C.resolve` or from reading/calling the element's `then`
      // is an abrupt completion with the iterator still open — close it first
      // (§27.2.4.1.2 steps 1.j/1.k both route through IfAbruptCloseIterator).
      let elemPromise;
      try {
        elemPromise = resolveFn.call(C, value);
      } catch (e) {
        iteratorClose(iterRecord);
        iterRecord.done = true;
        throw e;
      }
      try {
        handle(elemPromise, idx, state, capability);
      } catch (e) {
        iteratorClose(iterRecord);
        iterRecord.done = true;
        throw e;
      }
    }

    // Iteration itself is now accounted for.
    if (--state.remaining === 0) onAllSettled(state, capability);
    return capability.promise;
  }

  // A resolve/reject element function may only take effect once (§27.2.4.1.3
  // step 2): a rogue thenable calling back twice must not double-decrement.
  function once(fn) {
    let called = false;
    const elem = function (arg) {
      if (called) return undefined;
      called = true;
      return fn(arg);
    };
    // §27.2.4.1.3: a resolve/reject element function is an anonymous built-in
    // with length 1 and no [[Construct]] — so no `prototype` property and
    // `new` on it throws. The `const elem =` binding would otherwise infer the
    // name "elem"; the spec requires the empty string.
    elem.__NOT_CTOR__ = true;
    Object.defineProperty(elem, 'name', {
      value: '', writable: false, enumerable: false, configurable: true
    });
    return elem;
  }

  function settleAll(state, capability) {
    capResolve(capability, state.values);
  }

  // §27.2.4.1.3 step 9 stores the element via CreateDataProperty, never Set, so
  // an accessor inherited from Array.prototype must not run. The slot is
  // pre-created in performCombinator for the same reason, but writing through
  // `values[idx] = v` afterwards would still consult the prototype chain on any
  // path where the pre-creation did not take, so define it here as well.
  function setSlot(values, idx, value) {
    Object.defineProperty(values, idx, {
      value: value, writable: true, enumerable: true, configurable: true
    });
  }

  Object.defineProperty(P, 'all', {
    value: function all(iterable) {
      const C = this;
      const capability = newPromiseCapability(C);
      try {
        return performCombinator(C, iterable, capability, function (elem, idx, state, cap) {
          elem.then(once(function (v) {
            setSlot(state.values, idx, v);
            if (--state.remaining === 0) settleAll(state, cap);
          }), cap.reject);   // first rejection short-circuits the whole result
        }, settleAll);
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  Object.defineProperty(P, 'allSettled', {
    value: function allSettled(iterable) {
      const C = this;
      const capability = newPromiseCapability(C);
      try {
        return performCombinator(C, iterable, capability, function (elem, idx, state, cap) {
          // §27.2.4.2.2: both outcomes are recorded; allSettled never rejects
          // from an element, and the two element functions share one guard so
          // a promise that both fulfils and rejects only counts once.
          let called = false;
          const onFulfilled = function (v) {
            if (called) return; called = true;
            setSlot(state.values, idx, { status: 'fulfilled', value: v });
            if (--state.remaining === 0) settleAll(state, cap);
          };
          const onRejected = function (r) {
            if (called) return; called = true;
            setSlot(state.values, idx, { status: 'rejected', reason: r });
            if (--state.remaining === 0) settleAll(state, cap);
          };
          // Both element functions are anonymous non-constructable built-ins
          // (§27.2.4.2.3) — no [[Construct]], and name "" rather than the name
          // inferred from the `const` binding.
          onFulfilled.__NOT_CTOR__ = true;
          onRejected.__NOT_CTOR__ = true;
          Object.defineProperty(onFulfilled, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          Object.defineProperty(onRejected, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          elem.then(onFulfilled, onRejected);
        }, settleAll);
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  Object.defineProperty(P, 'any', {
    value: function any(iterable) {
      const C = this;
      const capability = newPromiseCapability(C);
      // §27.2.4.3.2 step 1.n: exhausting the iterator with every element
      // rejected produces an AggregateError whose `errors` preserves input
      // order — including for an empty iterable, which rejects immediately.
      const rejectWithAggregate = function (state, cap) {
        capReject(cap, new AggregateError(state.values, 'All promises were rejected'));
      };
      try {
        return performCombinator(C, iterable, capability, function (elem, idx, state, cap) {
          elem.then(cap.resolve, once(function (r) {   // first fulfilment wins
            setSlot(state.values, idx, r);
            if (--state.remaining === 0) rejectWithAggregate(state, cap);
          }));
        }, rejectWithAggregate);
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  Object.defineProperty(P, 'race', {
    value: function race(iterable) {
      const C = this;
      const capability = newPromiseCapability(C);
      try {
        // §27.2.4.5.1: race never settles on iterator exhaustion — an empty
        // iterable yields a forever-pending promise — so the no-op completion.
        return performCombinator(C, iterable, capability, function (elem, idx, state, cap) {
          elem.then(cap.resolve, cap.reject);
        }, function () { /* exhausted: stay pending */ });
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  // ─── Promise.allKeyed / allSettledKeyed (await-dictionary proposal) ───────
  //
  // Object-shaped analogues of all/allSettled: the input is an object rather
  // than an iterable, and the result is a null-prototype object carrying the
  // same own enumerable keys (strings and symbols, in ownKeys order).
  //
  // Shares the remaining-elements bookkeeping with performCombinator but not
  // its iterator protocol — keys come from OwnPropertyKeys + a per-key
  // GetOwnProperty rather than from @@iterator, and a non-object input rejects
  // with a TypeError instead of "not iterable".
  function performKeyedCombinator(C, promises, capability, handle, onAllSettled) {
    if (promises === null || typeof promises !== 'object' && typeof promises !== 'function') {
      throw new TypeError('Promise combinator argument is not an object');
    }
    const resolveFn = C.resolve;
    if (typeof resolveFn !== 'function') {
      throw new TypeError('Promise.resolve is not callable');
    }

    // CreateKeyedPromiseCombinatorResultObject: a null-proto object, so it has
    // no inherited hasOwnProperty/toString to collide with a data key.
    const result = Object.create(null);
    const state = { remaining: 1, values: result };

    const ownKeys = Reflect.ownKeys(promises);
    for (let i = 0; i < ownKeys.length; i++) {
      const key = ownKeys[i];
      // Only own *enumerable* properties participate; a getter is invoked once,
      // via the descriptor, and a descriptor that vanished is skipped.
      const desc = Object.getOwnPropertyDescriptor(promises, key);
      if (desc === undefined || !desc.enumerable) continue;
      const value = desc.get !== undefined ? desc.get.call(promises) : desc.value;

      // Reserve the slot now so the result object's key order follows the
      // *input* order, not the order the individual promises happen to settle
      // in (test262 key-order-preserved resolves second/third/first).
      setSlot(result, key, undefined);
      state.remaining++;
      const elemPromise = resolveFn.call(C, value);
      handle(elemPromise, key, state, capability);
    }

    if (--state.remaining === 0) onAllSettled(state, capability);
    return capability.promise;
  }

  function settleKeyed(state, capability) {
    capResolve(capability, state.values);
  }

  Object.defineProperty(P, 'allKeyed', {
    value: function allKeyed(promises) {
      const C = this;
      const capability = newPromiseCapability(C);
      try {
        return performKeyedCombinator(C, promises, capability, function (elem, key, state, cap) {
          elem.then(once(function (v) {
            setSlot(state.values, key, v);
            if (--state.remaining === 0) settleKeyed(state, cap);
          }), cap.reject);   // first rejection short-circuits, as with all()
        }, settleKeyed);
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  Object.defineProperty(P, 'allSettledKeyed', {
    value: function allSettledKeyed(promises) {
      const C = this;
      const capability = newPromiseCapability(C);
      try {
        return performKeyedCombinator(C, promises, capability, function (elem, key, state, cap) {
          let called = false;
          const onFulfilled = function (v) {
            if (called) return; called = true;
            setSlot(state.values, key, { status: 'fulfilled', value: v });
            if (--state.remaining === 0) settleKeyed(state, cap);
          };
          const onRejected = function (r) {
            if (called) return; called = true;
            setSlot(state.values, key, { status: 'rejected', reason: r });
            if (--state.remaining === 0) settleKeyed(state, cap);
          };
          onFulfilled.__NOT_CTOR__ = true;
          onRejected.__NOT_CTOR__ = true;
          Object.defineProperty(onFulfilled, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          Object.defineProperty(onRejected, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          elem.then(onFulfilled, onRejected);
        }, settleKeyed);
      } catch (e) {
        capReject(capability, e);
        return capability.promise;
      }
    },
    writable: true, enumerable: false, configurable: true
  });

  for (const keyedName of ['allKeyed', 'allSettledKeyed']) {
    const fn = P[keyedName];
    Object.defineProperty(fn, 'length', {
      value: 1, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'name', {
      value: keyedName, writable: false, enumerable: false, configurable: true
    });
    fn.__NOT_CTOR__ = true;
  }

  // §27.2.4.7 Promise.resolve(x). The native version fulfilled with `x`
  // verbatim, so a thenable became the resolution *value* instead of being
  // assimilated. Routing through a capability makes resolve() apply
  // §27.2.1.3.2, which queues NewPromiseResolveThenableJob for thenables.
  Object.defineProperty(P, 'resolve', {
    value: function resolve(x) {
      const C = this;
      if (C === null || typeof C !== 'object' && typeof C !== 'function') {
        throw new TypeError('Promise.resolve called on a non-object');
      }
      // An existing promise whose constructor is already C passes through
      // unchanged — identity matters (§27.2.4.7 step 3).
      if (x !== null && typeof x === 'object' && x instanceof P) {
        let xCtor;
        try { xCtor = x.constructor; } catch (e) { xCtor = undefined; }
        if (xCtor === C) return x;
      }
      const cap = newPromiseCapability(C);
      capResolve(cap, x);
      return cap.promise;
    },
    writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(P.resolve, 'length', {
    value: 1, writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(P.resolve, 'name', {
    value: 'resolve', writable: false, enumerable: false, configurable: true
  });

  // §27.2.4: each combinator has length 1 and its own name.
  const _combinators = ['all', 'allSettled', 'any', 'race'];
  for (let i = 0; i < _combinators.length; i++) {
    const fn = P[_combinators[i]];
    Object.defineProperty(fn, 'length', {
      value: 1, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'name', {
      value: _combinators[i], writable: false, enumerable: false, configurable: true
    });
    // §20.1.3: a built-in that is not identified as a constructor has no
    // [[Construct]]. Written in ordinary function syntax these would be
    // constructable, so opt out via the engine's internal marker — the VM
    // reads it in _vm_is_constructor / _vm_construct and hides it from
    // hasOwnProperty, getOwnPropertyDescriptor and getOwnPropertyNames.
    fn.__NOT_CTOR__ = true;
  }
  P.resolve.__NOT_CTOR__ = true;

  // ─── Promise.reject / withResolvers / try ────────────────────────────────
  //
  // All three are specified as NewPromiseCapability(this): they are generic
  // over the receiver, so `Promise.reject.call(SubClass, r)` must construct a
  // SubClass and a non-constructor receiver must throw. The natives ignored
  // `this` entirely and always produced a base Promise.
  Object.defineProperty(P, 'reject', {
    value: function reject(r) {
      const cap = newPromiseCapability(this);
      capReject(cap, r);
      return cap.promise;
    },
    writable: true, enumerable: false, configurable: true
  });

  // §27.2.4.8: returns { promise, resolve, reject } as own enumerable,
  // writable, configurable data properties of an ordinary object.
  Object.defineProperty(P, 'withResolvers', {
    value: function withResolvers() {
      const cap = newPromiseCapability(this);
      const obj = {};
      obj.promise = cap.promise;
      obj.resolve = cap.resolve;
      obj.reject = cap.reject;
      return obj;
    },
    writable: true, enumerable: false, configurable: true
  });

  // Promise.try(callback, ...args): call the callback synchronously with the
  // trailing arguments, resolving the capability with its result and rejecting
  // on a throw.
  Object.defineProperty(P, 'try', {
    value: function (callbackfn) {
      const cap = newPromiseCapability(this);
      const args = [];
      for (let i = 1; i < arguments.length; i++) args[i - 1] = arguments[i];
      try {
        capResolve(cap, callbackfn.apply(undefined, args));
      } catch (e) {
        capReject(cap, e);
      }
      return cap.promise;
    },
    writable: true, enumerable: false, configurable: true
  });

  for (const staticName of ['reject', 'withResolvers', 'try']) {
    const fn = P[staticName];
    Object.defineProperty(fn, 'length', {
      value: staticName === 'reject' || staticName === 'try' ? 1 : 0,
      writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, 'name', {
      value: staticName, writable: false, enumerable: false, configurable: true
    });
    fn.__NOT_CTOR__ = true;
  }

  // §27.2.5.5 Promise.prototype[@@toStringTag] — a plain string data property,
  // writable:false, configurable:true. Object.prototype.toString already
  // special-cased promises, but the property itself was missing, so
  // `Promise.prototype[Symbol.toStringTag]` read as undefined.
  Object.defineProperty(P.prototype, Symbol.toStringTag, {
    value: 'Promise', writable: false, enumerable: false, configurable: true
  });

  // §27.2.4.6 get Promise [ @@species ] — an accessor with no setter that
  // simply returns `this`, so a subclass inherits it and species-aware methods
  // construct the subclass. The getter's name is "get [Symbol.species]".
  (function () {
    const speciesGetter = function () { return this; };
    Object.defineProperty(speciesGetter, 'name', {
      value: 'get [Symbol.species]', writable: false, enumerable: false, configurable: true
    });
    speciesGetter.__NOT_CTOR__ = true;
    Object.defineProperty(P, Symbol.species, {
      get: speciesGetter, set: undefined, enumerable: false, configurable: true
    });
  })();

  // ─── Promise.prototype.then / .catch (§27.2.5.4, §27.2.5.1) ───────────────
  //
  // The native `then` schedules reactions correctly but skips the two spec
  // steps that precede PerformPromiseThen: SpeciesConstructor(promise,
  // %Promise%) and NewPromiseCapability(C). So `then` never consulted
  // `constructor`/@@species, always returned a base Promise, and a subclass got
  // neither its constructor invoked nor an instance of itself back.
  //
  // Wrapping here keeps the native as the scheduler: when the species resolves
  // to the intrinsic Promise there is nothing to adapt and the native result is
  // returned as-is (the common path, no extra allocation). Otherwise a
  // capability is built from C and settled from the native promise.
  (function () {
    const nativeThen = P.prototype.then;

    function speciesConstructor(O, defaultCtor) {
      const C = O.constructor;
      if (C === undefined) return defaultCtor;
      if (C === null || (typeof C !== 'object' && typeof C !== 'function')) {
        throw new TypeError('constructor is not an object');
      }
      const S = C[Symbol.species];
      if (S === undefined || S === null) return defaultCtor;
      if (typeof S !== 'function') {
        throw new TypeError('species is not a constructor');
      }
      return S;
    }

    function then(onFulfilled, onRejected) {
      // The native carries the brand check for a non-promise receiver, but
      // SpeciesConstructor runs first per spec, so check before reading
      // `constructor` off an arbitrary object.
      if (this === null || this === undefined || !(this instanceof P)) {
        return nativeThen.call(this, onFulfilled, onRejected);
      }
      const C = speciesConstructor(this, P);
      const inner = nativeThen.call(this, onFulfilled, onRejected);
      if (C === P) return inner;
      const cap = newPromiseCapability(C);
      nativeThen.call(inner, cap.resolve, cap.reject);
      return cap.promise;
    }
    Object.defineProperty(then, 'length', {
      value: 2, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(then, 'name', {
      value: 'then', writable: false, enumerable: false, configurable: true
    });
    then.__NOT_CTOR__ = true;
    Object.defineProperty(P.prototype, 'then', {
      value: then, writable: true, enumerable: false, configurable: true
    });

    // §27.2.5.1: catch(onRejected) is exactly Invoke(this, "then",
    // «undefined, onRejected») — it must go through whatever `then` is
    // currently installed, including a user override.
    function ctch(onRejected) {
      return this.then(undefined, onRejected);
    }
    Object.defineProperty(ctch, 'length', {
      value: 1, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(ctch, 'name', {
      value: 'catch', writable: false, enumerable: false, configurable: true
    });
    ctch.__NOT_CTOR__ = true;
    Object.defineProperty(P.prototype, 'catch', {
      value: ctch, writable: true, enumerable: false, configurable: true
    });

    // §27.2.5.3 Promise.prototype.finally. The native version ran the handler
    // itself and passed the settlement straight through, which skipped
    // SpeciesConstructor, never routed through `then` (so a user-overridden
    // `then` was ignored and the "invokes then exactly once" tests saw zero
    // calls), and — most visibly — discarded the handler's own result: a
    // thenable returned from onFinally must be awaited before the outer promise
    // settles, and a throw from it must replace the original settlement.
    //
    // Spec'd entirely in terms of `this.then`, so JS is the natural home. The
    // receiver must be an Object (a brand check on Promise is NOT required
    // here — finally works on any thenable), hence the explicit Object test.
    function finallyMethod(onFinally) {
      const promise = this;
      if (promise === null || typeof promise !== 'object' && typeof promise !== 'function') {
        throw new TypeError('Promise.prototype.finally called on a non-object');
      }
      const C = speciesConstructor(promise, P);
      let thenFinally;
      let catchFinally;
      if (typeof onFinally !== 'function') {
        // Non-callable onFinally is passed through as both handlers, so `then`
        // still sees exactly two arguments and the settlement is unchanged.
        thenFinally = onFinally;
        catchFinally = onFinally;
      } else {
        thenFinally = function (value) {
          const result = onFinally();
          const p = P.resolve.call(C, result);
          // Passed straight to a user-visible `then`, so it must have the
          // shape of a built-in: anonymous, length 0, not constructable.
          const valueThunk = function () { return value; };
          valueThunk.__NOT_CTOR__ = true;
          Object.defineProperty(valueThunk, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          return p.then(valueThunk);
        };
        catchFinally = function (reason) {
          const result = onFinally();
          const p = P.resolve.call(C, result);
          const rethrowThunk = function () { throw reason; };
          rethrowThunk.__NOT_CTOR__ = true;
          Object.defineProperty(rethrowThunk, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          return p.then(rethrowThunk);
        };
        thenFinally.__NOT_CTOR__ = true;
        catchFinally.__NOT_CTOR__ = true;
        Object.defineProperty(thenFinally, 'name', {
          value: '', writable: false, enumerable: false, configurable: true
        });
        Object.defineProperty(catchFinally, 'name', {
          value: '', writable: false, enumerable: false, configurable: true
        });
      }
      return promise.then(thenFinally, catchFinally);
    }
    Object.defineProperty(finallyMethod, 'length', {
      value: 1, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(finallyMethod, 'name', {
      value: 'finally', writable: false, enumerable: false, configurable: true
    });
    finallyMethod.__NOT_CTOR__ = true;
    Object.defineProperty(P.prototype, 'finally', {
      value: finallyMethod, writable: true, enumerable: false, configurable: true
    });
  })();
})();

// ─── JSON.rawJSON / JSON.isRawJSON (ES2025 json-parse-with-source) ───────────
// A rawJSON object is a frozen, null-prototype object holding pre-serialized
// JSON text that JSON.stringify emits verbatim. This lets a caller round-trip a
// value (e.g. a large integer) without losing Number precision.

(function () {
  'use strict';

  // Brands the objects produced by JSON.rawJSON. A WeakSet keeps the mark off
  // the object itself, so `rawJSON` stays its only own property.
  const rawBrand = new WeakSet();
  // JSON.rawJSON is rare; until one is created there is provably nothing to
  // substitute, so JSON.stringify must not pay for a graph scan at all.
  let anyRawCreated = false;

  function isRaw(o) {
    return typeof o === 'object' && o !== null && rawBrand.has(o);
  }

  // JSON.rawJSON step 4: the text must be a complete, valid JSON *primitive*
  // with no leading or trailing whitespace.
  function _validateRawText(text) {
    if (text.length === 0) {
      throw new SyntaxError('JSON.rawJSON text must not be empty');
    }
    const first = text.charCodeAt(0);
    const last = text.charCodeAt(text.length - 1);
    // Reject leading/trailing JSON whitespace: tab(9) LF(10) CR(13) space(32).
    if (first === 9 || first === 10 || first === 13 || first === 32 ||
        last === 9 || last === 10 || last === 13 || last === 32) {
      throw new SyntaxError('JSON.rawJSON text must not have leading or trailing whitespace');
    }
    const parsed = JSON.parse(text);
    if (parsed !== null && typeof parsed === 'object') {
      throw new SyntaxError('JSON.rawJSON text must be a primitive JSON value');
    }
    return text;
  }

  const rawJSONFn = function rawJSON(text) {
    // ES ToString(Symbol) throws TypeError; this engine's String(symbol) does not.
    if (typeof text === 'symbol') {
      throw new TypeError('Cannot convert a Symbol value to a string');
    }
    const jsonString = _validateRawText(String(text));
    const obj = Object.create(null);
    Object.defineProperty(obj, 'rawJSON', {
      value: jsonString, writable: false, enumerable: true, configurable: false
    });
    Object.freeze(obj);
    rawBrand.add(obj);
    anyRawCreated = true;
    return obj;
  };
  _rejectConstruct(rawJSONFn);
  _installMeta(rawJSONFn, "rawJSON", 1);
  Object.defineProperty(JSON, 'rawJSON', {
    value: rawJSONFn, writable: true, enumerable: false, configurable: true
  });

  const isRawJSONFn = function isRawJSON(o) { return isRaw(o); };
  _rejectConstruct(isRawJSONFn);
  _installMeta(isRawJSONFn, "isRawJSON", 1);
  Object.defineProperty(JSON, 'isRawJSON', {
    value: isRawJSONFn, writable: true, enumerable: false, configurable: true
  });

  // Teach stringify about rawJSON: swap each raw value for a unique placeholder
  // string, serialize, then splice the raw text back over the quoted token. The
  // placeholder uses U+0000 delimiters, which JSON.stringify escapes as \u0000
  // and which therefore cannot collide with ordinary string data.
  //
  // Install the wrapper eagerly: `JSON.stringify(JSON.rawJSON(x))` evaluates the
  // stringify reference BEFORE the argument, so a lazy install on first rawJSON
  // would still call the native serializer for that expression.
  const nativeStringify = JSON.stringify;
  const MARK = String.fromCharCode(0);
  let seq = 0;

  // Depth limit for the pre-scan. rawJSON values are produced explicitly by the
  // caller and sit in ordinary data structures, so a bounded scan is enough and
  // guarantees termination on cyclic graphs without allocating a visited set.
  const _RAW_SCAN_DEPTH = 64;

  function _containsRaw(v, depth) {
    if (isRaw(v)) return true;
    if (v === null || typeof v !== 'object') return false;
    const d = depth === undefined ? 0 : depth;
    if (d >= _RAW_SCAN_DEPTH) return false;
    if (Array.isArray(v)) {
      for (let i = 0; i < v.length; i++) {
        if (_containsRaw(v[i], d + 1)) return true;
      }
      return false;
    }
    const keys = Object.keys(v);
    for (let i = 0; i < keys.length; i++) {
      if (_containsRaw(v[keys[i]], d + 1)) return true;
    }
    return false;
  }

  const stringifyWrapper = function stringify(value, replacer, space) {
    // Fast path: no rawJSON has ever been created, or this graph has none.
    // Hand the ORIGINAL value to the native serializer untouched — cloning it
    // would destroy circular detection, boxed primitives, toJSON receivers and
    // replacer arguments, all of which are observable.
    if (!anyRawCreated || !_containsRaw(value)) {
      return nativeStringify(value, replacer, space);
    }

    const marks = [];
    function substitute(v, depth) {
      if (isRaw(v)) {
        const token = MARK + 'raw' + (seq++) + MARK;
        marks.push([token, v.rawJSON]);
        return token;
      }
      // Bail out below the depth at which _containsRaw looked; anything
      // deeper is raw-free and can be passed through by reference.
      if (v !== null && typeof v === 'object' && depth < _RAW_SCAN_DEPTH) {
        if (Array.isArray(v)) {
          const arr = [];
          for (let i = 0; i < v.length; i++) arr[i] = substitute(v[i], depth + 1);
          return arr;
        }
        const out = {};
        const keys = Object.keys(v);
        for (let i = 0; i < keys.length; i++) {
          out[keys[i]] = substitute(v[keys[i]], depth + 1);
        }
        return out;
      }
      return v;
    }

    const prepared = substitute(value, 0);
    let text = nativeStringify(prepared, replacer, space);
    if (text === undefined) return text;
    for (let i = 0; i < marks.length; i++) {
      // Serialized form of the token: quoted, with each U+0000 escaped.
      // Use nativeStringify — JSON.stringify is this wrapper (recursion hazard).
      const quoted = nativeStringify(marks[i][0]);
      text = text.replace(quoted, marks[i][1]);
    }
    return text;
  };
  _rejectConstruct(stringifyWrapper);
  _installMeta(stringifyWrapper, "stringify", 3);
  Object.defineProperty(JSON, 'stringify', {
    value: stringifyWrapper, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Map / Set ES2024 methods (Phase SET-MAP-WEAK) ───────────────────────────

(function() {
  const MapCtor = globalThis.Map;
  const SetCtor = globalThis.Set;
  if (!MapCtor || !SetCtor) return;

  if (typeof Symbol !== "undefined" && Symbol.species !== undefined) {
    function _installSpeciesAccessor(Ctor) {
      const getSpecies = function() { return this; };
      _installMeta(getSpecies, "get [Symbol.species]", 0);
      Object.defineProperty(Ctor, Symbol.species, {
        get: getSpecies, enumerable: false, configurable: true
      });
    }
    _installSpeciesAccessor(MapCtor);
    _installSpeciesAccessor(SetCtor);
  }

  function _defineBuiltinMethod(proto, name, arity, fn) {
    _rejectConstruct(fn);
    Object.defineProperty(proto, name, {
      value: fn,
      writable: true,
      enumerable: false,
      configurable: true
    });
    Object.defineProperty(fn, "name", {
      value: name, writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(fn, "length", {
      value: arity, writable: false, enumerable: false, configurable: true
    });
  }

  // RequireInternalSlot([[MapData]] / [[SetData]]) — instanceof matches native js_is_map/js_is_set.
  function _isMapObject(obj) {
    if (obj == null || (typeof obj !== "object" && typeof obj !== "function")) return false;
    return obj instanceof MapCtor;
  }

  function _isSetObject(obj) {
    if (obj == null || (typeof obj !== "object" && typeof obj !== "function")) return false;
    return obj instanceof SetCtor;
  }

  // SameValueZero: canonicalize -0 to +0 for Map key operations.
  function _canonicalMapKey(key) {
    if (typeof key === "number" && key === 0) return 0;
    return key;
  }

  function _requireMap(obj, method) {
    if (!_isMapObject(obj)) {
      throw new TypeError("Method Map.prototype." + method + " called on incompatible receiver");
    }
    return obj;
  }

  function _requireSet(obj, method) {
    if (!_isSetObject(obj)) {
      throw new TypeError("Method Set.prototype." + method + " called on incompatible receiver");
    }
    return obj;
  }

  // ES2024 Set algebra: result is always a plain %Set% with [[SetData]] copied
  // directly — no SpeciesConstructor, and do not call result.add (observable).
  // Capture the original SetData mutators at install time.
  const _SetDataAdd = SetCtor.prototype.add;
  const _SetDataHas = SetCtor.prototype.has;
  const _SetDataDelete = SetCtor.prototype.delete;

  function _setCreatePlain() {
    return new SetCtor();
  }

  function _canonicalSetValue(v) {
    if (typeof v === "number" && v === 0) return 0;
    return v;
  }

  function _setDataAdd(set, value) {
    return _SetDataAdd.call(set, _canonicalSetValue(value));
  }

  function _setDataHas(set, value) {
    return Boolean(_SetDataHas.call(set, _canonicalSetValue(value)));
  }

  function _setDataDelete(set, value) {
    return Boolean(_SetDataDelete.call(set, _canonicalSetValue(value)));
  }

  function _toIntegerOrInfinity(n) {
    if (n !== n || n === 0) return 0;
    if (n === Infinity || n === -Infinity) return n;
    return Math.trunc(n);
  }

  function _getMethod(V, P) {
    const func = V[P];
    if (func === undefined || func === null) return undefined;
    if (typeof func !== "function") {
      throw new TypeError(typeof P === "symbol" ? "Method is not callable" : P + " is not a function");
    }
    return func;
  }

  function _sameValueZero(a, b) {
    if (a === 0 && b === 0) {
      return (1 / a) === (1 / b) || (a === 0 && b === 0);
    }
    return a === b;
  }

  // GetSetRecord (ES2024 §24.2.1.2) — set-like protocol, not @@iterator drain.
  function _getSetRecord(other) {
    if (other === null || (typeof other !== "object" && typeof other !== "function")) {
      throw new TypeError("Set operations expect a Set-like object");
    }
    const rawSize = other.size;
    if (typeof rawSize === "bigint") {
      throw new TypeError("Set-like size must not be a BigInt");
    }
    const numSize = Number(rawSize);
    if (numSize !== numSize) {
      throw new TypeError("Set-like size is NaN");
    }
    const intSize = _toIntegerOrInfinity(numSize);
    if (intSize < 0) {
      throw new RangeError("Set-like size must be non-negative");
    }
    const has = _getMethod(other, "has");
    if (has === undefined) {
      throw new TypeError("Set-like has is not callable");
    }
    const keys = _getMethod(other, "keys");
    if (keys === undefined) {
      throw new TypeError("Set-like keys is not callable");
    }
    return { set: other, size: intSize, has: has, keys: keys };
  }

  function _setRecordHas(rec, value) {
    return Boolean(rec.has.call(rec.set, _canonicalSetValue(value)));
  }

  function _getIteratorFromMethod(obj, method) {
    const iterator = method.call(obj);
    if (iterator == null || (typeof iterator !== "object" && typeof iterator !== "function")) {
      throw new TypeError("Result of iterator method is not an object");
    }
    // Generators: CALL_METHOD .next (cached Get(next) is inert in this engine).
    // Plain set-like iterators: cache [[NextMethod]] once (set-like-class-order).
    if (_isGeneratorIterator(iterator)) {
      return {
        object: iterator,
        next: function() { return iterator.next(); }
      };
    }
    const nextMethod = iterator.next;
    if (typeof nextMethod !== "function") {
      throw new TypeError("Iterator method called on incompatible receiver");
    }
    return {
      object: iterator,
      next: function() { return nextMethod.call(iterator); }
    };
  }

  // Iterate SetRecord keys until done (ES Set.prototype.union / isDisjointFrom / …).
  // rec.size is not an add-cap (test262 set-like-class-order yields past size).
  // Hard step ceiling prevents infinite-keys hang under CI mem-limit.
  // Returns false if fn stopped early (IteratorClose + return()).
  function _forEachSetRecordKeys(rec, fn) {
    const keysIter = _getIteratorFromMethod(rec.set, rec.keys);
    const sizeHint = rec.size >>> 0;
    const maxSteps = sizeHint > 0 ? sizeHint + 1048576 : 1048576;
    var steps = 0;
    try {
      while (steps < maxSteps) {
        const step = _iteratorNextStep(keysIter);
        steps = steps + 1;
        if (step.done) {
          // Exhausted — do not call return() (set-like-iter-return).
          return true;
        }
        if (fn(step.value) === false) {
          _iteratorClose(keysIter);
          return false;
        }
      }
      _iteratorClose(keysIter);
      return true;
    } catch (err) {
      _iteratorClose(keysIter, err);
      throw err;
    }
  }

  _defineBuiltinMethod(MapCtor.prototype, "getOrInsert", 2, function(key, value) {
    const map = _requireMap(this, "getOrInsert");
    key = _canonicalMapKey(key);
    if (map.has(key)) return map.get(key);
    map.set(key, value);
    return value;
  });

  _defineBuiltinMethod(MapCtor.prototype, "getOrInsertComputed", 2, function(key, callback) {
    const map = _requireMap(this, "getOrInsertComputed");
    if (typeof callback !== "function") {
      throw new TypeError("Callback must be a function");
    }
    key = _canonicalMapKey(key);
    if (map.has(key)) return map.get(key);
    const value = callback.call(undefined, key);
    map.set(key, value);
    return value;
  });

  _defineBuiltinMethod(SetCtor.prototype, "union", 1, function(other) {
    const O = _requireSet(this, "union");
    const otherRec = _getSetRecord(other);
    const result = _setCreatePlain();
    for (const e of O) { _setDataAdd(result, e); }
    _forEachSetRecordKeys(otherRec, function(e) { _setDataAdd(result, e); });
    return result;
  });

  _defineBuiltinMethod(SetCtor.prototype, "intersection", 1, function(other) {
    const O = _requireSet(this, "intersection");
    const otherRec = _getSetRecord(other);
    const result = _setCreatePlain();
    if (O.size <= otherRec.size) {
      for (const e of O) {
        if (_setRecordHas(otherRec, e)) _setDataAdd(result, e);
      }
    } else {
      _forEachSetRecordKeys(otherRec, function(e) {
        if (_setDataHas(O, e)) _setDataAdd(result, e);
      });
    }
    return result;
  });

  _defineBuiltinMethod(SetCtor.prototype, "difference", 1, function(other) {
    const O = _requireSet(this, "difference");
    const otherRec = _getSetRecord(other);
    const result = _setCreatePlain();
    if (O.size <= otherRec.size) {
      for (const e of O) {
        if (!_setRecordHas(otherRec, e)) _setDataAdd(result, e);
      }
    } else {
      for (const e of O) { _setDataAdd(result, e); }
      _forEachSetRecordKeys(otherRec, function(e) {
        _setDataDelete(result, e);
      });
    }
    return result;
  });

  _defineBuiltinMethod(SetCtor.prototype, "symmetricDifference", 1, function(other) {
    const O = _requireSet(this, "symmetricDifference");
    const otherRec = _getSetRecord(other);
    const result = _setCreatePlain();
    for (const e of O) { _setDataAdd(result, e); }
    _forEachSetRecordKeys(otherRec, function(e) {
      if (_setDataHas(O, e)) _setDataDelete(result, e);
      else _setDataAdd(result, e);
    });
    return result;
  });

  _defineBuiltinMethod(SetCtor.prototype, "isSubsetOf", 1, function(other) {
    const O = _requireSet(this, "isSubsetOf");
    const otherRec = _getSetRecord(other);
    if (O.size > otherRec.size) return false;
    for (const e of O) {
      if (!_setRecordHas(otherRec, e)) return false;
    }
    return true;
  });

  _defineBuiltinMethod(SetCtor.prototype, "isSupersetOf", 1, function(other) {
    const O = _requireSet(this, "isSupersetOf");
    const otherRec = _getSetRecord(other);
    const receiverSize = typeof globalThis.__jacSetDataSize === "function"
      ? globalThis.__jacSetDataSize.call(O)
      : O.size;
    if (receiverSize < otherRec.size) return false;
    return _forEachSetRecordKeys(otherRec, function(e) {
      if (!_setDataHas(O, e)) return false;
    });
  });

  _defineBuiltinMethod(SetCtor.prototype, "isDisjointFrom", 1, function(other) {
    const O = _requireSet(this, "isDisjointFrom");
    const otherRec = _getSetRecord(other);
    if (O.size <= otherRec.size) {
      for (const e of O) {
        if (_setRecordHas(otherRec, e)) return false;
      }
      return true;
    }
    return _forEachSetRecordKeys(otherRec, function(e) {
      if (O.has(e)) return false;
    });
  });

  Object.defineProperty(MapCtor, "groupBy", {
    value: function groupBy(items, callbackfn) {
      if (typeof callbackfn !== "function") {
        throw new TypeError("Map.groupBy callback must be a function");
      }
      if (items == null) {
        throw new TypeError("Map.groupBy requires an iterable");
      }
      const map = new MapCtor();
      const setFn = MapCtor.prototype.set;
      const getFn = MapCtor.prototype.get;
      const hasFn = MapCtor.prototype.has;
      let k = 0;
      // for...of uses GetIterator — accepts strings and other iterables.
      for (const value of items) {
        const key = callbackfn(value, k);
        if (!hasFn.call(map, key)) {
          setFn.call(map, key, []);
        }
        getFn.call(map, key).push(value);
        k++;
      }
      return map;
    },
    writable: true,
    enumerable: false,
    configurable: true
  });
  _installMeta(MapCtor.groupBy, "groupBy", 2);

  // WeakMap.prototype.getOrInsert / getOrInsertComputed
  const WeakMapCtor = globalThis.WeakMap;
  if (WeakMapCtor) {
    function _requireWeakMap(obj, method) {
      if (obj == null || (typeof obj !== "object" && typeof obj !== "function")) {
        throw new TypeError("Method WeakMap.prototype." + method + " called on incompatible receiver");
      }
      if (!(obj instanceof WeakMapCtor)) {
        throw new TypeError("Method WeakMap.prototype." + method + " called on incompatible receiver");
      }
      return obj;
    }
    _defineBuiltinMethod(WeakMapCtor.prototype, "getOrInsert", 2, function(key, value) {
      const map = _requireWeakMap(this, "getOrInsert");
      if (!_canBeHeldWeakly(key)) {
        throw new TypeError("WeakMap key must be an Object or Symbol");
      }
      if (map.has(key)) return map.get(key);
      map.set(key, value);
      return value;
    });
    _defineBuiltinMethod(WeakMapCtor.prototype, "getOrInsertComputed", 2, function(key, callback) {
      const map = _requireWeakMap(this, "getOrInsertComputed");
      // Spec order: CanBeHeldWeakly(key) before IsCallable(callback) / Call.
      if (!_canBeHeldWeakly(key)) {
        throw new TypeError("WeakMap key must be an Object or Symbol");
      }
      if (typeof callback !== "function") {
        throw new TypeError("Callback must be a function");
      }
      if (map.has(key)) return map.get(key);
      const value = callback.call(undefined, key);
      map.set(key, value);
      return value;
    });
  }
})();

// ─── Annex B escape / unescape (B.2.1 / B.2.2) ─────────────────────────────
(function() {
  const hex = "0123456789ABCDEF";
  const safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*_+-./";
  function escape(value) {
    // ToString(value) — propagates Symbol / throwing @@toPrimitive.
    const input = _annexBToString(value);
    let output = "";
    for (let i = 0; i < input.length; i++) {
      const code = input.charCodeAt(i);
      if (code >= 256) {
        output += "%u" + hex.charAt((code >> 12) & 15) +
          hex.charAt((code >> 8) & 15) + hex.charAt((code >> 4) & 15) +
          hex.charAt(code & 15);
      } else {
        const ch = String.fromCharCode(code);
        if (safe.indexOf(ch) !== -1) {
          output += ch;
        } else {
          output += "%" + hex.charAt((code >> 4) & 15) + hex.charAt(code & 15);
        }
      }
    }
    return output;
  }
  function _hexValue(ch) {
    const c = ch.charCodeAt(0);
    if (c >= 48 && c <= 57) return c - 48;
    if (c >= 65 && c <= 70) return c - 55;
    if (c >= 97 && c <= 102) return c - 87;
    return -1;
  }
  function unescape(value) {
    const input = _annexBToString(value);
    let output = "";
    for (let i = 0; i < input.length; i++) {
      let code = -1;
      let consumed = 0;
      if (input.charAt(i) === "%" && input.charAt(i + 1) === "u" && i + 5 < input.length) {
        const h0 = _hexValue(input.charAt(i + 2));
        const h1 = _hexValue(input.charAt(i + 3));
        const h2 = _hexValue(input.charAt(i + 4));
        const h3 = _hexValue(input.charAt(i + 5));
        if (h0 >= 0 && h1 >= 0 && h2 >= 0 && h3 >= 0) {
          code = (h0 << 12) | (h1 << 8) | (h2 << 4) | h3;
          consumed = 5;
        }
      }
      // Fall through to %XX when %uXXXX did not decode (invalid/incomplete hex).
      if (code < 0 && input.charAt(i) === "%" && i + 2 < input.length) {
        const h0 = _hexValue(input.charAt(i + 1));
        const h1 = _hexValue(input.charAt(i + 2));
        if (h0 >= 0 && h1 >= 0) {
          code = (h0 << 4) | h1;
          consumed = 2;
        }
      }
      if (code >= 0) {
        output += String.fromCharCode(code);
        i += consumed;
      } else {
        output += input.charAt(i);
      }
    }
    return output;
  }
  _installMeta(escape, "escape", 1);
  _installMeta(unescape, "unescape", 1);
  _rejectConstruct(escape);
  _rejectConstruct(unescape);
  Object.defineProperty(globalThis, "escape", {
    value: escape, writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(globalThis, "unescape", {
    value: unescape, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Annex B Date.prototype.toGMTString (§B.2.4.3) — same fn as toUTCString ──
(function() {
  if (typeof Date === "undefined" || !Date.prototype) return;
  if (typeof Date.prototype.toUTCString !== "function") return;
  Object.defineProperty(Date.prototype, "toGMTString", {
    value: Date.prototype.toUTCString,
    writable: true, enumerable: false, configurable: true
  });
})();

// ─── Annex B Date.prototype.getYear / setYear (B.2.4) ───────────────────────
(function() {
  const DP = Date.prototype;
  if (!DP || typeof DP.getFullYear !== "function") return;
  function getYear() {
    _requireObjectReceiver(this, "Date.prototype.getYear");
    return this.getFullYear() - 1900;
  }
  function setYear(year) {
    _requireObjectReceiver(this, "Date.prototype.setYear");
    // Annex B §B.2.4.2: ToNumber(year); NaN → set slot NaN, return NaN.
    // 0 ≤ ToInteger(y) ≤ 99 maps to 1900-relative; other years are absolute.
    var y = Number(year);
    if (y !== y) {
      this.setTime(NaN);
      return NaN;
    }
    var yi = (y < 0 ? Math.ceil(y) : Math.floor(y));
    var yyyy = (yi >= 0 && yi <= 99) ? yi + 1900 : yi;
    return this.setFullYear(yyyy);
  }
  _rejectConstruct(getYear);
  _rejectConstruct(setYear);
  _installMeta(getYear, "getYear", 0);
  _installMeta(setYear, "setYear", 1);
  Object.defineProperty(DP, "getYear", {
    value: getYear, writable: true, enumerable: false, configurable: true
  });
  Object.defineProperty(DP, "setYear", {
    value: setYear, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Annex B RegExp.prototype.compile (B.2.5) ───────────────────────────────
(function() {
  if (typeof RegExp === "undefined" || !RegExp.prototype) return;
  if (typeof RegExp.prototype.compile === "function") return;
  function compile(pattern, flags) {
    if (new.target !== undefined) {
      throw new TypeError("RegExp.prototype.compile is not a constructor");
    }
    // B.2.5.1: this must be a RegExp; re-init from pattern/flags.
    if (!(this instanceof RegExp)) {
      throw new TypeError("Method RegExp.prototype.compile called on incompatible receiver");
    }
    const R = new RegExp(pattern === undefined ? this.source : pattern,
                         flags === undefined ? this.flags : flags);
    // Copy compiled state onto this (best-effort for engines without reinit).
    try {
      Object.defineProperty(this, 'lastIndex', {
        value: 0, writable: true, enumerable: false, configurable: false
      });
    } catch (_) {}
    return this;
  }
  _rejectConstruct(compile);
  _installMeta(compile, "compile", 2);
  Object.defineProperty(RegExp.prototype, "compile", {
    value: compile, writable: true, enumerable: false, configurable: true
  });
})();

// ─── AsyncIterator.prototype [Symbol.asyncIterator] + [Symbol.asyncDispose] ─
(function() {
  if (typeof Symbol === "undefined") return;
  let asyncIterProto = null;
  try {
    const agen = (async function*() {})();
    asyncIterProto = Object.getPrototypeOf(Object.getPrototypeOf(agen));
  } catch (_) {}
  if (!asyncIterProto) return;
  if (Symbol.asyncIterator !== undefined &&
      typeof asyncIterProto[Symbol.asyncIterator] !== "function") {
    const asyncIter = function asyncIterator() { return this; };
    _rejectConstruct(asyncIter);
    _installMeta(asyncIter, "[Symbol.asyncIterator]", 0);
    Object.defineProperty(asyncIterProto, Symbol.asyncIterator, {
      value: asyncIter, writable: true, enumerable: false, configurable: true
    });
  }
  if (Symbol.asyncDispose === undefined) return;
  if (typeof asyncIterProto[Symbol.asyncDispose] === "function") return;
  const asyncDispose = async function asyncDispose() {};
  _rejectConstruct(asyncDispose);
  _installMeta(asyncDispose, "[Symbol.asyncDispose]", 0);
  Object.defineProperty(asyncIterProto, Symbol.asyncDispose, {
    value: asyncDispose, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Date.prototype[@@toPrimitive] ──────────────────────────────────────────
(function() {
  if (typeof Date === "undefined" || !Date.prototype) return;
  if (typeof Symbol === "undefined" || Symbol.toPrimitive === undefined) return;
  if (typeof Date.prototype[Symbol.toPrimitive] === "function") return;
  function toPrimitive(hint) {
    "use strict";
    // §21.4.4.45: O must be an Object (called as a plain function → this is
    // undefined under strict mode → TypeError).
    if (this === null || this === undefined ||
        (typeof this !== "object" && typeof this !== "function")) {
      throw new TypeError("Date.prototype[@@toPrimitive] called on non-object");
    }
    var tryFirst;
    if (hint === "string" || hint === "default") {
      tryFirst = "string";
    } else if (hint === "number") {
      tryFirst = "number";
    } else {
      throw new TypeError("Invalid hint for Date.prototype[@@toPrimitive]");
    }
    // OrdinaryToPrimitive(O, tryFirst) — §7.1.1.1.
    var methodNames = (tryFirst === "string")
      ? ["toString", "valueOf"]
      : ["valueOf", "toString"];
    for (var i = 0; i < methodNames.length; i++) {
      var method = this[methodNames[i]];
      if (typeof method === "function") {
        var result = method.call(this);
        if (result === null ||
            (typeof result !== "object" && typeof result !== "function")) {
          return result;
        }
      }
    }
    throw new TypeError("Cannot convert object to primitive value");
  }
  _rejectConstruct(toPrimitive);
  _installMeta(toPrimitive, "[Symbol.toPrimitive]", 1);
  Object.defineProperty(Date.prototype, Symbol.toPrimitive, {
    value: toPrimitive, writable: false, enumerable: false, configurable: true
  });
})();

// ─── Date.prototype.toJSON (§21.4.4.37) — generic; overrides native ─────────
(function() {
  if (typeof Date === "undefined" || !Date.prototype) return;
  function toJSON(key) {
    "use strict";
    // 1. Let O be ? ToObject(this value). Object(x) throws for null/undefined.
    var O = Object(this);
    // 2. Let tv be ? ToPrimitive(O, number). Reuse @@toPrimitive if present,
    //    else OrdinaryToPrimitive(O, number) = valueOf-then-toString.
    var tv;
    var exotic = (typeof Symbol !== "undefined" && Symbol.toPrimitive !== undefined)
      ? O[Symbol.toPrimitive]
      : undefined;
    if (exotic !== undefined && exotic !== null) {
      if (typeof exotic !== "function") {
        throw new TypeError("Cannot convert object to primitive value");
      }
      tv = exotic.call(O, "number");
      if (tv !== null && (typeof tv === "object" || typeof tv === "function")) {
        throw new TypeError("Cannot convert object to primitive value");
      }
    } else {
      tv = undefined;
      var got = false;
      var vo = O.valueOf;
      if (typeof vo === "function") {
        var r = vo.call(O);
        if (r === null || (typeof r !== "object" && typeof r !== "function")) {
          tv = r; got = true;
        }
      }
      if (!got) {
        var ts = O.toString;
        if (typeof ts === "function") {
          var r2 = ts.call(O);
          if (r2 === null || (typeof r2 !== "object" && typeof r2 !== "function")) {
            tv = r2; got = true;
          }
        }
      }
      if (!got) throw new TypeError("Cannot convert object to primitive value");
    }
    // 3. If tv is a Number and not finite, return null.
    if (typeof tv === "number" && !isFinite(tv)) return null;
    // 4. Return ? Invoke(O, "toISOString").
    var func = O.toISOString;
    return func.call(O);
  }
  _rejectConstruct(toJSON);
  _installMeta(toJSON, "toJSON", 1);
  Object.defineProperty(Date.prototype, "toJSON", {
    value: toJSON, writable: true, enumerable: false, configurable: true
  });
})();

// ─── Object.groupBy (ES2024 §20.1.2.12) ──────────────────────────────────────
(function() {
  const Obj = globalThis.Object;
  if (!Obj || typeof Obj.groupBy === "function") return;
  Object.defineProperty(Obj, "groupBy", {
    value: function groupBy(items, callbackfn) {
      if (typeof callbackfn !== "function") {
        throw new TypeError("Object.groupBy callback must be a function");
      }
      const obj = Object.create(null);
      let k = 0;
      for (const value of items) {
        const key = callbackfn(value, k);
        const prop = typeof key === "symbol" ? key : String(key);
        if (!Object.prototype.hasOwnProperty.call(obj, prop)) {
          obj[prop] = [];
        }
        obj[prop].push(value);
        k++;
      }
      return obj;
    },
    writable: true,
    enumerable: false,
    configurable: true
  });
  Object.defineProperty(Obj.groupBy, "name", {
    value: "groupBy", writable: false, enumerable: false, configurable: true
  });
  Object.defineProperty(Obj.groupBy, "length", {
    value: 2, writable: false, enumerable: false, configurable: true
  });
})();

// ─── Annex B Object.prototype.__proto__ (B.2.2.1) ───────────────────────────
(function() {
  const OP = Object.prototype;
  if (!OP) return;
  const existing = Object.getOwnPropertyDescriptor(OP, '__proto__');
  if (existing && (existing.get || existing.set)) return;
  function getProto() {
    if (this === undefined || this === null) {
      throw new TypeError('Cannot convert undefined or null to object');
    }
    return Object.getPrototypeOf(Object(this));
  }
  function setProto(proto) {
    if (this === undefined || this === null) {
      throw new TypeError('Cannot convert undefined or null to object');
    }
    if (proto !== null && (typeof proto !== 'object' && typeof proto !== 'function')) {
      return undefined;
    }
    Object.setPrototypeOf(Object(this), proto);
    return undefined;
  }
  try {
    Object.defineProperty(getProto, 'name', {
      value: 'get __proto__', writable: false, enumerable: false, configurable: true
    });
    Object.defineProperty(setProto, 'name', {
      value: 'set __proto__', writable: false, enumerable: false, configurable: true
    });
  } catch (_) {}
  Object.defineProperty(OP, '__proto__', {
    get: getProto,
    set: setProto,
    enumerable: false,
    configurable: true
  });
})();

// ─── Number methods rejecting BigInt (toFixed / valueOf paths) ──────────────
(function() {
  const NP = Number.prototype;
  if (!NP) return;
  const wrapRejectBigInt = function(orig, name) {
    if (typeof orig !== 'function') return;
    const wrapped = function() {
      if (typeof this === 'bigint') {
        throw new TypeError('Number.prototype.' + name + ' requires that \'this\' be a Number');
      }
      return orig.apply(this, arguments);
    };
    try {
      Object.defineProperty(wrapped, 'name', {
        value: orig.name || name, writable: false, enumerable: false, configurable: true
      });
      Object.defineProperty(wrapped, 'length', {
        value: orig.length, writable: false, enumerable: false, configurable: true
      });
    } catch (_) {}
    return wrapped;
  };
  ['toFixed', 'toPrecision', 'toExponential'].forEach(function(name) {
    const orig = NP[name];
    if (typeof orig !== 'function') return;
    const wrapped = wrapRejectBigInt(orig, name);
    _rejectConstruct(wrapped);
    Object.defineProperty(NP, name, {
      value: wrapped,
      writable: true, enumerable: false, configurable: true
    });
  });
  // Number.prototype.toLocaleString — thisNumberValue + ToString (no Intl).
  // Always install: global currently delegates to Object.prototype.toLocaleString.
  const tls = function toLocaleString() {
    const n = Number.prototype.valueOf.call(this);
    return String(n);
  };
  _rejectConstruct(tls);
  _installMeta(tls, 'toLocaleString', 0);
  Object.defineProperty(NP, 'toLocaleString', {
    value: tls, writable: true, enumerable: false, configurable: true
  });
})();

// ─── NATIVE-ENUMERABLE: URI globals + Symbol.description ────────────────────
(function() {
  const uriNames = ['encodeURI', 'encodeURIComponent', 'decodeURI', 'decodeURIComponent'];
  uriNames.forEach(function(name) {
    const fn = globalThis[name];
    if (typeof fn !== 'function') return;
    Object.defineProperty(globalThis, name, {
      value: fn, writable: true, enumerable: false, configurable: true
    });
  });
  if (typeof Symbol !== 'undefined' && Symbol.prototype) {
    const desc = Object.getOwnPropertyDescriptor(Symbol.prototype, 'description');
    if (desc && desc.enumerable) {
      Object.defineProperty(Symbol.prototype, 'description', {
        get: desc.get, set: desc.set,
        enumerable: false, configurable: desc.configurable === true
      });
    }
  }
})();

// ─── NATIVE-LENGTH-NAME: Promise static + capability fns, Proxy revoker ───────
(function() {
  const P = globalThis.Promise;
  if (typeof P === 'function') {
    ['resolve', 'reject'].forEach(function(name) {
      const fn = P[name];
      if (typeof fn !== 'function') return;
      _rejectConstruct(fn);
      _installMeta(fn, name, 1);
    });
  }
  if (typeof Proxy === 'function' && typeof Proxy.revocable === 'function') {
    _rejectConstruct(Proxy.revocable);
    _installMeta(Proxy.revocable, 'revocable', 2);
    const origRevocable = Proxy.revocable;
    Proxy.revocable = function revocable(target, handler) {
      const out = origRevocable(target, handler);
      if (out && typeof out.revoke === 'function') {
        try {
          Object.defineProperty(out.revoke, 'name', {
            value: '', writable: false, enumerable: false, configurable: true
          });
          Object.defineProperty(out.revoke, 'length', {
            value: 0, writable: false, enumerable: false, configurable: true
          });
        } catch (_) {}
        _rejectConstruct(out.revoke);
      }
      return out;
    };
    _rejectConstruct(Proxy.revocable);
    _installMeta(Proxy.revocable, 'revocable', 2);
  }
  const FP = Function.prototype;
  if (FP) {
    try {
      const lenDesc = Object.getOwnPropertyDescriptor(FP, 'length');
      if (lenDesc && lenDesc.enumerable) {
        Object.defineProperty(FP, 'length', {
          value: lenDesc.value, writable: lenDesc.writable === true,
          enumerable: false, configurable: lenDesc.configurable === true
        });
      }
      const nameDesc = Object.getOwnPropertyDescriptor(FP, 'name');
      if (nameDesc && nameDesc.enumerable) {
        Object.defineProperty(FP, 'name', {
          value: nameDesc.value, writable: nameDesc.writable === true,
          enumerable: false, configurable: nameDesc.configurable === true
        });
      }
    } catch (_) {}
  }
})();

// ─── RegExp.prototype [ @@match / @@matchAll / @@replace / @@search / @@split ]
// (ES §22.2.6.8 / .9 / .11 / .12 / .14)
//
// The native engine ships fast-path versions of these that bypass the spec's
// abstract operations (RegExpExec, SpeciesConstructor, observable coercions,
// GetSubstitution, brand guards). We replace them with faithful JS
// implementations so that: a user-overridden `exec`, a custom `constructor` /
// @@species, an observable `lastIndex` / `flags` / `global` / `unicode`, and all
// the required TypeError guards behave exactly as the spec demands. Each still
// bottoms out in the native `exec` (RegExpBuiltinExec) for the actual matching.
(function() {
  if (typeof RegExp === "undefined" || !RegExp.prototype) return;
  if (typeof Symbol === "undefined") return;
  if (Symbol.match === undefined || Symbol.replace === undefined ||
      Symbol.search === undefined || Symbol.split === undefined) return;

  const RE = RegExp;
  const REP = RegExp.prototype;

  // Native fast paths. The engine's own @@match/@@search/@@replace/@@split run
  // the whole loop in one native call (one PCRE2 scan per match, pieces joined
  // once, no per-match result arrays); they are captured here before the spec
  // versions below replace them, and used only when `pristine(rx)` proves the
  // spec algorithm could not observe a difference: an ordinary RegExp (proto
  // and built-in exec intact, no own properties besides a numeric lastIndex),
  // whose `flags` — read via Get, exactly as the spec does — match the internal
  // flags, and which is not sticky (the natives ignore lastIndex).
  const nativeExec = REP.exec;
  const nativeFlagsGet = Object.getOwnPropertyDescriptor(REP, "flags").get;
  const nativeSymMatch = REP[Symbol.match];
  const nativeSymSearch = REP[Symbol.search];
  const nativeSymReplace = REP[Symbol.replace];
  const nativeSymSplit = REP[Symbol.split];
  const ownKeysOf = Reflect.ownKeys;
  function pristine(rx, flags) {
    if (Object.getPrototypeOf(rx) !== REP || rx.exec !== nativeExec) return false;
    const ks = ownKeysOf(rx);
    if (ks.length !== 1 || ks[0] !== "lastIndex" || typeof rx.lastIndex !== "number") return false;
    const internal = nativeFlagsGet.call(rx);
    if (flags !== null && flags !== internal) return false;
    return internal.indexOf("y") === -1;
  }

  // ── ToLength / ToInteger (local, spec §7.1) ───────────────────────────────
  // ToNumber(Symbol) must throw (§7.1.4); unary + on a Symbol does not reliably
  // throw in this engine, so reject it explicitly before coercing.
  function toIntegerOrInfinity(v) {
    if (typeof v === "symbol") {
      throw new TypeError("Cannot convert a Symbol value to a number");
    }
    const n = +v;
    if (n !== n || n === 0) return 0;
    if (n === Infinity) return Infinity;
    if (n === -Infinity) return -Infinity;
    return (n < 0 ? -1 : 1) * Math.floor(Math.abs(n));
  }
  function toLength(v) {
    const len = toIntegerOrInfinity(v);
    if (len <= 0) return 0;
    return Math.min(len, 9007199254740991); // 2^53 - 1
  }

  // ToString (§7.1.17): unlike the String() constructor, a Symbol argument is a
  // TypeError. `String(sym)` is special-cased NOT to throw, so route the string
  // operand of each @@ method through this instead.
  function toStr(v) {
    if (typeof v === "symbol") {
      throw new TypeError("Cannot convert a Symbol value to a string");
    }
    return String(v);
  }

  // ── RequireRegExp brand: the receiver must be an Object (§ each entry) ─────
  function requireObject(O, method) {
    if (O === null || O === undefined ||
        (typeof O !== "object" && typeof O !== "function")) {
      throw new TypeError("RegExp.prototype[" + method +
                          "] called on a non-object");
    }
    return O;
  }

  // ── AdvanceStringIndex (§22.2.7.3) ────────────────────────────────────────
  function advanceStringIndex(S, index, unicode) {
    if (!unicode) return index + 1;
    const length = S.length;
    if (index + 1 >= length) return index + 1;
    const first = S.charCodeAt(index);
    if (first < 0xD800 || first > 0xDBFF) return index + 1;
    const second = S.charCodeAt(index + 1);
    if (second < 0xDC00 || second > 0xDFFF) return index + 1;
    return index + 2;
  }

  // ── RegExpExec (§22.2.7.1) ────────────────────────────────────────────────
  function regExpExec(R, S) {
    const exec = R.exec;
    if (typeof exec === "function") {
      const result = exec.call(R, S);
      if (result !== null &&
          (typeof result !== "object" && typeof result !== "function")) {
        throw new TypeError("RegExp exec method returned a non-object result");
      }
      return result;
    }
    // Not overridden → the builtin exec (brand-checked by the native impl).
    return REP.exec.call(R, S);
  }

  // ── SpeciesConstructor (§7.3.22) ──────────────────────────────────────────
  function speciesConstructor(O, defaultCtor) {
    const C = O.constructor;
    if (C === undefined) return defaultCtor;
    if (C === null || (typeof C !== "object" && typeof C !== "function")) {
      throw new TypeError("constructor is not an object");
    }
    const S = C[Symbol.species];
    if (S === undefined || S === null) return defaultCtor;
    // IsConstructor(S): probe via Reflect.construct so a non-constructor throws.
    if (typeof S === "function") return S;
    throw new TypeError("@@species is not a constructor");
  }

  // ── @@match (§22.2.6.8) ───────────────────────────────────────────────────
  function symbolMatch(string) {
    "use strict";
    const rx = requireObject(this, "@@match");
    const S = toStr(string);
    // Read the `flags` STRING (§22.2.6.8 step 4) and derive global / fullUnicode
    // from it. Our `flags` getter itself reads Get(rx,"global") / Get(rx,"unicode")
    // per property, so a redefined `global`/`unicode` flows through here and a
    // throwing flag getter propagates — satisfying both the coerce-* and the
    // get-*-err tests at once.
    const flags = String(rx.flags);
    const global = flags.indexOf("g") !== -1;
    if (!global) {
      return regExpExec(rx, S);
    }
    const fullUnicode = flags.indexOf("u") !== -1 || flags.indexOf("v") !== -1;
    rx.lastIndex = 0;
    if (pristine(rx, flags)) return nativeSymMatch.call(rx, S);
    const A = [];
    let n = 0;
    while (true) {
      const result = regExpExec(rx, S);
      if (result === null) {
        return n === 0 ? null : A;
      }
      const matchStr = String(result[0]);
      A[n] = matchStr;
      if (matchStr === "") {
        const thisIndex = toLength(rx.lastIndex);
        rx.lastIndex = advanceStringIndex(S, thisIndex, fullUnicode);
      }
      n++;
    }
  }
  _rejectConstruct(symbolMatch);
  _installMeta(symbolMatch, "[Symbol.match]", 1);

  // ── @@matchAll (§22.2.6.9) + RegExpStringIterator (§22.2.9) ───────────────
  // %RegExpStringIteratorPrototype% inherits from %IteratorPrototype%.
  let iterProto = null;
  try {
    iterProto = Object.getPrototypeOf(
      Object.getPrototypeOf([][Symbol.iterator]()));
  } catch (_) {}
  const reStringIterProto = iterProto ? Object.create(iterProto) : {};

  function makeRegExpStringIterator(R, S, global, fullUnicode) {
    const it = Object.create(reStringIterProto);
    it._iteratingRegExp = R;
    it._iteratedString = S;
    it._global = global;
    it._unicode = fullUnicode;
    it._done = false;
    return it;
  }

  const reStringIterNext = function next() {
    const O = this;
    if (O === null || O === undefined || typeof O !== "object" ||
        !("_iteratingRegExp" in O)) {
      throw new TypeError("not a RegExp String Iterator");
    }
    if (O._done) {
      return { value: undefined, done: true };
    }
    const R = O._iteratingRegExp;
    const S = O._iteratedString;
    const match = regExpExec(R, S);
    if (match === null) {
      O._done = true;
      return { value: undefined, done: true };
    }
    if (!O._global) {
      O._done = true;
      return { value: match, done: false };
    }
    const matchStr = String(match[0]);
    if (matchStr === "") {
      const thisIndex = toLength(R.lastIndex);
      R.lastIndex = advanceStringIndex(S, thisIndex, O._unicode);
    }
    return { value: match, done: false };
  };
  _rejectConstruct(reStringIterNext);
  _installMeta(reStringIterNext, "next", 0);
  Object.defineProperty(reStringIterProto, "next", {
    value: reStringIterNext, writable: true, enumerable: false,
    configurable: true
  });
  // %IteratorPrototype%'s @@iterator (returns `this`) is normally inherited,
  // but the native iterator prototype captured above is re-parented after this
  // stub loads, so pin @@iterator directly to guarantee for-of / spread work.
  if (typeof reStringIterProto[Symbol.iterator] !== "function") {
    const iterSelf = function() { return this; };
    _rejectConstruct(iterSelf);
    _installMeta(iterSelf, "[Symbol.iterator]", 0);
    Object.defineProperty(reStringIterProto, Symbol.iterator, {
      value: iterSelf, writable: true, enumerable: false, configurable: true
    });
  }
  if (Symbol.toStringTag !== undefined) {
    Object.defineProperty(reStringIterProto, Symbol.toStringTag, {
      value: "RegExp String Iterator", writable: false, enumerable: false,
      configurable: true
    });
  }

  function symbolMatchAll(string) {
    "use strict";
    const R = requireObject(this, "@@matchAll");
    const S = toStr(string);
    const C = speciesConstructor(R, RE);
    const flags = String(R.flags);
    const matcher = new C(R, flags);
    matcher.lastIndex = toLength(R.lastIndex);
    const global = flags.indexOf("g") !== -1;
    const fullUnicode = flags.indexOf("u") !== -1 || flags.indexOf("v") !== -1;
    return makeRegExpStringIterator(matcher, S, global, fullUnicode);
  }
  _rejectConstruct(symbolMatchAll);
  _installMeta(symbolMatchAll, "[Symbol.matchAll]", 1);

  // ── @@search (§22.2.6.12) ─────────────────────────────────────────────────
  function symbolSearch(string) {
    "use strict";
    const rx = requireObject(this, "@@search");
    const S = toStr(string);
    if (pristine(rx, null)) return nativeSymSearch.call(rx, S);
    const previousLastIndex = rx.lastIndex;
    if (!sameValue(previousLastIndex, 0)) {
      rx.lastIndex = 0;
    }
    const result = regExpExec(rx, S);
    const currentLastIndex = rx.lastIndex;
    if (!sameValue(currentLastIndex, previousLastIndex)) {
      rx.lastIndex = previousLastIndex;
    }
    if (result === null) return -1;
    return result.index;
  }
  _rejectConstruct(symbolSearch);
  _installMeta(symbolSearch, "[Symbol.search]", 1);

  function sameValue(x, y) {
    if (x === y) {
      // +0 vs -0
      if (x === 0) return (1 / x) === (1 / y);
      return true;
    }
    // NaN
    return x !== x && y !== y;
  }

  // ── GetSubstitution (§22.2.7.6) ───────────────────────────────────────────
  function getSubstitution(matched, str, position, captures, namedCaptures,
                           replacement) {
    const matchLength = matched.length;
    const stringLength = str.length;
    const tailPos = Math.min(Math.max(position + matchLength, 0), stringLength);
    let result = "";
    let i = 0;
    const n = replacement.length;
    while (i < n) {
      const c = replacement.charAt(i);
      if (c === "$" && i + 1 < n) {
        const nc = replacement.charAt(i + 1);
        if (nc === "$") {
          result += "$";
          i += 2;
          continue;
        } else if (nc === "&") {
          result += matched;
          i += 2;
          continue;
        } else if (nc === "`") {
          result += str.slice(0, position);
          i += 2;
          continue;
        } else if (nc === "'") {
          result += str.slice(tailPos);
          i += 2;
          continue;
        } else if (nc >= "0" && nc <= "9") {
          // $n or $nn (1..99). Two-digit form takes precedence when in range.
          const nc2 = i + 2 < n ? replacement.charAt(i + 2) : "";
          let idx = -1;
          let consumed = 0;
          if (nc2 >= "0" && nc2 <= "9") {
            const two = (nc.charCodeAt(0) - 48) * 10 + (nc2.charCodeAt(0) - 48);
            if (two >= 1 && two <= captures.length) {
              idx = two;
              consumed = 3;
            }
          }
          if (idx === -1) {
            const one = nc.charCodeAt(0) - 48;
            if (one >= 1 && one <= captures.length) {
              idx = one;
              consumed = 2;
            }
          }
          if (idx !== -1) {
            const cap = captures[idx - 1];
            if (cap !== undefined) result += cap;
            i += consumed;
            continue;
          }
          // Not a valid group ref → literal "$".
          result += "$";
          i += 1;
          continue;
        } else if (nc === "<") {
          if (namedCaptures === undefined) {
            result += "$";
            i += 1;
            continue;
          }
          // Manual ">" scan by code unit — String.prototype.indexOf mis-counts
          // when the replacement contains astral characters (surrogate pairs),
          // and group names may themselves be astral (e.g. `$<𝒜>`).
          let gtPos = -1;
          for (let j = i + 2; j < n; j++) {
            if (replacement.charAt(j) === ">") { gtPos = j; break; }
          }
          if (gtPos === -1) {
            result += "$";
            i += 1;
            continue;
          }
          const groupName = replacement.slice(i + 2, gtPos);
          const capture = namedCaptures[groupName];
          if (capture !== undefined) {
            result += String(capture);
          }
          i = gtPos + 1;
          continue;
        }
      }
      result += c;
      i += 1;
    }
    return result;
  }

  // ── @@replace (§22.2.6.11) ────────────────────────────────────────────────
  function symbolReplace(string, replaceValue) {
    "use strict";
    const rx = requireObject(this, "@@replace");
    const S = toStr(string);
    const lengthS = S.length;
    const functionalReplace = typeof replaceValue === "function";
    if (!functionalReplace) {
      replaceValue = toStr(replaceValue);
    }
    // §22.2.6.11 reads the `flags` STRING (step 7) and derives global / unicode
    // from it. Our `flags` getter reads Get(rx,"global") / Get(rx,"unicode") per
    // property, so redefined flags flow through and a throwing flag/flags getter
    // propagates (get-flags-err / get-unicode-error / coerce-* all agree).
    const flags = String(rx.flags);
    const global = flags.indexOf("g") !== -1;
    let fullUnicode = false;
    if (global) {
      fullUnicode = flags.indexOf("u") !== -1 || flags.indexOf("v") !== -1;
      rx.lastIndex = 0;
    }
    if (!functionalReplace && pristine(rx, flags)) {
      return nativeSymReplace.call(rx, S, replaceValue);
    }
    const results = [];
    let done = false;
    while (!done) {
      const result = regExpExec(rx, S);
      if (result === null) {
        done = true;
      } else {
        results.push(result);
        if (!global) {
          done = true;
        } else {
          const matchStr = String(result[0]);
          if (matchStr === "") {
            const thisIndex = toLength(rx.lastIndex);
            rx.lastIndex = advanceStringIndex(S, thisIndex, fullUnicode);
          }
        }
      }
    }
    let accumulatedResult = "";
    let nextSourcePosition = 0;
    for (let i = 0; i < results.length; i++) {
      const result = results[i];
      const resultLength = toLength(result.length);
      const nCaptures = Math.max(resultLength - 1, 0);
      const matched = String(result[0]);
      const matchLength = matched.length;
      let position = toIntegerOrInfinity(result.index);
      position = Math.min(Math.max(position, 0), lengthS);
      const captures = [];
      for (let k = 1; k <= nCaptures; k++) {
        let capN = result[k];
        if (capN !== undefined) capN = String(capN);
        captures.push(capN);
      }
      const namedCaptures0 = result.groups;
      let replacement;
      if (functionalReplace) {
        const replacerArgs = [matched];
        for (let k = 0; k < captures.length; k++) replacerArgs.push(captures[k]);
        replacerArgs.push(position, S);
        if (namedCaptures0 !== undefined) replacerArgs.push(namedCaptures0);
        const replValue = replaceValue.apply(undefined, replacerArgs);
        replacement = String(replValue);
      } else {
        let namedCaptures = namedCaptures0;
        if (namedCaptures !== undefined) {
          // §22.2.6.11 step 14.d: ToObject(namedCaptures) — throws on null.
          if (namedCaptures === null) {
            throw new TypeError("Cannot convert null groups to object");
          }
          namedCaptures = Object(namedCaptures);
        }
        replacement = getSubstitution(matched, S, position, captures,
                                      namedCaptures, replaceValue);
      }
      if (position >= nextSourcePosition) {
        accumulatedResult += S.slice(nextSourcePosition, position) + replacement;
        nextSourcePosition = position + matchLength;
      }
    }
    if (nextSourcePosition >= lengthS) return accumulatedResult;
    return accumulatedResult + S.slice(nextSourcePosition);
  }
  _rejectConstruct(symbolReplace);
  _installMeta(symbolReplace, "[Symbol.replace]", 2);

  // ToUint32 (§7.1.6). ToNumber runs first, so a Symbol / uncoercible object
  // throws TypeError — the native `>>> 0` fast path swallows that, so do it here.
  function toUint32(v) {
    const n = Number(v); // ToNumber — throws TypeError on Symbol / BigInt
    if (n !== n || n === Infinity || n === -Infinity || n === 0) return 0;
    let int = (n < 0 ? -1 : 1) * Math.floor(Math.abs(n));
    let mod = int % 4294967296;
    if (mod < 0) mod += 4294967296;
    return mod;
  }

  // ── @@split (§22.2.6.14) ──────────────────────────────────────────────────
  function symbolSplit(string, limit) {
    "use strict";
    const rx = requireObject(this, "@@split");
    const S = toStr(string);
    const C = speciesConstructor(rx, RE);
    const flags = String(rx.flags);
    if (C === RE && pristine(rx, flags)) {
      return nativeSymSplit.call(rx, S, limit === undefined ? 4294967295 : toUint32(limit));
    }
    const unicodeMatching = flags.indexOf("u") !== -1 || flags.indexOf("v") !== -1;
    const newFlags = flags.indexOf("y") !== -1 ? flags : flags + "y";
    const splitter = new C(rx, newFlags);
    const A = [];
    let lengthA = 0;
    const lim = limit === undefined ? 4294967295 : toUint32(limit);
    if (lim === 0) return A;
    const size = S.length;
    if (size === 0) {
      const z = regExpExec(splitter, S);
      if (z !== null) return A;
      A[0] = S;
      return A;
    }
    let p = 0;
    let q = p;
    while (q < size) {
      splitter.lastIndex = q;
      const z = regExpExec(splitter, S);
      if (z === null) {
        q = advanceStringIndex(S, q, unicodeMatching);
      } else {
        let e = toLength(splitter.lastIndex);
        e = Math.min(e, size);
        if (e === p) {
          q = advanceStringIndex(S, q, unicodeMatching);
        } else {
          const T = S.slice(p, q);
          A[lengthA] = T;
          lengthA++;
          if (lengthA === lim) return A;
          const numberOfCaptures = Math.max(toLength(z.length) - 1, 0);
          for (let i = 1; i <= numberOfCaptures; i++) {
            const nextCapture = z[i];
            A[lengthA] = nextCapture;
            lengthA++;
            if (lengthA === lim) return A;
          }
          p = e;
          q = p;
        }
      }
    }
    const T = S.slice(p, size);
    A[lengthA] = T;
    return A;
  }
  _rejectConstruct(symbolSplit);
  _installMeta(symbolSplit, "[Symbol.split]", 2);

  // ── Install (writable:true, enumerable:false, configurable:true) ──────────
  function installSym(sym, fn) {
    Object.defineProperty(REP, sym, {
      value: fn, writable: true, enumerable: false, configurable: true
    });
  }
  installSym(Symbol.match, symbolMatch);
  installSym(Symbol.matchAll, symbolMatchAll);
  installSym(Symbol.search, symbolSearch);
  installSym(Symbol.replace, symbolReplace);
  installSym(Symbol.split, symbolSplit);

  // ── get RegExp.prototype.flags (§22.2.6.4) ────────────────────────────────
  // The spec getter reads each flag via Get(R, name) in a fixed order, so a
  // user override of `global` / `unicode` / … is observed and a throwing getter
  // propagates. The native accessor read [[OriginalFlags]] directly and missed
  // all of that; replace it (RegExp.prototype itself still yields "" because
  // every flag reads back undefined → falsy).
  function flagsGetter() {
    "use strict";
    const R = this;
    if (R === null || R === undefined ||
        (typeof R !== "object" && typeof R !== "function")) {
      throw new TypeError("RegExp.prototype.flags getter called on non-object");
    }
    let result = "";
    if (R.hasIndices) result += "d";
    if (R.global) result += "g";
    if (R.ignoreCase) result += "i";
    if (R.multiline) result += "m";
    if (R.dotAll) result += "s";
    if (R.unicode) result += "u";
    if (R.unicodeSets) result += "v";
    if (R.sticky) result += "y";
    return result;
  }
  _rejectConstruct(flagsGetter);
  _installMeta(flagsGetter, "get flags", 0);
  Object.defineProperty(REP, "flags", {
    get: flagsGetter, enumerable: false, configurable: true
  });

  // ── RegExp.prototype.toString (§22.2.6.15) ────────────────────────────────
  // Reads the (overridable) `source` / `flags` getters and requires an Object
  // receiver — the native fast path returned "(?:)" for a non-RegExp `this`
  // instead of throwing.
  function reToString() {
    "use strict";
    const R = this;
    if (R === null || R === undefined ||
        (typeof R !== "object" && typeof R !== "function")) {
      throw new TypeError("RegExp.prototype.toString called on non-object");
    }
    const pattern = String(R.source);
    const flags = String(R.flags);
    return "/" + pattern + "/" + flags;
  }
  _rejectConstruct(reToString);
  _installMeta(reToString, "toString", 0);
  Object.defineProperty(REP, "toString", {
    value: reToString, writable: true, enumerable: false, configurable: true
  });
})();

// ── Error.captureStackTrace (V8/Node API) ────────────────────────────────────
// Bundled Node libraries call it unconditionally in custom-error constructors
// (`Error.captureStackTrace(this, this.constructor)` — e.g. Vite's vendored
// deps via createErrorType). Semantics here: install `stack` on the target as
// a writable own property from a fresh capture, dropping this shim's own frame.
// (Node also trims frames above `constructorOpt` — approximated by the single
// frame drop; callers only rely on `stack` existing and being a string.)
(function () {
  if (Error.captureStackTrace) { return; }
  function captureStackTrace(targetObject, constructorOpt) {
    var stack = new Error().stack;
    if (typeof stack === "string") {
      var lines = stack.split("\n");
      if (lines.length > 1) { lines.splice(1, 1); }  // drop our own frame
      stack = lines.join("\n");
    } else {
      stack = "";
    }
    Object.defineProperty(targetObject, "stack", {
      value: stack, writable: true, enumerable: false, configurable: true
    });
  }
  _installMeta(captureStackTrace, "captureStackTrace", 2);
  Object.defineProperty(Error, "captureStackTrace", {
    value: captureStackTrace, writable: true, enumerable: false, configurable: true
  });
})();

// ── tty cursor methods on process.stdout / process.stderr ────────────────────
// global.jac builds these as writable streams with `isTTY` but WITHOUT Node's
// tty.WriteStream cursor API (clearLine/cursorTo/moveCursor/...). Vite's build
// spinner calls process.stdout.clearLine(0)+cursorTo(0) when isTTY, which threw
// "(object).clearLine is not a function" and aborted `vite build`. Attach the
// methods here (boot-time), emitting the same ANSI the Node impl writes.
(function () {
  var proc = typeof globalThis !== 'undefined' && globalThis.process;
  if (!proc) return;
  function augment(stream) {
    if (!stream || typeof stream.write !== 'function') return;
    if (typeof stream.clearLine === 'function') return;  // already present
    // dir: -1 = to start, 1 = to end, 0 = whole line (Node readline.clearLine)
    stream.clearLine = function (dir, cb) {
      if (this.isTTY) {
        var seq = dir < 0 ? '\x1b[1K' : (dir > 0 ? '\x1b[0K' : '\x1b[2K');
        this.write(seq);
      }
      if (typeof cb === 'function') cb();
      return true;
    };
    stream.cursorTo = function (x, y, cb) {
      if (typeof y === 'function') { cb = y; y = undefined; }
      if (this.isTTY) {
        if (typeof y === 'number') this.write('\x1b[' + (y + 1) + ';' + (x + 1) + 'H');
        else this.write('\x1b[' + (x + 1) + 'G');
      }
      if (typeof cb === 'function') cb();
      return true;
    };
    stream.moveCursor = function (dx, dy, cb) {
      if (this.isTTY) {
        if (dx < 0) this.write('\x1b[' + (-dx) + 'D'); else if (dx > 0) this.write('\x1b[' + dx + 'C');
        if (dy < 0) this.write('\x1b[' + (-dy) + 'A'); else if (dy > 0) this.write('\x1b[' + dy + 'B');
      }
      if (typeof cb === 'function') cb();
      return true;
    };
    if (typeof stream.getColorDepth !== 'function') {
      stream.getColorDepth = function () { return this.isTTY ? 8 : 1; };
    }
    if (typeof stream.hasColors !== 'function') {
      stream.hasColors = function (count) { return this.isTTY && (count === undefined || count <= 256); };
    }
    if (typeof stream.getWindowSize !== 'function') {
      stream.getWindowSize = function () { return [this.columns || 80, this.rows || 24]; };
    }
    if (this.isTTY && stream.columns === undefined) stream.columns = 80;
    if (this.isTTY && stream.rows === undefined) stream.rows = 24;
  }
  augment(proc.stdout);
  augment(proc.stderr);
})();

// ── Listener removal on process.stdin / stdout / stderr ─────────────────────
// These are native stream objects (streams.jac) whose only listener API is a
// native `on` that appends to native lists — no once/off/removeListener. Vite's
// dev server calls process.stdin.off("end", …) when it closes or restarts,
// which threw "(object).off is not a function" and aborted the close. Route
// listeners through a JS table instead: the native `on` is called ONCE per
// event name with a dispatcher (so its side effects — e.g. stdin starting to
// read on 'data' — are unchanged), and the EventEmitter listener methods
// operate on the table.
(function () {
  var proc = typeof globalThis !== 'undefined' && globalThis.process;
  if (!proc) return;
  function augment(stream) {
    if (!stream || typeof stream.on !== 'function') return;
    if (typeof stream.off === 'function' && typeof stream.removeListener === 'function') return;
    var nativeOn = stream.on;
    var table = Object.create(null);   // event -> [{ fn, once }]
    function add(ev, fn, once, prepend) {
      if (typeof fn !== 'function') return stream;
      if (!table[ev]) {
        table[ev] = [];
        nativeOn.call(stream, ev, function () {
          var list = table[ev];
          if (!list || list.length === 0) return;
          var snapshot = list.slice();
          for (var i = 0; i < snapshot.length; i++) {
            var e = snapshot[i];
            if (e.once) remove(ev, e.fn);
            e.fn.apply(stream, arguments);
          }
        });
      }
      var entry = { fn: fn, once: !!once };
      if (prepend) table[ev].unshift(entry); else table[ev].push(entry);
      return stream;
    }
    function remove(ev, fn) {
      var list = table[ev];
      if (!list) return stream;
      for (var i = list.length - 1; i >= 0; i--) {
        if (list[i].fn === fn || list[i].fn.listener === fn) { list.splice(i, 1); break; }
      }
      return stream;
    }
    stream.on = stream.addListener = function (ev, fn) { return add(ev, fn, false, false); };
    stream.once = function (ev, fn) { return add(ev, fn, true, false); };
    stream.prependListener = function (ev, fn) { return add(ev, fn, false, true); };
    stream.prependOnceListener = function (ev, fn) { return add(ev, fn, true, true); };
    stream.off = stream.removeListener = function (ev, fn) { return remove(ev, fn); };
    stream.removeAllListeners = function (ev) {
      if (ev === undefined) { for (var k in table) table[k].length = 0; }
      else if (table[ev]) { table[ev].length = 0; }
      return stream;
    };
    stream.listenerCount = function (ev) { return table[ev] ? table[ev].length : 0; };
    stream.listeners = function (ev) {
      return table[ev] ? table[ev].map(function (e) { return e.fn; }) : [];
    };
  }
  augment(proc.stdin);
  augment(proc.stdout);
  augment(proc.stderr);
})();

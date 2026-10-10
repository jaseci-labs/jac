/**
 * webassembly.js — WebAssembly runtime for js_engine (native Wasmtime)
 *
 * This shim is a thin JS surface over globalThis.__wasm, which delegates every
 * parse / validate / compile / instantiate / call to the vendored Wasmtime C
 * API (engine/src/ffi/wasmtime.jac → dispatch.jac → runtime/global.jac). The
 * previous hand-written binary-format parser + opcode interpreter is GONE —
 * WASM now runs as real (JIT-compiled) machine code.
 *
 * Handles: __wasm returns opaque small-int handles for module / instance /
 * function / memory / table / global. JS objects hold those handles and marshal
 * args across the boundary. WASM bytes cross via a native buffer (__buf.alloc).
 *
 * Scope (docs/wasm.md Phases 2 + 3):
 *   - validate / compile / new Module / Module.imports|exports
 *   - instantiate / new Instance / instance.exports (fns, Memory, Table, Global)
 *   - WebAssembly.Memory({initial,maximum}) with live .buffer + .grow(n)
 *   - WebAssembly.Table({initial,maximum,element}) get/set/grow/length
 *   - WebAssembly.Global({value,mutable}, v) read + write .value (+ i64 BigInt)
 *   - JS→WASM imported callbacks (importObject function/memory/table/global)
 *   - i64 params/results/globals ↔ BigInt
 *   - trap / error → distinct CompileError / LinkError / RuntimeError
 */
'use strict';

(function() {
    if (typeof globalThis.WebAssembly !== 'undefined' &&
        globalThis.WebAssembly.__jacIsReal) {
        return;
    }

    var __wasm = globalThis.__wasm;
    var __buf = globalThis.__buf;

    function CompileError(msg) {
        var e = new Error(msg || 'WebAssembly CompileError');
        e.name = 'CompileError';
        Object.setPrototypeOf(e, CompileError.prototype);
        return e;
    }
    CompileError.prototype = Object.create(Error.prototype);
    CompileError.prototype.constructor = CompileError;

    function LinkError(msg) {
        var e = new Error(msg || 'WebAssembly LinkError');
        e.name = 'LinkError';
        Object.setPrototypeOf(e, LinkError.prototype);
        return e;
    }
    LinkError.prototype = Object.create(Error.prototype);
    LinkError.prototype.constructor = LinkError;

    function RuntimeError(msg) {
        var e = new Error(msg || 'WebAssembly RuntimeError');
        e.name = 'RuntimeError';
        Object.setPrototypeOf(e, RuntimeError.prototype);
        return e;
    }
    RuntimeError.prototype = Object.create(Error.prototype);
    RuntimeError.prototype.constructor = RuntimeError;

    // Extern kinds as reported by __wasm.exportKind / moduleImports.kind.
    var KIND_FUNC = 0, KIND_GLOBAL = 1, KIND_TABLE = 2, KIND_MEMORY = 3;
    // Wasmtime externkind order is func=0,global=1,table=2,memory=3; the public
    // WebAssembly.Module.imports/exports "kind" strings follow that mapping.
    var EXTERN_KIND_NAMES = ['function', 'global', 'table', 'memory'];

    // Flat wasmtime valkinds (must match ffi/wasmtime.jac WASMTIME_*).
    var VAL_I32 = 0, VAL_I64 = 1, VAL_F32 = 2, VAL_F64 = 3;
    var VAL_FUNCREF = 5, VAL_EXTERNREF = 6;

    // Error classes (must match ffi/wasmtime.jac WASM_ERRCLASS_*).
    var ERR_NONE = 0, ERR_COMPILE = 1, ERR_LINK = 2, ERR_RUNTIME = 3;

    function lastWasmError() {
        try { return __wasm.lastError() || ''; } catch (e) { return ''; }
    }
    function lastWasmErrorClass() {
        try { return __wasm.lastErrorClass() | 0; } catch (e) { return ERR_NONE; }
    }
    // Throw the WebAssembly error class matching the last recorded error class.
    // `fallbackCtor` is used when the engine didn't classify (ERR_NONE).
    function throwWasmError(prefix, fallbackCtor) {
        var msg = prefix + (lastWasmError() || 'failed');
        var cls = lastWasmErrorClass();
        if (cls === ERR_COMPILE) throw new CompileError(msg);
        if (cls === ERR_LINK) throw new LinkError(msg);
        if (cls === ERR_RUNTIME) throw new RuntimeError(msg);
        throw new (fallbackCtor || RuntimeError)(msg);
    }

    function valKindFromString(s) {
        if (s === 'i32') return VAL_I32;
        if (s === 'i64') return VAL_I64;
        if (s === 'f32') return VAL_F32;
        if (s === 'f64') return VAL_F64;
        if (s === 'anyfunc' || s === 'funcref') return VAL_FUNCREF;
        if (s === 'externref') return VAL_EXTERNREF;
        throw new TypeError("Unknown value type '" + s + "'");
    }

    function toBytes(src) {
        if (src == null) throw new TypeError('Invalid BufferSource');
        if (src instanceof ArrayBuffer) return new Uint8Array(src);
        if (ArrayBuffer.isView && ArrayBuffer.isView(src)) {
            return new Uint8Array(src.buffer, src.byteOffset, src.byteLength);
        }
        if (typeof src === 'object' && typeof src.length === 'number') {
            var out = new Uint8Array(src.length);
            for (var i = 0; i < src.length; i++) out[i] = src[i] & 0xff;
            return out;
        }
        throw new TypeError('Invalid BufferSource');
    }

    // Copy JS bytes into a freshly-allocated native buffer. Returns {ptr,len};
    // caller MUST __buf.free(ptr).
    function bytesToNative(bytes) {
        var n = bytes.length;
        var ptr = __buf.alloc(n > 0 ? n : 1);
        for (var i = 0; i < n; i++) __buf.setByte(ptr, i, bytes[i] & 0xff);
        return { ptr: ptr, len: n };
    }

    // ── WebAssembly.Memory ────────────────────────────────────────────────────
    function _wrapExternalBuffer(ptr, len) {
        var nb = globalThis.__napiBinary;
        if (!nb || typeof nb.wrapExternal !== 'function') {
            throw new RuntimeError('external ArrayBuffer support unavailable');
        }
        return nb.wrapExternal(ptr, len);
    }

    function MemoryObject(descriptor) {
        if (!(this instanceof MemoryObject)) return new MemoryObject(descriptor);
        if (descriptor && descriptor.__jacMemHandle !== undefined) {
            this._memH = descriptor.__jacMemHandle;
        } else {
            if (typeof descriptor !== 'object' || descriptor === null) {
                throw new TypeError('WebAssembly.Memory descriptor required');
            }
            var initial = descriptor.initial >>> 0;
            var maximum = (descriptor.maximum === undefined) ? -1 : (descriptor.maximum >>> 0);
            var memH = __wasm.memCreate(initial, maximum);
            if (!memH) {
                throw new RangeError('WebAssembly.Memory: ' + (lastWasmError() || 'allocation failed'));
            }
            this._memH = memH;
        }
        this._buffer = _wrapExternalBuffer(__wasm.memPtr(this._memH), __wasm.memSize(this._memH));
    }
    Object.defineProperty(MemoryObject.prototype, 'buffer', {
        get: function() { return this._buffer; },
        enumerable: true, configurable: true
    });
    Object.defineProperty(MemoryObject.prototype, Symbol.toStringTag, {
        value: 'WebAssembly.Memory', configurable: true
    });
    MemoryObject.prototype.grow = function(delta) {
        var d = delta >>> 0;
        var prevPages = __wasm.memGrow(this._memH, d);
        if (prevPages < 0) {
            throw new RangeError('WebAssembly.Memory.grow: ' + (lastWasmError() || 'failed'));
        }
        var nb = globalThis.__napiBinary;
        var oldBuf = this._buffer;
        if (oldBuf && nb && typeof nb.detach === 'function') {
            try { nb.detach(oldBuf); } catch (e) { /* best-effort */ }
        }
        this._buffer = _wrapExternalBuffer(__wasm.memPtr(this._memH), __wasm.memSize(this._memH));
        return prevPages;
    };

    // ── WebAssembly.Table ─────────────────────────────────────────────────────
    // Backed by a native table handle (funcref/externref). get() returns the
    // stored ref: a callable JS function for a non-null funcref, null for empty,
    // or an opaque marker for a non-null externref (host externref values are not
    // yet fully round-tripped). set() accepts null or a WASM exported function.
    function TableObject(descriptor, value) {
        if (!(this instanceof TableObject)) return new TableObject(descriptor, value);
        if (descriptor && descriptor.__jacTableHandle !== undefined) {
            this._tableH = descriptor.__jacTableHandle;
            this._element = descriptor.__jacElement || 'anyfunc';
            return;
        }
        if (typeof descriptor !== 'object' || descriptor === null) {
            throw new TypeError('WebAssembly.Table descriptor required');
        }
        var element = descriptor.element;
        if (element !== 'anyfunc' && element !== 'funcref' && element !== 'externref') {
            throw new TypeError("WebAssembly.Table element must be 'anyfunc' or 'externref'");
        }
        var elemKind = (element === 'externref') ? VAL_EXTERNREF : VAL_FUNCREF;
        var initial = descriptor.initial >>> 0;
        var maximum = (descriptor.maximum === undefined) ? -1 : (descriptor.maximum >>> 0);
        var tableH = __wasm.tableCreate(elemKind, initial, maximum);
        if (!tableH) {
            throwWasmError('WebAssembly.Table: ', RangeError);
        }
        this._tableH = tableH;
        this._element = element;
        // Fill with the provided init value (only null is representable now).
        if (value !== undefined && value !== null) {
            for (var i = 0; i < initial; i++) this.set(i, value);
        }
    }
    Object.defineProperty(TableObject.prototype, 'length', {
        get: function() { return __wasm.tableSize(this._tableH); },
        enumerable: true, configurable: true
    });
    Object.defineProperty(TableObject.prototype, Symbol.toStringTag, {
        value: 'WebAssembly.Table', configurable: true
    });
    TableObject.prototype.get = function(index) {
        var idx = index >>> 0;
        var k = __wasm.tableGetKind(this._tableH, idx);
        if (k < 0) throw new RangeError('WebAssembly.Table.get: index out of bounds');
        if (k === 0) return null;
        if (k === 2) {
            // Non-null externref — host value round-trip not yet supported.
            return {}; // opaque placeholder object (identity not preserved)
        }
        // Non-null funcref. js_engine does not yet reconstruct a JS callable from a
        // stored funcref (would need a bound export wrapper); return a thunk that
        // reports the slot is occupied but not directly callable across the FFI.
        var tableH = this._tableH;
        var fn = function() {
            throw new RuntimeError('calling a WebAssembly.Table funcref element directly is not supported');
        };
        fn.__jacWasmFuncrefSlot = idx;
        return fn;
    };
    TableObject.prototype.set = function(index, value) {
        var idx = index >>> 0;
        var ok;
        if (value === null || value === undefined) {
            ok = __wasm.tableSetNull(this._tableH, idx);
        } else if (typeof value === 'function' && value.__jacWasmFuncH !== undefined) {
            ok = __wasm.tableSetFunc(this._tableH, idx, value.__jacWasmFuncH);
        } else if (typeof value === 'function') {
            // A non-WASM JS function cannot be stored as a funcref without a host
            // func wrapper; matching Node, only null / WASM exported funcs work.
            throw new TypeError('WebAssembly.Table.set: only WASM exported functions or null are supported as funcref values');
        } else {
            throw new TypeError('WebAssembly.Table.set: invalid value');
        }
        if (!ok) throwWasmError('WebAssembly.Table.set: ', RangeError);
    };
    TableObject.prototype.grow = function(delta, value) {
        var d = delta >>> 0;
        var prev = __wasm.tableGrow(this._tableH, d);
        if (prev < 0) throwWasmError('WebAssembly.Table.grow: ', RangeError);
        if (value !== undefined && value !== null) {
            for (var i = prev; i < prev + d; i++) this.set(i, value);
        }
        return prev;
    };

    // ── WebAssembly.Global ─────────────────────────────────────────────────────
    // Backed by a native global handle. Supports read + write .value, the mutable
    // check, and i64 ↔ BigInt. Exported globals are wrapped with their declared
    // mutability recorded natively.
    function GlobalObject(descriptor, value) {
        if (!(this instanceof GlobalObject)) return new GlobalObject(descriptor, value);
        if (descriptor && descriptor.__jacGlobalHandle !== undefined) {
            this._globalH = descriptor.__jacGlobalHandle;
            this._mutable = __wasm.globalIsMutable(this._globalH);
            return;
        }
        if (typeof descriptor !== 'object' || descriptor === null) {
            throw new TypeError('WebAssembly.Global descriptor required');
        }
        var kind = valKindFromString(descriptor.value);
        var mutable = !!descriptor.mutable;
        var ival = 0, dval = 0;
        if (kind === VAL_I64) {
            ival = (typeof value === 'bigint') ? value :
                   (value === undefined ? 0n : BigInt(Math.trunc(Number(value) || 0)));
        } else if (kind === VAL_F32 || kind === VAL_F64) {
            dval = (value === undefined) ? 0 : Number(value);
        } else {
            ival = (value === undefined) ? 0 : (Number(value) | 0);
        }
        var globalH = __wasm.globalCreate(kind, mutable, ival, dval);
        if (!globalH) throwWasmError('WebAssembly.Global: ', RangeError);
        this._globalH = globalH;
        this._mutable = mutable;
    }
    Object.defineProperty(GlobalObject.prototype, 'value', {
        get: function() {
            if (this._globalH === undefined) return undefined;
            return __wasm.globalGet(this._globalH);
        },
        set: function(v) {
            if (this._globalH === undefined) return;
            if (!this._mutable) {
                throw new TypeError('WebAssembly.Global.value: cannot set value of an immutable global');
            }
            var kind = __wasm.globalKind(this._globalH);
            var ival = 0, dval = 0;
            if (kind === VAL_I64) {
                ival = (typeof v === 'bigint') ? v : BigInt(Math.trunc(Number(v) || 0));
            } else if (kind === VAL_F32 || kind === VAL_F64) {
                dval = Number(v);
            } else {
                ival = Number(v) | 0;
            }
            if (!__wasm.globalSet(this._globalH, ival, dval)) {
                throwWasmError('WebAssembly.Global.value: ', TypeError);
            }
        },
        enumerable: true, configurable: true
    });
    GlobalObject.prototype.valueOf = function() { return this.value; };
    Object.defineProperty(GlobalObject.prototype, Symbol.toStringTag, {
        value: 'WebAssembly.Global', configurable: true
    });

    // ── WebAssembly.Module ────────────────────────────────────────────────────
    var AbstractModuleSourceProto = Object.create(Object.prototype);
    Object.defineProperty(AbstractModuleSourceProto, Symbol.toStringTag, {
        configurable: true,
        get: function() {
            if (this && this._wasmBrand) return this._wasmBrand;
            return '';
        }
    });

    function _compileToHandle(bytes) {
        var nb = bytesToNative(bytes);
        var modH;
        try {
            modH = __wasm.compile(nb.ptr, nb.len);
        } finally {
            __buf.free(nb.ptr);
        }
        if (!modH) {
            throwWasmError('WebAssembly.compile: ', CompileError);
        }
        return modH;
    }

    function ModuleObject(bytes) {
        if (!(this instanceof ModuleObject)) {
            return new ModuleObject(bytes);
        }
        if (bytes && bytes.__jacModHandle !== undefined) {
            this._modH = bytes.__jacModHandle;
        } else {
            this._modH = _compileToHandle(toBytes(bytes));
        }
        this._wasmBrand = 'WebAssembly.Module';
    }
    ModuleObject.prototype = Object.create(AbstractModuleSourceProto);
    ModuleObject.prototype.constructor = ModuleObject;
    Object.defineProperty(ModuleObject.prototype, Symbol.toStringTag, {
        value: 'WebAssembly.Module', configurable: true
    });
    ModuleObject.imports = function(mod) {
        if (!(mod instanceof ModuleObject)) throw new TypeError('Module required');
        var raw = __wasm.moduleImports(mod._modH);
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            out.push({
                module: raw[i].module,
                name: raw[i].name,
                kind: EXTERN_KIND_NAMES[raw[i].kind] || 'function'
            });
        }
        return out;
    };
    ModuleObject.exports = function(mod) {
        if (!(mod instanceof ModuleObject)) throw new TypeError('Module required');
        var raw = __wasm.moduleExports(mod._modH);
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            out.push({
                name: raw[i].name,
                kind: EXTERN_KIND_NAMES[raw[i].kind] || 'function'
            });
        }
        return out;
    };
    ModuleObject.customSections = function() { return []; };

    // ── WebAssembly.Instance ──────────────────────────────────────────────────
    function _makeExportFn(funcH, name) {
        var f = function() {
            var args = [funcH];
            for (var i = 0; i < arguments.length; i++) args.push(arguments[i]);
            // __wasm.invoke(funcHandle, ...args) → result | [results] | undefined.
            // On trap/error, invoke returns undefined; surface the classified error.
            var res = __wasm.invoke.apply(__wasm, args);
            // Distinguish a genuine undefined result (void func) from a trap: check
            // the error class after the call — a runtime trap sets it.
            if (res === undefined) {
                var cls = lastWasmErrorClass();
                var msg = lastWasmError();
                if (cls === ERR_RUNTIME && msg) throw new RuntimeError(msg);
            }
            return res;
        };
        f.__jacWasmFuncH = funcH;
        try { Object.defineProperty(f, 'name', { value: name, configurable: true }); } catch (e) {}
        return f;
    }

    function _buildExports(instH) {
        var exportsObj = Object.create(null);
        var count = __wasm.exportCount(instH);
        for (var i = 0; i < count; i++) {
            var name = __wasm.exportName(instH, i);
            var kind = __wasm.exportKind(instH, i);
            if (kind === KIND_FUNC) {
                var funcH = __wasm.bindFunc(instH, name);
                if (!funcH) {
                    throw new LinkError('failed to bind export "' + name + '": ' + (lastWasmError() || ''));
                }
                exportsObj[name] = _makeExportFn(funcH, name);
            } else if (kind === KIND_MEMORY) {
                var memH = __wasm.exportMemory(instH, name);
                if (!memH) {
                    throw new LinkError('failed to bind memory export "' + name + '": ' + (lastWasmError() || ''));
                }
                exportsObj[name] = new MemoryObject({ __jacMemHandle: memH });
            } else if (kind === KIND_GLOBAL) {
                var globalH = __wasm.exportGlobal(instH, name);
                if (!globalH) {
                    throw new LinkError('failed to bind global export "' + name + '": ' + (lastWasmError() || ''));
                }
                exportsObj[name] = new GlobalObject({ __jacGlobalHandle: globalH });
            } else if (kind === KIND_TABLE) {
                var tableH = __wasm.exportTable(instH, name);
                if (!tableH) {
                    throw new LinkError('failed to bind table export "' + name + '": ' + (lastWasmError() || ''));
                }
                exportsObj[name] = new TableObject({ __jacTableHandle: tableH });
            } else {
                exportsObj[name] = undefined;
            }
        }
        return exportsObj;
    }

    function _instantiateModule(mod, importObject) {
        var ims = ModuleObject.imports(mod);
        if (ims.length === 0) {
            // Fast path: no imports.
            var instH0 = __wasm.instantiate(mod._modH);
            if (!instH0) {
                throwWasmError('WebAssembly.instantiate: ', LinkError);
            }
            return instH0;
        }
        // Imports path: open a store, scan imports, wire each host value, then
        // instantiate with the imports array. importsBegin returns the import
        // count (>=0) or -1.
        // Per spec (ReadImports): a module with imports requires an importObject
        // that is an Object; otherwise TypeError (Node throws TypeError here).
        if (typeof importObject !== 'object' || importObject === null) {
            throw new TypeError('WebAssembly.instantiate(): Argument 1 must be an object');
        }
        var n = __wasm.importsBegin(mod._modH);
        if (n < 0) {
            throwWasmError('WebAssembly.instantiate: ', LinkError);
        }
        for (var i = 0; i < ims.length; i++) {
            var im = ims[i];
            var modNs = importObject[im.module];
            // Missing / non-object module namespace → TypeError (matches Node).
            if (typeof modNs !== 'object' || modNs === null) {
                throw new TypeError('WebAssembly.instantiate(): Import #' + i + ' module="' + im.module + '" error: module is not an object or function');
            }
            var val = modNs[im.name];
            if (im.kind === 'function') {
                if (typeof val !== 'function') {
                    throw new LinkError('WebAssembly.instantiate(): Import #' + i + ' module="' + im.module + '" function="' + im.name + '" error: function import requires a callable');
                }
                if (!__wasm.importsAddFunc(i, val)) {
                    throwWasmError('WebAssembly.instantiate: ', LinkError);
                }
            } else if (im.kind === 'memory') {
                if (!(val instanceof MemoryObject)) {
                    throw new LinkError('WebAssembly.instantiate: import "' + im.name + '" must be a WebAssembly.Memory');
                }
                if (!__wasm.importsAddMemory(i, val._memH)) {
                    throwWasmError('WebAssembly.instantiate: ', LinkError);
                }
            } else if (im.kind === 'global') {
                if (!(val instanceof GlobalObject)) {
                    throw new LinkError('WebAssembly.instantiate: import "' + im.name + '" must be a WebAssembly.Global');
                }
                if (!__wasm.importsAddGlobal(i, val._globalH)) {
                    throwWasmError('WebAssembly.instantiate: ', LinkError);
                }
            } else if (im.kind === 'table') {
                if (!(val instanceof TableObject)) {
                    throw new LinkError('WebAssembly.instantiate: import "' + im.name + '" must be a WebAssembly.Table');
                }
                if (!__wasm.importsAddTable(i, val._tableH)) {
                    throwWasmError('WebAssembly.instantiate: ', LinkError);
                }
            }
        }
        var instH = __wasm.instantiateImports(mod._modH);
        if (!instH) {
            throwWasmError('WebAssembly.instantiate: ', LinkError);
        }
        return instH;
    }

    function InstanceObject(module, importObject) {
        if (!(this instanceof InstanceObject)) {
            return new InstanceObject(module, importObject);
        }
        var mod = module instanceof ModuleObject ? module : new ModuleObject(module);
        var instH = _instantiateModule(mod, importObject);
        this._instH = instH;
        this._module = mod;
        this.exports = _buildExports(instH);
    }
    Object.defineProperty(InstanceObject.prototype, Symbol.toStringTag, {
        value: 'WebAssembly.Instance', configurable: true
    });

    // ── Top-level API ─────────────────────────────────────────────────────────
    function validate(bytes) {
        var b;
        try { b = toBytes(bytes); } catch (e) { return false; }
        var nb = bytesToNative(b);
        try {
            return !!__wasm.validate(nb.ptr, nb.len);
        } finally {
            __buf.free(nb.ptr);
        }
    }

    function compileSync(bytes) {
        return new ModuleObject(toBytes(bytes));
    }

    function instantiateSync(source, importObject) {
        if (source instanceof ModuleObject) {
            var inst = new InstanceObject(source, importObject);
            return { instance: inst, module: source };
        }
        var mod = compileSync(source);
        var inst2 = new InstanceObject(mod, importObject);
        return { instance: inst2, module: mod };
    }

    var WebAssembly = {
        __jacIsReal: true,
        compile: function(bytes) {
            try { return Promise.resolve(compileSync(bytes)); }
            catch (e) { return Promise.reject(e); }
        },
        instantiate: function(source, importObject) {
            try {
                if (source instanceof ModuleObject) {
                    return Promise.resolve(new InstanceObject(source, importObject));
                }
                return Promise.resolve(instantiateSync(source, importObject));
            } catch (e) { return Promise.reject(e); }
        },
        compileStreaming: function() {
            return Promise.reject(new TypeError('compileStreaming not supported'));
        },
        instantiateStreaming: function() {
            return Promise.reject(new TypeError('instantiateStreaming not supported'));
        },
        validate: validate,
        compileSync: compileSync,
        instantiateSync: instantiateSync,
        Module: ModuleObject,
        Instance: InstanceObject,
        Memory: MemoryObject,
        Table: TableObject,
        Global: GlobalObject,
        Tag: function Tag() { throw new Error('WebAssembly.Tag not supported'); },
        Exception: function Exception() { throw new Error('WebAssembly.Exception not supported'); },
        CompileError: CompileError,
        LinkError: LinkError,
        RuntimeError: RuntimeError
    };

    globalThis.WebAssembly = WebAssembly;

    /** Engine helper: compile+instantiate, return exports object. */
    globalThis.__jacLoadWasmEsm = function(bytes, importObject) {
        var result = instantiateSync(bytes, importObject);
        return result.instance.exports;
    };

    /** Binary-safe file read (readFileSync string path truncates at NUL). */
    function readFileBytes(filePath) {
        var fs = require('fs');
        var st = fs.statSync(filePath);
        var size = st.size | 0;
        var fd = fs.openSync(filePath, 'r');
        try {
            var buf = Buffer.alloc(size);
            var n = fs.readSync(fd, buf, 0, size, 0);
            if (n < size) return buf.subarray(0, n);
            return buf;
        } finally {
            fs.closeSync(fd);
        }
    }

    /** Load a .wasm file as an ESM namespace (Node --experimental-wasm-modules). */
    globalThis.__jacLoadWasmEsmFile = function(wasmPath, sourcePhaseOnly) {
        var bytes = readFileBytes(wasmPath);
        var mod = compileSync(bytes);
        if (sourcePhaseOnly) {
            return mod;
        }
        var importObject = Object.create(null);
        var result = instantiateSync(mod, importObject);
        var exportsObj = result.instance.exports;
        var ns = Object.create(null);
        var names = Object.keys(exportsObj);
        for (var ei = 0; ei < names.length; ei++) {
            var en = names[ei];
            ns[en] = exportsObj[en];
        }
        Object.defineProperty(ns, Symbol.toStringTag, {
            value: 'Module', configurable: true
        });
        return ns;
    };

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = WebAssembly;
    }
})();

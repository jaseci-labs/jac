glob JAC_RUNTIME_JS_OBJECT: str = r"""{
  int: {
    bit_length(n) {
      if (n === 0) return 0;
      return Math.floor(Math.log2(Math.abs(n))) + 1;
    },
    bit_count(n) {
      let x = Math.abs(n);
      let count = 0;
      while (x) { count += x & 1; x >>= 1; }
      return count;
    },
    to_bytes(n, length, byteorder) {
      const bytes = [];
      let val = n < 0 ? (1 << (length * 8)) + n : n;
      for (let i = 0; i < length; i++) {
        bytes.push(val & 0xff);
        val >>= 8;
      }
      if (byteorder === "big") bytes.reverse();
      return bytes;
    },
    from_bytes(bytes, byteorder) {
      const b = byteorder === "big" ? bytes : [...bytes].reverse();
      let result = 0;
      for (const byte of b) result = (result << 8) | byte;
      return result;
    },
    mod(a, b) { return ((a % b) + b) % b; }
  },

  float: {
    as_integer_ratio(f) {
      if (!isFinite(f)) throw new _jac.exc.ValueError("cannot convert " + f + " to integer ratio");
      if (f === 0) return [0, 1];
      let num = f, den = 1;
      while (num !== Math.floor(num)) { num *= 2; den *= 2; }
      const g = _jac.float._gcd(Math.abs(num), den);
      return [num / g, den / g];
    },
    _gcd(a, b) { while (b) { [a, b] = [b, a % b]; } return a; },
    hex(f) {
      return f.toString(16);
    },
    fromhex(s) {
      return parseFloat(s);
    },
    mod(a, b) { return ((a % b) + b) % b; }
  },

  complex: {
    conjugate(c) { return {re: c.re, im: -c.im}; },
    add(a, b) { return {re: a.re + b.re, im: a.im + b.im}; },
    sub(a, b) { return {re: a.re - b.re, im: a.im - b.im}; },
    mul(a, b) { return {re: a.re * b.re - a.im * b.im, im: a.re * b.im + a.im * b.re}; },
    truediv(a, b) {
      const d = b.re * b.re + b.im * b.im;
      return {re: (a.re * b.re + a.im * b.im) / d, im: (a.im * b.re - a.re * b.im) / d};
    },
    pow(a, b) {
      if (typeof b === "number") b = {re: b, im: 0};
      if (typeof a === "number") a = {re: a, im: 0};
      if (b.im === 0 && Number.isInteger(b.re)) {
        let result = {re: 1, im: 0};
        for (let i = 0; i < Math.abs(b.re); i++) result = _jac.complex.mul(result, a);
        return b.re < 0 ? _jac.complex.truediv({re: 1, im: 0}, result) : result;
      }
      const r = Math.sqrt(a.re * a.re + a.im * a.im);
      const theta = Math.atan2(a.im, a.re);
      const lnr = Math.log(r);
      const newR = Math.exp(lnr * b.re - theta * b.im);
      const newTheta = lnr * b.im + theta * b.re;
      return {re: newR * Math.cos(newTheta), im: newR * Math.sin(newTheta)};
    },
    eq(a, b) {
      if (typeof b === "number") b = {re: b, im: 0};
      if (typeof a === "number") a = {re: a, im: 0};
      return a.re === b.re && a.im === b.im;
    },
    neg(a) { return {re: -a.re, im: -a.im}; },
    pos(a) { return {re: +a.re, im: +a.im}; }
  },

  str: {
    capitalize(s) {
      if (s.length === 0) return s;
      return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
    },
    title(s) {
      return s.replace(/\b\w/g, c => c.toUpperCase());
    },
    swapcase(s) {
      return [...s].map(c => c === c.toUpperCase() ? c.toLowerCase() : c.toUpperCase()).join("");
    },
    count(s, sub, start, end) {
      const t = s.slice(start || 0, end);
      if (sub === "") return t.length + 1;
      let count = 0, pos = 0;
      while ((pos = t.indexOf(sub, pos)) !== -1) { count++; pos += sub.length; }
      return count;
    },
    find(s, sub, start, end) {
      const t = s.slice(start || 0, end);
      const idx = t.indexOf(sub);
      return idx === -1 ? -1 : idx + (start || 0);
    },
    rfind(s, sub, start, end) {
      const t = s.slice(start || 0, end);
      const idx = t.lastIndexOf(sub);
      return idx === -1 ? -1 : idx + (start || 0);
    },
    index(s, sub, start, end) {
      const idx = _jac.str.find(s, sub, start, end);
      if (idx === -1) throw new _jac.exc.ValueError("substring not found");
      return idx;
    },
    rindex(s, sub, start, end) {
      const idx = _jac.str.rfind(s, sub, start, end);
      if (idx === -1) throw new _jac.exc.ValueError("substring not found");
      return idx;
    },
    startswith(s, prefix, start, end) {
      return s.slice(start || 0, end).startsWith(prefix);
    },
    endswith(s, suffix, start, end) {
      return s.slice(start || 0, end).endsWith(suffix);
    },
    replace(s, old, new_, count) {
      if (count === undefined) return s.split(old).join(new_);
      let result = s, n = 0;
      while (n < count) {
        const idx = result.indexOf(old);
        if (idx === -1) break;
        result = result.slice(0, idx) + new_ + result.slice(idx + old.length);
        n++;
      }
      return result;
    },
    strip(s, chars) {
      if (!chars) return s.trim();
      let start = 0, end = s.length;
      while (start < end && chars.indexOf(s[start]) !== -1) start++;
      while (end > start && chars.indexOf(s[end - 1]) !== -1) end--;
      return s.slice(start, end);
    },
    lstrip(s, chars) {
      if (!chars) return s.trimStart();
      let start = 0;
      while (start < s.length && chars.indexOf(s[start]) !== -1) start++;
      return s.slice(start);
    },
    rstrip(s, chars) {
      if (!chars) return s.trimEnd();
      let end = s.length;
      while (end > 0 && chars.indexOf(s[end - 1]) !== -1) end--;
      return s.slice(0, end);
    },
    removeprefix(s, prefix) {
      return s.startsWith(prefix) ? s.slice(prefix.length) : s;
    },
    removesuffix(s, suffix) {
      return (suffix && s.endsWith(suffix)) ? s.slice(0, -suffix.length) : s;
    },
    split(s, sep, maxsplit) {
      if (sep === undefined || sep === null) {
        const parts = s.trim().split(/\s+/);
        if (maxsplit === undefined) return parts;
        if (maxsplit <= 0) return [s];
        return [...parts.slice(0, maxsplit), parts.slice(maxsplit).join(" ")].filter(x => x !== undefined);
      }
      if (maxsplit === undefined) return s.split(sep);
      const parts = s.split(sep);
      if (parts.length <= maxsplit + 1) return parts;
      return [...parts.slice(0, maxsplit), parts.slice(maxsplit).join(sep)];
    },
    rsplit(s, sep, maxsplit) {
      if (maxsplit === undefined) return _jac.str.split(s, sep);
      const parts = s.split(sep);
      if (parts.length <= maxsplit + 1) return parts;
      const keep = parts.length - maxsplit;
      return [parts.slice(0, keep).join(sep), ...parts.slice(keep)];
    },
    splitlines(s, keepends) {
      const lines = s.split(/(\r\n|\r|\n)/);
      const result = [];
      for (let i = 0; i < lines.length; i += 2) {
        const line = lines[i];
        const sep = lines[i + 1] || "";
        if (line || sep) result.push(keepends ? line + sep : line);
      }
      return result;
    },
    partition(s, sep) {
      const idx = s.indexOf(sep);
      if (idx === -1) return [s, "", ""];
      return [s.slice(0, idx), sep, s.slice(idx + sep.length)];
    },
    rpartition(s, sep) {
      const idx = s.lastIndexOf(sep);
      if (idx === -1) return ["", "", s];
      return [s.slice(0, idx), sep, s.slice(idx + sep.length)];
    },
    format(s, ...args) {
      let i = 0;
      return s.replace(/\{(\w*)\}/g, (match, key) => {
        if (key === "") return args[i++];
        if (!isNaN(key)) return args[parseInt(key)];
        return args[0] && typeof args[0] === "object" ? args[0][key] : match;
      });
    },
    format_map(s, mapping) {
      return s.replace(/\{(\w+)\}/g, (match, key) => key in mapping ? mapping[key] : match);
    },
    center(s, width, fillchar) {
      const fc = fillchar || " ";
      if (s.length >= width) return s;
      const total = width - s.length;
      const left = Math.floor(total / 2);
      return fc.repeat(left) + s + fc.repeat(total - left);
    },
    zfill(s, width) {
      if (s.length >= width) return s;
      const sign = (s[0] === "+" || s[0] === "-") ? s[0] : "";
      const body = sign ? s.slice(1) : s;
      return sign + "0".repeat(width - s.length) + body;
    },
    expandtabs(s, tabsize) {
      const ts = tabsize === undefined ? 8 : tabsize;
      let result = "", col = 0;
      for (const c of s) {
        if (c === "\t") { const sp = ts - (col % ts); result += " ".repeat(sp); col += sp; }
        else if (c === "\n" || c === "\r") { result += c; col = 0; }
        else { result += c; col++; }
      }
      return result;
    },
    isnumeric(s) {
      if (s.length === 0) return false;
      return [...s].every(c => /[\d\u00B2\u00B3\u00B9\u00BC-\u00BE\u2150-\u218F]/.test(c));
    },
    istitle(s) {
      return s === _jac.str.title(s) && /[A-Za-z]/.test(s);
    },
    translate(s, table) {
      return [...s].map(c => {
        const code = c.charCodeAt(0);
        if (code in table) {
          const v = table[code];
          if (v === null) return "";
          if (typeof v === "number") return String.fromCharCode(v);
          return v;
        }
        return c;
      }).join("");
    },
    maketrans(...args) {
      const table = {};
      if (args.length === 1) {
        const mapping = args[0];
        for (const [k, v] of Object.entries(mapping)) {
          table[typeof k === "string" ? k.charCodeAt(0) : k] = v;
        }
      } else if (args.length >= 2) {
        const from_ = args[0], to_ = args[1];
        for (let i = 0; i < from_.length; i++) {
          table[from_.charCodeAt(i)] = to_.charCodeAt(i);
        }
        if (args[2]) {
          for (const c of args[2]) table[c.charCodeAt(0)] = null;
        }
      }
      return table;
    },
    mod(s, args) {
      let i = 0;
      const a = Array.isArray(args) ? args : [args];
      return s.replace(/%([sd%])/g, (m, fmt) => {
        if (fmt === "%") return "%";
        return String(a[i++]);
      });
    }
  },

  // Runtime-polymorphic method dispatch, used when the codegen cannot prove
  // the static type of a method-call receiver (e.g. a `dict`-typed prop, the
  // result of `or` widening, or a comprehension over an untyped value) and so
  // cannot pick a typed emitter. The compiler emits
  // `_jac.poly.call(obj, "name", ...args)`; `call` resolves the *runtime* type
  // of `obj` and applies the matching Python operation, forwards to a
  // same-named method on a user-defined object, or raises AttributeError. The
  // per-type tables below carry the trivial native-mapped methods inline and
  // delegate the non-trivial ones to the shared `_jac.str/list/dict/set`
  // helpers, so each operation has a single implementation and no Python
  // method name can leak verbatim into the emitted JavaScript.
  poly: {
    _typename(o) {
      if (o === null || o === undefined) return "NoneType";
      if (Array.isArray(o)) return "list";
      if (o instanceof Set) return "set";
      if (o instanceof Map) return "dict";
      if (o instanceof Uint8Array) return "bytes";
      const t = typeof o;
      if (t === "string") return "str";
      if (t === "boolean") return "bool";
      if (t === "number") return Number.isInteger(o) ? "int" : "float";
      if (t === "object") return (o.constructor && o.constructor.name) || "object";
      return t;
    },
    // --- per-runtime-type Python method tables (keyed by Python name) ---
    // Trivial native-mapped ops are inline; non-trivial ones delegate to the
    // shared `_jac.<type>` helpers (which the typed emitters also use), so the
    // typed and polymorphic paths share one implementation.
    _str: {
      lower: (s) => s.toLowerCase(),
      upper: (s) => s.toUpperCase(),
      casefold: (s) => s.toLowerCase(),
      strip: (s, chars) => {
        if (chars === undefined) return s.trim();
        let i = 0, j = s.length;
        while (i < j && chars.indexOf(s[i]) !== -1) i++;
        while (j > i && chars.indexOf(s[j - 1]) !== -1) j--;
        return s.slice(i, j);
      },
      lstrip: (s, chars) => {
        if (chars === undefined) return s.replace(/^\s+/, "");
        let i = 0;
        while (i < s.length && chars.indexOf(s[i]) !== -1) i++;
        return s.slice(i);
      },
      rstrip: (s, chars) => {
        if (chars === undefined) return s.replace(/\s+$/, "");
        let j = s.length;
        while (j > 0 && chars.indexOf(s[j - 1]) !== -1) j--;
        return s.slice(0, j);
      },
      join: (s, parts) => Array.from(parts, x => String(x)).join(s)
    },
    _list: {
      append: (a, x) => { a.push(x); return null; },
      clear: (a) => { a.length = 0; return null; },
      copy: (a) => a.slice(),
      count: (a, x) => _jac.list.count(a, x),
      extend: (a, b) => { for (const v of b) a.push(v); return null; },
      index: (a, x, start, end) => _jac.list.index(a, x, start, end),
      insert: (a, i, x) => { a.splice(i, 0, x); return null; },
      pop: (a, i) => {
        if (i === undefined) return a.pop();
        const idx = i < 0 ? a.length + i : i;
        return a.splice(idx, 1)[0];
      },
      remove: (a, x) => _jac.list.remove(a, x),
      reverse: (a) => { a.reverse(); return null; },
      sort: (a, key) => _jac.list.sort(a, key)
    },
    _dict: {
      clear: (o) => _jac.dict.clear(o),
      copy: (o) => ({ ...o }),
      // Python `dict.get`: returns the stored value when the key is present
      // (even if it is null), and the default only when the key is absent.
      // A membership check is required — `o[key] ?? default_` would wrongly
      // substitute the default for a present-but-null value.
      get: (o, key, default_) =>
        Object.prototype.hasOwnProperty.call(o, key) ? o[key] : default_,
      items: (o) => Object.entries(o),
      keys: (o) => Object.keys(o),
      pop: (o, key, default_) => _jac.dict.pop(o, key, default_),
      popitem: (o) => _jac.dict.popitem(o),
      setdefault: (o, key, default_) => _jac.dict.setdefault(o, key, default_),
      update: (o, other) => {
        if (other instanceof Map) { for (const [k, v] of other) o[k] = v; }
        else if (Array.isArray(other)) { for (const [k, v] of other) o[k] = v; }
        else if (other) { for (const k of Object.keys(other)) o[k] = other[k]; }
        return null;
      },
      values: (o) => Object.values(o)
    },
    _set: {
      add: (s, x) => { s.add(x); return null; },
      clear: (s) => { s.clear(); return null; },
      copy: (s) => new Set(s),
      difference: (a, b) => _jac.set.difference(a, b),
      difference_update: (s, o) => _jac.set.difference_update(s, o),
      discard: (s, x) => { s.delete(x); return null; },
      intersection: (a, b) => _jac.set.intersection(a, b),
      intersection_update: (s, o) => _jac.set.intersection_update(s, o),
      isdisjoint: (a, b) => _jac.set.isDisjointFrom(a, b instanceof Set ? b : new Set(b)),
      issubset: (a, b) => _jac.set.isSubsetOf(a, b instanceof Set ? b : new Set(b)),
      issuperset: (a, b) => _jac.set.isSupersetOf(a, b instanceof Set ? b : new Set(b)),
      pop: (s) => _jac.set.pop(s),
      remove: (s, x) => _jac.set.remove(s, x),
      symmetric_difference: (a, b) => _jac.set.symmetricDifference(a, b),
      symmetric_difference_update: (s, o) => _jac.set.symmetric_difference_update(s, o),
      union: (a, b) => _jac.set.union(a, b),
      update: (s, o) => _jac.set.update(s, o)
    },
    // Jac dicts compile to plain objects, but interop code may hand us a real
    // Map; mirror the dict methods over the Map API for that case.
    _map: {
      clear: (m) => { m.clear(); return null; },
      copy: (m) => new Map(m),
      get: (m, key, default_) => (m.has(key) ? m.get(key) : default_),
      items: (m) => [...m.entries()],
      keys: (m) => [...m.keys()],
      pop: (m, key, default_) => {
        if (m.has(key)) { const v = m.get(key); m.delete(key); return v; }
        if (default_ !== undefined) return default_;
        throw new _jac.exc.KeyError("KeyError: " + key);
      },
      popitem: (m) => {
        if (m.size === 0) throw new _jac.exc.KeyError("dictionary is empty");
        const key = [...m.keys()].pop();
        const val = m.get(key);
        m.delete(key);
        return [key, val];
      },
      setdefault: (m, key, default_) => {
        if (!m.has(key)) m.set(key, default_ === undefined ? null : default_);
        return m.get(key);
      },
      update: (m, other) => {
        if (other instanceof Map) { for (const [k, v] of other) m.set(k, v); }
        else if (Array.isArray(other)) { for (const [k, v] of other) m.set(k, v); }
        else if (other) { for (const k of Object.keys(other)) m.set(k, other[k]); }
        return null;
      },
      values: (m) => [...m.values()]
    },
    // Single entry point. `obj.method(...args)` on a receiver whose static
    // type is not provably primitive is compiled to
    // `_jac.poly.call(obj, "method", ...args)`.
    call(o, m, ...args) {
      // 1. Genuine JS primitives get Python-semantic dispatch: a plain object
      //    is a Python dict, an Array is a list, a Set/Map/string/number/bytes
      //    maps to its Python counterpart. These are the types whose Python
      //    method semantics differ from (or have no) native JS equivalent.
      if (typeof o === "string") {
        if (_jac.poly._str[m]) return _jac.poly._str[m](o, ...args);
        if (_jac.str[m]) return _jac.str[m](o, ...args);
      } else if (typeof o === "number") {
        const ns = Number.isInteger(o) ? _jac.int : _jac.float;
        if (ns && ns[m]) return ns[m](o, ...args);
      } else if (Array.isArray(o)) {
        if (_jac.poly._list[m]) return _jac.poly._list[m](o, ...args);
      } else if (o instanceof Set) {
        if (_jac.poly._set[m]) return _jac.poly._set[m](o, ...args);
      } else if (o instanceof Map) {
        if (_jac.poly._map[m]) return _jac.poly._map[m](o, ...args);
      } else if (o instanceof Uint8Array) {
        if (_jac.bytes[m]) return _jac.bytes[m](o, ...args);
      } else if (
        o !== null && o !== undefined && typeof o === "object"
        && (Object.getPrototypeOf(o) === Object.prototype
            || Object.getPrototypeOf(o) === null)
      ) {
        // A plain object is a Python dict literal.
        if (_jac.poly._dict[m]) return _jac.poly._dict[m](o, ...args);
      }
      // 2. Otherwise forward to a same-named method the receiver carries
      //    itself: a user-defined class instance, a host/framework object
      //    (Headers, URLSearchParams, ...), a callable with attached methods,
      //    or a Set/Map/Array method not mirrored above. This matches the
      //    direct `obj.method(...)` that a typed call would have emitted.
      if (o !== null && o !== undefined && typeof o[m] === "function") {
        return o[m](...args);
      }
      // 3. Nothing applies: raise the Python-style error instead of leaking a
      //    method name or silently returning a wrong value.
      throw new _jac.exc.AttributeError(
        "'" + _jac.poly._typename(o) + "' object has no attribute '" + m + "'");
    },
    // Backward-compatible named shims. The compiler now emits `call`, but a
    // previously-built bundle may still reference a named helper; these route
    // it through the same dispatcher (rest params preserve the arg count).
    lower(s, ...r) { return _jac.poly.call(s, "lower", ...r); },
    upper(s, ...r) { return _jac.poly.call(s, "upper", ...r); },
    strip(s, ...r) { return _jac.poly.call(s, "strip", ...r); },
    lstrip(s, ...r) { return _jac.poly.call(s, "lstrip", ...r); },
    rstrip(s, ...r) { return _jac.poly.call(s, "rstrip", ...r); },
    append(a, ...r) { return _jac.poly.call(a, "append", ...r); },
    extend(a, ...r) { return _jac.poly.call(a, "extend", ...r); },
    pop(a, ...r) { return _jac.poly.call(a, "pop", ...r); },
    get(o, ...r) { return _jac.poly.call(o, "get", ...r); },
    contains(c, x) {
      // Python-equivalent membership for a value of unknown static type.
      // string -> substring; array (list/tuple/range) -> element;
      // Set/Map -> key/element; plain object (dict) -> own key.
      if (typeof c === "string") return c.includes(x);
      if (Array.isArray(c)) return c.includes(x);
      if (c instanceof Set || c instanceof Map) return c.has(x);
      if (c !== null && typeof c === "object") {
        return Object.prototype.hasOwnProperty.call(c, x);
      }
      return false;
    },
    getitem(c, i) {
      // Subscript read for a value of unknown static type. This is a faithful
      // superset of a raw `c[i]`: it only adds Python's negative indexing for
      // sequences (string/array) and otherwise preserves JS semantics exactly
      // (mapping/object access, out-of-range -> `undefined`, no new throws).
      if (typeof i === "number" && i < 0
          && (typeof c === "string" || Array.isArray(c))) {
        return c[c.length + i];
      }
      if (c instanceof Map) return c.get(i);
      return c[i];
    },
    setitem(c, i, v) {
      // Subscript assignment for a value of unknown/list static type. A
      // negative index writes the array element counted from the end (a raw
      // JS `c[-1] = v` would instead create a bogus "-1" property); every
      // other case behaves like a plain `c[i] = v`.
      if (typeof i === "number" && i < 0 && Array.isArray(c)) {
        c[c.length + i] = v;
        return v;
      }
      if (c instanceof Map) { c.set(i, v); return v; }
      c[i] = v;
      return v;
    },
    and_(a, bf) {
      // Python `a and b`: returns `a` when it is falsy, else evaluates and
      // returns `b`. `bf` is a thunk so the right operand keeps short-circuit
      // (lazy) evaluation, and `a` is evaluated exactly once by the caller.
      return _jac.builtin.bool(a) ? bf() : a;
    },
    or_(a, bf) {
      // Python `a or b`: returns `a` when it is truthy, else `b`.
      return _jac.builtin.bool(a) ? a : bf();
    }
  },

  list: {
    remove(arr, val) {
      const i = arr.indexOf(val);
      if (i === -1) throw new _jac.exc.ValueError("list.remove(x): x not in list");
      arr.splice(i, 1);
    },
    index(arr, val, start, end) {
      const s = start || 0;
      const e = end === undefined ? arr.length : end;
      for (let i = s; i < e; i++) {
        if (arr[i] === val) return i;
      }
      throw new _jac.exc.ValueError(val + " is not in list");
    },
    count(arr, val) {
      let c = 0;
      for (const item of arr) { if (item === val) c++; }
      return c;
    },
    sort(arr, key) {
      if (key) {
        arr.sort((a, b) => {
          const ka = key(a), kb = key(b);
          return ka < kb ? -1 : ka > kb ? 1 : 0;
        });
      } else {
        arr.sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
      }
    },
    repeat(arr, n) {
      const result = [];
      for (let i = 0; i < n; i++) result.push(...arr);
      return result;
    },
    eq(a, b) { return JSON.stringify(a) === JSON.stringify(b); },
    lt(a, b) {
      for (let i = 0; i < Math.min(a.length, b.length); i++) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
      }
      return a.length < b.length;
    },
    gt(a, b) { return _jac.list.lt(b, a); },
    le(a, b) { return _jac.list.eq(a, b) || _jac.list.lt(a, b); },
    ge(a, b) { return _jac.list.eq(a, b) || _jac.list.gt(a, b); },
    imul(arr, n) {
      const orig = [...arr];
      arr.length = 0;
      for (let i = 0; i < n; i++) arr.push(...orig);
      return arr;
    }
  },

  dict: {
    pop(d, key, default_) {
      if (key in d) { const v = d[key]; delete d[key]; return v; }
      if (default_ !== undefined) return default_;
      throw new _jac.exc.KeyError("KeyError: " + key);
    },
    popitem(d) {
      const keys = Object.keys(d);
      if (keys.length === 0) throw new _jac.exc.KeyError("dictionary is empty");
      const key = keys[keys.length - 1];
      const val = d[key];
      delete d[key];
      return [key, val];
    },
    setdefault(d, key, default_) {
      if (!(key in d)) d[key] = default_ === undefined ? null : default_;
      return d[key];
    },
    clear(d) {
      for (const key of Object.keys(d)) delete d[key];
    },
    fromkeys(keys, value) {
      const d = {};
      const v = value === undefined ? null : value;
      for (const k of keys) d[k] = v;
      return d;
    },
    eq(a, b) {
      const ka = Object.keys(a), kb = Object.keys(b);
      if (ka.length !== kb.length) return false;
      for (const k of ka) {
        if (!(k in b)) return false;
        const va = a[k], vb = b[k];
        if (va !== vb) {
          if (typeof va === "object" && typeof vb === "object" && va !== null && vb !== null) {
            if (JSON.stringify(va) !== JSON.stringify(vb)) return false;
          } else return false;
        }
      }
      return true;
    }
  },

  set: {
    remove(s, val) {
      if (!s.has(val)) throw new _jac.exc.KeyError("KeyError: " + val);
      s.delete(val);
    },
    pop(s) {
      if (s.size === 0) throw new _jac.exc.KeyError("pop from an empty set");
      const val = s.values().next().value;
      s.delete(val);
      return val;
    },
    update(s, other) { for (const v of other) s.add(v); },
    intersection_update(s, other) {
      const otherSet = other instanceof Set ? other : new Set(other);
      for (const v of s) { if (!otherSet.has(v)) s.delete(v); }
    },
    difference_update(s, other) {
      for (const v of other) s.delete(v);
    },
    symmetric_difference_update(s, other) {
      for (const v of other) { if (s.has(v)) s.delete(v); else s.add(v); }
    },
    union(a, b) {
      const r = new Set(a);
      for (const v of b) r.add(v);
      return r;
    },
    intersection(a, b) {
      const bs = b instanceof Set ? b : new Set(b);
      const r = new Set();
      for (const v of a) { if (bs.has(v)) r.add(v); }
      return r;
    },
    difference(a, b) {
      const bs = b instanceof Set ? b : new Set(b);
      const r = new Set();
      for (const v of a) { if (!bs.has(v)) r.add(v); }
      return r;
    },
    symmetricDifference(a, b) {
      const r = new Set(a);
      for (const v of b) { if (r.has(v)) r.delete(v); else r.add(v); }
      return r;
    },
    isSubsetOf(a, b) {
      if (a.size > b.size) return false;
      for (const v of a) { if (!b.has(v)) return false; }
      return true;
    },
    isSupersetOf(a, b) { return _jac.set.isSubsetOf(b, a); },
    isDisjointFrom(a, b) {
      for (const v of a) { if (b.has(v)) return false; }
      return true;
    },
    is_proper_subset(a, b) {
      if (a.size >= b.size) return false;
      for (const v of a) { if (!b.has(v)) return false; }
      return true;
    },
    is_proper_superset(a, b) { return _jac.set.is_proper_subset(b, a); },
    eq(a, b) {
      if (a.size !== b.size) return false;
      for (const v of a) { if (!b.has(v)) return false; }
      return true;
    }
  },

  bytes: {
    hex(b) {
      return Array.from(b).map(x => x.toString(16).padStart(2, "0")).join("");
    },
    fromhex(s) {
      const arr = [];
      const clean = s.replace(/\s/g, "");
      for (let i = 0; i < clean.length; i += 2) arr.push(parseInt(clean.substr(i, 2), 16));
      return new Uint8Array(arr);
    },
    _indexOf(b, sub, start, end) {
      const s = start || 0;
      const e = end === undefined ? b.length : end;
      const sl = sub.length;
      if (sl === 0) return s;
      for (let i = s; i <= e - sl; i++) {
        let m = true;
        for (let j = 0; j < sl; j++) { if (b[i + j] !== sub[j]) { m = false; break; } }
        if (m) return i;
      }
      return -1;
    },
    _lastIndexOf(b, sub, start, end) {
      const s = start || 0;
      const e = end === undefined ? b.length : end;
      const sl = sub.length;
      if (sl === 0) return e;
      for (let i = e - sl; i >= s; i--) {
        let m = true;
        for (let j = 0; j < sl; j++) { if (b[i + j] !== sub[j]) { m = false; break; } }
        if (m) return i;
      }
      return -1;
    },
    count(b, sub) {
      let c = 0, p = 0;
      while (p <= b.length - sub.length) {
        const idx = _jac.bytes._indexOf(b, sub, p);
        if (idx === -1) break;
        c++; p = idx + sub.length;
      }
      return c;
    },
    find(b, sub, start, end) { return _jac.bytes._indexOf(b, sub, start, end); },
    rfind(b, sub, start, end) { return _jac.bytes._lastIndexOf(b, sub, start, end); },
    index(b, sub, start, end) {
      const idx = _jac.bytes._indexOf(b, sub, start, end);
      if (idx === -1) throw new _jac.exc.ValueError("substring not found");
      return idx;
    },
    rindex(b, sub, start, end) {
      const idx = _jac.bytes._lastIndexOf(b, sub, start, end);
      if (idx === -1) throw new _jac.exc.ValueError("substring not found");
      return idx;
    },
    startswith(b, prefix, start, end) {
      const s = start || 0;
      if (prefix.length > b.length - s) return false;
      for (let i = 0; i < prefix.length; i++) { if (b[s + i] !== prefix[i]) return false; }
      return true;
    },
    endswith(b, suffix, start, end) {
      const e = end === undefined ? b.length : end;
      if (suffix.length > e) return false;
      const off = e - suffix.length;
      for (let i = 0; i < suffix.length; i++) { if (b[off + i] !== suffix[i]) return false; }
      return true;
    },
    replace(b, old_, new_, count) {
      const r = [];
      let pos = 0, n = 0;
      const max = count === undefined ? Infinity : count;
      while (pos <= b.length) {
        if (n < max) {
          const idx = _jac.bytes._indexOf(b, old_, pos);
          if (idx !== -1) {
            for (let i = pos; i < idx; i++) r.push(b[i]);
            for (let i = 0; i < new_.length; i++) r.push(new_[i]);
            pos = idx + old_.length; n++;
            continue;
          }
        }
        for (let i = pos; i < b.length; i++) r.push(b[i]);
        break;
      }
      return new Uint8Array(r);
    },
    _isWS(c) { return c === 32 || c === 9 || c === 10 || c === 13 || c === 11 || c === 12; },
    strip(b, chars) {
      let s = 0, e = b.length;
      if (chars) { const cs = new Set(chars); while (s < e && cs.has(b[s])) s++; while (e > s && cs.has(b[e-1])) e--; }
      else { while (s < e && _jac.bytes._isWS(b[s])) s++; while (e > s && _jac.bytes._isWS(b[e-1])) e--; }
      return b.slice(s, e);
    },
    lstrip(b, chars) {
      let s = 0;
      if (chars) { const cs = new Set(chars); while (s < b.length && cs.has(b[s])) s++; }
      else { while (s < b.length && _jac.bytes._isWS(b[s])) s++; }
      return b.slice(s);
    },
    rstrip(b, chars) {
      let e = b.length;
      if (chars) { const cs = new Set(chars); while (e > 0 && cs.has(b[e-1])) e--; }
      else { while (e > 0 && _jac.bytes._isWS(b[e-1])) e--; }
      return b.slice(0, e);
    },
    removeprefix(b, prefix) {
      if (_jac.bytes.startswith(b, prefix)) return b.slice(prefix.length);
      return b.slice();
    },
    removesuffix(b, suffix) {
      if (suffix.length > 0 && _jac.bytes.endswith(b, suffix)) return b.slice(0, b.length - suffix.length);
      return b.slice();
    },
    split(b, sep, maxsplit) {
      const parts = [];
      let pos = 0, n = 0;
      const max = maxsplit === undefined ? Infinity : maxsplit;
      while (pos <= b.length) {
        if (n >= max) { parts.push(b.slice(pos)); return parts; }
        const idx = _jac.bytes._indexOf(b, sep, pos);
        if (idx === -1) { parts.push(b.slice(pos)); return parts; }
        parts.push(b.slice(pos, idx));
        pos = idx + sep.length; n++;
      }
      if (pos <= b.length) parts.push(b.slice(pos));
      return parts;
    },
    rsplit(b, sep, maxsplit) {
      if (maxsplit === undefined) return _jac.bytes.split(b, sep);
      const parts = [];
      let end = b.length, n = 0;
      while (end >= 0 && n < maxsplit) {
        const idx = _jac.bytes._lastIndexOf(b, sep, 0, end);
        if (idx === -1) break;
        parts.unshift(b.slice(idx + sep.length, end));
        end = idx; n++;
      }
      parts.unshift(b.slice(0, end));
      return parts;
    },
    splitlines(b, keepends) {
      const result = [];
      let start = 0;
      for (let i = 0; i < b.length; i++) {
        if (b[i] === 10 || b[i] === 13) {
          let eol = i + 1;
          if (b[i] === 13 && i + 1 < b.length && b[i + 1] === 10) eol++;
          result.push(keepends ? b.slice(start, eol) : b.slice(start, i));
          start = eol;
          if (eol > i + 1) i++;
        }
      }
      if (start < b.length) result.push(b.slice(start));
      return result;
    },
    join(sep, parts) {
      if (parts.length === 0) return new Uint8Array(0);
      const r = [];
      for (let i = 0; i < parts.length; i++) {
        if (i > 0) for (const x of sep) r.push(x);
        for (const x of parts[i]) r.push(x);
      }
      return new Uint8Array(r);
    },
    partition(b, sep) {
      const idx = _jac.bytes._indexOf(b, sep);
      if (idx === -1) return [b.slice(), new Uint8Array(0), new Uint8Array(0)];
      return [b.slice(0, idx), sep.slice(), b.slice(idx + sep.length)];
    },
    rpartition(b, sep) {
      const idx = _jac.bytes._lastIndexOf(b, sep);
      if (idx === -1) return [new Uint8Array(0), new Uint8Array(0), b.slice()];
      return [b.slice(0, idx), sep.slice(), b.slice(idx + sep.length)];
    },
    _isUp(c) { return c >= 65 && c <= 90; },
    _isLo(c) { return c >= 97 && c <= 122; },
    _isAl(c) { return (c >= 65 && c <= 90) || (c >= 97 && c <= 122); },
    _isDig(c) { return c >= 48 && c <= 57; },
    capitalize(b) {
      if (b.length === 0) return new Uint8Array(0);
      const r = new Uint8Array(b.length);
      r[0] = _jac.bytes._isLo(b[0]) ? b[0] - 32 : b[0];
      for (let i = 1; i < b.length; i++) r[i] = _jac.bytes._isUp(b[i]) ? b[i] + 32 : b[i];
      return r;
    },
    lower(b) {
      const r = new Uint8Array(b.length);
      for (let i = 0; i < b.length; i++) r[i] = _jac.bytes._isUp(b[i]) ? b[i] + 32 : b[i];
      return r;
    },
    upper(b) {
      const r = new Uint8Array(b.length);
      for (let i = 0; i < b.length; i++) r[i] = _jac.bytes._isLo(b[i]) ? b[i] - 32 : b[i];
      return r;
    },
    title(b) {
      const r = new Uint8Array(b.length);
      let prev = false;
      for (let i = 0; i < b.length; i++) {
        if (_jac.bytes._isAl(b[i])) {
          r[i] = prev ? (_jac.bytes._isUp(b[i]) ? b[i] + 32 : b[i]) : (_jac.bytes._isLo(b[i]) ? b[i] - 32 : b[i]);
          prev = true;
        } else { r[i] = b[i]; prev = false; }
      }
      return r;
    },
    swapcase(b) {
      const r = new Uint8Array(b.length);
      for (let i = 0; i < b.length; i++) {
        if (_jac.bytes._isUp(b[i])) r[i] = b[i] + 32;
        else if (_jac.bytes._isLo(b[i])) r[i] = b[i] - 32;
        else r[i] = b[i];
      }
      return r;
    },
    center(b, width, fb) {
      const f = fb || 32;
      if (b.length >= width) return b.slice();
      const total = width - b.length;
      const left = Math.floor(total / 2);
      const r = new Uint8Array(width);
      r.fill(f, 0, left); r.set(b, left); r.fill(f, left + b.length);
      return r;
    },
    ljust(b, width, fb) {
      const f = fb || 32;
      if (b.length >= width) return b.slice();
      const r = new Uint8Array(width);
      r.set(b); r.fill(f, b.length);
      return r;
    },
    rjust(b, width, fb) {
      const f = fb || 32;
      if (b.length >= width) return b.slice();
      const r = new Uint8Array(width);
      const off = width - b.length;
      r.fill(f, 0, off); r.set(b, off);
      return r;
    },
    zfill(b, width) {
      if (b.length >= width) return b.slice();
      const r = new Uint8Array(width);
      let off = 0;
      if (b.length > 0 && (b[0] === 43 || b[0] === 45)) { r[0] = b[0]; off = 1; }
      const pad = width - b.length;
      r.fill(48, off, off + pad);
      for (let i = off; i < b.length; i++) r[pad + i] = b[i];
      return r;
    },
    expandtabs(b, tabsize) {
      const ts = tabsize === undefined ? 8 : tabsize;
      const r = [];
      let col = 0;
      for (let i = 0; i < b.length; i++) {
        if (b[i] === 9) { const sp = ts - (col % ts); for (let j = 0; j < sp; j++) r.push(32); col += sp; }
        else if (b[i] === 10 || b[i] === 13) { r.push(b[i]); col = 0; }
        else { r.push(b[i]); col++; }
      }
      return new Uint8Array(r);
    },
    translate(b, table, del_) {
      const r = [];
      const ds = del_ ? new Set(del_) : null;
      for (let i = 0; i < b.length; i++) {
        if (ds && ds.has(b[i])) continue;
        r.push(table && table[b[i]] !== undefined ? table[b[i]] : b[i]);
      }
      return new Uint8Array(r);
    },
    maketrans(from_, to_) {
      const t = new Uint8Array(256);
      for (let i = 0; i < 256; i++) t[i] = i;
      for (let i = 0; i < from_.length; i++) t[from_[i]] = to_[i];
      return t;
    },
    isalnum(b) {
      if (b.length === 0) return false;
      for (let i = 0; i < b.length; i++) if (!_jac.bytes._isAl(b[i]) && !_jac.bytes._isDig(b[i])) return false;
      return true;
    },
    isalpha(b) {
      if (b.length === 0) return false;
      for (let i = 0; i < b.length; i++) if (!_jac.bytes._isAl(b[i])) return false;
      return true;
    },
    isascii(b) {
      for (let i = 0; i < b.length; i++) if (b[i] > 127) return false;
      return true;
    },
    isdigit(b) {
      if (b.length === 0) return false;
      for (let i = 0; i < b.length; i++) if (!_jac.bytes._isDig(b[i])) return false;
      return true;
    },
    islower(b) {
      let has = false;
      for (let i = 0; i < b.length; i++) {
        if (_jac.bytes._isUp(b[i])) return false;
        if (_jac.bytes._isLo(b[i])) has = true;
      }
      return has;
    },
    isupper(b) {
      let has = false;
      for (let i = 0; i < b.length; i++) {
        if (_jac.bytes._isLo(b[i])) return false;
        if (_jac.bytes._isUp(b[i])) has = true;
      }
      return has;
    },
    isspace(b) {
      if (b.length === 0) return false;
      for (let i = 0; i < b.length; i++) if (!_jac.bytes._isWS(b[i])) return false;
      return true;
    },
    istitle(b) {
      let prev = false, has = false;
      for (let i = 0; i < b.length; i++) {
        if (_jac.bytes._isUp(b[i])) { if (prev) return false; prev = true; has = true; }
        else if (_jac.bytes._isLo(b[i])) { if (!prev) return false; prev = true; has = true; }
        else prev = false;
      }
      return has;
    },
    add(a, b) {
      const r = new Uint8Array(a.length + b.length);
      r.set(a); r.set(b, a.length);
      return r;
    },
    mul(b, n) {
      const r = new Uint8Array(b.length * n);
      for (let i = 0; i < n; i++) r.set(b, i * b.length);
      return r;
    },
    mod(b, args) {
      const s = new TextDecoder().decode(b);
      return new TextEncoder().encode(_jac.str.mod(s, args));
    },
    eq(a, b) {
      if (a.length !== b.length) return false;
      for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
      return true;
    },
    lt(a, b) {
      for (let i = 0; i < Math.min(a.length, b.length); i++) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
      }
      return a.length < b.length;
    },
    gt(a, b) { return _jac.bytes.lt(b, a); },
    le(a, b) { return _jac.bytes.eq(a, b) || _jac.bytes.lt(a, b); },
    ge(a, b) { return _jac.bytes.eq(a, b) || _jac.bytes.gt(a, b); },
    contains(b, sub) { return _jac.bytes._indexOf(b, sub) !== -1; }
  },

  tuple: {
    count(arr, val) { return _jac.list.count(arr, val); },
    index(arr, val, start, end) { return _jac.list.index(arr, val, start, end); },
    repeat(arr, n) { return _jac.list.repeat(arr, n); },
    eq(a, b) { return _jac.list.eq(a, b); },
    lt(a, b) { return _jac.list.lt(a, b); },
    gt(a, b) { return _jac.list.gt(a, b); },
    le(a, b) { return _jac.list.le(a, b); },
    ge(a, b) { return _jac.list.ge(a, b); }
  },

  range: {
    count(r, val) {
      if (typeof r[Symbol.iterator] === "function") {
        let c = 0;
        for (const v of r) { if (v === val) c++; }
        return c;
      }
      return 0;
    },
    index(r, val) {
      let i = 0;
      for (const v of r) { if (v === val) return i; i++; }
      throw new _jac.exc.ValueError(val + " is not in range");
    },
    eq(a, b) {
      if (a.length !== b.length) return false;
      for (let i = 0; i < a.length; i++) { if (a[i] !== b[i]) return false; }
      return true;
    },
    contains(r, val) {
      for (const v of r) { if (v === val) return true; }
      return false;
    }
  },

  builtin: {
    round(n, ndigits) {
      if (ndigits === undefined) return Math.round(n);
      const f = Math.pow(10, ndigits);
      return Math.round(n * f) / f;
    },
    sum(iterable, start) {
      let total = start || 0;
      for (const v of iterable) total += v;
      return total;
    },
    sorted(iterable, key, reverse) {
      const arr = [...iterable];
      if (key) {
        arr.sort((a, b) => {
          const ka = key(a), kb = key(b);
          return ka < kb ? -1 : ka > kb ? 1 : 0;
        });
      } else {
        arr.sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
      }
      if (reverse) arr.reverse();
      return arr;
    },
    enumerate(iterable, start) {
      const s = start || 0;
      return [...iterable].map((v, i) => [s + i, v]);
    },
    zip(...iterables) {
      const arrays = iterables.map(it => [...it]);
      const len = Math.min(...arrays.map(a => a.length));
      const result = [];
      for (let i = 0; i < len; i++) {
        result.push(arrays.map(a => a[i]));
      }
      return result;
    },
    map(fn, ...iterables) {
      if (iterables.length === 1) return [...iterables[0]].map(fn);
      const arrays = iterables.map(it => [...it]);
      const len = Math.min(...arrays.map(a => a.length));
      const result = [];
      for (let i = 0; i < len; i++) {
        result.push(fn(...arrays.map(a => a[i])));
      }
      return result;
    },
    filter(fn, iterable) {
      return [...iterable].filter(fn || (x => x));
    },
    // Python subclass relation over builtin-type *tags* -- the string names
    // (`"str"`, `"int"`, ...) that `exit_builtin_type` lowers builtin types to.
    // `object` is the universal base and `bool` is a subclass of `int`; `tuple`
    // and `frozenset` share JS representations with `list`/`set`, so fold those
    // aliases to their runtime tag first. One source of truth so isinstance and
    // issubclass can never disagree.
    _tagSubclass(subTag, superTag) {
      const fold = (t) => t === "tuple" ? "list" : t === "frozenset" ? "set" : t;
      const sub = fold(subTag), sup = fold(superTag);
      if (sup === "object") return true;
      if (sub === sup) return true;
      if (sup === "int" && sub === "bool") return true;
      return false;
    },
    isinstance(o, classinfo) {
      // isinstance(x, (A, B, ...)) -- the tuple of types lowers to a JS array;
      // match if `o` is an instance of any member.
      if (Array.isArray(classinfo)) {
        for (const c of classinfo) {
          if (_jac.builtin.isinstance(o, c)) return true;
        }
        return false;
      }
      // Builtin types lower to a string tag (their Python type name): compare
      // the value's runtime type against it via the shared subclass relation.
      if (typeof classinfo === "string") {
        return _jac.builtin._tagSubclass(_jac.poly._typename(o), classinfo);
      }
      // User archetype / JS constructor.
      if (typeof classinfo === "function") return o instanceof classinfo;
      return false;
    },
    issubclass(cls, classinfo) {
      if (Array.isArray(classinfo)) {
        for (const c of classinfo) {
          if (_jac.builtin.issubclass(cls, c)) return true;
        }
        return false;
      }
      // When either side is a builtin-type tag, compare by the shared subclass
      // relation (covers `object`, `bool` ⊂ `int`, and identity).
      if (typeof cls === "string" || typeof classinfo === "string") {
        return _jac.builtin._tagSubclass(cls, classinfo);
      }
      if (cls === classinfo) return true;
      let proto = cls;
      while (proto) {
        if (proto === classinfo) return true;
        proto = Object.getPrototypeOf(proto);
      }
      return false;
    },
    id(o) {
      if (o === null || o === undefined) return 0;
      if (typeof o === "number") return o;
      return typeof o === "string" ? _jac.builtin._strHash(o) : 0;
    },
    _strHash(s) {
      let h = 0;
      for (let i = 0; i < s.length; i++) {
        h = ((h << 5) - h + s.charCodeAt(i)) | 0;
      }
      return h;
    },
    jid(obj) {
      if (obj === null || obj === undefined) {
        throw new _jac.exc.TypeError(
          "jid() called on " + String(obj)
          + " -- the server may have returned an error instead of a node."
          + " Check that your endpoint returned successfully before using jid()."
        );
      }
      if (obj._jac_id === undefined) {
        throw new _jac.exc.TypeError(
          "jid() expected a node or edge with graph identity, but received "
          + (typeof obj === "object" ? JSON.stringify(Object.keys(obj)) : typeof obj)
          + ". Only node and edge archetypes have a jid."
        );
      }
      return obj._jac_id;
    },
    // unsafe_html(x) returns a sentinel object that the JSX flattener
    // recognises and renders as raw HTML via dangerouslySetInnerHTML.
    // Named "unsafe" so the security implication is visible at the use site.
    unsafe_html(html) {
      return { __jacUnsafeHtml: String(html == null ? "" : html) };
    },
    hash(obj) { return _jac.builtin.id(obj); },
    repr(obj) { return JSON.stringify(obj); },
    pow(base, exp, mod) {
      let result = Math.pow(base, exp);
      if (mod !== undefined) result = ((result % mod) + mod) % mod;
      return result;
    },
    next(iter, default_) {
      const result = iter.next();
      if (result.done) {
        if (default_ !== undefined) return default_;
        throw new _jac.exc.StopIteration("StopIteration");
      }
      return result.value;
    },
    vars(o) {
      if (o === undefined) return {};
      const result = {};
      for (const [k, v] of Object.entries(o)) {
        if (typeof v !== "function") result[k] = v;
      }
      return result;
    },
    dir(o) {
      if (o === undefined) return [];
      return Object.getOwnPropertyNames(o).sort();
    },
    open() { throw new _jac.exc.OSError("open() is not supported in client-side JavaScript"); },
    format(value, format_spec) {
      if (!format_spec) return String(value);
      return String(value);
    },
    ascii(obj) {
      if (typeof obj === "string") {
        let r = "'";
        for (const c of obj) {
          const code = c.charCodeAt(0);
          if (c === "\\") r += "\\\\";
          else if (c === "'") r += "\\'";
          else if (code >= 0x20 && code <= 0x7e) r += c;
          else if (code < 0x100) r += "\\x" + code.toString(16).padStart(2, "0");
          else r += "\\u" + code.toString(16).padStart(4, "0");
        }
        return r + "'";
      }
      return String(obj);
    },
    complex(re, im) { return {re: re || 0, im: im || 0}; },
    bool(x) {
      if (x === null || x === undefined || x === false || x === 0 || x === "" || Number.isNaN(x)) return false;
      if (Array.isArray(x)) return x.length > 0;
      if (x instanceof Set || x instanceof Map) return x.size > 0;
      if (typeof x === "object") return Object.keys(x).length > 0;
      return true;
    },
    range(...args) {
      let start, stop, step;
      if (args.length === 1) { start = 0; stop = args[0]; step = 1; }
      else if (args.length === 2) { start = args[0]; stop = args[1]; step = 1; }
      else { start = args[0]; stop = args[1]; step = args[2]; }
      if (step === 0) throw new _jac.exc.ValueError("range() arg 3 must not be zero");
      const result = [];
      if (step > 0) { for (let i = start; i < stop; i += step) result.push(i); }
      else { for (let i = start; i > stop; i += step) result.push(i); }
      return result;
    },
    slice(...args) {
      if (args.length === 1) return { start: null, stop: args[0], step: null };
      return { start: args[0] !== undefined ? args[0] : null, stop: args[1] !== undefined ? args[1] : null, step: args[2] !== undefined ? args[2] : null };
    },
    format(value, format_spec) {
      if (!format_spec || format_spec === "") return String(value);
      const m = format_spec.match(/^([<>^]?)(\d+)?(?:\.(\d+))?([dfseboxXn%]?)$/);
      if (!m) return String(value);
      const [, align, widthStr, precStr, ftype] = m;
      let s;
      const prec = precStr !== undefined ? parseInt(precStr) : undefined;
      if (ftype === "f" || ftype === "") {
        s = prec !== undefined ? Number(value).toFixed(prec) : String(value);
      } else if (ftype === "d") {
        s = String(Math.floor(Number(value)));
      } else if (ftype === "b") {
        s = Number(value).toString(2);
      } else if (ftype === "o") {
        s = Number(value).toString(8);
      } else if (ftype === "x") {
        s = Number(value).toString(16);
      } else if (ftype === "X") {
        s = Number(value).toString(16).toUpperCase();
      } else if (ftype === "e") {
        s = prec !== undefined ? Number(value).toExponential(prec) : Number(value).toExponential();
      } else if (ftype === "%") {
        s = (prec !== undefined ? (Number(value) * 100).toFixed(prec) : (Number(value) * 100).toFixed(6)) + "%";
      } else if (ftype === "s" || ftype === "n") {
        s = String(value);
      } else {
        s = String(value);
      }
      if (widthStr) {
        const width = parseInt(widthStr);
        if (s.length < width) {
          const pad = " ".repeat(width - s.length);
          if (align === "<") s = s + pad;
          else if (align === "^") {
            const left = Math.floor((width - s.length) / 2);
            s = " ".repeat(left) + s + " ".repeat(width - s.length - left);
          }
          else s = pad + s;
        }
      }
      return s;
    }
  },

  exc: __JAC_EXC_RUNTIME__
}""",
     _JS_RESERVED_EXC_NAMES: set[str] = {"TypeError", "ReferenceError"};

def _build_exc_runtime_js -> str {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    lines: list[str] = ["(() => {"];
    exports: list[str] = [];
    for (name, parent) in JAC_TYPE_REGISTRY.exception_entries() {
        local = (name + "_") if name in _JS_RESERVED_EXC_NAMES else name;
        parent_local = (
            "Error"
                if parent is None
                else ((parent + "_") if parent in _JS_RESERVED_EXC_NAMES else parent)
        );
        lines.append(
            "    class " + local + " extends " + parent_local + " { constructor(m) { super(m); this.name = '" + name + "'; } }"
        );
        exports.append(
            (name + ": " + local) if name in _JS_RESERVED_EXC_NAMES else name
        );
    }
    lines.append("    const _all = { " + ", ".join(exports) + " };");

    lines.append("    function matches(e, name) {");
    lines.append("      if (name === 'BaseException') return true;");
    lines.append(
        "      if (name === 'Exception') return (e instanceof _all.Exception) || !(e instanceof _all.BaseException);"
    );
    lines.append("      const cls = _all[name];");
    lines.append("      return cls ? (e instanceof cls) : false;");
    lines.append("    }");
    lines.append("    return Object.assign(_all, { matches });");
    lines.append("  })()");
    return "\n".join(lines);
}

def build_jac_runtime_js -> str {
    return JAC_RUNTIME_JS_OBJECT.replace(
        "__JAC_EXC_RUNTIME__", _build_exc_runtime_js()
    );
}

glob _OSP_KERNEL_JS_CACHE: list[str] = [];

def build_osp_kernel_js -> str {
    if _OSP_KERNEL_JS_CACHE {
        return _OSP_KERNEL_JS_CACHE[0];
    }
    import os;
    import shutil;
    import tempfile;
    import jaclang;
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
    import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
    import from jaclang.compiler.passes.ecmascript { estree as es }
    src = os.path.join(os.path.dirname(jaclang.__file__), "jac0core", "osp_kernel.jac");

    tmp_dir = tempfile.mkdtemp();
    cl_copy = os.path.join(tmp_dir, "osp_kernel.cl.jac");
    shutil.copyfile(src, cl_copy);
    js = "";
    try {
        prog = JacProgram();
        ir = prog.compile(file_path=cl_copy, no_cgen=True);
        program = EsastGenPass(ir_in=ir, prog=prog).ir_out.gen.es_ast;
        kept: list = [];
        if isinstance(program, es.Program) {
            for stmt in program.body {
                is_jac_rt = (
                    isinstance(stmt, es.VariableDeclaration)
                    and stmt.declarations
                    and isinstance(stmt.declarations[0].id, es.Identifier)
                    and (stmt.declarations[0].id.name == "_jac")
                );
                if is_jac_rt or isinstance(stmt, es.ExportNamedDeclaration) {
                    continue;
                }
                kept.append(stmt);
            }
        }
        js = es_to_js(es.Program(body=kept));
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
    _OSP_KERNEL_JS_CACHE.append(js);
    return js;
}

def build_osp_graph_js -> str {
    return r"""
function __ospConn(srcs, tgts, makeEdge, undirected) {
  srcs = Array.isArray(srcs) ? srcs : [srcs];
  tgts = Array.isArray(tgts) ? tgts : [tgts];
  for (const s of srcs) for (const t of tgts) {
    const e = makeEdge ? makeEdge() : {};
    e.__src = s; e.__tgt = t; e.__undirected = !!undirected;
    (s.__edges ??= []).push(e); (t.__edges ??= []).push(e);
  }
  return tgts.length === 1 ? tgts[0] : tgts;
}
function __ospRefs(nodes, dir, edgeTag, edgesOnly) {
  nodes = Array.isArray(nodes) ? nodes : [nodes];
  const seen = new Set(), out = [];
  for (const n of nodes) for (const e of (n.__edges || [])) {
    if (edgeTag != null && e.__tag !== edgeTag) continue;
    const eff = e.__undirected ? 3 : dir;
    if ((eff === 2 || eff === 3) && e.__src === n) {
      const o = edgesOnly ? e : e.__tgt;
      if (!seen.has(o)) { seen.add(o); out.push(o); }
    }
    if ((eff === 1 || eff === 3) && e.__tgt === n) {
      const o = edgesOnly ? e : e.__src;
      if (!seen.has(o)) { seen.add(o); out.push(o); }
    }
  }
  return out;
}
""";
}

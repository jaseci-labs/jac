"""JavaScript runtime object for Jac primitive operations.

Provides the _jac runtime that bridges Python-like primitive methods
to their JavaScript implementations. Organized by type namespace.

Injected as `const _jac = <this object>;` into generated JS modules
that reference _jac.* calls from the primitive emitters.
"""

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
      if (!isFinite(f)) throw new Error("cannot convert " + f + " to integer ratio");
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
    eq(a, b) { return a.re === b.re && a.im === b.im; },
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
      if (idx === -1) throw new Error("substring not found");
      return idx;
    },
    rindex(s, sub, start, end) {
      const idx = _jac.str.rfind(s, sub, start, end);
      if (idx === -1) throw new Error("substring not found");
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
      return s.replace(/\t/g, () => " ".repeat(ts));
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

  list: {
    remove(arr, val) {
      const i = arr.indexOf(val);
      if (i === -1) throw new Error("list.remove(x): x not in list");
      arr.splice(i, 1);
    },
    index(arr, val, start, end) {
      const s = start || 0;
      const e = end === undefined ? arr.length : end;
      for (let i = s; i < e; i++) {
        if (arr[i] === val) return i;
      }
      throw new Error(val + " is not in list");
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
      throw new Error("KeyError: " + key);
    },
    popitem(d) {
      const keys = Object.keys(d);
      if (keys.length === 0) throw new Error("dictionary is empty");
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
      if (!s.has(val)) throw new Error("KeyError: " + val);
      s.delete(val);
    },
    pop(s) {
      if (s.size === 0) throw new Error("pop from an empty set");
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
      throw new Error(val + " is not in range");
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
    issubclass(cls, classinfo) {
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
        throw new Error("StopIteration");
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
    open() { throw new Error("open() is not supported in client-side JavaScript"); },
    format(value, format_spec) {
      if (!format_spec) return String(value);
      return String(value);
    },
    ascii(obj) {
      const s = JSON.stringify(String(obj));
      return s.replace(/[^\x00-\x7F]/g, c => "\\u" + c.charCodeAt(0).toString(16).padStart(4, "0"));
    },
    complex(re, im) { return {re: re || 0, im: im || 0}; }
  }
}""";

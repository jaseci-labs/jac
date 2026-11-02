impl _build_exc_runtime_js -> str {
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
            "    class "
                + local
                + " extends "
                + parent_local
                + " { constructor(m) { super(m); this.name = '"
                + name
                + "'; } }"
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

impl _build_types_runtime_js -> str {
    emitter: PrimitiveEmitter[(str, ESEmitCtx)] = ESBuiltinEmitter();
    ctx = ESEmitCtx(unparser=JSCodeGenerator());
    entries: list[str] = [];
    for (tok, name) in sorted(TOKEN_MAP.items()) {
        if not tok.startswith("TYP_") {
            continue;
        }
        has_emitter = name in emitter.static_names();
        if not has_emitter and not JAC_TYPE_REGISTRY.is_sized(name) {
            continue;
        }

        bodies: list[(str | None)] = [];
        for argv in ([], ["a[0]"], ["a[0]", "a[1]"]) {
            try {
                if has_emitter {
                    bodies.append(emitter.dispatch_static(name, ctx, argv));
                } else {
                    bodies.append(es_sized_cast(name, argv));
                }
            } except Exception {
                bodies.append(None);
            }
        }
        supported = [
            b
            for b in bodies
            if b is not None
        ];
        if not supported {
            continue;
        }
        (zero, one, two) = (
            bodies[0] or supported[0],
            bodies[1] or supported[-1],
            bodies[2] or (bodies[1] or supported[-1])
        );
        if zero == one and one == two {
            body = "(" + one + ")";
        } elif one == two {
            body = "a.length === 0 ? (" + zero + ") : (" + one + ")";
        } else {
            body = (
                "a.length === 0 ? ("
                + zero
                + ") : a.length === 1 ? ("
                + one
                + ") : ("
                + two
                + ")"
            );
        }
        entries.append("    " + name + ': _t("' + name + '", (...a) => ' + body + ")");
    }
    entries.append('    object: _t("object", (...a) => ({}))');
    entries.append('    NoneType: _t("NoneType", (...a) => null)');

    sized_lines: list[str] = [];
    for shape in numeric_shapes() {
        if not shape.sized {
            continue;
        }
        sized_lines.append(
            "    T."
                + shape.name
                + ".wrap = (x) => _jac.fw.wrap('"
                + shape.name
                + "', x);"
        );
        if not shape.is_float {
            sized_lines.append(
                "    Object.defineProperties(T."
                    + shape.name
                    + ", { MIN: { get: () => _jac.fw.bounds('"
                    + shape.name
                    + "')[0] }, MAX: { get: () => _jac.fw.bounds('"
                    + shape.name
                    + "')[1] } });"
            );
        }
    }
    return "\n".join(
        [
            "(() => {",
            "    const _t = (tag, fn) => Object.assign(fn, {",
            "      __jac_type__: tag,",
            "      __name__: tag,",
            "      toString: () => \"<class '\" + tag + \"'>\"",
            "    });",
            "    const T = {",
            ",\n".join(entries),
            "    };",
            "\n".join(sized_lines),
            "    return T;",
            "  })()"
        ]
    );
}

impl _build_fw_runtime_js -> str {
    rows: list[str] = [];
    for shape in numeric_shapes() {
        if not shape.sized {
            continue;
        }
        t = shape.name;
        w = shape.width;
        if shape.is_float {
            rnd = "Math.fround" if w == 32 else "Number";
            rows.append(f"    F.cast_{t} = (x) => {rnd}(Number(x));");
            rows.append(f"    F.neg_{t} = (a) => {rnd}(-a);");
            rows.append(f"    F.abs_{t} = (a) => {rnd}(Math.abs(a));");
            rows.append(
                f"    F.div_{t} = (a, b) => "
                f"{{ if (b === 0) zdiv('float division by zero'); "
                f"return {rnd}(a / b); }};"
            );
            rows.append(
                f"    F.fdiv_{t} = (a, b) => "
                f"{{ if (b === 0) zdiv('float floor division by zero'); "
                f"return {rnd}(Math.floor(a / b)); }};"
            );
            rows.append(
                f"    F.mod_{t} = (a, b) => "
                f"{{ if (b === 0) zdiv('float modulo by zero'); "
                f"return {rnd}(a - b * Math.floor(a / b)); }};"
            );
            rows.append(f"    F.pow_{t} = (a, b) => {rnd}(Math.pow(a, b));");
            continue;
        }
        (lo, hi) = range_of(t);
        big = w == 64;
        sfx = "n" if big else "";
        z = f"0{sfx}";
        one = f"1{sfx}";
        wn = f"{w}{sfx}";
        rows.append(f"    const LO_{t} = {lo}{sfx}, HI_{t} = {hi}{sfx};");
        rows.append(f"    F.c_{t} = (v) => (v >= LO_{t} && v <= HI_{t}) ? v : ovf();");
        if big {
            rows.append(
                f"    F.big_{t} = (x) => F.c_{t}(typeof x === 'bigint' ? x "
                f": (typeof x === 'string' ? BigInt(x) "
                f": BigInt(Math.trunc(Number(x)))));"
            );
            rows.append(f"    F.cast_{t} = (x) => F.big_{t}(x);");
            rows.append(f"    F.abs_{t} = (a) => F.c_{t}(a < {z} ? -a : a);");
            rows.append(
                f"    F.div_{t} = (a, b) => {{ if (b === {z}) "
                f"zdiv('division by zero'); return Number(a) / Number(b); }};"
            );
            rows.append(
                f"    F.fdiv_{t} = (a, b) => {{ if (b === {z}) "
                f"zdiv('integer division or modulo by zero'); let q = a / b; "
                f"if ((a % b) !== {z} && ((a < {z}) !== (b < {z}))) q -= {one}; "
                f"return F.c_{t}(q); }};"
            );
            rows.append(
                f"    F.mod_{t} = (a, b) => {{ if (b === {z}) "
                f"zdiv('integer division or modulo by zero'); let r = a % b; "
                f"if (r !== {z} && ((r < {z}) !== (b < {z}))) r += b; return r; }};"
            );
            rows.append(
                f"    F.pow_{t} = (a, b) => {{ if (b < {z}) "
                f"return Math.pow(Number(a), Number(b)); "
                f"if ((a > {one} || a < -{one}) && b >= {wn}) ovf(); "
                f"return F.c_{t}(a ** b); }};"
            );
            rows.append(
                f"    F.shl_{t} = (a, b) => {{ const n = BigInt(b); "
                f"if (n < {z} || n >= {wn}) shiftErr(); return F.c_{t}(a << n); }};"
            );
            rows.append(
                f"    F.shr_{t} = (a, b) => {{ const n = BigInt(b); "
                f"if (n < {z} || n >= {wn}) shiftErr(); return a >> n; }};"
            );
        } else {
            rows.append(
                f"    F.cast_{t} = (x) => {{ const v = Math.trunc(Number(x)); "
                f"if (!Number.isFinite(v)) ovf(); return F.c_{t}(v || 0); }};"
            );
            rows.append(f"    F.abs_{t} = (a) => F.c_{t}(Math.abs(a));");
            rows.append(
                f"    F.div_{t} = (a, b) => {{ if (b === 0) "
                f"zdiv('division by zero'); return a / b; }};"
            );
            rows.append(
                f"    F.fdiv_{t} = (a, b) => {{ if (b === 0) "
                f"zdiv('integer division or modulo by zero'); "
                f"return F.c_{t}(Math.floor(a / b)); }};"
            );
            rows.append(
                f"    F.mod_{t} = (a, b) => {{ if (b === 0) "
                f"zdiv('integer division or modulo by zero'); "
                f"return a - b * Math.floor(a / b); }};"
            );
            rows.append(
                f"    F.pow_{t} = (a, b) => {{ if (b < 0) return Math.pow(a, b); "
                f"if (Math.abs(a) >= 2 && b >= {w}) ovf(); "
                f"return F.c_{t}(Math.pow(a, b)); }};"
            );
            rows.append(
                f"    F.shl_{t} = (a, b) => {{ if (b < 0 || b >= {w}) shiftErr(); "
                f"return F.c_{t}(a * Math.pow(2, b)); }};"
            );
            rows.append(
                f"    F.shr_{t} = (a, b) => {{ if (b < 0 || b >= {w}) shiftErr(); "
                f"return Math.floor(a / Math.pow(2, b)); }};"
            );
        }
        rows.append(f"    F.neg_{t} = (a) => F.c_{t}(-a);");
        if shape.signed {
            rows.append(f"    F.inv_{t} = (a) => F.c_{t}(~a);");
        } elif big {
            rows.append(f"    F.inv_{t} = (a) => (~a) & HI_{t};");
        } elif w == 32 {
            rows.append(f"    F.inv_{t} = (a) => ((~a) >>> 0);");
        } else {
            rows.append(f"    F.inv_{t} = (a) => (~a) & HI_{t};");
        }
        rows.append(f"    B.{t} = [LO_{t}, HI_{t}];");
        rows.append(f"    WBITS.{t} = {w}n;");
        tail = (
            f"return v >= (1n << {w - 1}n) ? v - m : v; }};"
                if shape.signed
                else "return v; };"
        );
        rows.append(
            f"    W.{t} = (x) => {{ const m = 1n << {w}n; "
            f"let v = (typeof x === 'bigint' ? x : BigInt(Math.trunc(Number(x)))) "
            f"% m; if (v < 0n) v += m; "
                + tail
        );
    }
    return "\n".join(
        [
            "(() => {",
            "    const ovf = () => { throw new _jac.exc.OverflowError("
            "'integer overflow'); };",
            "    const shiftErr = () => { throw new _jac.exc.OverflowError("
            "'shift count out of range'); };",
            "    const zdiv = (m) => { throw new _jac.exc.ZeroDivisionError(m); };",
            "    const F = {}, B = {}, W = {}, WBITS = {};",
            "\n".join(rows),
            "    F.r_f32 = Math.fround;",
            "    F.bounds = (name) => B[name];",
            "    F.wrap = (name, x) => { const v = W[name](x); "
            "return B[name][1] > Number.MAX_SAFE_INTEGER ? v : Number(v); };",
            "    F.wrapping = (name, a, b, op) => {",
            "      const A = BigInt(a);",
            "      const Bv = b === undefined ? 0n : BigInt(b);",
            "      let r;",
            "      if (op === '+') r = A + Bv; else if (op === '-') r = A - Bv;",
            "      else if (op === '*') r = A * Bv;",
            "      else if (op === 'neg') r = -A;",
            "      else if (op === '<<') r = A << (Bv & (WBITS[name] - 1n));",
            "      else throw new _jac.exc.TypeError("
            "'unsupported wrapping operator ' + op);",
            "      return F.wrap(name, r);",
            "    };",
            "    const SAFE = 9007199254740991n;",
            "    F.replacer = function (k, v) {",
            "      if (typeof v !== 'bigint') return v;",
            "      return (v >= -SAFE && v <= SAFE) ? Number(v) : v.toString();",
            "    };",
            "    F.stringify = (v, space) => JSON.stringify(v, F.replacer, space);",
            "    if (typeof globalThis !== 'undefined')"
            " globalThis.__jacFwReplacer__ = F.replacer;",
            "    return F;",
            "  })()"
        ]
    );
}

impl build_jac_runtime_js -> str {
    return JAC_RUNTIME_JS_OBJECT.replace(
        "__JAC_EXC_RUNTIME__", _build_exc_runtime_js()
    ).replace(
        "__JAC_TYPES_RUNTIME__", _build_types_runtime_js()
    ).replace(
        "__JAC_FW_RUNTIME__", _build_fw_runtime_js()
    );
}

impl build_jac_prelude_module -> str {
    return (
        "const _jac = (globalThis."
        + JAC_RUNTIME_GLOBAL
        + " ??= "
        + build_jac_runtime_js()
        + ");\nexport { _jac };\n"
    );
}

impl write_jac_prelude_file(dir_path: str) -> str {
    import os;
    os.makedirs(dir_path, exist_ok=True);
    out = os.path.join(dir_path, JAC_PRELUDE_BASENAME);
    text = build_jac_prelude_module();
    try {
        with open(out, encoding="utf-8") as handle {
            if handle.read() == text {
                return out;
            }
        }
    } except (OSError, UnicodeDecodeError) {}
    with open(out, "w", encoding="utf-8") as handle {
        handle.write(text);
    }
    return out;
}

impl stage_jac_prelude_package(dir_path: str) -> str {
    import os;
    import json;
    pkg = os.path.join(dir_path, "node_modules", "@jac", "prelude");
    os.makedirs(pkg, exist_ok=True);
    with open(os.path.join(pkg, "index.js"), "w", encoding="utf-8") as handle {
        handle.write(build_jac_prelude_module());
    }
    with open(os.path.join(pkg, "package.json"), "w", encoding="utf-8") as handle {
        handle.write(
            json.dumps(
                {"name": JAC_PRELUDE_MODULE, "type": "module", "main": "index.js"}
            )
                + "\n"
        );
    }
    return pkg;
}

impl point_jac_prelude_at(js: str, target: str = "") -> str {
    dest = target or ("./" + JAC_PRELUDE_BASENAME);
    for quote in ['"', "'"] {
        js = js.replace(quote + JAC_PRELUDE_MODULE + quote, quote + dest + quote);
    }
    return js;
}

impl build_osp_core_js -> str {
    return active_host().client_osp_core_js();
}

impl build_osp_driver_js -> str {
    return r"""
if (!globalThis.__jacOspCore) {
  globalThis.__jacOspCore = {
    O: [null], H: new Map(),
    osp_conn, osp_conn_many, osp_refs, osp_refs_many, osp_refs_edge_pred,
    osp_wrap1, osp_destroy, osp_is_dead,
    osp_disconn_between, osp_disconn_between_many, osp_disconn_between_pred,
    osp_edge_peer,
    osp_spawn, osp_visit, osp_report, osp_disengage, osp_forget,
    osp_register_type, osp_register_desc, osp_node_desc, osp_is_a,
    OspWalkerDesc, OspNodeDesc, OspSlot, OspRuntime
  };
}
var __ospC = globalThis.__jacOspCore;
var __ospO = __ospC.O;
var __ospH = __ospC.H;
var __ospGenericEdge = globalThis.__jacOspGenericEdge ??= class __ospGenericEdge {};
function __ospId(o) {
  if (o == null) return 0;
  let h = __ospH.get(o);
  if (h === undefined) { h = __ospO.length; __ospO.push(o); __ospH.set(o, h); }
  return h;
}
function __ospConnW(src, tgt, mkEdge, undirected, tag = -1, edgesOnly = false) {
  const srcs = Array.isArray(src) ? src : [src];
  const tgts = Array.isArray(tgt) ? tgt : [tgt];
  for (const value of [...srcs, ...tgts]) {
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      throw new TypeError("connect operands must be nodes or flat collections of nodes");
    }
  }
  const sh = srcs.map(__ospId);
  const th = tgts.map(__ospId);
  const eh = [];
  for (let i = 0; i < sh.length * th.length; i++) eh.push(__ospId(mkEdge()));
  const r = __ospC.osp_conn_many(sh, th, eh, undirected ? 1 : 0, tag, 0, 0);
  if (r < 0) throw new Error("cannot connect a destroyed node");
  return edgesOnly ? eh.map((h) => __ospO[h]) : tgt;
}
function __ospRefsW(origin, dir, tag = -1, edgesOnly = 0, pred = null) {
  const oh = __ospId(origin);
  if (pred === null) {
    return __ospC.osp_refs(oh, dir, tag, edgesOnly ? 1 : 0).map((h) => __ospO[h]);
  }
  return __ospC.osp_refs_edge_pred(
    [oh], dir, tag, edgesOnly ? 1 : 0, (eh) => !!pred(__ospO[eh])
  ).map((h) => __ospO[h]);
}
function __ospRefsManyW(objs, dir, tag = -1, edgesOnly = 0, pred = null) {
  const hs = [];
  for (const o of objs) hs.push(__ospId(o));
  if (pred === null) {
    return __ospC.osp_refs_many(hs, dir, tag, edgesOnly ? 1 : 0).map((h) => __ospO[h]);
  }
  return __ospC.osp_refs_edge_pred(
    hs, dir, tag, edgesOnly ? 1 : 0, (eh) => !!pred(__ospO[eh])
  ).map((h) => __ospO[h]);
}
function __ospDestroyW(x, strict = false) {
  // `del` on a value target: flatten through arrays, sets, map values and
  // plain-object values and destroy every archetype found. Strict, as the
  // Python backend's `destroy(..., strict=True)`: a leaf that is not a graph
  // object raises before anything is destroyed.
  const seen = new Set();
  const stack = [x];
  const found = [];
  while (stack.length) {
    const v = stack.pop();
    if (v !== null && v !== undefined && typeof v === "object") {
      const h = __ospH.get(v);
      if (h !== undefined) { found.push(h); continue; }
      if (seen.has(v)) continue;
      if (Array.isArray(v) || v instanceof Set) { seen.add(v); for (const e of v) stack.push(e); continue; }
      if (v instanceof Map) { seen.add(v); for (const e of v.values()) stack.push(e); continue; }
      if (Object.getPrototypeOf(v) === Object.prototype) { seen.add(v); for (const e of Object.values(v)) stack.push(e); continue; }
    }
    if (strict) {
      throw new TypeError("cannot destroy " + (v === null ? "None" : typeof v)
        + ": a `del` value target must yield nodes, edges or archetypes");
    }
  }
  let n = 0;
  for (const h of found) { n += __ospC.osp_destroy(h); __ospC.osp_forget(h); }
  return n;
}
function __ospLiveStarts(starts) {
  for (const o of starts) {
    if (__ospC.osp_is_dead(__ospId(o))) {
      throw new Error("cannot spawn on a destroyed graph object");
    }
  }
  return starts;
}
function __ospDiscBetweenW(a, b, dir, tag = -1) {
  const as = Array.isArray(a) ? a : [a];
  const bs = Array.isArray(b) ? b : [b];
  return __ospC.osp_disconn_between_many(as.map(__ospId), bs.map(__ospId), dir, tag);
}
function __ospDiscBetweenPredW(a, b, dir, tag, pred) {
  return __ospC.osp_disconn_between_pred(
    __ospId(a), __ospId(b), dir, tag, (eh) => !!pred(__ospO[eh])
  );
}
""";
}

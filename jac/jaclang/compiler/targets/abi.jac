"""Pure psABI classification for the native foreign boundary
(One Owner Per Analysis, Phase 8).

No pass state: callers supply a struct's flattened scalar layout - a list
of (byte_offset, is_float, bit_width) leaves - plus its total size and
alignment, and the target triple. The returned plan dict is the single
authority for how a by-value C struct crosses the call boundary:

  - "memory": passed indirectly (byval pointer / caller copy / sret)
  - "coerce": list[ir.Type] register pieces when not memory
  - "byval": for memory args, whether the indirect pointer carries
    `byval` (System V: backend copies) vs a caller-made copy passed as a
    plain pointer (AAPCS)
  - "safe": for register structs, whether the coerce pieces must be
    loaded via an over-read-safe buffer (AAPCS coerces a partial struct
    up to a full register) vs loaded in place (System V sizes each
    eightbyte exactly)
  - "size", "align"

Directly unit-tested (tests/compiler/test_abi_lib.jac) against
hand-computed System V AMD64 and AArch64 AAPCS expectations.
"""
import from jaclang.compiler.passes.native.llvm { ir }

"""Size/align/scalar-class of a primitive LLVM type for ABI layout."""
def scalar_layout(llt: (ir.Type | None)) -> tuple {
    if isinstance(llt, ir.DoubleType) {
        return (8, 8, [(0, True, 64)]);
    }
    if isinstance(llt, ir.FloatType) {
        return (4, 4, [(0, True, 32)]);
    }
    if isinstance(llt, ir.IntType) {
        w = llt.width;
        nbytes = w // 8;
        if nbytes < 1 {
            nbytes = 1;
        }
        return (nbytes, nbytes, [(0, False, w)]);
    }
    if isinstance(llt, ir.PointerType) {
        return (8, 8, [(0, False, 64)]);
    }
    # Fallback: treat unknown as a 64-bit integer eightbyte.
    return (8, 8, [(0, False, 64)]);
}

"""System V AMD64 eightbyte classification (see module docstring)."""
def classify_struct_sysv(size: int, align: int, scalars: list) -> dict {
    if size == 0 {
        return {
            "size": 0,
            "align": 1,
            "memory": False,
            "coerce": [],
            "byval": True,
            "safe": False
        };
    }
    # Aggregates larger than two eightbytes are MEMORY class (byval / sret).
    if size > 16 {
        return {
            "size": size,
            "align": align,
            "memory": True,
            "coerce": [],
            "byval": True,
            "safe": False
        };
    }
    num_eb = (size + 7) // 8;
    eb_cls: list = [];
    eb_dbl: list = [];
    eb_nfloat: list = [];
    for _e in range(num_eb) {
        eb_cls.append("NONE");
        eb_dbl.append(False);
        eb_nfloat.append(0);
    }
    for (off, is_sse, bits) in scalars {
        eb = off // 8;
        if eb >= num_eb {
            continue;
        }
        cur = eb_cls[eb];
        cls = "SSE" if is_sse else "INT";
        if cur == "NONE" {
            eb_cls[eb] = cls;
        } elif cur == "INT" or cls == "INT" {
            eb_cls[eb] = "INT";
        } else {
            eb_cls[eb] = "SSE";
        }
        if is_sse {
            eb_nfloat[eb] += 1;
            if bits == 64 {
                eb_dbl[eb] = True;
            }
        }
    }
    coerce: list = [];
    for eb in range(num_eb) {
        used = size - (eb * 8);
        if used > 8 {
            used = 8;
        }
        if eb_cls[eb] == "SSE" {
            if eb_dbl[eb] {
                coerce.append(ir.DoubleType());
            } elif eb_nfloat[eb] >= 2 {
                coerce.append(ir.VectorType(ir.FloatType(), 2));
            } else {
                coerce.append(ir.FloatType());
            }
        } else {
            # INTEGER (NONE padding also folds here). Round the used bytes up to
            # the nearest power-of-two integer width.
            if used <= 1 {
                coerce.append(ir.IntType(8));
            } elif used <= 2 {
                coerce.append(ir.IntType(16));
            } elif used <= 4 {
                coerce.append(ir.IntType(32));
            } else {
                coerce.append(ir.IntType(64));
            }
        }
    }
    return {
        "size": size,
        "align": align,
        "memory": False,
        "coerce": coerce,
        "byval": True,
        "safe": False
    };
}

"""AArch64 AAPCS classification (see module docstring): homogeneous
floating-point aggregates (<=4 same-type float/double leaves) ride
SIMD/FP registers; other aggregates <=16 bytes ride general registers;
larger ones pass indirectly via a caller-made copy."""
def classify_struct_aapcs(size: int, align: int, scalars: list) -> dict {
    if size == 0 {
        return {
            "size": 0,
            "align": 1,
            "memory": False,
            "coerce": [],
            "byval": False,
            "safe": True
        };
    }
    # HFA: every leaf scalar is the same floating-point type, at most 4 of them.
    is_hfa = len(scalars) >= 1 and len(scalars) <= 4;
    hfa_bits = scalars[0][2] if scalars else 0;
    for (_off, _is_sse, _bits) in scalars {
        if not _is_sse or _bits != hfa_bits {
            is_hfa = False;
        }
    }
    if is_hfa {
        elem = ir.DoubleType() if hfa_bits == 64 else ir.FloatType();
        return {
            "size": size,
            "align": align,
            "memory": False,
            "coerce": [ir.ArrayType(elem, len(scalars))],
            "byval": False,
            "safe": True
        };
    }
    # Non-HFA aggregates larger than 16 bytes are passed indirectly.
    if size > 16 {
        return {
            "size": size,
            "align": align,
            "memory": True,
            "coerce": [],
            "byval": False,
            "safe": True
        };
    }
    # Otherwise: general-purpose registers, one i64 per (partial) eightbyte.
    if size <= 8 {
        coerce: list = [ir.IntType(64)];
    } else {
        coerce: list = [ir.ArrayType(ir.IntType(64), 2)];
    }
    return {
        "size": size,
        "align": align,
        "memory": False,
        "coerce": coerce,
        "byval": False,
        "safe": True
    };
}

"""Classify a by-value struct for the C ABI selected by `triple`."""
def classify_struct(size: int, align: int, scalars: list, triple: str) -> dict {
    if "aarch64" in triple or "arm64" in triple {
        return classify_struct_aapcs(size, align, scalars);
    }
    return classify_struct_sysv(size, align, scalars);
}

"""Marshalling plan for a foreign function: the single decision of HOW a
declared C signature crosses the call boundary on the active target.

Inputs are declaration-surface facts only: the foreign struct model
(targets.foreign.collect_foreign_structs), the declared
(param_name, type_name) pairs in order, the declared return type name,
and the target triple. Returns None when no by-value foreign struct is
involved - pure-scalar foreign functions (sqrt, strlen, calloc, ...)
keep the backend's legacy declaration path, which also handles reuse of
the compiler's canonical extern declarations.

The returned dict is the stored call plan:

  - "params": one entry per declared parameter, in order:
      {"kind": "scalar",     "pname", "tname", "argpos"}
      {"kind": "struct_mem", "pname", "sname", "align", "byval", "argpos"}
      {"kind": "struct_reg", "pname", "sname", "coerce", "safe", "argpos"}
  - "ret": {"kind": "scalar"} | {"kind": "sret", "sname", "align"}
           | {"kind": "struct_reg", "sname", "coerce", "safe"}
  - "sret": True when the return is MEMORY class; the hidden sret pointer
    is argument 0 and every parameter "argpos" is already shifted by one
  - "sig": the expanded LLVM argument slots, one per actual argument:
      ("sretptr", sname) | ("structptr", sname) | ("coerce", ir.Type)
      | ("scalar", param_index)
    Struct pointer slots are left symbolic: identified struct types are
    LLVM-module-context-bound, so the backend materializes them. Scalar
    slots reference the declared parameter by index for the same reason
    (scalar lowering consults the checker-typed annotation).
  - "sig_ret": ("void",) | ("coerce", [pieces]) | ("scalar",)
"""
def classify_foreign_fn(
    structs: dict, params: list, ret_tname: (str | None), triple: str
) -> (dict | None) {
    import from jaclang.compiler.targets.foreign { foreign_struct_layout }
    has_struct = ret_tname is not None and ret_tname in structs;
    for (_pn, _tn) in params {
        if _tn is not None and _tn in structs {
            has_struct = True;
        }
    }
    if not has_struct {
        return None;
    }
    sig: list = [];
    param_plan: list = [];
    for (i, (pname, tname)) in enumerate(params) {
        pn = pname or f"arg{i}";
        if tname is not None and tname in structs {
            (sz, al, leaves) = foreign_struct_layout(structs, tname);
            cls = classify_struct(sz, al, leaves, triple);
            if cls["memory"] {
                param_plan.append(
                    {
                        "kind": "struct_mem",
                        "sname": tname,
                        "pname": pn,
                        "align": cls["align"],
                        "byval": cls["byval"],
                        "argpos": len(sig)
                    }
                );
                sig.append(("structptr", tname));
            } else {
                start = len(sig);
                for ct in cls["coerce"] {
                    sig.append(("coerce", ct));
                }
                param_plan.append(
                    {
                        "kind": "struct_reg",
                        "sname": tname,
                        "pname": pn,
                        "coerce": cls["coerce"],
                        "safe": cls["safe"],
                        "argpos": start
                    }
                );
            }
        } else {
            param_plan.append(
                {"kind": "scalar", "tname": tname, "pname": pn, "argpos": len(sig)}
            );
            sig.append(("scalar", i));
        }
    }
    sret = False;
    sig_ret: tuple = ("scalar", );
    ret_plan: dict = {"kind": "scalar"};
    if ret_tname is not None and ret_tname in structs {
        (rsz, ral, rleaves) = foreign_struct_layout(structs, ret_tname);
        rcls = classify_struct(rsz, ral, rleaves, triple);
        if rcls["memory"] {
            sret = True;
            sig_ret = ("void", );
            sig = [("sretptr", ret_tname)] + sig;
            for pp in param_plan {
                pp["argpos"] += 1;
            }
            ret_plan = {"kind": "sret", "sname": ret_tname, "align": rcls["align"]};
        } else {
            sig_ret = ("coerce", rcls["coerce"]);
            ret_plan = {
                "kind": "struct_reg",
                "sname": ret_tname,
                "coerce": rcls["coerce"],
                "safe": rcls["safe"]
            };
        }
    }
    return {
        "params": param_plan,
        "ret": ret_plan,
        "sret": sret,
        "sig": sig,
        "sig_ret": sig_ret
    };
}

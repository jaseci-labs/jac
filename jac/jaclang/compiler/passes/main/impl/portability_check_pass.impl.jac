"""Portability check pass implementation."""

# JS-specific globals and their Jac alternatives
glob JS_GLOBALS: dict[str, str] = {
         "console": "print()",
         "Math": "Jac builtins (abs, round, min, max, pow, etc.)",
         "JSON": "Jac serialization primitives",
         "Array": "list",
         "Object": "dict",
         "Map": "dict",
         "Set": "set",
         "Promise": "async/await",
         "setTimeout": "async patterns",
         "setInterval": "async patterns",
         "clearTimeout": "async patterns",
         "clearInterval": "async patterns",
         "fetch": "Jac HTTP primitives",
         "document": "Jac DOM abstractions",
         "window": "Jac platform abstractions",
         "Buffer": "bytes",
         "Symbol": "Jac types",
         "WeakMap": "dict",
         "WeakSet": "set",
         "RegExp": "str methods or re module",
         "Infinity": "float('inf')",
         "NaN": "float('nan')"
     },
     # JS-idiomatic methods and their Jac alternatives
     JS_METHODS: dict[str, str] = {
         "push": ".append()",
         "forEach": "for loop",
         "indexOf": ".index() or 'in' operator",
         "lastIndexOf": ".index() with reverse",
         "splice": "slice assignment",
         "unshift": ".insert(0, val)",
         "shift": ".pop(0)",
         "includes": "'in' operator",
         "findIndex": "enumerate() with condition",
         "find": "next() with generator",
         "every": "all()",
         "some": "any()",
         "flat": "list flattening",
         "flatMap": "list comprehension",
         "fill": "list multiplication or comprehension",
         "from": "list()",
         "isArray": "isinstance(x, list)",
         "charAt": "string indexing s[i]",
         "charCodeAt": "ord()",
         "fromCharCode": "chr()",
         "substring": "string slicing s[a:b]",
         "substr": "string slicing s[a:a+n]",
         "slice": "slicing [a:b]",
         "padStart": ".rjust() or .zfill()",
         "padEnd": ".ljust()",
         "trimStart": ".lstrip()",
         "trimEnd": ".rstrip()",
         "trim": ".strip()",
         "repeat": "'str * n'",
         "replaceAll": ".replace()",
         "toFixed": "format() or round()",
         "toPrecision": "format()",
         "toString": "str()",
         "parseInt": "int()",
         "parseFloat": "float()",
         "hasOwnProperty": "hasattr() or 'in' operator",
         "assign": "dict unpacking {**a, **b}",
         "freeze": "frozenset or tuple",
         "stringify": "str() or json.dumps()",
         "parse": "json.loads()"
     },
     # JS-specific keywords/identifiers that may appear as bare names
     JS_KEYWORDS: dict[str, str] = {
         "undefined": "None",
         "typeof": "type()",
         "void": "None"
     },
     # JS-specific property accesses and their alternatives
     JS_PROPERTIES: dict[str, str] = {
         "length": "len()",
         "prototype": "Jac inheritance",
         "constructor": "type() or __init__",
         "__proto__": "Jac inheritance"
     };


impl PortabilityCheckPass.postinit -> None {
    super.postinit();
}

"""Run all portability checks via bulk sub-node queries (no tree traversal).

Warnings fire in ALL contexts (server, client, native) because Jac idioms
are the preferred style everywhere. The ES backend translates Jac idioms
to their JS equivalents, so there is no reason to use JS-specific patterns
even in cl {} blocks.
"""
impl PortabilityCheckPass.transform(ir_in: uni.Module) -> uni.Module {
    self._check_js_globals(self.ir_in);
    self._check_js_methods(self.ir_in);
    self._check_js_keywords(self.ir_in);
    self._check_js_properties(self.ir_in);
    for annex_mod in self.ir_in.impl_mod + self.ir_in.test_mod + self.ir_in.variant_mod {
        self._check_js_globals(annex_mod);
        self._check_js_methods(annex_mod);
        self._check_js_keywords(annex_mod);
        self._check_js_properties(annex_mod);
    }
    return ir_in;
}

"""Detect usage of JS-specific global objects (console, Math, JSON, etc.)."""
impl PortabilityCheckPass._check_js_globals(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name, brute_force=True);
    for name_nd in all_names {
        # Only check name usage (Load context), not definitions
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip if the name resolved to a user-defined symbol
        if name_nd.sym is not None {
            continue;
        }
        # Skip names inside import statements
        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }
        if name_nd.value in JS_GLOBALS {
            self.emit(
                W6001,
                node_override=name_nd,
                name=name_nd.value,
                alternative=JS_GLOBALS[name_nd.value]
            );
        }
    }
}

"""Detect usage of JS-idiomatic method calls (.push, .forEach, .indexOf, etc.)."""
impl PortabilityCheckPass._check_js_methods(mod: uni.Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=uni.AtomTrailer, brute_force=True);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }
        # Check if the right side is a Name that matches a JS method
        if not isinstance(trailer.right, uni.Name) {
            continue;
        }
        method_name = trailer.right.value;
        if method_name not in JS_METHODS {
            continue;
        }
        # Check if this attribute access is the target of a function call
        # (i.e., it's actually being called as a method)
        parent = trailer.parent;
        is_method_call = isinstance(parent, uni.FuncCall) and parent.target is trailer;
        # Only warn if actually called as a method
        if is_method_call {
            self.emit(
                W6002,
                node_override=trailer.right,
                method=method_name,
                alternative=JS_METHODS[method_name]
            );
        }
    }
}

"""Detect usage of JS-specific keywords used as identifiers (undefined, typeof, etc.)."""
impl PortabilityCheckPass._check_js_keywords(mod: uni.Module) -> None {
    import ast as ast3;
    all_names = mod.get_all_sub_nodes(typ=uni.Name, brute_force=True);
    for name_nd in all_names {
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip if the name resolved to a user-defined symbol
        if name_nd.sym is not None {
            continue;
        }
        # Skip names inside import statements
        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }
        # Skip attribute access right-hand side (x.undefined is fine as a field name)
        parent = name_nd.parent;
        if isinstance(parent, uni.AtomTrailer)
        and parent.is_attr
        and parent.right is name_nd {
            continue;
        }
        if name_nd.value in JS_KEYWORDS {
            self.emit(
                W6003,
                node_override=name_nd,
                name=name_nd.value,
                alternative=JS_KEYWORDS[name_nd.value]
            );
        }
    }
}

"""Detect usage of JS-specific property access (.length instead of len(), etc.)."""
impl PortabilityCheckPass._check_js_properties(mod: uni.Module) -> None {
    all_trailers = mod.get_all_sub_nodes(typ=uni.AtomTrailer, brute_force=True);
    for trailer in all_trailers {
        if not trailer.is_attr {
            continue;
        }
        if not isinstance(trailer.right, uni.Name) {
            continue;
        }
        prop_name = trailer.right.value;
        if prop_name not in JS_PROPERTIES {
            continue;
        }
        # Make sure this is a property access, not a method call
        parent = trailer.parent;
        is_call = isinstance(parent, uni.FuncCall) and parent.target is trailer;
        if not is_call {
            self.emit(
                W6004,
                node_override=trailer.right,
                prop=prop_name,
                alternative=JS_PROPERTIES[prop_name]
            );
        }
    }
}

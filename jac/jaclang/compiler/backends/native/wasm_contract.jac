import from jaclang.compiler.frontend.unitree { Ability, FuncSignature, UnaryExpr }
import from jaclang.compiler.frontend.constant { OwnershipKind }

def value_contract(expr: any, ownership: OwnershipKind = OwnershipKind.NONE) -> dict {
    if isinstance(expr, UnaryExpr) and expr.ownership != OwnershipKind.NONE {
        ownership = expr.ownership;
        expr = expr.operand;
    }
    name = expr.unparse().strip() if expr is not None else "None";
    mode = {
        OwnershipKind.NONE: "value", OwnershipKind.OWN: "own",
        OwnershipKind.BORROW: "borrow", OwnershipKind.MUT_BORROW: "borrow_mut",
        OwnershipKind.IMM: "borrow"
    }[ownership];
    primitives = {"int", "float", "bool", "None", "i8", "u8", "i16", "u16",
                  "i32", "u32", "i64", "u64", "f32", "f64"};
    if name in primitives {
        return {"type": name, "mode": mode, "kind": "scalar"};
    }
    if mode == "value" {
        raise ValueError(f"Wasm boundary type '{name}' requires an explicit ownership contract");
    }
    return {"type": name, "mode": mode, "kind": "handle"};
}

def function_contract(decl: Ability) -> dict {
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        raise ValueError("Wasm exports require a function signature");
    }
    params: list[dict] = [];
    for p in sig.get_parameters() {
        if p.type_tag is None {
            raise ValueError(f"Wasm parameter '{p.sym_name}' requires a type");
        }
        value = value_contract(p.type_tag.tag, p.type_tag.ownership);
        value["name"] = p.sym_name;
        params.append(value);
    }
    return {"params": params, "result": value_contract(sig.return_type)};
}

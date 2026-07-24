"""Dicts with distinct pointer value types in one module (#7626 C7).

The registry shape that demoted type_registry.jac: one archetype holding a
dict[str, Obj] field next to a dict[str, str | None] field. The dict helper
family used to be cached per "str:ptr" name while its LLVM signature was built
from whichever pointer-valued dict was emitted first, so the second dict's
stores raised a raw llvmlite TypeError and demoted the whole module.
"""

obj Entry {
    has name: str,
        suffix: str,
        spec: str | None = None;
}

obj Reg {
    has entries: dict[str, Entry],
        parents: dict[str, str | None];

    def get(name: str) -> Entry | None {
        return self.entries.get(name, None);
    }

    def parent_of(name: str) -> str | None {
        return self.parents.get(name, None);
    }
}

def _mk_reg -> Reg {
    return Reg(
        entries={
            "int": Entry(name="int", suffix="Int", spec="i64"),
            "str": Entry(name="str", suffix="Str", spec="i8*"),
            "list": Entry(name="list", suffix="List")
        },
        parents={"BaseException": None, "Exception": "BaseException"}
    );
}

def dict_struct_vals_py -> dict {
    reg = _mk_reg();
    e = reg.get("int");
    missing = reg.get("nope");
    espec = "" if e is None else (e.spec or "");
    listspec = "unset";
    le = reg.get("list");
    if le is not None and le.spec is None {
        listspec = "none";
    }
    base_par = reg.parent_of("BaseException");
    exc_par = reg.parent_of("Exception");
    return {
        "int_suffix": "" if e is None else e.suffix,
        "int_spec": espec,
        "missing_is_none": missing is None,
        "list_spec_none": listspec,
        "base_parent_none": base_par is None,
        "exc_parent": exc_par or "",
        "n_entries": len(reg.entries),
        "n_parents": len(reg.parents),

    };
}

cl def dict_struct_vals_cl -> dict {
    return {};
}

na {
    def _mk_reg_na -> Reg {
        return Reg(
            entries={
                "int": Entry(name="int", suffix="Int", spec="i64"),
                "str": Entry(name="str", suffix="Str", spec="i8*"),
                "list": Entry(name="list", suffix="List")
            },
            parents={"BaseException": None, "Exception": "BaseException"}
        );
    }

    def dict_struct_vals_na -> dict[str, any] {
        reg = _mk_reg_na();
        e = reg.get("int");
        missing = reg.get("nope");
        espec = "" if e is None else (e.spec or "");
        listspec = "unset";
        le = reg.get("list");
        if le is not None and le.spec is None {
            listspec = "none";
        }
        base_par = reg.parent_of("BaseException");
        exc_par = reg.parent_of("Exception");
        return {
            "int_suffix": "" if e is None else e.suffix,
            "int_spec": espec,
            "missing_is_none": missing is None,
            "list_spec_none": listspec,
            "base_parent_none": base_par is None,
            "exc_parent": exc_par or "",
            "n_entries": len(reg.entries),
            "n_parents": len(reg.parents),

        };
    }
}

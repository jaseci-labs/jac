import json;
import re;
import from jaclang.compiler.backends.native.llvm { ir }
import type from jaclang.compiler.backends.native.llvm.binding {
    ModuleRef,
    TargetMachine,
    ValueRef
}

enum NativeLoweringKind { CALLABLE = "callable", FIELD = "field" }

def prepare_native_library(
    module: ModuleRef, target: TargetMachine, exports: set[str]
) {
    import from collections.abc { Iterator }
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    functions = module.functions;
    globals = module.global_variables;
    assert isinstance(functions, Iterator);
    assert isinstance(globals, Iterator);
    members: list[ValueRef] = list(functions) + list(globals);
    defined = {
        str(member.name)
        for member in members
        if not member.is_declaration
    };
    missing = exports - defined;
    if missing {
        raise ValueError(
            "Native library exports have no definitions: " + ", ".join(sorted(missing))
        );
    }
    issues = native_lowering_issues(str(module));
    failed: set[str] = set();
    candidates: dict[str, str] = {};
    for issue in issues {
        if issue.kind == NativeLoweringKind.FIELD {
            failed.add(issue.symbol);
            continue;
        }
        symbol = issue.symbol;
        actual = symbol if symbol in defined else symbol + ".__jac_demoted";
        if actual not in defined {
            failed.add(symbol);
        } else {
            candidates[actual] = symbol;
        }
    }
    for member in members {
        name = str(member.name);
        if name.endswith(".__jac_demoted") {
            candidates[name] = name[:-len(".__jac_demoted")];
        }
    }
    for member in members {
        name = str(member.name);
        if not member.is_declaration
            and name not in exports
            and not name.startswith("llvm.") {
            member.linkage = "internal";
        }
    }
    tuning = llvm.create_pipeline_tuning_options(speed_level=0);
    builder = llvm.create_pass_builder(target, tuning);
    manager = llvm.ModulePassManager();
    manager.add_global_dead_code_eliminate_pass();
    manager.run(module, builder);
    remaining = module.functions;
    assert isinstance(remaining, Iterator);
    for function in remaining {
        name = str(function.name);
        if name in candidates {
            failed.add(candidates[name]);
        }
    }
    if failed {
        raise ValueError(
            "Incomplete native library closure: " + ", ".join(sorted(failed))
        );
    }
    module.verify();
}

obj NativeLoweringIssue {
    has symbol: str,
        kind: NativeLoweringKind,
        source: str,
        code: str,
        detail: str;

    def record(module: ir.Module) {
        payload = json.dumps(
            [self.symbol, self.kind.value, self.source, self.code, self.detail],
            ensure_ascii=True
        ).encode(
            "utf-8"
        ).hex();
        module.add_named_metadata("jac.native.lowering.v1", [payload]);
    }
}

def native_lowering_issues(llvm_ir_text: str) -> list[NativeLoweringIssue] {
    """Read only records referenced by the versioned native metadata schema.

    Hex encodes the JSON payload so LLVM string escaping and metadata number
    renumbering during linking cannot change its content. Malformed metadata is
    an error, never evidence that a strict compilation succeeded.
    """;
    roots = re.findall(
        r'^!jac\.native\.lowering\.v1\s*=\s*!\{([^}]*)\}', llvm_ir_text, re.MULTILINE
    );
    if not roots {
        return [];
    }
    definitions = dict(
        re.findall(
            r'^!(\d+)\s*=\s*!\{\s*!"([0-9a-f]+)"\s*\}', llvm_ir_text, re.MULTILINE
        )
    );
    issues: list[NativeLoweringIssue] = [];
    seen: set[str] = set();
    for references in roots {
        for key in re.findall(r'!(\d+)', references) {
            payload = definitions[key];
            if payload in seen {
                continue;
            }
            seen.add(payload);
            values = json.loads(bytes.fromhex(payload).decode("utf-8"));
            if not isinstance(values, list)
                or len(values) != 5
                or not all(isinstance(value, str) for value in values) {
                raise ValueError("Invalid native lowering metadata");
            }
            issues.append(
                NativeLoweringIssue(
                    symbol=values[0],
                    kind=NativeLoweringKind(values[1]),
                    source=values[2],
                    code=values[3],
                    detail=values[4]
                )
            );
        }
    }
    return issues;
}

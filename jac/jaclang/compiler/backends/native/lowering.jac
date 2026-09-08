import json;
import re;
import from jaclang.compiler.backends.native.llvm { ir }

enum NativeLoweringKind { CALLABLE = "callable", FIELD = "field" }

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

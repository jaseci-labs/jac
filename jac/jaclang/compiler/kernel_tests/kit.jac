"""What kernel test cases analyse with. A source is written into the running
case's scratch directory and compiled by a fresh program under a fresh project
host, the way a compile request is; parsing alone uses the parser directly, and
lowering runs the decision step with no emission."""
import os;

obj Analysis {
    has program: JacProgram,
        module: uni.Module,
        path: str;

    def error_codes -> list[str] {
        return [
            alert.code.code
            for alert in self.program.errors_had
            if alert.code is not None
        ];
    }

    def warning_codes -> list[str] {
        return [
            alert.code.code
            for alert in self.program.warnings_had
            if alert.code is not None
        ];
    }

    def messages -> list[str] {
        return [alert.pretty_print() for alert in self.program.errors_had];
    }
}

obj Lowered {
    has lowering: MirLowering,
        mir: MirModule;

    def symbol_of(name: str) -> str {
        for decl in self.lowering.decls.values() {
            if self.lowering.name_of(decl.ability) == name {
                return decl.symbol;
            }
        }
        raise AssertionError(f"the module declares no function named '{name}'");
    }

    def demoted(name: str) -> bool {
        return self.symbol_of(name) in self.mir.demoted;
    }

    def reason(name: str) -> str {
        symbol = self.symbol_of(name);
        if symbol not in self.mir.demoted {
            raise AssertionError(f"'{name}' was not demoted");
        }
        return self.mir.demoted[symbol];
    }
}

def write_source(name: str, text: str) -> str {
    path = os.path.join(case_scratch(), name);
    with open(path, "w", encoding="utf-8") as handle {
        handle.write(text);
    }
    return os.path.realpath(path);
}

def analyse(
    text: str, name: str = "case.jac", options: (CompileOptions | None) = None
) -> Analysis {
    path = write_source(name, text);
    host = ProjectHost(root=case_scratch());
    install_host(host);
    program = JacProgram();
    with host.session() {
        module = program.compile(
            path, options=options if options is not None else CompileOptions(no_cgen=True)
        );
    }
    return Analysis(program=program, module=module, path=path);
}

def parse_text(text: str, name: str = "case.jac") -> uni.Module {
    path = os.path.join(case_scratch(), name);
    (module, had_error) = parse(text, path, prog=JacProgram());
    if had_error {
        raise AssertionError(f"the case source did not parse: {text!r}");
    }
    return module;
}

def lower_text(text: str, name: str = "case.jac") -> Lowered {
    analysis = analyse(
        text,
        name,
        CompileOptions(
            force_codespace="native", skip_native_engine=True, aot_mode=True
        )
    );
    if analysis.program.errors_had {
        raise AssertionError(
            "the case source did not analyse: " + "\n".join(analysis.messages())
        );
    }
    lowering = MirLowering(
        prog=analysis.program,
        module=analysis.module,
        mir=MirModule(path=analysis.path, prefix=native_unit_prefix(analysis.path))
    );
    return Lowered(lowering=lowering, mir=lowering.lower());
}

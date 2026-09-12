import from jaclang.compiler.pipeline.keys { SPACES }
import from jaclang.compiler.pipeline.keys { PLACEMENT_SUMMARY }
import os;
import from jaclang.compiler.pipeline.program_pass { ProgramTransform, QueryTransform }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.analysis.placement.products {
    NativeEligibility,
    PlacementSpaces
}
import from jaclang.compiler.ir.enums { CodeContext }

walker PlacementSummaryPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.placement.evidence { summarize_module }
        key = os.path.abspath(ir_in.loc.mod_path)
            if ir_in.loc.mod_path
            else f'@{id(ir_in)}';
        self.prog.analysis.publish(key, PLACEMENT_SUMMARY, summarize_module(ir_in));
        return ir_in;
    }
}

walker ProgramPlacementPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.placement.solver {
            refresh_placement_module,
            solve_program_placement
        }
        refresh_placement_module(ir_in, self.prog);
        solve_program_placement(ir_in, self.prog);
        return ir_in;
    }
}

walker PlacementSpacesPass(ProgramTransform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.binding.module_facts { ModuleFacts }
        facts = PlacementSpaces();
        facts.native_module = ir_in.declares_codespace(
            CodeContext.NATIVE, path_hint=ir_in.loc.mod_path
        );
        facts.has_native = ModuleFacts.has_native_context_stmts(ir_in);
        for stmt in ir_in.body {
            if isinstance(stmt, uni.ContextAwareNode) {
                facts.spaces.add(stmt.code_context);
            }
        }
        if not facts.spaces {
            facts.spaces.add(CodeContext.SERVER);
        }
        self.prog.analysis.publish(ir_in.loc.mod_path, SPACES, facts);
        return ir_in;
    }
}

walker NativeEligibilityPass(QueryTransform[NativeEligibility]) {
    has hold_exempt: bool = False,
        result: NativeEligibility = NativeEligibility();

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.placement.evidence {
            scan_native_blockers
        }
        (reason, dependencies) = scan_native_blockers(
            ir_in,
            os.path.dirname(os.path.abspath(ir_in.loc.mod_path)),
            allow_pub=True,
            hold_exempt=self.hold_exempt,
            classify_imports=True
        );
        self.result = NativeEligibility(reason, dependencies);
        return ir_in;
    }
}

walker NativeClosurePass(QueryTransform[bool]) {
    has dependencies: list[str],
        hold_exempt: bool = False,
        result: bool = True;

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.session.target_options {
            effective_native_closure_cap
        }
        import from jaclang.compiler.analysis.placement.native_fallback {
            _note_native_closure_cap
        }
        import from jaclang.compiler.bootstrap.native_scope {
            in_native_scope_path,
            scope_lowering_active
        }
        import from jaclang.compiler.api { native_dependency_facts }
        path = ir_in.loc.mod_path;
        seen: set[str] = {path};
        pending = list(self.dependencies);
        cap = effective_native_closure_cap();
        while pending {
            if len(seen) > cap {
                _note_native_closure_cap(path, cap);
                self.result = False;
                break;
            }
            target = pending.pop();
            if target in seen {
                continue;
            }
            if in_native_scope_path(target) and not scope_lowering_active() {
                self.result = False;
                break;
            }
            facts = native_dependency_facts(self.prog, target, self.hold_exempt);
            if facts.reason {
                self.result = False;
                break;
            }
            seen.add(target);
            pending.extend(facts.dependencies);
        }
        return ir_in;
    }
}

walker PlacementReportPass(QueryTransform[dict]) {
    has result: dict = {};

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.analysis.placement.evidence {
            _collect_placement_rows
        }
        self.result = _collect_placement_rows(self.prog);
        return ir_in;
    }
}

walker NativeDemotionPass(QueryTransform[bool]) {
    has path: str,
        result: bool = True;

    def transform(ir_in: uni.Module) -> uni.Module {
        import from jaclang.compiler.pipeline.products { invalidate_client_product }
        import from jaclang.compiler.analysis.placement.native_fallback {
            _drop_demoted_native_bindings
        }
        for importer in self.prog.deps.dependents.get(
            os.path.realpath(self.path), set()
        ) {
            module = self.prog.find_module(importer);
            if module is not None {
                invalidate_client_product(self.prog, module);
                _drop_demoted_native_bindings(module, self.path);
            }
        }
        return ir_in;
    }
}

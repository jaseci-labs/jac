impl SourceSpan.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "line": self.line,
        "col": self.col,
        "end_line": self.end_line,
        "end_col": self.end_col
    };
}

impl SourceSpan.from_dict(raw: dict[str, any]) -> SourceSpan {
    return SourceSpan(
        path=str(raw["path"]),
        line=int(raw["line"]),
        col=int(raw["col"]),
        end_line=int(raw["end_line"]),
        end_col=int(raw["end_col"])
    );
}

impl RelatedNote.to_dict -> dict[str, any] {
    return {
        "label": self.label,
        "span": self.span.to_dict()
    };
}

impl RelatedNote.from_dict(raw: dict[str, any]) -> RelatedNote {
    return RelatedNote(
        label=str(raw["label"]),
        span=SourceSpan.from_dict(raw["span"])
    );
}

impl KernelDiagnostic.to_dict -> dict[str, any] {
    return {
        "code": self.code,
        "severity": self.severity,
        "message": self.message,
        "span": self.span.to_dict(),
        "help": self.help,
        "pass_name": self.pass_name,
        "related": [item.to_dict() for item in self.related]
    };
}

impl KernelDiagnostic.from_dict(raw: dict[str, any]) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=str(raw["code"]),
        severity=str(raw["severity"]),
        message=str(raw["message"]),
        span=SourceSpan.from_dict(raw["span"]),
        help=str(raw["help"]),
        pass_name=str(raw["pass_name"]),
        related=[RelatedNote.from_dict(item) for item in raw["related"]]
    );
}

impl NativeDemotion.to_dict -> dict[str, any] {
    return {
        "symbol": self.symbol,
        "kind": self.kind,
        "reason": self.reason,
        "code": self.code,
        "span": self.span.to_dict()
    };
}

impl NativeDemotion.from_dict(raw: dict[str, any]) -> NativeDemotion {
    return NativeDemotion(
        symbol=str(raw["symbol"]),
        kind=str(raw["kind"]),
        reason=str(raw["reason"]),
        code=str(raw["code"]),
        span=SourceSpan.from_dict(raw["span"])
    );
}

impl CompiledUnit.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "module_name": self.module_name,
        "bytecode": self.bytecode,
        "python_source": self.python_source,
        "interface": self.interface,
        "placement": self.placement,
        "client_js": self.client_js,
        "native_object": self.native_object,
        "native_iface": self.native_iface,
        "native_deps": list(self.native_deps),
        "native_ir": self.native_ir,
        "native_layout": self.native_layout,
        "demoted": [item.to_dict() for item in self.demoted],
        "jac_deps": list(self.jac_deps),
        "app": self.app,
        "persistence": list(self.persistence),
        "import_edges": list(self.import_edges),
        "interop": self.interop,
        "client_manifest": self.client_manifest,
        "iface_shape": self.iface_shape,
        "effects": self.effects,
        "sections": dict(self.sections)
    };
}

impl CompiledUnit.from_dict(raw: dict[str, any]) -> CompiledUnit {
    return CompiledUnit(
        path=str(raw["path"]),
        module_name=str(raw["module_name"]),
        bytecode=bytes(raw["bytecode"]),
        python_source=str(raw["python_source"]),
        interface=bytes(raw["interface"]),
        placement=str(raw["placement"]),
        client_js=str(raw["client_js"]),
        native_object=bytes(raw["native_object"]),
        native_iface=str(raw["native_iface"]),
        native_deps=[str(item) for item in raw["native_deps"]],
        native_ir=str(raw["native_ir"]),
        native_layout=str(raw["native_layout"]),
        demoted=[NativeDemotion.from_dict(item) for item in raw["demoted"]],
        jac_deps=[str(item) for item in raw["jac_deps"]],
        app=str(raw["app"]),
        persistence=[str(item) for item in raw["persistence"]],
        import_edges=[str(item) for item in raw["import_edges"]],
        interop=str(raw["interop"]),
        client_manifest=str(raw["client_manifest"]),
        iface_shape=str(raw["iface_shape"]),
        effects=str(raw["effects"]),
        sections=dict(raw["sections"])
    );
}

impl CompileRequest.to_dict -> dict[str, any] {
    return {
        "paths": list(self.paths),
        "project_root": self.project_root,
        "search_paths": list(self.search_paths),
        "package_root": self.package_root,
        "options": self.options.to_dict(),
        "sources": dict(self.sources),
        "products": list(self.products)
    };
}

impl CompileRequest.from_dict(raw: dict[str, any]) -> CompileRequest {
    return CompileRequest(
        paths=[str(item) for item in raw["paths"]],
        project_root=str(raw["project_root"]),
        search_paths=[str(item) for item in raw["search_paths"]],
        package_root=str(raw["package_root"]),
        options=CompileOptions.from_dict(raw["options"]),
        sources=dict(raw["sources"]),
        products=[str(item) for item in raw["products"]]
    );
}

impl SourceRead.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "digest": self.digest
    };
}

impl SourceRead.from_dict(raw: dict[str, any]) -> SourceRead {
    return SourceRead(
        path=str(raw["path"]),
        digest=str(raw["digest"])
    );
}

impl CompileResult.to_dict -> dict[str, any] {
    return {
        "units": [item.to_dict() for item in self.units],
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings],
        "reached": list(self.reached),
        "reads": [item.to_dict() for item in self.reads]
    };
}

impl CompileResult.from_dict(raw: dict[str, any]) -> CompileResult {
    return CompileResult(
        units=[CompiledUnit.from_dict(item) for item in raw["units"]],
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]],
        reached=[str(item) for item in raw["reached"]],
        reads=[SourceRead.from_dict(item) for item in raw["reads"]]
    );
}

impl CoverageRow.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "outcome": self.outcome,
        "code": self.code,
        "detail": self.detail,
        "seams": list(self.seams),
        "late": self.late
    };
}

impl CoverageRow.from_dict(raw: dict[str, any]) -> CoverageRow {
    return CoverageRow(
        path=str(raw["path"]),
        outcome=str(raw["outcome"]),
        code=str(raw["code"]),
        detail=str(raw["detail"]),
        seams=[str(item) for item in raw["seams"]],
        late=int(raw["late"])
    );
}

impl PlacementRow.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "symbol": self.symbol,
        "placement": self.placement,
        "reason": self.reason
    };
}

impl PlacementRow.from_dict(raw: dict[str, any]) -> PlacementRow {
    return PlacementRow(
        path=str(raw["path"]),
        symbol=str(raw["symbol"]),
        placement=str(raw["placement"]),
        reason=str(raw["reason"])
    );
}

impl CheckRequest.to_dict -> dict[str, any] {
    return {
        "paths": list(self.paths),
        "project_root": self.project_root,
        "search_paths": list(self.search_paths),
        "package_root": self.package_root,
        "options": self.options.to_dict(),
        "sources": dict(self.sources),
        "native_coverage": self.native_coverage,
        "placements": self.placements,
        "closure": self.closure,
        "module_facts": self.module_facts
    };
}

impl CheckRequest.from_dict(raw: dict[str, any]) -> CheckRequest {
    return CheckRequest(
        paths=[str(item) for item in raw["paths"]],
        project_root=str(raw["project_root"]),
        search_paths=[str(item) for item in raw["search_paths"]],
        package_root=str(raw["package_root"]),
        options=CompileOptions.from_dict(raw["options"]),
        sources=dict(raw["sources"]),
        native_coverage=bool(raw["native_coverage"]),
        placements=bool(raw["placements"]),
        closure=bool(raw["closure"]),
        module_facts=bool(raw["module_facts"])
    );
}

impl ModuleFact.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "app": self.app,
        "spaces": list(self.spaces),
        "decided": self.decided,
        "client_declared": self.client_declared,
        "errors": self.errors,
        "imports": list(self.imports)
    };
}

impl ModuleFact.from_dict(raw: dict[str, any]) -> ModuleFact {
    return ModuleFact(
        path=str(raw["path"]),
        app=str(raw["app"]),
        spaces=[str(item) for item in raw["spaces"]],
        decided=str(raw["decided"]),
        client_declared=bool(raw["client_declared"]),
        errors=int(raw["errors"]),
        imports=[str(item) for item in raw["imports"]]
    );
}

impl AppEdge.to_dict -> dict[str, any] {
    return {
        "consumer": self.consumer,
        "provider": self.provider
    };
}

impl AppEdge.from_dict(raw: dict[str, any]) -> AppEdge {
    return AppEdge(
        consumer=str(raw["consumer"]),
        provider=str(raw["provider"])
    );
}

impl CheckResult.to_dict -> dict[str, any] {
    return {
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings],
        "reached": list(self.reached),
        "coverage": [item.to_dict() for item in self.coverage],
        "placements": [item.to_dict() for item in self.placements],
        "modules": [item.to_dict() for item in self.modules],
        "app_edges": [item.to_dict() for item in self.app_edges]
    };
}

impl CheckResult.from_dict(raw: dict[str, any]) -> CheckResult {
    return CheckResult(
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]],
        reached=[str(item) for item in raw["reached"]],
        coverage=[CoverageRow.from_dict(item) for item in raw["coverage"]],
        placements=[PlacementRow.from_dict(item) for item in raw["placements"]],
        modules=[ModuleFact.from_dict(item) for item in raw["modules"]],
        app_edges=[AppEdge.from_dict(item) for item in raw["app_edges"]]
    );
}

impl NativeBuildRequest.to_dict -> dict[str, any] {
    return {
        "roots": list(self.roots),
        "kind": self.kind,
        "output": self.output,
        "project_root": self.project_root,
        "search_paths": list(self.search_paths),
        "package_root": self.package_root,
        "options": self.options.to_dict(),
        "link_mode": self.link_mode,
        "native_unit": self.native_unit,
        "library_api": self.library_api,
        "callbacks": self.callbacks,
        "emit_c": self.emit_c,
        "refuse_python_imports": self.refuse_python_imports,
        "refuse_demoted": self.refuse_demoted,
        "require_entry": self.require_entry,
        "kernel_entries": self.kernel_entries,
        "assert_no_rc": self.assert_no_rc
    };
}

impl NativeBuildRequest.from_dict(raw: dict[str, any]) -> NativeBuildRequest {
    return NativeBuildRequest(
        roots=[str(item) for item in raw["roots"]],
        kind=str(raw["kind"]),
        output=str(raw["output"]),
        project_root=str(raw["project_root"]),
        search_paths=[str(item) for item in raw["search_paths"]],
        package_root=str(raw["package_root"]),
        options=CompileOptions.from_dict(raw["options"]),
        link_mode=str(raw["link_mode"]),
        native_unit=bool(raw["native_unit"]),
        library_api=bool(raw["library_api"]),
        callbacks=bool(raw["callbacks"]),
        emit_c=bool(raw["emit_c"]),
        refuse_python_imports=bool(raw["refuse_python_imports"]),
        refuse_demoted=bool(raw["refuse_demoted"]),
        require_entry=bool(raw["require_entry"]),
        kernel_entries=bool(raw["kernel_entries"]),
        assert_no_rc=bool(raw["assert_no_rc"])
    );
}

impl LinkedUnit.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "digest": self.digest,
        "stamp": self.stamp.to_dict()
    };
}

impl LinkedUnit.from_dict(raw: dict[str, any]) -> LinkedUnit {
    return LinkedUnit(
        path=str(raw["path"]),
        digest=str(raw["digest"]),
        stamp=NativeStamp.from_dict(raw["stamp"])
    );
}

impl CallbackBinding.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "symbol": self.symbol,
        "ret_type": self.ret_type,
        "param_types": list(self.param_types)
    };
}

impl CallbackBinding.from_dict(raw: dict[str, any]) -> CallbackBinding {
    return CallbackBinding(
        name=str(raw["name"]),
        symbol=str(raw["symbol"]),
        ret_type=str(raw["ret_type"]),
        param_types=[str(item) for item in raw["param_types"]]
    );
}

impl NativeBuildResult.to_dict -> dict[str, any] {
    return {
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings],
        "linked": self.linked,
        "reused": self.reused,
        "output": self.output,
        "mode": self.mode,
        "triple": self.triple,
        "units": [item.to_dict() for item in self.units],
        "recompiled": self.recompiled,
        "analysed": self.analysed,
        "lowered": self.lowered,
        "generated": self.generated,
        "sha256": self.sha256,
        "plan_digest": self.plan_digest,
        "root_native": self.root_native,
        "has_entry": self.has_entry,
        "python_imports": list(self.python_imports),
        "demoted": list(self.demoted),
        "rc_symbols": list(self.rc_symbols),
        "rc_probes": list(self.rc_probes),
        "libraries": list(self.libraries),
        "callbacks": [item.to_dict() for item in self.callbacks],
        "log": list(self.log)
    };
}

impl NativeBuildResult.from_dict(raw: dict[str, any]) -> NativeBuildResult {
    return NativeBuildResult(
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]],
        linked=bool(raw["linked"]),
        reused=bool(raw["reused"]),
        output=str(raw["output"]),
        mode=str(raw["mode"]),
        triple=str(raw["triple"]),
        units=[LinkedUnit.from_dict(item) for item in raw["units"]],
        recompiled=int(raw["recompiled"]),
        analysed=int(raw["analysed"]),
        lowered=int(raw["lowered"]),
        generated=int(raw["generated"]),
        sha256=str(raw["sha256"]),
        plan_digest=str(raw["plan_digest"]),
        root_native=bool(raw["root_native"]),
        has_entry=bool(raw["has_entry"]),
        python_imports=[str(item) for item in raw["python_imports"]],
        demoted=[str(item) for item in raw["demoted"]],
        rc_symbols=[str(item) for item in raw["rc_symbols"]],
        rc_probes=[str(item) for item in raw["rc_probes"]],
        libraries=[str(item) for item in raw["libraries"]],
        callbacks=[CallbackBinding.from_dict(item) for item in raw["callbacks"]],
        log=[str(item) for item in raw["log"]]
    );
}

impl ElementSpace.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "space": self.space,
        "line": self.line,
        "dual": self.dual
    };
}

impl ElementSpace.from_dict(raw: dict[str, any]) -> ElementSpace {
    return ElementSpace(
        name=str(raw["name"]),
        space=str(raw["space"]),
        line=int(raw["line"]),
        dual=bool(raw["dual"])
    );
}

impl ImportSpace.to_dict -> dict[str, any] {
    return {
        "target": self.target,
        "line": self.line,
        "client_only": self.client_only
    };
}

impl ImportSpace.from_dict(raw: dict[str, any]) -> ImportSpace {
    return ImportSpace(
        target=str(raw["target"]),
        line=int(raw["line"]),
        client_only=bool(raw["client_only"])
    );
}

impl MarkerScan.to_dict -> dict[str, any] {
    return {
        "text": self.text,
        "changed": self.changed,
        "claims": [item.to_dict() for item in self.claims],
        "sv_imports": [item.to_dict() for item in self.sv_imports],
        "note": self.note
    };
}

impl MarkerScan.from_dict(raw: dict[str, any]) -> MarkerScan {
    return MarkerScan(
        text=str(raw["text"]),
        changed=bool(raw["changed"]),
        claims=[ElementSpace.from_dict(item) for item in raw["claims"]],
        sv_imports=[ImportSpace.from_dict(item) for item in raw["sv_imports"]],
        note=str(raw["note"])
    );
}

impl AccessRewrite.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "line": self.line,
        "kind": self.kind,
        "name": self.name,
        "reason": self.reason
    };
}

impl AccessRewrite.from_dict(raw: dict[str, any]) -> AccessRewrite {
    return AccessRewrite(
        path=str(raw["path"]),
        line=int(raw["line"]),
        kind=str(raw["kind"]),
        name=str(raw["name"]),
        reason=str(raw["reason"])
    );
}

impl AccessPlan.to_dict -> dict[str, any] {
    return {
        "rewrites": [item.to_dict() for item in self.rewrites],
        "notes": list(self.notes)
    };
}

impl AccessPlan.from_dict(raw: dict[str, any]) -> AccessPlan {
    return AccessPlan(
        rewrites=[AccessRewrite.from_dict(item) for item in raw["rewrites"]],
        notes=[str(item) for item in raw["notes"]]
    );
}

impl StubCatalogReport.to_dict -> dict[str, any] {
    return {
        "summary": self.summary,
        "load_failures": list(self.load_failures)
    };
}

impl StubCatalogReport.from_dict(raw: dict[str, any]) -> StubCatalogReport {
    return StubCatalogReport(
        summary=str(raw["summary"]),
        load_failures=[str(item) for item in raw["load_failures"]]
    );
}

impl NpmSource.to_dict -> dict[str, any] {
    return {
        "npm_path": self.npm_path,
        "source_path": self.source_path,
        "js": self.js,
        "dts": self.dts,
        "external_imports": list(self.external_imports)
    };
}

impl NpmSource.from_dict(raw: dict[str, any]) -> NpmSource {
    return NpmSource(
        npm_path=str(raw["npm_path"]),
        source_path=str(raw["source_path"]),
        js=str(raw["js"]),
        dts=str(raw["dts"]),
        external_imports=[str(item) for item in raw["external_imports"]]
    );
}

impl TextEdit.to_dict -> dict[str, any] {
    return {
        "span": self.span.to_dict(),
        "text": self.text
    };
}

impl TextEdit.from_dict(raw: dict[str, any]) -> TextEdit {
    return TextEdit(
        span=SourceSpan.from_dict(raw["span"]),
        text=str(raw["text"])
    );
}

impl CompletionItem.to_dict -> dict[str, any] {
    return {
        "label": self.label,
        "kind": self.kind,
        "detail": self.detail,
        "insert_text": self.insert_text
    };
}

impl CompletionItem.from_dict(raw: dict[str, any]) -> CompletionItem {
    return CompletionItem(
        label=str(raw["label"]),
        kind=str(raw["kind"]),
        detail=str(raw["detail"]),
        insert_text=str(raw["insert_text"])
    );
}

impl InlayHint.to_dict -> dict[str, any] {
    return {
        "line": self.line,
        "col": self.col,
        "label": self.label,
        "kind": self.kind
    };
}

impl InlayHint.from_dict(raw: dict[str, any]) -> InlayHint {
    return InlayHint(
        line=int(raw["line"]),
        col=int(raw["col"]),
        label=str(raw["label"]),
        kind=str(raw["kind"])
    );
}

impl DocumentSymbol.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "kind": self.kind,
        "span": self.span.to_dict(),
        "children": [item.to_dict() for item in self.children]
    };
}

impl DocumentSymbol.from_dict(raw: dict[str, any]) -> DocumentSymbol {
    return DocumentSymbol(
        name=str(raw["name"]),
        kind=str(raw["kind"]),
        span=SourceSpan.from_dict(raw["span"]),
        children=[DocumentSymbol.from_dict(item) for item in raw["children"]]
    );
}

impl ToolOutput.to_dict -> dict[str, any] {
    return {
        "text": self.text,
        "errors": [item.to_dict() for item in self.errors],
        "warnings": [item.to_dict() for item in self.warnings]
    };
}

impl ToolOutput.from_dict(raw: dict[str, any]) -> ToolOutput {
    return ToolOutput(
        text=str(raw["text"]),
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]],
        warnings=[KernelDiagnostic.from_dict(item) for item in raw["warnings"]]
    );
}

impl GrammarReport.to_dict -> dict[str, any] {
    return {
        "ebnf": self.ebnf,
        "rules": self.rules,
        "diagnostics": self.diagnostics,
        "errors": [item.to_dict() for item in self.errors]
    };
}

impl GrammarReport.from_dict(raw: dict[str, any]) -> GrammarReport {
    return GrammarReport(
        ebnf=str(raw["ebnf"]),
        rules=int(raw["rules"]),
        diagnostics=str(raw["diagnostics"]),
        errors=[KernelDiagnostic.from_dict(item) for item in raw["errors"]]
    );
}

impl ArchPlan.to_dict -> dict[str, any] {
    return {
        "arch_path": self.arch_path,
        "text": self.text,
        "modules": list(self.modules),
        "fed": list(self.fed),
        "added": self.added,
        "dropped": self.dropped,
        "rules": self.rules,
        "rules_added": self.rules_added,
        "refusal": self.refusal,
        "hint": self.hint
    };
}

impl ArchPlan.from_dict(raw: dict[str, any]) -> ArchPlan {
    return ArchPlan(
        arch_path=str(raw["arch_path"]),
        text=str(raw["text"]),
        modules=[str(item) for item in raw["modules"]],
        fed=[str(item) for item in raw["fed"]],
        added=int(raw["added"]),
        dropped=int(raw["dropped"]),
        rules=int(raw["rules"]),
        rules_added=int(raw["rules_added"]),
        refusal=str(raw["refusal"]),
        hint=str(raw["hint"])
    );
}

impl SourceRef.from_dict(raw: dict[str, any]) -> SourceRef {
    return SourceRef(
        file=str(raw["file"]),
        line=int(raw["line"]),
        col=int(raw["col"]),
        role=str(raw["role"]),
        snippet=str(raw["snippet"])
    );
}

impl CodeDiagnostic.from_dict(raw: dict[str, any]) -> CodeDiagnostic {
    return CodeDiagnostic(
        file=str(raw["file"]),
        line=int(raw["line"]),
        severity=str(raw["severity"]),
        message=str(raw["message"])
    );
}

impl ContextSlice.from_dict(raw: dict[str, any]) -> ContextSlice {
    return ContextSlice(
        query=str(raw["query"]),
        target=SymbolInfo.from_dict(raw["target"]) if raw["target"] is not None else None,
        related=[SymbolInfo.from_dict(item) for item in raw["related"]],
        uses=[SourceRef.from_dict(item) for item in raw["uses"]]
    );
}

impl OutlineSymbol.to_dict -> dict[str, any] {
    return {
        "kind": self.kind,
        "name": self.name,
        "owner": self.owner,
        "file": self.file,
        "line": self.line,
        "end_line": self.end_line,
        "col": self.col,
        "doc": self.doc,
        "bases": list(self.bases),
        "signature": self.signature,
        "event": self.event,
        "type_str": self.type_str,
        "target": self.target
    };
}

impl OutlineSymbol.from_dict(raw: dict[str, any]) -> OutlineSymbol {
    return OutlineSymbol(
        kind=str(raw["kind"]),
        name=str(raw["name"]),
        owner=str(raw["owner"]),
        file=str(raw["file"]),
        line=int(raw["line"]),
        end_line=int(raw["end_line"]),
        col=int(raw["col"]),
        doc=str(raw["doc"]),
        bases=[str(item) for item in raw["bases"]],
        signature=str(raw["signature"]),
        event=str(raw["event"]),
        type_str=str(raw["type_str"]),
        target=str(raw["target"])
    );
}

impl ModuleOutline.to_dict -> dict[str, any] {
    return {
        "path": self.path,
        "doc": self.doc,
        "files": list(self.files),
        "symbols": [item.to_dict() for item in self.symbols],
        "error": self.error
    };
}

impl ModuleOutline.from_dict(raw: dict[str, any]) -> ModuleOutline {
    return ModuleOutline(
        path=str(raw["path"]),
        doc=str(raw["doc"]),
        files=[str(item) for item in raw["files"]],
        symbols=[OutlineSymbol.from_dict(item) for item in raw["symbols"]],
        error=str(raw["error"])
    );
}

impl EditSymbol.to_dict -> dict[str, any] {
    return {
        "key": self.key,
        "kind": self.kind,
        "line": self.line,
        "end_line": self.end_line,
        "text": self.text,
        "signature": self.signature
    };
}

impl EditSymbol.from_dict(raw: dict[str, any]) -> EditSymbol {
    return EditSymbol(
        key=str(raw["key"]),
        kind=str(raw["kind"]),
        line=int(raw["line"]),
        end_line=int(raw["end_line"]),
        text=str(raw["text"]),
        signature=str(raw["signature"])
    );
}

impl WiringChange.to_dict -> dict[str, any] {
    return {
        "kind": self.kind,
        "detail": self.detail,
        "module": self.module
    };
}

impl WiringChange.from_dict(raw: dict[str, any]) -> WiringChange {
    return WiringChange(
        kind=str(raw["kind"]),
        detail=str(raw["detail"]),
        module=str(raw["module"])
    );
}

impl WiredFiles.to_dict -> dict[str, any] {
    return {
        "owned": self.owned,
        "files": list(self.files)
    };
}

impl WiredFiles.from_dict(raw: dict[str, any]) -> WiredFiles {
    return WiredFiles(
        owned=bool(raw["owned"]),
        files=[str(item) for item in raw["files"]]
    );
}

impl WiringModule.to_dict -> dict[str, any] {
    return {
        "local": self.local,
        "file": self.file,
        "import_name": self.import_name,
        "project": self.project
    };
}

impl WiringModule.from_dict(raw: dict[str, any]) -> WiringModule {
    return WiringModule(
        local=str(raw["local"]),
        file=str(raw["file"]),
        import_name=str(raw["import_name"]),
        project=bool(raw["project"])
    );
}

impl WiringEdge.to_dict -> dict[str, any] {
    return {
        "provider": self.provider,
        "consumer": self.consumer,
        "scope": list(self.scope),
        "names": list(self.names),
        "form": self.form,
        "injected": self.injected,
        "line": self.line,
        "crosses": self.crosses,
        "rules": list(self.rules),
        "violation": self.violation,
        "arms": list(self.arms)
    };
}

impl WiringEdge.from_dict(raw: dict[str, any]) -> WiringEdge {
    return WiringEdge(
        provider=str(raw["provider"]),
        consumer=str(raw["consumer"]),
        scope=[str(item) for item in raw["scope"]],
        names=[str(item) for item in raw["names"]],
        form=str(raw["form"]),
        injected=bool(raw["injected"]),
        line=int(raw["line"]),
        crosses=bool(raw["crosses"]),
        rules=[str(item) for item in raw["rules"]],
        violation=str(raw["violation"]),
        arms=[str(item) for item in raw["arms"]]
    );
}

impl WiringRule.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "sources": list(self.sources),
        "targets": list(self.targets),
        "names": list(self.names),
        "governs": list(self.governs)
    };
}

impl WiringRule.from_dict(raw: dict[str, any]) -> WiringRule {
    return WiringRule(
        name=str(raw["name"]),
        sources=[str(item) for item in raw["sources"]],
        targets=[str(item) for item in raw["targets"]],
        names=[str(item) for item in raw["names"]],
        governs=[str(item) for item in raw["governs"]]
    );
}

impl WiringModel.to_dict -> dict[str, any] {
    return {
        "arch_path": self.arch_path,
        "parsed": self.parsed,
        "modules": [item.to_dict() for item in self.modules],
        "edges": [item.to_dict() for item in self.edges],
        "rules": [item.to_dict() for item in self.rules]
    };
}

impl WiringModel.from_dict(raw: dict[str, any]) -> WiringModel {
    return WiringModel(
        arch_path=str(raw["arch_path"]),
        parsed=bool(raw["parsed"]),
        modules=[WiringModule.from_dict(item) for item in raw["modules"]],
        edges=[WiringEdge.from_dict(item) for item in raw["edges"]],
        rules=[WiringRule.from_dict(item) for item in raw["rules"]]
    );
}

impl TokenSymbol.to_dict -> dict[str, any] {
    return {
        "line": self.line,
        "col": self.col,
        "end_col": self.end_col,
        "name": self.name,
        "kind": self.kind,
        "dotted": self.dotted,
        "decl_path": self.decl_path,
        "decl_line": self.decl_line,
        "decl_col": self.decl_col
    };
}

impl TokenSymbol.from_dict(raw: dict[str, any]) -> TokenSymbol {
    return TokenSymbol(
        line=int(raw["line"]),
        col=int(raw["col"]),
        end_col=int(raw["end_col"]),
        name=str(raw["name"]),
        kind=str(raw["kind"]),
        dotted=str(raw["dotted"]),
        decl_path=str(raw["decl_path"]),
        decl_line=int(raw["decl_line"]),
        decl_col=int(raw["decl_col"])
    );
}

impl SourceToken.to_dict -> dict[str, any] {
    return {
        "kind": self.kind,
        "value": self.value,
        "line": self.line,
        "col": self.col,
        "end_line": self.end_line,
        "end_col": self.end_col
    };
}

impl SourceToken.from_dict(raw: dict[str, any]) -> SourceToken {
    return SourceToken(
        kind=str(raw["kind"]),
        value=str(raw["value"]),
        line=int(raw["line"]),
        col=int(raw["col"]),
        end_line=int(raw["end_line"]),
        end_col=int(raw["end_col"])
    );
}

impl TokenStream.to_dict -> dict[str, any] {
    return {
        "tokens": [item.to_dict() for item in self.tokens],
        "comments": [item.to_dict() for item in self.comments]
    };
}

impl TokenStream.from_dict(raw: dict[str, any]) -> TokenStream {
    return TokenStream(
        tokens=[SourceToken.from_dict(item) for item in raw["tokens"]],
        comments=[SourceSpan.from_dict(item) for item in raw["comments"]]
    );
}

impl CompileResult.ok -> bool {
    return not self.errors;
}

impl CompileResult.unit(path: str) -> CompiledUnit {
    real = os.path.realpath(path);
    for candidate in self.units {
        if os.path.realpath(candidate.path) == real {
            return candidate;
        }
    }
    raise KernelError(f"the kernel compiled no unit for {path}");
}

impl CheckResult.ok -> bool {
    return not self.errors;
}

impl enter_world(project_root: str, search_paths: list[str], package_root: str) {
    if not package_root {
        raise KernelError("the request names no jaclang package root");
    }
    if not search_paths {
        raise KernelError("the request names no module search paths");
    }
    set_package_root(package_root);
    install_search_roots(search_paths);
}

impl source_span(loc: Span) -> SourceSpan {
    return SourceSpan(
        path=loc.mod_path,
        line=loc.first_line,
        col=loc.col_start,
        end_line=loc.last_line,
        end_col=loc.col_end
    );
}

impl node_span(loc: CodeLocInfo) -> SourceSpan {
    return source_span(Span.from_loc(loc));
}

impl kernel_diagnostic(alert: Alert, severity: str) -> KernelDiagnostic {
    code = alert.code;
    origin = alert.from_pass;
    hint = alert.help_text or (code.help_text if code is not None else None) or "";
    return KernelDiagnostic(
        code=code.code if code is not None else "",
        severity=severity,
        message=alert.msg,
        span=source_span(alert.loc),
        help=hint,
        pass_name=origin.__name__ if origin is not None else "",
        related=[
            RelatedNote(label=label, span=source_span(where))
            for (label, where) in alert.related
        ]
    );
}

impl other_compiler_diagnostic(path: str, tree: str) -> KernelDiagnostic {
    return KernelDiagnostic(
        code=E1408.code,
        severity="error",
        message=E1408.format_message(path=path, tree=tree),
        span=SourceSpan(path=path, line=1, col=1, end_line=1, end_col=1),
        help=E1408.help_text or ""
    );
}

impl collect_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
) {
    for alert in program.errors_had {
        errors.append(kernel_diagnostic(alert, "error"));
    }
    for alert in program.warnings_had {
        warnings.append(kernel_diagnostic(alert, "warning"));
    }
}

impl merge_app_diagnostics(
    collected: list[tuple[str, list[KernelDiagnostic]]]
) -> list[KernelDiagnostic] {
    def key_of(diag: KernelDiagnostic) -> tuple[str, str, int, int, str, str] {
        return (
            diag.severity,
            diag.span.path,
            diag.span.line,
            diag.span.col,
            diag.code,
            diag.message
        );
    }
    seen_apps: dict[tuple[str, str, int, int, str, str], set[str]] = {};
    for (app_name, found) in collected {
        for diag in found {
            seen_apps.setdefault(key_of(diag), set()).add(app_name);
        }
    }
    merged: list[KernelDiagnostic] = [];
    emitted: set[tuple[str, str, int, int, str, str]] = set();
    for (app_name, found) in collected {
        for diag in found {
            key = key_of(diag);
            if len(seen_apps[key]) >= len(collected) {
                if key not in emitted {
                    emitted.add(key);
                    merged.append(diag);
                }
                continue;
            }
            tagged = copy.copy(diag);
            tagged.message = f"[app:{app_name}] {diag.message}";
            merged.append(tagged);
        }
    }
    return merged;
}

impl emitted_paths(host: ProjectHost, requested: list[str]) -> list[str] {
    chosen: list[str] = [];
    for real in requested {
        if real in host.units {
            chosen.append(real);
        }
    }
    for real in host.units {
        if real in chosen or not real.endswith(".jac") {
            continue;
        }
        if real in host.grown
            or not is_module_cache_valid(real, get_module_cache_path(real)) {
            chosen.append(real);
        }
    }
    return chosen;
}

impl compiled_unit(host: ProjectHost, real: str, want_source: bool) -> CompiledUnit {
    products = host.units[real];
    task = host.analyses.get(real);
    if task is None {
        raise KernelError(f"the kernel holds products for {real} but no analysis");
    }
    module = task.module;
    client = client_artifact_from_json(products.client) if products.client else None;
    return CompiledUnit(
        path=real,
        module_name=module.name,
        bytecode=products.bytecode,
        python_source=active_engine().python_source(module) if want_source else "",
        interface=products.iface.encode("utf-8"),
        placement=products.placement,
        client_js=client.js if client is not None else "",
        native_iface=products.native_iface,
        native_deps=list(products.native_deps),
        native_ir=products.native_ir,
        native_layout=products.native_layout,
        jac_deps=list(products.jac_deps),
        app=products.app,
        persistence=list(products.persistence),
        import_edges=list(products.import_edges),
        interop=products.interop,
        client_manifest=products.client_manifest,
        iface_shape=products.iface_shape,
        effects=products.effects,
        sections=unit_sections(products, None)
    );
}

impl run_compile(
    program: JacProgram, host: ProjectHost, request: CompileRequest
) -> CompileResult {
    result = CompileResult();
    want_source = "python_source" in request.products;
    options = copy.copy(request.options);
    if not request.products {
        options.no_cgen = True;
    }
    for (path, text) in request.sources.items() {
        host.overlay[os.path.realpath(path)] = text;
    }
    if not options.no_cgen {
        host.close_over(options);
    }
    requested: list[str] = [];
    with host.session() {
        for path in request.paths {
            real = os.path.realpath(path);
            other = other_compiler_root(real);
            if other {
                result.errors.append(other_compiler_diagnostic(real, other));
                continue;
            }
            requested.append(real);
            program.compile(real, use_str=host.overlay.get(real), options=options);
        }
        if not options.no_cgen {
            tried: set[str] = set(requested);
            grew = True;
            while grew {
                grew = False;
                for real in list(host.analyses) {
                    if real in tried or real in host.units {
                        continue;
                    }
                    tried.add(real);
                    if other_compiler_root(real) or not real.endswith(".jac") {
                        continue;
                    }
                    program.compile(real, use_str=host.overlay.get(real), options=options);
                    grew = True;
                }
            }
        }
    }
    collect_diagnostics(program, result.errors, result.warnings);
    result.reached = sorted(host.analyses.keys());
    result.reads = [
        SourceRead(path=path, digest=digest)
        for (path, digest) in sorted(host.source_reads.items())
    ];
    if options.no_cgen {
        return result;
    }
    for real in emitted_paths(host, requested) {
        result.units.append(compiled_unit(host, real, want_source));
    }
    return result;
}

impl run_check(
    program: JacProgram, host: ProjectHost, request: CheckRequest
) -> CheckResult {
    result = CheckResult();
    options = copy.copy(request.options);
    options.no_cgen = not request.native_coverage;
    for (path, text) in request.sources.items() {
        host.overlay[os.path.realpath(path)] = text;
    }
    if request.native_coverage {
        na_coverage_begin();
    }
    with host.session() {
        for path in request.paths {
            real = os.path.realpath(path);
            other = other_compiler_root(real);
            if other {
                result.errors.append(other_compiler_diagnostic(real, other));
                continue;
            }
            program.compile(real, use_str=host.overlay.get(real), options=options);
        }
        if request.closure {
            checked: set[str] = set();
            grew = True;
            while grew {
                grew = False;
                for real in list(host.analyses) {
                    if real in checked {
                        continue;
                    }
                    checked.add(real);
                    if other_compiler_root(real) or not real.endswith(".jac") {
                        continue;
                    }
                    program.compile(real, use_str=host.overlay.get(real), options=options);
                    grew = True;
                }
            }
        }
    }
    collect_diagnostics(program, result.errors, result.warnings);
    if request.native_coverage {
        for (path, record) in sorted(na_coverage_end().items()) {
            result.coverage.append(
                CoverageRow(
                    path=path,
                    outcome=str(record["outcome"]),
                    code=str(record.get("code", "")),
                    detail=str(record.get("detail", "")),
                    seams=[str(seam) for seam in record.get("seams", [])],
                    late=int(record.get("late", 0))
                )
            );
        }
    }
    if request.placements {
        for (path, rows) in collect_placement_rows(program).items() {
            for row in rows.get("rows", []) {
                result.placements.append(
                    PlacementRow(
                        path=path,
                        symbol=str(row["name"]),
                        placement=str(row["space"]),
                        reason="; ".join([str(note) for note in row["evidence"]])
                    )
                );
            }
        }
    }
    if request.module_facts {
        import from jaclang.compiler.driver.pipeline { require }
        import from jaclang.compiler.driver.pipeline_types { CompilationProduct }
        for real in sorted(host.analyses.keys()) {
            module = host.analyses[real].module;
            result.modules.append(
                module_fact(program, real, module, request.options.target_app)
            );
            if not real.endswith(".jac") {
                continue;
            }
            manifest = module.gen.interop_manifest;
            if manifest is None or not (manifest.app_edges or manifest.surface) {
                require(program, module, CompilationProduct.BOUNDARIES);
                manifest = module.gen.interop_manifest;
            }
            if manifest is not None {
                for (consumer, provider) in manifest.app_edges {
                    result.app_edges.append(
                        AppEdge(consumer=str(consumer), provider=str(provider))
                    );
                }
            }
        }
    }
    result.reached = sorted(host.analyses.keys());
    return result;
}

impl module_fact(
    program: JacProgram, real: str, module: uni.Module, app: str
) -> ModuleFact {
    imports: set[str] = set();
    for statement in module.get_all_sub_nodes(Import) {
        if not statement.is_jac or statement.is_virtual_jac {
            continue;
        }
        targets = [statement.from_loc]
            if statement.from_loc is not None
            else [
                item
                for item in statement.items
                if isinstance(item, ModulePath)
            ];
        for target in targets {
            dependency = target.resolve_relative_path();
            if dependency and dependency.endswith(".jac") {
                imports.add(os.path.realpath(dependency));
            }
        }
    }
    return ModuleFact(
        path=real,
        app=app,
        spaces=sorted(module_spaces(module)),
        decided=str(module.decided_codespace or ""),
        client_declared=module.declares_codespace(CodeContext.CLIENT, path_hint=real),
        errors=program.count_module_errors(os.path.normpath(real)),
        imports=sorted(imports)
    );
}

impl NativeBuildResult.ok -> bool {
    return not self.errors;
}

impl native_build_request(request: NativeBuildRequest) -> NativeBuildResult {
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root_dir=request.project_root);
    previous = enter_compiler(host);
    try {
        return run_native_build(JacProgram(), host, request);
    } finally {
        leave_compiler(previous);
    }
}

impl run_native_build(
    program: JacProgram, host: ProjectHost, request: NativeBuildRequest
) -> NativeBuildResult {
    import re;
    result = NativeBuildResult(output=request.output);
    options = copy.copy(request.options);
    program.options = options;
    registry = program.native_units();
    def progress(line: str) {
        result.log.append(line);
    }
    registry.progress = progress;
    kinds = {
        "executable": ArtifactKind.EXECUTABLE,
        "shared": ArtifactKind.SHARED,
        "wasm": ArtifactKind.WASM
    };
    if request.kind != "plan" and request.kind not in kinds {
        raise KernelError(f"unknown native artifact kind '{request.kind}'");
    }
    roots = [os.path.realpath(path) for path in request.roots];
    if not roots {
        raise KernelError("a native build names no root module");
    }
    previous = push_native_target(options.native_target or "");
    try {
        with host.session() {
            root_module: (uni.Module | None) = None;
            if request.kind == "wasm" or request.callbacks {
                root_module = program.compile(roots[0], options=options);
                result.root_native = root_module.decided_codespace == "native"
                    and root_module.gen.native_iface is not None;
            }
            try {
                plan = build_link_plan(
                    program,
                    roots,
                    options,
                    mode=request.link_mode,
                    native_unit=request.native_unit
                );
            } except LinkPlanError as err {
                raise KernelError(str(err)) from err;
            }
            collect_diagnostics(program, result.errors, result.warnings);
            result.mode = plan.mode;
            result.triple = plan.triple;
            result.recompiled = len(registry.compiled_paths);
            result.analysed = program.analysis.cache_events.get("native_unit_analysis", 0);
            result.lowered = program.analysis.cache_events.get("native_unit_lower", 0);
            result.generated = program.analysis.cache_events.get("native_unit_codegen", 0);
            for unit in plan.units {
                result.units.append(
                    LinkedUnit(
                        path=unit.path,
                        digest=unit.digest,
                        stamp=registry.stamp_for(options, unit.path)
                    )
                );
            }
            result.python_imports = sorted(
                {name for unit in plan.units for name in unit.iface.python_imports}
            );
            result.demoted = list(plan.demoted_symbols());
            result.has_entry = bool(plan.root_unit().iface.entry_symbol);
            result.libraries = plan.clib_paths();
            if result.errors or request.kind == "plan" {
                return result;
            }
            if request.kind == "wasm" and not result.root_native {
                return result;
            }
            if request.refuse_python_imports and result.python_imports {
                return result;
            }
            if request.refuse_demoted and result.demoted {
                return result;
            }
            if request.kernel_entries {
                import from jaclang.compiler.backends.native.kernel_stage0 {
                    refuse_missing_entries
                }
                try {
                    refuse_missing_entries(
                        plan, request.project_root or request.package_root
                    );
                } except RuntimeError as err {
                    raise KernelError(str(err)) from err;
                }
            }
            if request.assert_no_rc {
                parts: list[str] = [];
                for unit in plan.units {
                    if is_toolchain_unit(unit.path) {
                        continue;
                    }
                    code = registry.bitcode_for(unit.path, plan.options);
                    if code is not None {
                        parts.append(str(llvm.parse_bitcode(code)));
                    }
                }
                emitted = "\n".join(parts);
                result.rc_symbols = sorted(
                    {found.group(0) for found in re.finditer(r"__rc_[A-Za-z0-9_]*", emitted)}
                );
                result.rc_probes = [
                    probe
                    for probe in ["JAC_GC"]
                    if probe in emitted
                ];
                if result.rc_symbols or result.rc_probes {
                    return result;
                }
            }
            if request.require_entry and not result.has_entry {
                return result;
            }
            kind = kinds[request.kind];
            plan.library_api = request.library_api;
            if request.callbacks and root_module is not None {
                manifest = root_module.gen.interop_manifest;
                bindings = unique_callbacks(manifest.callable_native_imports)
                    if manifest is not None
                    else [];
                plan.callback_bindings = list(bindings);
                for binding in bindings {
                    result.callbacks.append(
                        CallbackBinding(
                            name=binding.name,
                            symbol=binding.symbol,
                            ret_type=binding.ret_type,
                            param_types=list(binding.param_types)
                        )
                    );
                }
            }
            if request.emit_c {
                import from jaclang.compiler.backends.native.c_emit { emit_c }
                (merged, _exports) = whole_program_module(
                    plan, plan.glue_spec(kind, "c", False)
                );
                optimize_merged_program(plan, merged, kind);
                merged_ir = str(merged);
                if options.memory_profile == "nogc" {
                    import from jaclang.compiler.backends.native.wasm_build {
                        _assert_ir_rc_free
                    }
                    _assert_ir_rc_free(merged_ir, roots[0]);
                }
                with open(request.output, "w", encoding="utf-8") as handle {
                    handle.write(emit_c(merged_ir));
                }
                result.linked = True;
                return result;
            }
            app_imports: (set | None) = None;
            if request.kind == "wasm" and root_module is not None {
                import from jaclang.compiler.backends.native.wasm_build {
                    app_declared_imports
                }
                app_imports = app_declared_imports(root_module);
            }
            program.release_compile_closure();
            linked = link_artifact(
                plan, request.output, kind, log=progress, app_imports=app_imports
            );
            result.linked = True;
            result.reused = linked.reused;
            result.sha256 = linked.sha256;
            result.plan_digest = linked.plan_digest;
        }
    } finally {
        pop_native_target(previous);
    }
    return result;
}

impl compile_request(request: CompileRequest) -> CompileResult {
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root_dir=request.project_root);
    previous = enter_compiler(host);
    try {
        return run_compile(JacProgram(), host, request);
    } finally {
        leave_compiler(previous);
    }
}

impl check_request(request: CheckRequest) -> CheckResult {
    enter_world(request.project_root, request.search_paths, request.package_root);
    host = ProjectHost(root_dir=request.project_root);
    previous = enter_compiler(host);
    try {
        return run_check(JacProgram(), host, request);
    } finally {
        leave_compiler(previous);
    }
}

impl open_session(
    project_root: str, search_paths: list[str], package_root: str
) -> KernelSession {
    return KernelSession(
        project_root=project_root, search_paths=search_paths, package_root=package_root
    );
}

impl KernelSession.postinit {
    enter_world(self.project_root, self.search_paths, self.package_root);
    self._host = ProjectHost(root_dir=self.project_root);
    program = JacProgram();
    program.deps.tracking = True;
    self._program = program;
    self.options = copy.copy(self.options);
    self.options.no_cgen = True;
}

impl KernelSession.live_program -> JacProgram {
    program = self._program;
    if program is None {
        raise KernelError("the kernel session is closed");
    }
    return program;
}

impl KernelSession.live_host -> ProjectHost {
    host = self._host;
    if host is None {
        raise KernelError("the kernel session is closed");
    }
    return host;
}

impl KernelSession.enter -> ProjectHost {
    host = self._host;
    if host is None or self._program is None {
        raise KernelError("the kernel session is closed");
    }
    self._entered.append(enter_compiler(host));
    return host;
}

impl KernelSession.leave {
    leave_compiler(self._entered.pop());
}

impl KernelSession.invalidate(real: str) {
    program = self.live_program();
    host = self.live_host();
    stale = {real} | program.transitive_dependents(real);
    for path in stale {
        program.drop_module_alerts(path);
        program.invalidate_module(path);
        host.forget_program_products(program, path);
        self._analysed.pop(path, None);
    }
}

impl KernelSession.owner(real: str) -> str {
    host = self.live_host();
    base = host.base_file(real);
    return os.path.realpath(base) if base else real;
}

impl KernelSession.touch(real: str) {
    owner = self.owner(real);
    for path in {real, owner} {
        self._versions[path] = self._versions.get(path, 0) + 1;
        self.invalidate(path);
    }
}

impl KernelSession.app_targets(real: str) -> list[tuple[str, str, str]] {
    host = self.live_host();
    space = host.workspace(real);
    if space is None {
        return [];
    }
    app = host.app_for_path(real);
    if app is not None {
        return [(app.name, app.kind, app.`entry or real)];
    }
    return [
        (each.name, each.kind, each.`entry or real)
        for each in list(space.apps.values())[:self.shared_app_limit]
    ];
}

impl KernelSession.compile_for(
    real: str, target: (tuple[str, str, str] | None)
) -> uni.Module {
    host = self.live_host();
    program = self.live_program();
    options = copy.copy(self.options);
    if target is not None {
        (name, kind, entry_path) = target;
        space = host.workspace(real);
        options.target_app = name;
        options.app_kind = kind;
        options.entry_point = entry_path;
        options.project_root = space.project_root if space is not None else None;
    }
    for path in self.own_files(real) {
        program.drop_module_alerts(path);
    }
    program.invalidate_module(real);
    with host.session() {
        return program.compile(real, use_str=host.overlay.get(real), options=options);
    }
}

impl KernelSession.own_files(real: str) -> set[str] {
    host = self.live_host();
    return {
        real,
        *[
            os.path.realpath(path)
            for path in [
                *host.annex_files(real, ".impl.jac"),
                *host.annex_files(real, ".test.jac")
            ]
        ]
    };
}

impl KernelSession.analysed(path: str) -> uni.Module {
    real = self.owner(os.path.realpath(path));
    program = self.live_program();
    self.enter();
    try {
        version = self._versions.get(real, 0);
        held = program.find_module(real);
        if held is not None and self._analysed.get(real) == version {
            return held;
        }
        targets = self.app_targets(real);
        module = self.compile_for(real, targets[0] if targets else None);
        self._analysed[real] = version;
        return module;
    } finally {
        self.leave();
    }
}

impl KernelSession.update(path: str, text: str) {
    real = os.path.realpath(path);
    host = self.live_host();
    host.overlay[real] = text;
    self._open.add(real);
    self.touch(real);
}

impl KernelSession.close(path: str) {
    real = os.path.realpath(path);
    host = self.live_host();
    self._open.discard(real);
    held = host.overlay.pop(real, None);
    if held is None {
        return;
    }
    on_disk = read_file_with_encoding(real) if os.path.isfile(real) else None;
    if on_disk != held {
        self.touch(real);
    }
}

impl KernelSession.forget(path: str) {
    real = os.path.realpath(path);
    host = self.live_host();
    program = self.live_program();
    host.overlay.pop(real, None);
    self._open.discard(real);
    self.touch(real);
    program.release_module(real);
    self._versions.pop(real, None);
    self._analysed.pop(real, None);
}

impl KernelSession.rename_module(old_path: str, new_path: str) {
    old_real = os.path.realpath(old_path);
    new_real = os.path.realpath(new_path);
    if old_real == new_real {
        return;
    }
    host = self.live_host();
    held = host.overlay.get(old_real);
    was_open = old_real in self._open;
    self.forget(old_real);
    if held is not None {
        host.overlay[new_real] = held;
    }
    if was_open {
        self._open.add(new_real);
    }
    self.touch(new_real);
}

impl KernelSession.dependents(path: str) -> list[str] {
    program = self.live_program();
    if not self._edges_seeded and self.project_root {
        import from jaclang.compiler.driver.ifacecache { seed_dep_edges }
        self.enter();
        try {
            seed_dep_edges(program, self.project_root);
        } finally {
            self.leave();
        }
        self._edges_seeded = True;
    }
    real = os.path.realpath(path);
    found = program.transitive_dependents(real) | program.transitive_dependents(
        self.owner(real)
    );
    return sorted([os.path.realpath(dep) for dep in found]);
}

impl KernelSession.set_shared_app_limit(limit: int) {
    if limit < 1 {
        raise KernelError(f"the shared-app limit must be at least 1, not {limit}");
    }
    self.shared_app_limit = limit;
    self._analysed.clear();
}

impl KernelSession.diagnostics(path: str) -> list[KernelDiagnostic] {
    real = self.owner(os.path.realpath(path));
    files = self.own_files(real);
    program = self.live_program();
    def gathered -> list[KernelDiagnostic] {
        found: list[KernelDiagnostic] = [];
        for (severity, alerts) in [
            ("error", program.errors_had),
            ("warning", program.warnings_had)
        ] {
            for alert in alerts {
                if alert.loc.mod_path and os.path.realpath(alert.loc.mod_path) in files {
                    found.append(kernel_diagnostic(alert, severity));
                }
            }
        }
        return found;
    }
    self.enter();
    try {
        targets = self.app_targets(real);
    } finally {
        self.leave();
    }
    if len(targets) <= 1 {
        self.analysed(real);
        return gathered();
    }
    collected: list[tuple[str, list[KernelDiagnostic]]] = [];
    self.enter();
    try {
        for target in targets {
            self.compile_for(real, target);
            collected.append((target[0], gathered()));
        }
        self._analysed[real] = self._versions.get(real, 0);
    } finally {
        self.leave();
    }
    return merge_app_diagnostics(collected);
}

impl KernelSession.hover(path: str, line: int, col: int) -> str {
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    return hover_text(selected) if selected is not None else "";
}

impl KernelSession.definition(path: str, line: int, col: int) -> list[SourceSpan] {
    real = os.path.realpath(path);
    module = self.analysed(real);
    selected = token_at(module, real, line, col);
    if selected is None {
        return string_import_definition(module, line, col);
    }
    return definition_spans(self.live_program(), selected);
}

impl KernelSession.references(path: str, line: int, col: int) -> list[SourceSpan] {
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return reference_spans(selected) if selected is not None else [];
}

impl KernelSession.completion(path: str, line: int, col: int) -> list[CompletionItem] {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        source = host.read_source(real);
    } finally {
        self.leave();
    }
    if inside_literal_or_comment(source, real, line, col) {
        return [];
    }
    module = self.analysed(real);
    self.enter();
    try {
        return completion_items(self.live_program(), module, real, line, col);
    } finally {
        self.leave();
    }
}

impl KernelSession.semantic_tokens(path: str) -> list[int] {
    real = os.path.realpath(path);
    return semantic_token_data(self.analysed(real), real);
}

impl KernelSession.inlay_hints(
    path: str, first_line: int, last_line: int
) -> list[InlayHint] {
    return inlay_hint_rows(self.analysed(path), first_line, last_line);
}

impl KernelSession.symbols(path: str) -> list[DocumentSymbol] {
    module = self.analysed(path);
    return outline(module.sym_tab);
}

impl KernelSession.rename(
    path: str, line: int, col: int, new_name: str
) -> list[TextEdit] {
    real = os.path.realpath(path);
    selected = token_at(self.analysed(real), real, line, col);
    return rename_edits(selected, new_name) if selected is not None else [];
}

impl KernelSession.formatted(path: str, auto_lint: bool) -> ToolOutput {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        program = JacCompiler.jac_str_formatter(host.read_source(real), real, auto_lint);
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    main = program.mod.main;
    out.text = (main.gen.jac or "") if main is not None else "";
    return out;
}

impl KernelSession.format(path: str) -> ToolOutput {
    return self.formatted(path, False);
}

impl KernelSession.lint_fix(path: str) -> ToolOutput {
    return self.formatted(path, True);
}

impl KernelSession.lint(path: str) -> ToolOutput {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        program = JacCompiler.jac_str_linter(host.read_source(real), real);
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    return out;
}

impl KernelSession.parse(path: str) -> ToolOutput {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        (program, _module) = JacCompiler._prepare_tool_program(
            host.read_source(real), real
        );
    } finally {
        self.leave();
    }
    out = ToolOutput();
    collect_diagnostics(program, out.errors, out.warnings);
    return out;
}

impl KernelSession.statements(path: str) -> list[SourceSpan] {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        (program, module) = JacCompiler._prepare_tool_program(
            host.read_source(real), real
        );
    } finally {
        self.leave();
    }
    if module is None {
        raise KernelError(f"{real} does not parse: {program.errors_had[0].msg}");
    }
    return [
        node_span(stmt.loc)
        for stmt in module.body
        if stmt.loc.mod_path and os.path.realpath(stmt.loc.mod_path) == real
    ];
}

impl KernelSession.py_to_jac(path: str) -> ToolOutput {
    real = os.path.realpath(path);
    if not real.endswith((".py", ".pyi")) {
        raise KernelError(f"{real} is not a Python file");
    }
    out = ToolOutput();
    host = self.enter();
    try {
        program = JacProgram();
        (converted, had_error) = parse_python_source(host.read_source(real), real, program);
        collect_diagnostics(program, out.errors, out.warnings);
        if had_error {
            return out;
        }
        laid_out = JacCompiler.jac_str_formatter(
            unparse_module(converted, requires_format=False), real, False
        );
    } finally {
        self.leave();
    }
    collect_diagnostics(laid_out, out.errors, out.warnings);
    main = laid_out.mod.main;
    out.text = (main.gen.jac or "") if main is not None else "";
    return out;
}

impl KernelSession.ast_view(path: str, view: str) -> ToolOutput {
    real = os.path.realpath(path);
    if view not in PARSED_VIEWS and view not in ANALYSED_VIEWS {
        raise KernelError(
            f"unknown AST view '{view}'; expected one of "
            + ", ".join([*PARSED_VIEWS, *ANALYSED_VIEWS])
        );
    }
    out = ToolOutput();
    program = JacProgram();
    host = self.enter();
    try {
        source = host.read_source(real);
        if view in PARSED_VIEWS {
            module = program.parse_str(source, real);
            collect_diagnostics(program, out.errors, out.warnings);
            if not out.errors {
                out.text = parsed_view(module, view);
            }
            return out;
        }
        target = real;
        if real.endswith(".py") {
            (converted, had_error) = parse_python_source(source, real, program);
            if had_error {
                collect_diagnostics(program, out.errors, out.warnings);
                return out;
            }
            source = unparse_module(converted);
            target = real[:-len(".py")] + ".jac";
        }
        with host.session() {
            module = program.compile(
                target, use_str=source, options=CompileOptions(no_cgen=True)
            );
        }
        collect_diagnostics(program, out.errors, out.warnings);
        out.text = analysed_view(program, module, view);
        return out;
    } finally {
        self.leave();
    }
}

impl KernelSession.explain(
    path: str, topic: str, memory_profile: str = ""
) -> ToolOutput {
    real = os.path.realpath(path);
    if topic == "memory" {
        options = CompileOptions(
            rc_stats=True, nogc_debug=True, memory_profile=(memory_profile or None)
        );
    } elif topic == "native" {
        options = CompileOptions(aot_mode=True, default_codespace="native");
    } else {
        raise KernelError(
            f"unknown explain topic '{topic}'; the kernel explains 'memory' and 'native'"
        );
    }
    out = ToolOutput();
    program = JacProgram();
    host = self.enter();
    try {
        with host.session() {
            module = program.compile(
                real, use_str=host.overlay.get(real), options=options
            );
        }
    } finally {
        self.leave();
    }
    collect_diagnostics(program, out.errors, out.warnings);
    if topic == "native" {
        if module.gen.llvm_ir is not None {
            out.text = native_linked_ir_text(module);
        }
        return out;
    }
    name = os.path.basename(real);
    hints = sorted(
        inferred_hints(module), key=lambda (h: any) { (h.line, h.col); }
    );
    lines = [
        f"memory profile: {program.options.memory_profile
            if program.options and program.options.memory_profile
            else 'managed'}",
        f"inferred facts: {len(hints)}",
        *[f"  {name}:{h.line}:{h.col}  {h.label.strip()}" for h in hints],
        f"move sites: {len(module.own_move_sites)}",
        f"last-use releases: {sum([len(v) for v in module.rc_last_use.values()])}"
    ];
    out.text = "\n".join(lines);
    return out;
}

impl KernelSession.grammar -> GrammarReport {
    parser_path = os.path.join(
        self.package_root, "compiler", "frontend", "parser", "parser.jac"
    );
    grammar_report = GrammarReport(ebnf="", rules=0);
    program = JacProgram();
    host = self.enter();
    try {
        with host.session() {
            module = program.compile(
                parser_path,
                options=CompileOptions(
                    symtab_ir_only=True, no_cgen=True, need_full_ast=True
                )
            );
        }
        ignored: list[KernelDiagnostic] = [];
        collect_diagnostics(program, grammar_report.errors, ignored);
        if grammar_report.errors {
            return grammar_report;
        }
        extracted = run_utility(CompilationProduct.GRAMMAR, module, program);
    } finally {
        self.leave();
    }
    if not isinstance(extracted, GrammarExtractPass) {
        raise KernelError("the grammar product did not run the grammar extractor");
    }
    grammar_report.ebnf = extracted.emit_ebnf();
    grammar_report.rules = len(extracted.rules);
    grammar_report.diagnostics = extracted.emit_diagnostics();
    return grammar_report;
}

impl KernelSession.arch_plan(
    arch_path: str, action: str, prune: bool = False, graph_format: str = ""
) -> ArchPlan {
    real = os.path.realpath(arch_path);
    host = self.enter();
    try {
        if action == "init" {
            return init_plan(host, real);
        }
        if action == "sync" {
            return sync_plan(host, real, prune);
        }
        if action == "graph" {
            return graph_plan(real, graph_format);
        }
    } finally {
        self.leave();
    }
    raise KernelError(f"unknown arch action '{action}'; expected init, sync or graph");
}

impl KernelSession.compile(request: CompileRequest) -> CompileResult {
    host = self.enter();
    try {
        return run_compile(self.live_program(), host, request);
    } finally {
        self.leave();
    }
}

impl KernelSession.check(request: CheckRequest) -> CheckResult {
    host = self.enter();
    try {
        return run_check(self.live_program(), host, request);
    } finally {
        self.leave();
    }
}

impl KernelSession.module_outline(path: str) -> ModuleOutline {
    host = self.enter();
    try {
        with host.session() {
            return module_outline_of(host, path);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.edit_symbols(path: str, text: str) -> list[EditSymbol] {
    self.enter();
    try {
        return edit_symbol_rows(text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.import_texts(path: str, text: str) -> list[str] {
    self.enter();
    try {
        return import_text_rows(text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_changes(
    path: str, old_text: str, new_text: str
) -> list[WiringChange] {
    self.enter();
    try {
        return wiring_change_rows(old_text, new_text, os.path.realpath(path));
    } finally {
        self.leave();
    }
}

impl KernelSession.wired_dependents(head: str, names: list[str]) -> WiredFiles {
    host = self.enter();
    try {
        with host.session() {
            return wired_dependent_files(head, names);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_module_files(
    arch_path: str, consumers: list[str]
) -> list[str] {
    host = self.enter();
    try {
        with host.session() {
            return wiring_files_of(arch_path, consumers);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.wiring_model(arch_path: str) -> WiringModel {
    host = self.enter();
    try {
        with host.session() {
            return wiring_model_of(arch_path);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.token_symbols(path: str) -> list[TokenSymbol] {
    real = os.path.realpath(path);
    return token_symbol_rows(self.analysed(real), real);
}

impl KernelSession.assignment_hints(path: str) -> list[InlayHint] {
    real = os.path.realpath(path);
    return assignment_hint_rows(self.analysed(real), real);
}

impl KernelSession.tokens(path: str, text: str) -> TokenStream {
    return token_stream(text, os.path.realpath(path));
}

impl KernelSession.code_index -> CodeIntelligence {
    if not self.project_root {
        raise KernelError(
            "the code index needs a session opened on a project root, not an empty one"
        );
    }
    if self._intel is None {
        self._intel = CodeIntelligence(proj_dir=self.project_root);
    }
    return self._intel;
}

impl KernelSession.code_lookup(name: str) -> list[SymbolInfo] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().lookup(name);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_references(name: str) -> list[SourceRef] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().references(name);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_archetypes(kind: str) -> list[SymbolInfo] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().archetypes(kind);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_walkers(node_type: str) -> list[EntryPoint] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().walkers_visiting(node_type);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_slice(name: str, depth: int) -> ContextSlice {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().slice_for(name, depth);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_diagnostics(file: str) -> list[CodeDiagnostic] {
    host = self.enter();
    try {
        with host.session() {
            return self.code_index().diagnostics(file);
        }
    } finally {
        self.leave();
    }
}

impl KernelSession.code_refresh(file: str) {
    host = self.enter();
    try {
        with host.session() {
            self.code_index().refresh(file);
        }
    } finally {
        self.leave();
    }
}

impl SourceRef.render -> str {
    loc = f"{self.file}:{self.line}";
    return f"{loc}  {self.snippet}" if self.snippet else loc;
}

impl SourceRef.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "role": self.role,
        "snippet": self.snippet
    };
}

impl SymbolInfo.render -> str {
    head = f"{self.kind} {self.name}";
    if self.signature {
        head += self.signature;
    } elif self.type_str {
        head += f": {self.type_str}";
    }
    lines = [f"{head}    [{self.file}:{self.line}]"];
    if self.base_classes {
        lines.append("  extends: " + ", ".join(self.base_classes));
    }
    for f in self.fields {
        lines.append(f"  has {f}");
    }
    for a in self.abilities {
        lines.append(f"  def {a}");
    }
    if self.doc {
        lines.append("  " + self.doc.strip().splitlines()[0]);
    }
    return "\n".join(lines);
}

impl SymbolInfo.to_dict -> dict[str, any] {
    return {
        "name": self.name,
        "kind": self.kind,
        "file": self.file,
        "line": self.line,
        "col": self.col,
        "type_str": self.type_str,
        "doc": self.doc,
        "signature": self.signature,
        "fields": self.fields,
        "abilities": self.abilities,
        "base_classes": self.base_classes,
        "is_genai": self.is_genai
    };
}

impl SymbolInfo.from_dict(d: dict[str, any]) -> SymbolInfo {
    return SymbolInfo(
        name=str(d.get("name", "")),
        kind=str(d.get("kind", "symbol")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0)),
        col=int(d.get("col", 0)),
        type_str=str(d.get("type_str", "")),
        doc=str(d.get("doc", "")),
        signature=str(d.get("signature", "")),
        fields=list(d.get("fields", [])),
        abilities=list(d.get("abilities", [])),
        base_classes=list(d.get("base_classes", [])),
        is_genai=bool(d.get("is_genai", False))
    );
}

impl CodeDiagnostic.render -> str {
    return f"{self.severity}: {self.file}:{self.line}: {self.message}";
}

impl CodeDiagnostic.to_dict -> dict[str, any] {
    return {
        "file": self.file,
        "line": self.line,
        "severity": self.severity,
        "message": self.message
    };
}


impl EntryPoint.render -> str {
    return f"{self.walker_name}.{self.ability}  ({self.event} {self.node_type})  [{self.file}:{self.line}]";
}

impl EntryPoint.to_dict -> dict[str, any] {
    return {
        "walker_name": self.walker_name,
        "ability": self.ability,
        "node_type": self.node_type,
        "event": self.event,
        "file": self.file,
        "line": self.line
    };
}

impl EntryPoint.from_dict(d: dict[str, any]) -> EntryPoint {
    return EntryPoint(
        walker_name=str(d.get("walker_name", "")),
        ability=str(d.get("ability", "")),
        node_type=str(d.get("node_type", "")),
        event=str(d.get("event", "")),
        file=str(d.get("file", "")),
        line=int(d.get("line", 0))
    );
}

impl ContextSlice.render -> str {
    if self.target is None {
        return f"(no symbol named {self.query} was found)";
    }
    parts = ["# Definition", self.target.render()];
    if self.related {
        parts.append("\n# Referenced types");
        for s in self.related {
            parts.append(s.render());
        }
    }
    if self.uses {
        parts.append(f"\n# Used in {len(self.uses)} place(s)");
        for u in self.uses {
            parts.append("  " + u.render());
        }
    }
    return "\n".join(parts);
}

impl ContextSlice.to_dict -> dict[str, any] {
    return {
        "query": self.query,
        "target": self.target.to_dict() if self.target is not None else None,
        "related": [s.to_dict() for s in self.related],
        "uses": [u.to_dict() for u in self.uses]
    };
}

impl KernelSession.strip_markers(path: str, text: str) -> MarkerScan {
    self.enter();
    try {
        return marker_scan(text, path);
    } finally {
        self.leave();
    }
}

impl KernelSession.element_spaces(path: str) -> list[ElementSpace] {
    return top_element_spaces(self.analysed(path));
}

impl KernelSession.client_imports(path: str) -> list[ImportSpace] {
    real = os.path.realpath(path);
    module = self.analysed(real);
    if self.live_program().count_module_errors(os.path.normpath(module.loc.mod_path)) {
        return [];
    }
    return import_spaces(module);
}

impl KernelSession.access_plan(project_root: str) -> AccessPlan {
    self.enter();
    try {
        return served_access_plan(os.path.realpath(project_root));
    } finally {
        self.leave();
    }
}

impl KernelSession.package_api(base_root: str, exports: list[str]) -> str {
    import json;
    import from pathlib { Path }
    base_path = Path(base_root);
    host = self.enter();
    program = JacProgram();
    modules: dict[str, any] = {};
    module_docs: dict[str, str] = {};
    missing: list[str] = [];
    try {
        with host.session() {
            for name in sorted(set(exports)) {
                path = module_path_for(base_path, name);
                if path is None {
                    missing.append(name);
                    continue;
                }
                options = CompileOptions(no_cgen=True, project_root=str(base_path));
                with compilation_scope(options) {
                    module = program.compile(str(path), options=options);
                }
                modules[name] = module_surface(module, program.get_type_evaluator());
                text = doc_text(module);
                if text {
                    module_docs[name] = text;
                }
            }
        }
    } finally {
        program.release_compile_closure();
        self.leave();
    }
    if missing {
        raise KernelError(
            "exported module(s) not found in the package: " + ", ".join(missing)
        );
    }
    surface: dict[str, any] = {"format": API_FORMAT, "modules": modules};
    if module_docs {
        surface[MODULE_DOCS] = module_docs;
    }
    return json.dumps(surface, sort_keys=True);
}

impl KernelSession.stub_catalog(
    out_path: str, only: list[str], pkg_dir: str
) -> StubCatalogReport {
    self.enter();
    try {
        manifest = build_catalog(
            out_path, only=only or None, pkg_dir=pkg_dir or None, quiet=True
        );
    } finally {
        self.leave();
    }
    return StubCatalogReport(
        summary=f"stubcat: {manifest['modules']} modules, {manifest['symbols']} symbols, "
            f"{manifest['types']} types, {manifest['bytes']} bytes, "
            f"{manifest['failures']} evaluation failures in {manifest['seconds']}s",
        load_failures=[str(failure) for failure in manifest["load_failures"]]
    );
}

impl KernelSession.npm_sources(project_root: str) -> list[NpmSource] {
    import from pathlib { Path }
    project_path = Path(project_root);
    config = get_config_for_path(project_path);
    if config is None {
        raise KernelError(f"no jac.toml governs {project_root}");
    }
    host = self.enter();
    try {
        with host.session() {
            files = collect_npm_sources(config, project_root=project_path);
        }
    } except (NpmBoundaryError, ValueError) as err {
        raise KernelError(str(err)) from err;
    } finally {
        self.leave();
    }
    return [
        NpmSource(
            npm_path=item.npm_path,
            source_path=str(item.source_path) if item.source_path is not None else "",
            js=item.js,
            dts=item.dts,
            external_imports=list(item.external_imports)
        )
        for item in files
    ];
}

impl KernelSession.definition_rows(path: str) -> list[str] {
    real = os.path.realpath(path);
    host = self.enter();
    try {
        return definition_span_rows(
            JacProgram().parse_source(host.read_source(real), real)
        );
    } finally {
        self.leave();
    }
}

impl session_query(session: KernelSession, method: str, args: list[any]) -> any {
    if method == "update" {
        session.update(str(args[0]), str(args[1]));
        return None;
    }
    if method == "close" {
        session.close(str(args[0]));
        return None;
    }
    if method == "forget" {
        session.forget(str(args[0]));
        return None;
    }
    if method == "rename_module" {
        session.rename_module(str(args[0]), str(args[1]));
        return None;
    }
    if method == "dependents" {
        return list(session.dependents(str(args[0])));
    }
    if method == "set_shared_app_limit" {
        session.set_shared_app_limit(int(args[0]));
        return None;
    }
    if method == "diagnostics" {
        return [item.to_dict() for item in session.diagnostics(str(args[0]))];
    }
    if method == "hover" {
        return session.hover(str(args[0]), int(args[1]), int(args[2]));
    }
    if method == "definition" {
        return [item.to_dict() for item in session.definition(str(args[0]), int(args[1]), int(args[2]))];
    }
    if method == "references" {
        return [item.to_dict() for item in session.references(str(args[0]), int(args[1]), int(args[2]))];
    }
    if method == "completion" {
        return [item.to_dict() for item in session.completion(str(args[0]), int(args[1]), int(args[2]))];
    }
    if method == "semantic_tokens" {
        return list(session.semantic_tokens(str(args[0])));
    }
    if method == "inlay_hints" {
        return [item.to_dict() for item in session.inlay_hints(str(args[0]), int(args[1]), int(args[2]))];
    }
    if method == "symbols" {
        return [item.to_dict() for item in session.symbols(str(args[0]))];
    }
    if method == "rename" {
        return [item.to_dict() for item in session.rename(str(args[0]), int(args[1]), int(args[2]), str(args[3]))];
    }
    if method == "format" {
        return session.format(str(args[0])).to_dict();
    }
    if method == "lint_fix" {
        return session.lint_fix(str(args[0])).to_dict();
    }
    if method == "lint" {
        return session.lint(str(args[0])).to_dict();
    }
    if method == "parse" {
        return session.parse(str(args[0])).to_dict();
    }
    if method == "statements" {
        return [item.to_dict() for item in session.statements(str(args[0]))];
    }
    if method == "py_to_jac" {
        return session.py_to_jac(str(args[0])).to_dict();
    }
    if method == "ast_view" {
        return session.ast_view(str(args[0]), str(args[1])).to_dict();
    }
    if method == "explain" {
        return session.explain(str(args[0]), str(args[1]), str(args[2])).to_dict();
    }
    if method == "grammar" {
        return session.grammar().to_dict();
    }
    if method == "arch_plan" {
        return session.arch_plan(str(args[0]), str(args[1]), bool(args[2]), str(args[3])).to_dict();
    }
    if method == "strip_markers" {
        return session.strip_markers(str(args[0]), str(args[1])).to_dict();
    }
    if method == "element_spaces" {
        return [item.to_dict() for item in session.element_spaces(str(args[0]))];
    }
    if method == "client_imports" {
        return [item.to_dict() for item in session.client_imports(str(args[0]))];
    }
    if method == "access_plan" {
        return session.access_plan(str(args[0])).to_dict();
    }
    if method == "package_api" {
        return session.package_api(str(args[0]), [str(item) for item in args[1]]);
    }
    if method == "stub_catalog" {
        return session.stub_catalog(str(args[0]), [str(item) for item in args[1]], str(args[2])).to_dict();
    }
    if method == "npm_sources" {
        return [item.to_dict() for item in session.npm_sources(str(args[0]))];
    }
    if method == "definition_rows" {
        return list(session.definition_rows(str(args[0])));
    }
    if method == "compile" {
        return session.compile(CompileRequest.from_dict(args[0])).to_dict();
    }
    if method == "check" {
        return session.check(CheckRequest.from_dict(args[0])).to_dict();
    }
    if method == "module_outline" {
        return session.module_outline(str(args[0])).to_dict();
    }
    if method == "edit_symbols" {
        return [item.to_dict() for item in session.edit_symbols(str(args[0]), str(args[1]))];
    }
    if method == "import_texts" {
        return list(session.import_texts(str(args[0]), str(args[1])));
    }
    if method == "wiring_changes" {
        return [item.to_dict() for item in session.wiring_changes(str(args[0]), str(args[1]), str(args[2]))];
    }
    if method == "wired_dependents" {
        return session.wired_dependents(str(args[0]), [str(item) for item in args[1]]).to_dict();
    }
    if method == "wiring_module_files" {
        return list(session.wiring_module_files(str(args[0]), [str(item) for item in args[1]]));
    }
    if method == "wiring_model" {
        return session.wiring_model(str(args[0])).to_dict();
    }
    if method == "token_symbols" {
        return [item.to_dict() for item in session.token_symbols(str(args[0]))];
    }
    if method == "assignment_hints" {
        return [item.to_dict() for item in session.assignment_hints(str(args[0]))];
    }
    if method == "tokens" {
        return session.tokens(str(args[0]), str(args[1])).to_dict();
    }
    if method == "code_lookup" {
        return [item.to_dict() for item in session.code_lookup(str(args[0]))];
    }
    if method == "code_references" {
        return [item.to_dict() for item in session.code_references(str(args[0]))];
    }
    if method == "code_archetypes" {
        return [item.to_dict() for item in session.code_archetypes(str(args[0]))];
    }
    if method == "code_walkers" {
        return [item.to_dict() for item in session.code_walkers(str(args[0]))];
    }
    if method == "code_slice" {
        return session.code_slice(str(args[0]), int(args[1])).to_dict();
    }
    if method == "code_diagnostics" {
        return [item.to_dict() for item in session.code_diagnostics(str(args[0]))];
    }
    if method == "code_refresh" {
        session.code_refresh(str(args[0]));
        return None;
    }
    raise KernelError(f"the kernel session has no query {method!r}");
}

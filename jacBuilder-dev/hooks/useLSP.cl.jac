"""LSP hook — connects Monaco editor to jac lsp via WebSocket."""

import from react { useState, useEffect, useRef, useCallback }
import from ..utils.lsp_client {
    lspInit,
    lspRequest,
    lspNotify,
    lspShutdown,
    lspSetNotificationHandler
}

"""Map LSP CompletionItemKind to Monaco CompletionItemKind."""
def _mapCompletionKind(lspKind: int, monacoInstance: Any) -> int {
    kinds = monacoInstance.languages.CompletionItemKind;
    if lspKind == 1 { return kinds.Text; }
    if lspKind == 2 { return kinds.Method; }
    if lspKind == 3 { return kinds.Function; }
    if lspKind == 4 { return kinds.Constructor; }
    if lspKind == 5 { return kinds.Field; }
    if lspKind == 6 { return kinds.Variable; }
    if lspKind == 7 { return kinds.Class; }
    if lspKind == 8 { return kinds.Interface; }
    if lspKind == 9 { return kinds.Module; }
    if lspKind == 10 { return kinds.Property; }
    if lspKind == 13 { return kinds.Enum; }
    if lspKind == 14 { return kinds.Keyword; }
    if lspKind == 15 { return kinds.Snippet; }
    if lspKind == 21 { return kinds.Constant; }
    return kinds.Text;
}

"""Map LSP SymbolKind to Monaco SymbolKind."""
def _mapSymbolKind(lspKind: int, monacoInstance: Any) -> int {
    kinds = monacoInstance.languages.SymbolKind;
    if lspKind == 1 { return kinds.File; }
    if lspKind == 2 { return kinds.Module; }
    if lspKind == 5 { return kinds.Class; }
    if lspKind == 6 { return kinds.Method; }
    if lspKind == 7 { return kinds.Property; }
    if lspKind == 8 { return kinds.Field; }
    if lspKind == 12 { return kinds.Function; }
    if lspKind == 13 { return kinds.Variable; }
    if lspKind == 14 { return kinds.Constant; }
    return kinds.Variable;
}

"""Map LSP DiagnosticSeverity to Monaco MarkerSeverity."""
def _mapSeverity(lspSeverity: int, monacoInstance: Any) -> int {
    if lspSeverity == 1 { return monacoInstance.MarkerSeverity.Error; }
    if lspSeverity == 2 { return monacoInstance.MarkerSeverity.Warning; }
    if lspSeverity == 3 { return monacoInstance.MarkerSeverity.Info; }
    if lspSeverity == 4 { return monacoInstance.MarkerSeverity.Hint; }
    return monacoInstance.MarkerSeverity.Info;
}

"""Build a file URI from workspace path and relative file path."""
def _fileUri(workspacePath: str, relativePath: str) -> str {
    if relativePath.startsWith("/") {
        return "file://" + relativePath;
    }
    return "file://" + workspacePath + "/" + relativePath;
}

"""Register Monaco language providers for LSP features."""
def _registerProviders(monacoInstance: Any, userId: str, projectId: str, workspacePath: str, disposablesRef: Any, onOpenFileRef: Any = None) -> None {
    disposables = [];

    d1 = monacoInstance.languages.registerCompletionItemProvider("jac", {
        "triggerCharacters": [".", ":"],
        "provideCompletionItems": lambda(model: Any, position: Any) -> Any {
            return Reflect.construct(Promise, [lambda(resolve: Any) {
                uri = model.uri.toString();
                params = {
                    "textDocument": {"uri": uri},
                    "position": {"line": position.lineNumber - 1, "character": position.column - 1}
                };
                lspRequest(userId, projectId, "textDocument/completion", params, lambda(resp: Any) {
                    items = [];
                    if resp and resp.result {
                        resultItems = resp.result;
                        if resp.result.items { resultItems = resp.result.items; }
                        if Array.isArray(resultItems) {
                            for item in resultItems {
                                word = model.getWordUntilPosition(position);
                                range = {
                                    "startLineNumber": position.lineNumber,
                                    "endLineNumber": position.lineNumber,
                                    "startColumn": word.startColumn,
                                    "endColumn": word.endColumn
                                };
                                items.push({
                                    "label": item.label or "",
                                    "kind": _mapCompletionKind(item.kind or 1, monacoInstance),
                                    "insertText": item.insertText or item.label or "",
                                    "detail": item.detail or "",
                                    "documentation": item.documentation or "",
                                    "range": range
                                });
                            }
                        }
                    }
                    resolve.call(None, {"suggestions": items});
                });
            }]);
        }
    });
    disposables.push(d1);

    d2 = monacoInstance.languages.registerHoverProvider("jac", {
        "provideHover": lambda(model: Any, position: Any) -> Any {
            return Reflect.construct(Promise, [lambda(resolve: Any) {
                uri = model.uri.toString();
                params = {
                    "textDocument": {"uri": uri},
                    "position": {"line": position.lineNumber - 1, "character": position.column - 1}
                };
                lspRequest(userId, projectId, "textDocument/hover", params, lambda(resp: Any) {
                    if resp and resp.result and resp.result.contents {
                        contents = resp.result.contents;
                        value = "";
                        if typeof(contents) == "string" {
                            value = contents;
                        } elif contents.value {
                            value = contents.value;
                        } elif contents.kind {
                            value = contents.value or "";
                        }
                        hoverRange = None;
                        if resp.result.range {
                            r = resp.result.range;
                            hoverRange = {
                                "startLineNumber": r.start.line + 1,
                                "endLineNumber": r.end.line + 1,
                                "startColumn": r.start.character + 1,
                                "endColumn": r.end.character + 1
                            };
                        }
                        resolve.call(None, {
                            "contents": [{"value": value}],
                            "range": hoverRange
                        });
                    } else {
                        resolve.call(None, None);
                    }
                });
            }]);
        }
    });
    disposables.push(d2);

    d3 = monacoInstance.languages.registerDefinitionProvider("jac", {
        "provideDefinition": lambda(model: Any, position: Any) -> Any {
            return Reflect.construct(Promise, [lambda(resolve: Any) {
                uri = model.uri.toString();
                params = {
                    "textDocument": {"uri": uri},
                    "position": {"line": position.lineNumber - 1, "character": position.column - 1}
                };
                lspRequest(userId, projectId, "textDocument/definition", params, lambda(resp: Any) {
                    if resp and resp.result {
                        locations = resp.result;
                        if not Array.isArray(locations) { locations = [locations]; }
                        results = [];
                        for loc in locations {
                            if loc and loc.uri and loc.range {
                                results.push({
                                    "uri": monacoInstance.Uri.parse(loc.uri),
                                    "range": {
                                        "startLineNumber": loc.range.start.line + 1,
                                        "endLineNumber": loc.range.end.line + 1,
                                        "startColumn": loc.range.start.character + 1,
                                        "endColumn": loc.range.end.character + 1
                                    }
                                });
                            }
                        }
                        resolve.call(None, results);
                    } else {
                        resolve.call(None, []);
                    }
                });
            }]);
        }
    });
    disposables.push(d3);

    d4 = monacoInstance.languages.registerReferenceProvider("jac", {
        "provideReferences": lambda(model: Any, position: Any, context: Any) -> Any {
            return Reflect.construct(Promise, [lambda(resolve: Any) {
                uri = model.uri.toString();
                params = {
                    "textDocument": {"uri": uri},
                    "position": {"line": position.lineNumber - 1, "character": position.column - 1},
                    "context": {"includeDeclaration": True}
                };
                lspRequest(userId, projectId, "textDocument/references", params, lambda(resp: Any) {
                    if resp and resp.result and Array.isArray(resp.result) {
                        results = [];
                        for loc in resp.result {
                            if loc and loc.uri and loc.range {
                                results.push({
                                    "uri": monacoInstance.Uri.parse(loc.uri),
                                    "range": {
                                        "startLineNumber": loc.range.start.line + 1,
                                        "endLineNumber": loc.range.end.line + 1,
                                        "startColumn": loc.range.start.character + 1,
                                        "endColumn": loc.range.end.character + 1
                                    }
                                });
                            }
                        }
                        resolve.call(None, results);
                    } else {
                        resolve.call(None, []);
                    }
                });
            }]);
        }
    });
    disposables.push(d4);

    d5 = monacoInstance.languages.registerDocumentSymbolProvider("jac", {
        "provideDocumentSymbols": lambda(model: Any) -> Any {
            return Reflect.construct(Promise, [lambda(resolve: Any) {
                uri = model.uri.toString();
                params = {"textDocument": {"uri": uri}};
                lspRequest(userId, projectId, "textDocument/documentSymbol", params, lambda(resp: Any) {
                    if resp and resp.result and Array.isArray(resp.result) {
                        symbols = [];
                        for sym in resp.result {
                            symRange = sym.range or (sym.location and sym.location.range);
                            if symRange {
                                symbols.push({
                                    "name": sym.name or "",
                                    "detail": sym.detail or "",
                                    "kind": _mapSymbolKind(sym.kind or 13, monacoInstance),
                                    "range": {
                                        "startLineNumber": symRange.start.line + 1,
                                        "endLineNumber": symRange.end.line + 1,
                                        "startColumn": symRange.start.character + 1,
                                        "endColumn": symRange.end.character + 1
                                    },
                                    "selectionRange": {
                                        "startLineNumber": symRange.start.line + 1,
                                        "endLineNumber": symRange.end.line + 1,
                                        "startColumn": symRange.start.character + 1,
                                        "endColumn": symRange.end.character + 1
                                    }
                                });
                            }
                        }
                        resolve.call(None, symbols);
                    } else {
                        resolve.call(None, []);
                    }
                });
            }]);
        }
    });
    disposables.push(d5);

    d6 = monacoInstance.languages.registerCompletionItemProvider("jac", {
        "triggerCharacters": [],
        "provideCompletionItems": lambda(model: Any, position: Any) -> Any {
            word = model.getWordUntilPosition(position);
            prefix = word.word or "";
            if not prefix { return {"suggestions": []}; }
            range = {
                "startLineNumber": position.lineNumber,
                "endLineNumber": position.lineNumber,
                "startColumn": word.startColumn,
                "endColumn": word.endColumn
            };
            snippetKind = monacoInstance.languages.CompletionItemKind.Snippet;
            snippets = [
                {
                    "label": "walker",
                    "kind": snippetKind,
                    "insertText": "walker ${1:MyWalker} {\n    has ${2:param}: ${3:str} = ${4:\"\"};\n\n    can ${5:start} with ${6:Root} entry {\n        ${0}\n    }\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Walker archetype",
                    "documentation": "Create a new walker with an entry ability",
                    "range": range,
                    "sortText": "z1_walker"
                },
                {
                    "label": "node",
                    "kind": snippetKind,
                    "insertText": "node ${1:MyNode} {\n    has ${2:value}: ${3:str} = ${4:\"\"};\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Node archetype",
                    "documentation": "Create a new graph node",
                    "range": range,
                    "sortText": "z1_node"
                },
                {
                    "label": "obj",
                    "kind": snippetKind,
                    "insertText": "obj ${1:MyObj} {\n    has ${2:name}: ${3:str} = ${4:\"\"};\n\n    can ${5:method}() -> ${6:None} {\n        ${0}\n    }\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Object archetype",
                    "documentation": "Create a new object (class equivalent)",
                    "range": range,
                    "sortText": "z1_obj"
                },
                {
                    "label": "edge",
                    "kind": snippetKind,
                    "insertText": "edge ${1:MyEdge} {\n    has ${2:weight}: ${3:float} = ${4:1.0};\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Edge archetype",
                    "documentation": "Create a new graph edge type",
                    "range": range,
                    "sortText": "z1_edge"
                },
                {
                    "label": "can_entry",
                    "kind": snippetKind,
                    "insertText": "can ${1:start} with ${2:Root} entry {\n    ${0}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Entry ability",
                    "documentation": "Event-driven ability triggered on node visit",
                    "range": range,
                    "sortText": "z1_can_entry"
                },
                {
                    "label": "can_exit",
                    "kind": snippetKind,
                    "insertText": "can ${1:done} with ${2:Root} exit {\n    ${0}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Exit ability",
                    "documentation": "Event-driven ability triggered when leaving a node",
                    "range": range,
                    "sortText": "z1_can_exit"
                },
                {
                    "label": "with_entry",
                    "kind": snippetKind,
                    "insertText": "with entry {\n    ${0}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Entry point block",
                    "documentation": "Main entry point (equivalent to if __name__ == '__main__')",
                    "range": range,
                    "sortText": "z1_with_entry"
                },
                {
                    "label": "import_from",
                    "kind": snippetKind,
                    "insertText": "import from ${1:module} { ${2:name} }",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Import statement",
                    "documentation": "Import names from a module",
                    "range": range,
                    "sortText": "z1_import_from"
                },
                {
                    "label": "test",
                    "kind": snippetKind,
                    "insertText": "test ${1:test_name} {\n    ${0}\n    assert ${2:True};\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Test block",
                    "documentation": "Create a new test case",
                    "range": range,
                    "sortText": "z1_test"
                },
                {
                    "label": "enum",
                    "kind": snippetKind,
                    "insertText": "enum ${1:MyEnum} {\n    ${2:VALUE1} = ${3:\"value1\"},\n    ${4:VALUE2} = ${5:\"value2\"}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Enum definition",
                    "documentation": "Create a new enumeration",
                    "range": range,
                    "sortText": "z1_enum"
                },
                {
                    "label": "walker_pub",
                    "kind": snippetKind,
                    "insertText": "walker:pub ${1:MyPublicWalker} {\n    has ${2:param}: ${3:str} = ${4:\"\"};\n\n    can ${5:start} with Root entry {\n        ${0}\n    }\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Public walker (no auth)",
                    "documentation": "Create a public walker endpoint (no JWT required)",
                    "range": range,
                    "sortText": "z1_walker_pub"
                },
                {
                    "label": "for_in",
                    "kind": snippetKind,
                    "insertText": "for ${1:item} in ${2:items} {\n    ${0}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "For loop",
                    "documentation": "Iterate over a collection",
                    "range": range,
                    "sortText": "z1_for_in"
                },
                {
                    "label": "try_except",
                    "kind": snippetKind,
                    "insertText": "try {\n    ${1}\n} except ${2:Exception} as ${3:e} {\n    ${0}\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Try/except block",
                    "documentation": "Error handling with try/except",
                    "range": range,
                    "sortText": "z1_try_except"
                },
                {
                    "label": "match_case",
                    "kind": snippetKind,
                    "insertText": "match ${1:value} {\n    case ${2:pattern1} {\n        ${3}\n    }\n    case _ {\n        ${0}\n    }\n}",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Match/case block",
                    "documentation": "Pattern matching with match/case",
                    "range": range,
                    "sortText": "z1_match_case"
                },
                {
                    "label": "glob",
                    "kind": snippetKind,
                    "insertText": "glob ${1:_my_var}: ${2:dict} = ${3:{}};",
                    "insertTextRules": monacoInstance.languages.CompletionItemInsertTextRule.InsertAsSnippet,
                    "detail": "Global variable",
                    "documentation": "Module-level global variable declaration",
                    "range": range,
                    "sortText": "z1_glob"
                }
            ];
            filtered = [];
            lowerPrefix = prefix.toLowerCase();
            for s in snippets {
                if s.label.toLowerCase().startsWith(lowerPrefix) or s.label.toLowerCase().includes(lowerPrefix) {
                    filtered.push(s);
                }
            }
            return {"suggestions": filtered};
        }
    });
    disposables.push(d6);

    d7 = monacoInstance.editor.registerEditorOpener({
        "openCodeEditor": lambda(source: Any, resource: Any, selectionOrPosition: Any) -> bool {
            uri = resource.toString();
            filePath = uri;
            if filePath.startsWith("file://") {
                filePath = filePath.substring(7);
            }
            if workspacePath and filePath.startsWith(workspacePath + "/") {
                filePath = filePath.substring(workspacePath.length + 1);
            }
            if onOpenFileRef and onOpenFileRef.current {
                openFn = onOpenFileRef.current;
                targetLine = 1;
                targetCol = 1;
                if selectionOrPosition {
                    if selectionOrPosition.lineNumber {
                        targetLine = selectionOrPosition.lineNumber;
                        targetCol = selectionOrPosition.column or 1;
                    } elif selectionOrPosition.startLineNumber {
                        targetLine = selectionOrPosition.startLineNumber;
                        targetCol = selectionOrPosition.startColumn or 1;
                    }
                }
                openFn.call(None, filePath, targetLine, targetCol);
                return True;
            }
            return False;
        }
    });
    disposables.push(d7);

    disposablesRef.current = disposables;
}

"""Check if a file is a server-side .jac file (not .cl.jac) that the LSP understands."""
def _isJacFile(path: str) -> bool {
    if not path { return False; }
    if path.endsWith(".cl.jac") { return False; }
    return path.endsWith(".jac");
}

"""Check if a URI points to a client-variant file that the LSP cannot properly analyze.
Matches: *.cl.jac, *.cl.impl.jac, and *.impl.jac where the base has .cl.jac but no bare .jac head."""
def _isClientVariantUri(uri: str, clImplBasesRef: Any = None) -> bool {
    if not uri { return False; }
    path = uri;
    if path.indexOf("?") >= 0 { path = path.split("?")[0]; }
    if path.endsWith(".cl.jac") { return True; }
    if path.endsWith(".cl.impl.jac") { return True; }
    if path.endsWith(".impl.jac") and clImplBasesRef and clImplBasesRef.current {
        fileName = path.split("/").pop() or "";
        baseName = fileName.replace(".impl.jac", "");
        if clImplBasesRef.current[baseName] { return True; }
    }
    return False;
}

"""Build a lookup of base names that have .cl.jac but no bare .jac head.
For these bases, any .impl.jac belongs to the client variant."""
def _buildClientImplBases(fileList: list) -> Any {
    clBases = {};
    headBases = {};
    bn = "";
    fn = "";
    for f in fileList {
        fn = f.split("/").pop() or f;
        if fn.endsWith(".cl.jac") and not fn.endsWith(".impl.jac") {
            bn = fn.replace(".cl.jac", "");
            clBases[bn] = True;
        } elif fn.endsWith(".jac") and not fn.endsWith(".cl.jac") and not fn.endsWith(".impl.jac") {
            bn = fn.replace(".jac", "");
            headBases[bn] = True;
        }
    }
    result = {};
    keys = Object.keys(clBases);
    for k in keys {
        if not headBases[k] {
            result[k] = True;
        }
    }
    return result;
}

"""Hook for connecting Monaco to jac lsp via WebSocket."""
def:pub useLSP(userId: str, projectId: str, workspacePath: str, monacoRef: Any, monacoReady: bool = False, fileList: list = [], onOpenFile: Any = None) -> Any {
    has lspReady: bool = False;
    disposablesRef = useRef([]);
    openDocsRef = useRef({});
    lspReadyRef = useRef(False);
    clImplBasesRef = useRef({});
    onOpenFileRef = useRef(None);

    useEffect(lambda -> None {
        onOpenFileRef.current = onOpenFile;
    }, [onOpenFile]);

    useEffect(lambda -> None {
        clImplBasesRef.current = _buildClientImplBases(fileList);
    }, [fileList]);

    def sendDidOpen(path: str, content: str) -> None {
        if not lspReadyRef.current or not _isJacFile(path) { return; }
        if openDocsRef.current[path] { return; }
        openDocsRef.current[path] = 1;
        uri = _fileUri(workspacePath, path);
        lspNotify(userId, projectId, "textDocument/didOpen", {
            "textDocument": {"uri": uri, "languageId": "jac", "version": 1, "text": content}
        });
    }

    def sendDidChange(path: str, content: str) -> None {
        if not lspReadyRef.current or not _isJacFile(path) { return; }
        ver = (openDocsRef.current[path] or 1) + 1;
        openDocsRef.current[path] = ver;
        uri = _fileUri(workspacePath, path);
        lspNotify(userId, projectId, "textDocument/didChange", {
            "textDocument": {"uri": uri, "version": ver},
            "contentChanges": [{"text": content}]
        });
    }

    def sendDidClose(path: str) -> None {
        if not lspReadyRef.current or not _isJacFile(path) { return; }
        openDocsRef.current[path] = undefined;
        uri = _fileUri(workspacePath, path);
        lspNotify(userId, projectId, "textDocument/didClose", {
            "textDocument": {"uri": uri}
        });
    }

    def sendDidSave(path: str) -> None {
        if not lspReadyRef.current or not _isJacFile(path) { return; }
        uri = _fileUri(workspacePath, path);
        lspNotify(userId, projectId, "textDocument/didSave", {
            "textDocument": {"uri": uri}
        });
    }

    useEffect(lambda {
        if not userId or not projectId or not workspacePath { return lambda -> None { }; }
        monacoInstance = monacoRef.current if monacoRef else None;
        if not monacoInstance { return lambda -> None { }; }

        lspSetNotificationHandler(lambda(notification: Any) {
            if not notification or not notification.method { return; }
            if notification.method == "textDocument/publishDiagnostics" {
                params = notification.params;
                if params and params.uri and monacoRef.current {
                    if _isClientVariantUri(params.uri, clImplBasesRef) { return; }
                    m = monacoRef.current;
                    diagnostics = params.diagnostics or [];
                    markers = [];
                    for diag in diagnostics {
                        r = diag.range;
                        if r {
                            markers.push({
                                "severity": _mapSeverity(diag.severity or 1, m),
                                "startLineNumber": r.start.line + 1,
                                "startColumn": r.start.character + 1,
                                "endLineNumber": r.end.line + 1,
                                "endColumn": r.end.character + 1,
                                "message": diag.message or "",
                                "source": diag.source or "jac"
                            });
                        }
                    }
                    modelUri = m.Uri.parse(params.uri);
                    model = m.editor.getModel(modelUri);
                    if model {
                        m.editor.setModelMarkers(model, "jac-lsp", markers);
                    }
                }
            }
        });

        lspInit(userId, projectId, workspacePath, lambda {
            lspReady = True;
            lspReadyRef.current = True;
            mi = monacoRef.current;
            if mi {
                _registerProviders(mi, userId, projectId, workspacePath, disposablesRef, onOpenFileRef);
            }
        });

        return lambda -> None {
            lspReady = False;
            lspReadyRef.current = False;
            for d in disposablesRef.current {
                if d and d.dispose { d.dispose(); }
            }
            disposablesRef.current = [];
            openDocsRef.current = {};
            lspShutdown(userId, projectId);
            lspSetNotificationHandler(None);
        };
    }, [userId, projectId, workspacePath, monacoReady]);

    def searchWorkspaceSymbols(query: str, callback: Any) -> None {
        if not lspReadyRef.current { return; }
        params = {"query": query};
        lspRequest(userId, projectId, "workspace/symbol", params, lambda(resp: Any) {
            results = [];
            monacoInstance = monacoRef.current if monacoRef else None;
            if resp and resp.result and Array.isArray(resp.result) {
                for sym in resp.result {
                    loc = sym.location;
                    if loc and loc.uri and loc.range {
                        if _isClientVariantUri(loc.uri, clImplBasesRef) { continue; }
                        filePath = loc.uri;
                        if filePath.startsWith("file://") {
                            filePath = filePath.substring(7);
                        }
                        if workspacePath and filePath.startsWith(workspacePath + "/") {
                            filePath = filePath.substring(workspacePath.length + 1);
                        }
                        results.push({
                            "name": sym.name or "",
                            "kind": sym.kind or 13,
                            "containerName": sym.containerName or "",
                            "filePath": filePath,
                            "range": {
                                "startLine": loc.range.start.line + 1,
                                "startColumn": loc.range.start.character + 1,
                                "endLine": loc.range.end.line + 1,
                                "endColumn": loc.range.end.character + 1
                            }
                        });
                    }
                }
            }
            cb = callback;
            cb.call(None, results);
        });
    }

    return {
        "lspReady": lspReady,
        "sendDidOpen": sendDidOpen,
        "sendDidChange": sendDidChange,
        "sendDidClose": sendDidClose,
        "sendDidSave": sendDidSave,
        "searchWorkspaceSymbols": searchWorkspaceSymbols
    };
}

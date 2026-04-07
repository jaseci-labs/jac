"""Global Monaco initialization - ensures syntax highlighting is loaded once."""

import from "monaco-textmate" { Registry }
import from "monaco-editor-textmate" { wireTmGrammars }
import from "onigasm" { loadWASM }

# CORRECTED PATHS - Use absolute paths from web root
glob ONIG_WASM_PATH = "/static/assets/onigasm.wasm";
glob LANGUAGE_CONFIG_PATH = "/static/assets/language-configuration.json";
glob LOCAL_GRAMMAR_PATH = "/static/assets/jac.tmLanguage.json";
glob GITHUB_GRAMMAR_URL = "https://raw.githubusercontent.com/jaseci-labs/jac-vscode/main/syntaxes/jac.tmLanguage.json";

# Global initialization state
glob monacoInitialized = false;
glob initializationPromise = null;
glob cachedGrammarConfig = null;
glob cachedRegistry = null;
glob cachedGrammarMap = null;

"""Internal function to perform the actual initialization."""
async def _performInitialization() -> Any {
    try {
        # Load WASM
        await loadWASM(ONIG_WASM_PATH);

        # Fetch Jac grammar - try local first, fallback to GitHub
        jacGrammar = None;
        try {
            localResponse = await fetch(LOCAL_GRAMMAR_PATH);
            if localResponse.ok {
                jacGrammar = await localResponse.json();
            }
        } except Exception as localErr {
            console.warn("Local grammar fetch failed, trying GitHub:", localErr);
        }

        if not jacGrammar {
            response = await fetch(GITHUB_GRAMMAR_URL);
            if not response.ok {
                raise Reflect.construct(Error, [f"Failed to fetch grammar: {response.status}"]);
            }
            jacGrammar = await response.json();
        }

        grammarConfigRes = await fetch(LANGUAGE_CONFIG_PATH);

        if not grammarConfigRes.ok {
            raise Reflect.construct(Error, [f"Failed to fetch language config: {grammarConfigRes.status}"]);
        }
        cachedGrammarConfig = await grammarConfigRes.json();

        # Create TextMate registry
        registry = Reflect.construct(Registry, [{
            getGrammarDefinition: lambda {
                return {
                    format: "json",
                    content: JSON.stringify(jacGrammar)
                };
            }
        }]);

        cachedRegistry = registry;

        # Create grammar map
        grammar = Reflect.construct(Map, []);
        grammar.set("jac", "source.jac");
        cachedGrammarMap = grammar;

        monacoInitialized = true;

        return cachedGrammarConfig;

    } except Exception as error {
        initializationPromise = null;  # Reset on error to allow retry
        return null;
    }
}

"""Initialize Monaco globally - call this once when the app loads."""
async def:pub initializeMonacoGlobally() -> Any {
    # Configure Monaco worker URL (must be set before any Monaco usage)
    if not globalThis.MonacoEnvironment {
        globalThis.MonacoEnvironment = {
            getWorkerUrl: lambda(_moduleId: Any, _label: Any) {
                return "/static/assets/monaco-workers/editor.worker.js";
            }
        };
    }

    # If already initialized or in progress, return the existing promise
    if monacoInitialized {
        return cachedGrammarConfig;
    }

    if initializationPromise {
        return await initializationPromise;
    }

    # Create initialization promise by calling the async function
    initializationPromise = _performInitialization();

    return await initializationPromise;
}

"""Setup Monaco editor instance with Jac syntax highlighting."""
async def:pub setupMonacoEditor(monaco: Any, editor: Any) -> Any {
    try {
        # Ensure global initialization is complete
        if not monacoInitialized {
            await initializeMonacoGlobally();
        }

        # Register language if not already registered
        languages = monaco.languages.getLanguages();
        isJacRegistered = languages.some(lambda lang: Any { return lang.id == "jac"; });

        if not isJacRegistered {
            monaco.languages.register({ id: "jac" });
        }

        # Wire grammar to this specific editor instance (lightweight operation)
        if editor and cachedRegistry and cachedGrammarMap {
            await wireTmGrammars(monaco, cachedRegistry, cachedGrammarMap, editor);
        }

        return cachedGrammarConfig;

    } except Exception as error {
        return null;
    }
}

"""Configure Monaco themes - defines both dark and light variants."""
def:pub defineJacTheme(monaco: Any) -> None {
    try {
        monaco.editor.defineTheme("jac-theme-dark", {
            base: "vs-dark",
            inherit: true,
            rules: [
                { token: "storage.type.class.jac", foreground: "f97316", fontStyle: "bold" },
                { token: "storage.type.function.jac", foreground: "f97316", fontStyle: "bold" },
                { token: "keyword.control.flow.jac", foreground: "f97316", fontStyle: "bold" },
                { token: "keyword.control.import.jac", foreground: "f97316" },
                { token: "storage.type.has.jac", foreground: "f97316" },
                { token: "storage.modifier.declaration.jac", foreground: "f97316" },
                { token: "entity.name.type.class.jac", foreground: "fbbf24" },
                { token: "entity.name.function.jac", foreground: "fbbf24" },
                { token: "support.type.jac", foreground: "fb923c" },
                { token: "constant.language.jac", foreground: "fb923c" },
                { token: "string.quoted.single.jac", foreground: "86efac" },
                { token: "string.quoted.double.jac", foreground: "86efac" },
                { token: "string.interpolated.jac", foreground: "86efac" },
                { token: "constant.numeric.jac", foreground: "c084fc" },
                { token: "comment.line.jac", foreground: "6b7280", fontStyle: "italic" },
                { token: "comment.block.jac", foreground: "6b7280", fontStyle: "italic" },
                { token: "variable.parameter.jac", foreground: "93c5fd" },
                { token: "variable.language.special.self.jac", foreground: "93c5fd" }
            ],
            colors: {
                "editor.background": "#1a1b1e",
                "editor.foreground": "#e4e4e7",
                "editorLineNumber.foreground": "#6b7280",
                "editorLineNumber.activeForeground": "#f97316",
                "editorCursor.foreground": "#f97316",
                "editor.selectionBackground": "#f9731633"
            }
        });
        monaco.editor.defineTheme("jac-theme-light", {
            base: "vs",
            inherit: true,
            rules: [
                { token: "storage.type.class.jac", foreground: "c2410c", fontStyle: "bold" },
                { token: "storage.type.function.jac", foreground: "c2410c", fontStyle: "bold" },
                { token: "keyword.control.flow.jac", foreground: "c2410c", fontStyle: "bold" },
                { token: "keyword.control.import.jac", foreground: "c2410c" },
                { token: "storage.type.has.jac", foreground: "c2410c" },
                { token: "storage.modifier.declaration.jac", foreground: "c2410c" },
                { token: "entity.name.type.class.jac", foreground: "b45309" },
                { token: "entity.name.function.jac", foreground: "b45309" },
                { token: "support.type.jac", foreground: "ea580c" },
                { token: "constant.language.jac", foreground: "ea580c" },
                { token: "string.quoted.single.jac", foreground: "16a34a" },
                { token: "string.quoted.double.jac", foreground: "16a34a" },
                { token: "string.interpolated.jac", foreground: "16a34a" },
                { token: "constant.numeric.jac", foreground: "9333ea" },
                { token: "comment.line.jac", foreground: "9ca3af", fontStyle: "italic" },
                { token: "comment.block.jac", foreground: "9ca3af", fontStyle: "italic" },
                { token: "variable.parameter.jac", foreground: "2563eb" },
                { token: "variable.language.special.self.jac", foreground: "2563eb" }
            ],
            colors: {
                "editor.background": "#ffffff",
                "editor.foreground": "#1f2937",
                "editorLineNumber.foreground": "#9ca3af",
                "editorLineNumber.activeForeground": "#ea580c",
                "editorCursor.foreground": "#ea580c",
                "editor.selectionBackground": "#f9731633"
            }
        });
    } except Exception as error {
    }
}

"""Apply the correct Monaco theme based on resolved theme mode."""
def:pub applyMonacoTheme(monaco: Any, resolvedTheme: str) -> None {
    try {
        themeName = ("jac-theme-light" if resolvedTheme == "light" else "jac-theme-dark");
        monaco.editor.setTheme(themeName);
    } except Exception as error {
    }
}

"""Configure Monaco theme - only needs to be called once per Monaco instance."""
def:pub configureMonacoTheme(monaco: Any, grammarConfig: Any, resolvedTheme: str = "dark") -> None {
    try {
        if grammarConfig {
            monaco.languages.setLanguageConfiguration("jac", grammarConfig);
        }

        defineJacTheme(monaco);
        applyMonacoTheme(monaco, resolvedTheme);

    } except Exception as error {
    }
}

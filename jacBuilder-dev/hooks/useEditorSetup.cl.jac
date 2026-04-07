"""Editor setup hook — content sync, language detection, mount handler, minimap."""

import from react { useState, useEffect, useRef }
import from ..utils.monaco_initializer { setupMonacoEditor, configureMonacoTheme, applyMonacoTheme }

"""Hook for managing Monaco editor state: content sync, language, mount, minimap."""
def:pub useEditorSetup(ide: Any, lspRef: Any = None, resolvedTheme: str = "dark") -> Any {
    has editorContent: str = "";
    has showMinimap: bool = False;
    has wordWrap: bool = True;
    has monacoReady: bool = False;

    editorRef = useRef(None);
    monacoRef = useRef(None);

    # Sync editor content when active tab changes (skip diff tabs)
    useEffect(lambda -> None {
        if ide.activeTab and ide.activeTab.startsWith("diff://") { return; }
        for tab in ide.openTabs {
            if tab.path == ide.activeTab {
                editorContent = tab.content or "";
                return;
            }
        }
    }, [ide.activeTab]);

    useEffect(lambda -> None {
        if monacoRef.current {
            applyMonacoTheme(monacoRef.current, resolvedTheme);
        }
    }, [resolvedTheme]);

    # Determine language from file extension
    def getLanguage() -> str {
        path = ide.activeTab or "";
        if path.startsWith("diff://") {
            slashIdx = path.indexOf("/", 7);
            if slashIdx >= 0 { path = path.slice(slashIdx + 1); }
        }
        if path.endsWith(".json") { return "json"; }
        elif path.endsWith(".toml") { return "toml"; }
        elif path.endsWith(".md") { return "markdown"; }
        elif path.endsWith(".css") { return "css"; }
        elif path.endsWith(".html") { return "html"; }
        elif path.endsWith(".js") { return "javascript"; }
        elif path.endsWith(".ts") { return "typescript"; }
        return "jac";
    }

    # Monaco editor mount handler
    async def handleEditorDidMount(editor: Any, monacoInstance: Any) -> None {
        editorRef.current = editor;
        monacoRef.current = monacoInstance;
        monacoReady = True;

        await setupMonacoEditor(monacoInstance, editor);
        configureMonacoTheme(monacoInstance, None, resolvedTheme);

        # Ctrl+S save handler
        editor.addCommand(
            monacoInstance.KeyMod.CtrlCmd | monacoInstance.KeyCode.KeyS,
            lambda {
                ide.saveFile();
                if lspRef and lspRef.current and lspRef.current.sendDidSave and ide.activeTab {
                    lspRef.current.sendDidSave(ide.activeTab);
                }
            }
        );
    }

    # Handle editor content changes
    def handleEditorChange(value: Any) -> None {
        newValue = value or "";
        editorContent = newValue;
        if ide.activeTab {
            ide.updateTabContent(ide.activeTab, newValue);
        }
        if lspRef and lspRef.current and lspRef.current.sendDidChange and ide.activeTab {
            lspRef.current.sendDidChange(ide.activeTab, newValue);
        }
    }

    def toggleMinimap() -> None {
        newVal = not showMinimap;
        showMinimap = newVal;
        if editorRef.current {
            editorRef.current.updateOptions({"minimap": {"enabled": newVal}});
        }
    }

    def toggleWordWrap() -> None {
        newVal = not wordWrap;
        wordWrap = newVal;
        if editorRef.current {
            editorRef.current.updateOptions({"wordWrap": ("on" if newVal else "off")});
        }
    }

    return {
        "editorContent": editorContent,
        "showMinimap": showMinimap,
        "wordWrap": wordWrap,
        "monacoReady": monacoReady,
        "editorRef": editorRef,
        "monacoRef": monacoRef,
        "getLanguage": getLanguage,
        "handleEditorDidMount": handleEditorDidMount,
        "handleEditorChange": handleEditorChange,
        "toggleMinimap": toggleMinimap,
        "toggleWordWrap": toggleWordWrap
    };
}

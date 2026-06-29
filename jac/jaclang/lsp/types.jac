import from enum { IntEnum, StrEnum }
import from typing { Dict, List, Optional, Union }

glob TEXT_DOCUMENT_DID_OPEN = "textDocument/didOpen",
     TEXT_DOCUMENT_DID_SAVE = "textDocument/didSave",
     TEXT_DOCUMENT_DID_CHANGE = "textDocument/didChange",
     TEXT_DOCUMENT_DID_CLOSE = "textDocument/didClose",
     TEXT_DOCUMENT_FORMATTING = "textDocument/formatting",
     TEXT_DOCUMENT_COMPLETION = "textDocument/completion",
     TEXT_DOCUMENT_HOVER = "textDocument/hover",
     TEXT_DOCUMENT_DOCUMENT_SYMBOL = "textDocument/documentSymbol",
     TEXT_DOCUMENT_DEFINITION = "textDocument/definition",
     TEXT_DOCUMENT_REFERENCES = "textDocument/references",
     TEXT_DOCUMENT_RENAME = "textDocument/rename",
     TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL = "textDocument/semanticTokens/full",
     WORKSPACE_DID_CREATE_FILES = "workspace/didCreateFiles",
     WORKSPACE_DID_RENAME_FILES = "workspace/didRenameFiles",
     WORKSPACE_DID_DELETE_FILES = "workspace/didDeleteFiles",
     TEXT_DOCUMENT_LINTFIX_FORMATTING = "jac/lintfixFormat",
     WORKSPACE_SEMANTIC_TOKENS_REFRESH = "workspace/semanticTokens/refresh",
     INITIALIZE = "initialize",
     INITIALIZED = "initialized",
     SHUTDOWN = "shutdown",
     EXIT = "exit",
     TEXT_DOCUMENT_PUBLISH_DIAGNOSTICS = "textDocument/publishDiagnostics",
     WINDOW_SHOW_MESSAGE = "window/showMessage",
     WINDOW_LOG_MESSAGE = "window/logMessage";

enum MessageType(IntEnum) { Error = 1, Warning = 2, Info = 3, Log = 4 }

enum DiagnosticSeverity(IntEnum) { Error = 1, Warning = 2, Information = 3, Hint = 4 }

enum SymbolKind(IntEnum) {
    File = 1,
    Module = 2,
    Namespace = 3,
    Package = 4,
    Class = 5,
    Method = 6,
    Property = 7,
    Field = 8,
    Constructor = 9,
    Enum = 10,
    Interface = 11,
    Function = 12,
    Variable = 13,
    Constant = 14,
    String = 15,
    Number = 16,
    Boolean = 17,
    Array = 18,
    Object = 19,
    Key = 20,
    Null = 21,
    EnumMember = 22,
    Struct = 23,
    Event = 24,
    Operator = 25,
    TypeParameter = 26
}

enum CompletionItemKind(IntEnum) {
    Text = 1,
    Method = 2,
    Function = 3,
    Constructor = 4,
    Field = 5,
    Variable = 6,
    Class = 7,
    Interface = 8,
    Module = 9,
    Property = 10,
    Unit = 11,
    Value = 12,
    Enum = 13,
    Keyword = 14,
    Snippet = 15,
    Color = 16,
    File = 17,
    Reference = 18,
    Folder = 19,
    EnumMember = 20,
    Constant = 21,
    Struct = 22,
    Event = 23,
    Operator = 24,
    TypeParameter = 25
}

enum MarkupKind(StrEnum) { PlainText = "plaintext", Markdown = "markdown" }

enum TextDocumentSyncKind(IntEnum) { None_ = 0, Full = 1, Incremental = 2 }

enum PositionEncodingKind(StrEnum) {
    Utf8 = "utf-8",
    Utf16 = "utf-16",
    Utf32 = "utf-32"
}

obj Position {
    has line: int = 0,
        character: int = 0;

    def __repr__ -> str;
    def __eq__(other: object) -> bool;
    def __hash__ -> int;
}

obj Range {
    has start: Position = Position(),
        end: Position = Position();

    def __repr__ -> str;
    def __eq__(other: object) -> bool;
    def __hash__ -> int;
}

obj Location {
    has uri: str = "",
        range: Range = Range();

    def __repr__ -> str;
}

obj TextEdit {
    has range: Range = Range(),
        new_text: str = "";
}

obj MarkupContent {
    has kind: MarkupKind = MarkupKind.PlainText,
        value: str = "";
}

obj Diagnostic {
    has range: Range = Range(),
        message: str = "",
        severity: Optional[DiagnosticSeverity] = None,
        code: Optional[str] = None,
        source: Optional[str] = None;
}

obj TextDocumentIdentifier {
    has uri: str = "";
}

obj TextDocumentItem {
    has uri: str = "",
        language_id: str = "",
        version: int = 0,
        text: str = "";
}

obj VersionedTextDocumentIdentifier {
    has uri: str = "",
        version: int = 0;
}

obj TextDocumentContentChangeEvent_Type1 {
    has range: Range = Range(),
        text: str = "",
        range_length: Optional[int] = None;
}

obj TextDocumentContentChangeEvent {
    has text: str = "";
}

obj DidOpenTextDocumentParams {
    has text_document: TextDocumentItem = TextDocumentItem();
}

obj DidChangeTextDocumentParams {
    has text_document: VersionedTextDocumentIdentifier = VersionedTextDocumentIdentifier(),
        content_changes:
            list[
                Union[
                    TextDocumentContentChangeEvent_Type1,
                    TextDocumentContentChangeEvent
                ]
            ] = [];
}

obj DidCloseTextDocumentParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier();
}

obj DidSaveTextDocumentParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        text: Optional[str] = None;
}

obj CompletionContext {
    has trigger_kind: int = 1,
        trigger_character: Optional[str] = None;
}

obj TextDocumentPositionParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        position: Position = Position();
}

obj CompletionParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        position: Position = Position(),
        context: Optional[CompletionContext] = None;
}

obj DocumentSymbolParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier();
}

obj ReferenceContext {
    has include_declaration: bool = True;
}

obj ReferenceParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        position: Position = Position(),
        context: ReferenceContext = ReferenceContext();
}

obj RenameParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        position: Position = Position(),
        new_name: str = "";
}

obj FormattingOptions {
    has tab_size: int = 4,
        insert_spaces: bool = True;
}

obj DocumentFormattingParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier(),
        options: FormattingOptions = FormattingOptions();
}

obj SemanticTokensParams {
    has text_document: TextDocumentIdentifier = TextDocumentIdentifier();
}

obj FileCreate {
    has uri: str = "";
}

obj CreateFilesParams {
    has files: list[FileCreate] = [];
}

obj FileRename {
    has old_uri: str = "",
        new_uri: str = "";
}

obj RenameFilesParams {
    has files: list[FileRename] = [];
}

obj FileDelete {
    has uri: str = "";
}

obj DeleteFilesParams {
    has files: list[FileDelete] = [];
}

obj CompletionItemLabelDetails {
    has detail: Optional[str] = None,
        description: Optional[str] = None;
}

obj CompletionItem {
    has label: str = "",
        kind: Optional[CompletionItemKind] = None,
        label_details: Optional[CompletionItemLabelDetails] = None;
}

obj CompletionList {
    has is_incomplete: bool = False,
        items: list[CompletionItem] = [];
}

obj Hover {
    has contents: Union[MarkupContent, str] = "",
        range: Optional[Range] = None;
}

obj DocumentSymbol {
    has name: str = "",
        kind: SymbolKind = SymbolKind.File,
        range: Range = Range(),
        selection_range: Range = Range(),
        children: Optional[list[DocumentSymbol]] = None;
}

obj SemanticTokens {
    has data: list[int] = [];
}

obj WorkspaceEdit {
    has changes: Optional[dict[str, list[TextEdit]]] = None;
}

obj CompletionOptions {
    has trigger_characters: Optional[list[str]] = None,
        resolve_provider: Optional[bool] = None;
}

obj HoverOptions {
    has work_done_progress: Optional[bool] = None;
}

obj SemanticTokensLegend {
    has token_types: list[str] = [],
        token_modifiers: list[str] = [];
}

obj FileOperationPattern {
    has glob: str = "";
}

obj FileOperationFilter {
    has pattern: FileOperationPattern = FileOperationPattern();
}

obj FileOperationRegistrationOptions {
    has filters: list[FileOperationFilter] = [];
}

glob METHOD_TO_PARAMS: dict[str, type] = {
         TEXT_DOCUMENT_DID_OPEN: DidOpenTextDocumentParams,
         TEXT_DOCUMENT_DID_SAVE: DidSaveTextDocumentParams,
         TEXT_DOCUMENT_DID_CHANGE: DidChangeTextDocumentParams,
         TEXT_DOCUMENT_DID_CLOSE: DidCloseTextDocumentParams,
         TEXT_DOCUMENT_FORMATTING: DocumentFormattingParams,
         TEXT_DOCUMENT_COMPLETION: CompletionParams,
         TEXT_DOCUMENT_HOVER: TextDocumentPositionParams,
         TEXT_DOCUMENT_DOCUMENT_SYMBOL: DocumentSymbolParams,
         TEXT_DOCUMENT_DEFINITION: TextDocumentPositionParams,
         TEXT_DOCUMENT_REFERENCES: ReferenceParams,
         TEXT_DOCUMENT_RENAME: RenameParams,
         TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL: SemanticTokensParams,
         WORKSPACE_DID_CREATE_FILES: CreateFilesParams,
         WORKSPACE_DID_RENAME_FILES: RenameFilesParams,
         WORKSPACE_DID_DELETE_FILES: DeleteFilesParams,
         TEXT_DOCUMENT_LINTFIX_FORMATTING: DocumentFormattingParams
     };

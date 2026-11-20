def param_text(p: ApiParam) -> str;

def call_text(name: str, params: list[ApiParam], returns: str) -> str;

def symbol_text(sym: ApiSymbol) -> str;

def member_text(m: ApiMember) -> str;

def:pub DocText(text: str) -> JsxElement;

def:pub ApiSymbolCard(sym: ApiSymbol, anchor: str) -> JsxElement;

def:pub ApiDocs(modules: list[ApiModule]) -> JsxElement;

import json;

glob PARSED_VIEWS: tuple[str, ...] = ("tree", "json"),
     ANALYSED_VIEWS: tuple[str, ...] = (
         "sym",
         "sym.",
         "ast",
         "ast.",
         "cfg.",
         "unparse",
         "docir",
         "esast",
         "es"
     );

def module_banner(name: str) -> str;

def parsed_view(module: uni.Module, view: str) -> str;

def analysed_view(program: JacProgram, module: uni.Module, view: str) -> str;

def client_tree(program: JacProgram, module: uni.Module) -> EsNode;

import jaclang.compiler.passes.ecmascript.estree as es;

obj FreeIdentifier {
    has name: str,
        line: int,
        column: int;
}

glob RUNTIME_PRELUDE_GLOBALS: set[str] = {"__jacJsx", "__jacSpawn"};

def client_ambient_globals -> set[str];
def free_identifiers(program: es.Program, allowed: set[str]) -> list[FreeIdentifier];

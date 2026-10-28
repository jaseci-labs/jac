enum TsTypeKind {
    ANY = "any",
    NEVER = "never",
    VOID = "void",
    PRIM = "prim",
    LITERAL_STR = "literal-str",
    LITERAL_NUM = "literal-num",
    LITERAL_BOOL = "literal-bool",
    UNION = "union",
    ARRAY = "array",
    TUPLE = "tuple",
    FUNC = "func",
    REF = "ref"
}

enum TsDeclKind {
    ANY = "any",
    FUNCTION = "function",
    CONST = "const",
    TYPEALIAS = "typealias",
    INTERFACE = "interface",
    CLASS = "class",
    ENUM = "enum",
    NAMESPACE = "namespace",
    REEXPORT = "reexport"
}

enum TsAccess { PUBLIC = "public", PRIVATE = "private", PROTECTED = "protected" }

obj TsParam {
    has name: str = "",
        ty: (TsType | None) = None,
        optional: bool = False,
        rest: bool = False;
}

obj TsType {
    has kind: TsTypeKind = TsTypeKind.ANY,
        name: str = "",
        args: list[TsType] = [],
        params: list[TsParam] = [],
        ret: (TsType | None) = None;
}

obj TsMember {
    has name: str = "",
        ty: (TsType | None) = None,
        optional: bool = False,
        readonly: bool = False,
        is_method: bool = False,
        is_static: bool = False,
        access: TsAccess = TsAccess.PUBLIC;
}

obj TsDecl {
    has name: str = "",
        kind: TsDeclKind = TsDeclKind.ANY,
        ty: (TsType | None) = None,
        members: list[TsMember] = [],
        heritage: list[str] = [],
        call_sig: (TsType | None) = None;
}

glob _PRIM_NAMES: frozenset[str] = frozenset(
         {'string', 'number', 'boolean', 'object', 'symbol', 'bigint'}
     ),
     _ANY_NAMES: frozenset[str] = frozenset({'any', 'unknown', 'this'}),
     _VOID_NAMES: frozenset[str] = frozenset({'void', 'undefined', 'null'});

def _tokenize(src: str) -> (list[tuple[(str, str)]] | None);

def parse_dts(source: str) -> (dict[str, TsDecl] | None);

def _parse_dts_inner(source: str) -> (dict[str, TsDecl] | None);


def ts_decl_binding_kind(decl: TsDecl, decls: dict[str, TsDecl]) -> BindingKind;

obj Info {
    has name: str,
        semstr: (str | None);
}

obj TypeForm {
    has head: str,
        args: list[(ClassInfo | EnumInfo | TypeForm | str | None)] = [];
}

obj VarInfo(Info) {
    has type_info: (ClassInfo | EnumInfo | TypeForm | str | None) = None;
}

obj ParamInfo(VarInfo) {}

obj FieldInfo(VarInfo) {}

obj EnumInfo(Info) {
    has members: list[FieldInfo];
}

obj ClassInfo(Info) {
    has fields: list[FieldInfo],
        base_classes: list[ClassInfo],
        methods: list[MethodInfo];

    def postinit -> object;
}

obj FunctionInfo(Info) {
    has params: (list[ParamInfo] | None) = None,
        return_type: (ClassInfo | EnumInfo | TypeForm | str | None) = None,
        tools: (list[FunctionInfo] | None) = None,
        by_call: bool = False;

    def postinit -> object;
}

obj MethodInfo(FunctionInfo) {
    has parent_class: (ClassInfo | None) = None;
}

def mk_form(
    head: str, args: list[(ClassInfo | EnumInfo | TypeForm | str | None)]
) -> TypeForm;

def mk_list(inner: (ClassInfo | EnumInfo | TypeForm | str | None)) -> TypeForm;

def mk_dict(
    key: (ClassInfo | EnumInfo | TypeForm | str | None),
    val: (ClassInfo | EnumInfo | TypeForm | str | None)
) -> TypeForm;

def type_to_str(t: (Info | TypeForm | str | None)) -> str;

glob INFO_GRAPH_VERSION: int = 1;

obj InfoGraphWriter {
    has nodes: list[dict[str, any]] = [],
        index: dict[int, int] = {};

    def ref(item: (Info | TypeForm | str | None)) -> any;
    def refs(items: Sequence[(Info | TypeForm | str | None)]) -> list[any];
    def fill(record: dict[str, any], item: (Info | TypeForm));
}

obj InfoGraphReader {
    has records: list[dict[str, any]],
        built: list[(Info | TypeForm)] = [];

    def shell(record: dict[str, any]) -> (Info | TypeForm);
    def find(raw: any) -> (Info | TypeForm | None);
    def find_all(raw: any) -> list[(Info | TypeForm | None)];
    def type_ref(raw: any) -> (ClassInfo | EnumInfo | TypeForm | str | None);
    def type_refs(raw: any) -> list[(ClassInfo | EnumInfo | TypeForm | str | None)];
    def fields(raw: any) -> list[FieldInfo];
    def classes(raw: any) -> list[ClassInfo];
    def methods(raw: any) -> list[MethodInfo];
    def params(raw: any) -> list[ParamInfo];
    def functions(raw: any) -> list[FunctionInfo];
    def build -> list[(Info | TypeForm)];
}

def info_graph_to_json(entries: dict[str, Info]) -> str;

def info_graph_from_json(text: str) -> dict[str, Info];

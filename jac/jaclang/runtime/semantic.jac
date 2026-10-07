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
) -> TypeForm {
    return TypeForm(head=head, args=list(args));
}

def mk_list(inner: (ClassInfo | EnumInfo | TypeForm | str | None)) -> TypeForm {
    return TypeForm(head='list', args=[inner]);
}

def mk_dict(
    key: (ClassInfo | EnumInfo | TypeForm | str | None),
    val: (ClassInfo | EnumInfo | TypeForm | str | None)
) -> TypeForm {
    return TypeForm(head='dict', args=[key, val]);
}

def type_to_str(t: (Info | TypeForm | str | None)) -> str {
    if t is None {
        return 'None';
    }
    if isinstance(t, str) {
        return t;
    }
    if isinstance(t, TypeForm) {
        parts: list[str] = [];
        for arg in t.args {
            parts.append(type_to_str(arg));
        }
        if t.head == 'union' {
            return '|'.join(parts);
        }
        return f"{t.head}[{','.join(parts)}]";
    }
    return t.name;
}

glob INFO_GRAPH_VERSION: int = 1;

obj InfoGraphWriter {
    has nodes: list[dict[str, any]] = [],
        index: dict[int, int] = {};

    def ref(item: (Info | TypeForm | str | None)) -> any {
        if item is None or isinstance(item, str) {
            return item;
        }
        found = self.index.get(id(item));
        if found is not None {
            return {"n": found};
        }
        slot = len(self.nodes);
        self.index[id(item)] = slot;
        record: dict[str, any] = {};
        self.nodes.append(record);
        self.fill(record, item);
        return {"n": slot};
    }

    def refs(items: Sequence[(Info | TypeForm | str | None)]) -> list[any] {
        return [self.ref(item) for item in items];
    }

    def fill(record: dict[str, any], item: (Info | TypeForm)) {
        if isinstance(item, TypeForm) {
            record["k"] = "form";
            record["head"] = item.head;
            record["args"] = self.refs(item.args);
            return;
        }
        record["name"] = item.name;
        record["semstr"] = item.semstr;
        if isinstance(item, ClassInfo) {
            record["k"] = "class";
            record["fields"] = self.refs(item.fields);
            record["bases"] = self.refs(item.base_classes);
            record["methods"] = self.refs(item.methods);
        } elif isinstance(item, EnumInfo) {
            record["k"] = "enum";
            record["members"] = self.refs(item.members);
        } elif isinstance(item, FunctionInfo) {
            record["k"] = "method" if isinstance(item, MethodInfo) else "func";
            record["params"] = self.refs(item.params or []);
            record["returns"] = self.ref(item.return_type);
            record["tools"] = self.refs(item.tools or []);
            record["by_call"] = item.by_call;
            if isinstance(item, MethodInfo) {
                record["parent"] = self.ref(item.parent_class);
            }
        } elif isinstance(item, VarInfo) {
            record["k"] = "param"
                if isinstance(item, ParamInfo)
                else ("field" if isinstance(item, FieldInfo) else "var");
            record["type"] = self.ref(item.type_info);
        } else {
            record["k"] = "info";
        }
    }
}

obj InfoGraphReader {
    has records: list[dict[str, any]],
        built: list[(Info | TypeForm)] = [];

    def shell(record: dict[str, any]) -> (Info | TypeForm) {
        kind = str(record.get("k", "info"));
        name = str(record.get("name", ""));
        raw_semstr = record.get("semstr");
        semstr = str(raw_semstr) if raw_semstr is not None else None;
        if kind == "form" {
            return TypeForm(head=str(record.get("head", "")));
        }
        if kind == "class" {
            return ClassInfo(
                name=name, semstr=semstr, fields=[], base_classes=[], methods=[]
            );
        }
        if kind == "enum" {
            return EnumInfo(name=name, semstr=semstr, members=[]);
        }
        if kind == "method" {
            return MethodInfo(name=name, semstr=semstr);
        }
        if kind == "func" {
            return FunctionInfo(name=name, semstr=semstr);
        }
        if kind == "param" {
            return ParamInfo(name=name, semstr=semstr);
        }
        if kind == "field" {
            return FieldInfo(name=name, semstr=semstr);
        }
        if kind == "var" {
            return VarInfo(name=name, semstr=semstr);
        }
        return Info(name=name, semstr=semstr);
    }

    def find(raw: any) -> (Info | TypeForm | None) {
        if isinstance(raw, dict) {
            slot = raw.get("n");
            if isinstance(slot, int) and 0 <= slot < len(self.built) {
                return self.built[slot];
            }
        }
        return None;
    }

    def find_all(raw: any) -> list[(Info | TypeForm | None)] {
        if not isinstance(raw, list) {
            return [];
        }
        return [self.find(item) for item in raw];
    }

    def type_ref(raw: any) -> (ClassInfo | EnumInfo | TypeForm | str | None) {
        if isinstance(raw, str) {
            return raw;
        }
        found = self.find(raw);
        if isinstance(found, (ClassInfo, EnumInfo, TypeForm)) {
            return found;
        }
        return None;
    }

    def type_refs(raw: any) -> list[(ClassInfo | EnumInfo | TypeForm | str | None)] {
        if not isinstance(raw, list) {
            return [];
        }
        return [self.type_ref(item) for item in raw];
    }

    def fields(raw: any) -> list[FieldInfo] {
        out: list[FieldInfo] = [];
        for found in self.find_all(raw) {
            if isinstance(found, FieldInfo) {
                out.append(found);
            }
        }
        return out;
    }

    def classes(raw: any) -> list[ClassInfo] {
        out: list[ClassInfo] = [];
        for found in self.find_all(raw) {
            if isinstance(found, ClassInfo) {
                out.append(found);
            }
        }
        return out;
    }

    def methods(raw: any) -> list[MethodInfo] {
        out: list[MethodInfo] = [];
        for found in self.find_all(raw) {
            if isinstance(found, MethodInfo) {
                out.append(found);
            }
        }
        return out;
    }

    def params(raw: any) -> list[ParamInfo] {
        out: list[ParamInfo] = [];
        for found in self.find_all(raw) {
            if isinstance(found, ParamInfo) {
                out.append(found);
            }
        }
        return out;
    }

    def functions(raw: any) -> list[FunctionInfo] {
        out: list[FunctionInfo] = [];
        for found in self.find_all(raw) {
            if isinstance(found, FunctionInfo) {
                out.append(found);
            }
        }
        return out;
    }

    def build -> list[(Info | TypeForm)] {
        self.built = [self.shell(record) for record in self.records];
        for (item, record) in zip(self.built, self.records) {
            if isinstance(item, TypeForm) {
                item.args = self.type_refs(record.get("args"));
            } elif isinstance(item, ClassInfo) {
                item.fields = self.fields(record.get("fields"));
                item.base_classes = self.classes(record.get("bases"));
                item.methods = self.methods(record.get("methods"));
            } elif isinstance(item, EnumInfo) {
                item.members = self.fields(record.get("members"));
            } elif isinstance(item, FunctionInfo) {
                item.params = self.params(record.get("params"));
                item.return_type = self.type_ref(record.get("returns"));
                item.tools = self.functions(record.get("tools"));
                item.by_call = bool(record.get("by_call", False));
                if isinstance(item, MethodInfo) {
                    parent = self.find(record.get("parent"));
                    item.parent_class = parent
                        if isinstance(parent, ClassInfo)
                        else None;
                }
            } elif isinstance(item, VarInfo) {
                item.type_info = self.type_ref(record.get("type"));
            }
        }
        return self.built;
    }
}

def info_graph_to_json(entries: dict[str, Info]) -> str {
    import json;
    writer = InfoGraphWriter();
    keyed: dict[str, any] = {};
    for (key, info) in entries.items() {
        keyed[key] = writer.ref(info);
    }
    return json.dumps(
        {"version": INFO_GRAPH_VERSION, "entries": keyed, "nodes": writer.nodes},
        sort_keys=True
    );
}

def info_graph_from_json(text: str) -> dict[str, Info] {
    import json;
    raw = json.loads(text);
    out: dict[str, Info] = {};
    if not isinstance(raw, dict) or raw.get("version") != INFO_GRAPH_VERSION {
        return out;
    }
    records: list[dict[str, any]] = [];
    raw_nodes = raw.get("nodes");
    if isinstance(raw_nodes, list) {
        for record in raw_nodes {
            if isinstance(record, dict) {
                records.append(record);
            }
        }
    }
    reader = InfoGraphReader(records=records);
    reader.build();
    raw_entries = raw.get("entries");
    if isinstance(raw_entries, dict) {
        for (key, ref) in raw_entries.items() {
            found = reader.find(ref);
            if isinstance(found, Info) {
                out[str(key)] = found;
            }
        }
    }
    return out;
}

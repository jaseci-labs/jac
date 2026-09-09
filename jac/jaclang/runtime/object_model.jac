import sys;
import from copy { deepcopy }
import from reprlib { recursive_repr }
import from typing { get_origin, ClassVar as PyClassVar, Callable as PyCallable, cast }

glob MISSING: object = object();

class ObjectField {
    has name: str,
        `type: object,
        `default: object,
        default_factory: PyCallable[[], object] | None,
        `init: bool,
        repr: bool,
        compare: bool,
        kw_only: bool,
        metadata: dict[str, object];

    def init(
        self: ObjectField,
        *,
        name: str = "",
        annotation: object = None,
        `default: object = MISSING,
        default_factory: PyCallable[[], object] | None = None,
        `init: bool = True,
        repr: bool = True,
        compare: bool = True,
        kw_only: bool = False,
        metadata: dict[str, object] | None = None
    ) {
        if `default is not MISSING and default_factory is not None {
            raise ValueError("A field cannot have both a default and a factory");
        }
        if default_factory is not None and not callable(default_factory) {
            raise TypeError("A field default factory must be callable");
        }
        self.name = name;
        self.`type = annotation;
        self.`default = `default;
        self.default_factory = default_factory;
        self.`init = `init;
        self.repr = repr;
        self.compare = compare;
        self.kw_only = kw_only;
        self.metadata = dict(metadata or {});
    }

    def bind(self: ObjectField, name: str, annotation: object) -> ObjectField {
        return ObjectField(
            name=name,
            annotation=annotation,
            `default=self.`default,
            default_factory=self.default_factory,
            `init=self.`init,
            repr=self.repr,
            compare=self.compare,
            kw_only=self.kw_only,
            metadata=self.metadata
        );
    }
}

def field(
    *,
    `default: object = MISSING,
    default_factory: PyCallable[[], object] | None = None,
    `init: bool = True,
    repr: bool = True,
    compare: bool = True,
    kw_only: bool = False,
    metadata: dict[str, object] | None = None
) -> ObjectField {
    return ObjectField(
        `default=`default,
        default_factory=default_factory,
        `init=`init,
        repr=repr,
        compare=compare,
        kw_only=kw_only,
        metadata=metadata
    );
}

def is_jac_object(value: object) -> bool {
    cls = value if isinstance(value, `type) else type(value);
    return hasattr(cls, "__jac_fields__");
}

def fields(value: object) -> tuple[ObjectField, ...] {
    cls = value if isinstance(value, `type) else type(value);
    declared = cast(dict[str, ObjectField] | None, cls?.__jac_fields__);
    if declared is None {
        raise TypeError("Expected a Jac object or object type");
    }
    return tuple(declared.values());
}

def _is_class_var(annotation: object) -> bool {
    if annotation is PyClassVar or get_origin(annotation) is PyClassVar {
        return True;
    }
    if isinstance(annotation, str) {
        name = annotation.split("[", 1)[0].strip();
        return name in ("ClassVar", "typing.ClassVar");
    }
    return False;
}

def _install_init(cls: type, declared: list[ObjectField]) {
    """Generate a real signature so ordinary Python binding stays authoritative.

    Defaults are passed through a private namespace rather than interpolated
    into source. Factories execute only when the caller omits that argument.
    """;
    names = {f.name for f in declared};
    prefix = "_jac_";
    while any(name.startswith(prefix) for name in names) {
        prefix = "_" + prefix;
    }
    receiver = prefix + "self";
    missing = prefix + "missing";
    positional: list[str] = [];
    keywords: list[str] = [];
    body: list[str] = [];
    namespace: dict[str, object] = {missing: MISSING};
    seen_default = False;
    for (index, f) in enumerate(declared) {
        if not f.name.isidentifier() {
            raise ValueError(f"Invalid Jac field name: {f.name}");
        }
        key = f"{prefix}value_{index}";
        defaulted = f.`default is not MISSING or f.default_factory is not None;
        if f.`init {
            parameter = f.name;
            if f.default_factory is not None {
                parameter += "=" + missing;
                namespace[key] = f.default_factory;
                expression = f"{key}() if {f.name} is {missing} else {f.name}";
            } elif f.`default is not MISSING {
                namespace[key] = f.`default;
                parameter += f"={key}";
                expression = f.name;
            } else {
                expression = f.name;
            }

            if f.kw_only or (seen_default and not defaulted) {
                f.kw_only = True;
                keywords.append(parameter);
            } else {
                positional.append(parameter);
                seen_default = seen_default or defaulted;
            }
            body.append(f"{receiver}.{f.name} = {expression}");
        } elif f.default_factory is not None {
            namespace[key] = f.default_factory;
            body.append(f"{receiver}.{f.name} = {key}()");
        }
    }
    if hasattr(cls, "__post_init__") {
        body.append(f"{receiver}.__post_init__()");
    }
    params = [receiver] + positional;
    if keywords {
        params += ["*"] + keywords;
    }
    source = "def " + prefix + "build(" + ", ".join(namespace) + "):\n";
    source += "    def __init__(" + ", ".join(params) + "):\n";
    source += "\n".join("        " + line for line in (body or ["pass"]));
    source += "\n    return __init__\n";
    module = sys.modules.get(cls.__module__);
    module_globals = vars(module) if module is not None else {};
    generated: dict[str, object] = {};
    exec(source, module_globals, generated);
    build = cast(PyCallable[..., PyCallable], generated[prefix + "build"]);
    initializer = build(**namespace);
    setattr(initializer, "__qualname__", cls.__qualname__ + ".__init__");
    setattr(initializer, "__module__", cls.__module__);
    setattr(
        initializer,
        "__annotations__",
        {
            f.name: f.`type
            for f in declared
            if f.`init
        }
            | {"return": None}
    );
    setattr(cls, "__init__", initializer);
}

def make_object(cls: type) -> type {
    """Install Jac's field contract without generating equality or hashing.""";
    declared: dict[str, ObjectField] = {};
    for base in reversed(cls.__mro__[1:]) {
        inherited: dict[str, ObjectField] = getattr(base, "__jac_fields__", {});
        for (name, f) in inherited.items() {
            declared[name] = f.bind(name, f.`type);
        }
    }
    annotations: dict[str, object] = cls.__dict__.get("__annotations__", {});
    for (name, annotation) in annotations.items() {
        if _is_class_var(annotation) {
            declared.pop(name, None);
            continue;
        }
        value = cls.__dict__.get(name, MISSING);
        f = value.bind(name, annotation)
            if isinstance(value, ObjectField)
            else ObjectField(name=name, annotation=annotation, `default=value);
        declared[name] = f;
        if isinstance(value, ObjectField) {
            if f.`default is MISSING {
                delattr(cls, name);
            } else {
                setattr(cls, name, f.`default);
            }
        }
    }
    setattr(cls, "__jac_fields__", declared);
    if annotations and "__init__" not in cls.__dict__ {
        _install_init(cls, list(declared.values()));
    }
    if "__repr__" not in cls.__dict__ {
        @recursive_repr()
        def object_repr(value: object) -> str {
            parts = [
                f"{f.name}={getattr(value, f.name)!r}"
                for f in declared.values()
                if f.repr
            ];
            return type(value).__qualname__ + "(" + ", ".join(parts) + ")";
        }
        setattr(cls, "__repr__", object_repr);
    }
    if "__match_args__" not in cls.__dict__ {
        setattr(
            cls,
            "__match_args__",
            tuple(
                f.name
                for f in declared.values()
                if f.`init and not f.kw_only
            )
        );
    }
    if not hasattr(cls, "__get_pydantic_core_schema__") {
        setattr(cls, "__get_pydantic_core_schema__", classmethod(_pydantic_schema));
    }
    return cls;
}

def _pydantic_schema(cls: type, source: object, handler: any) -> object {
    import from jaclang.runtime.object_pydantic { object_schema }
    return object_schema(cls, source, handler);
}

def asdict(value: object) -> dict[str, object] {
    if isinstance(value, `type) or not is_jac_object(value) {
        raise TypeError("Expected a Jac object instance");
    }
    return {f.name: _asdict_value(getattr(value, f.name)) for f in fields(value)};
}

def _asdict_value(value: object) -> object {
    if is_jac_object(value) and not isinstance(value, `type) {
        return asdict(value);
    }
    if isinstance(value, list) {
        return [_asdict_value(item) for item in value];
    }
    if isinstance(value, tuple) {
        items = [_asdict_value(item) for item in value];
        if hasattr(value, "_fields") {
            return type(value)(*items);
        }
        return tuple(items);
    }
    if isinstance(value, dict) {
        return {
            _asdict_value(key): _asdict_value(item) for (key, item) in value.items()
        };
    }
    return deepcopy(value);
}

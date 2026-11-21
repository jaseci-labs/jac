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
        kw_only: bool;

    def init(
        self: ObjectField,
        *,
        name: str = "",
        annotation: object = None,
        `default: object = MISSING,
        default_factory: PyCallable[[], object] | None = None,
        `init: bool = True,
        repr: bool = True,
        kw_only: bool = False
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
        self.kw_only = kw_only;
    }

    def bind(self: ObjectField, name: str, annotation: object) -> ObjectField;
}


def is_jac_object(value: object) -> bool;

def fields(value: object) -> tuple[ObjectField, ...];

def _is_class_var(annotation: object) -> bool;

def _install_init(cls: type, declared: list[ObjectField]);

def make_object(cls: type) -> type;

def _pydantic_schema(cls: type, source: object, handler: any) -> object;

def asdict(value: object) -> dict[str, object];

def _asdict_value(value: object) -> object;

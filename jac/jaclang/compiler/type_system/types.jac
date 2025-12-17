"""Representation of types used during type analysis."""
import from abc { ABC }
import from enum { IntEnum, auto }
import from pathlib { Path }
import from typing { TYPE_CHECKING, ClassVar }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.unitree { Expr, Symbol }
        import from jaclang.pycore.unitree { UniScopeNode as SymbolTable }
    }
}

"""Enumeration of type categories."""
class TypeCategory(IntEnum) {
    with entry {
        Unbound = auto();
        Unknown = auto();
        Never = auto();
        Any = auto();
        Module = auto();
        TypeVar = auto();
        Class = auto();
        Function = auto();
        Union = auto();
    }
}

"""Flags to set on a type.\n\n    foo = 42  # <-- Here type of foo is `int` class, Instance type.\n    foo = int # <-- Here type of foo is `type[int]`, Instantiable is set.\n    foo: int = 42\n         ^^^------- Here the type of the expression `int` is `type[int]`\n                    That is same as the prefetched int_class that has the\n                    flag Instantiable set.\n\n                    calling convertToInstance() will return the same type\n                    with Instance flag set.\n    """
class TypeFlags(IntEnum) {
    with entry {
        Null = 0;
        Instantiable = 1 << 0;
        Instance = 1 << 1;
        Ambiguous = 1 << 2;
    }
}

"""Enumeration of parameter categories."""
class ParameterCategory(IntEnum) {
    with entry {
        Positional = auto();
        ArgsList = auto();
        KwargsDict = auto();
    }
}

"""Maps to pyright's TypeBase<T> in the types.ts file.\n\n    This is the base class for all type instance of the jaclang that holds\n    information about the type's category and any additional metadata and\n    utilities to analyze type information and provide type checking.\n    """
class TypeBase(ABC) {
    with entry {
        CATEGORY: ClassVar[TypeCategory];
    }

    """Initialize obviously."""
    def init(self: TypeBase, flags: TypeFlags = TypeFlags.Null) -> None {
        self.flags: TypeFlags = flags;
    }

    """Returns the category of the type."""
    @property
    def category(self: TypeBase) -> TypeCategory {
        return self.CATEGORY;
    }

    """Return an instance of an unknown type."""
    static def unknown -> UnknownType {
        return UnknownType();
    }

    """Return whether the type is instantiable."""
    def is_instantiable(self: TypeBase) -> bool {
        return bool((self.flags & TypeFlags.Instantiable));
    }

    """Return whether the type is an instance."""
    def is_instance(self: TypeBase) -> bool {
        return bool((self.flags & TypeFlags.Instance));
    }

    """Return whether the class can be instantiated."""
    def is_instantiable_class(self: TypeBase) -> bool {
        return ((self.category == TypeCategory.Class) and self.is_instantiable());
    }

    """Return whether the class is an instance."""
    def is_class_instance(self: TypeBase) -> bool {
        return ((self.category == TypeCategory.Class) and self.is_instance());
    }
}

"""Represents a type that is not bound to a specific value or context."""
class UnboundType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unbound;
    }
}

"""Represents a type that is not known or cannot be determined."""
class UnknownType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Unknown;
    }
}

"""Represents a type that can never occur."""
class NeverType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Never;
    }
}

"""Represents a type that can be anything."""
class AnyType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Any;
    }
}

"""Represents a module type."""
class ModuleType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Module;
    }

    """Initialize the class."""
    def init(
        self: ModuleType, mod_name: str, file_uri: Path, symbol_table: SymbolTable
    ) -> None {
        super.init();
        self.mod_name = mod_name;
        self.file_uri = file_uri;
        self.symbol_table = symbol_table;
    }
}

"""Represents a type variable."""
class TypeVarType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.TypeVar;
    }

    """Initialize obviously."""
    def init(self: TypeVarType) -> None {
        super.init();
    }
}

"""Represents a class type."""
class ClassType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Class;
    }

    """Holds the shared details of class type.\n\n        The shared detail of classes will points to the same instance across multiple clones\n        of the same class. This is needed when we do `==` between two classes, if they have the\n        same shared object, that means they both are the same class (with different context).\n        """
    class ClassDetailsShared {
        """Initialize obviously."""
        def init(
            self: ClassDetailsShared,
            class_name: str,
            symbol_table: SymbolTable,
            *,
            type_params: (list[TypeVarType] | None) = None,
            base_classes: (list[TypeBase] | None) = None,
            is_builtin_class: bool = False,
            is_data_class: bool = False,
            is_root_class: bool = False
        ) -> None {
            self.class_name = class_name;
            self.symbol_table = symbol_table;
            self.type_params = type_params or [];
            self.base_classes = base_classes or [];
            self.mro: list[ClassType] = [];
            self.is_builtin_class = is_builtin_class;
            self.is_data_class = is_data_class;
            self.is_root_class = is_root_class;
        }
    }

    """Holds the private details of class type.\n\n        The private details of classes will be unique to each class instance.\n        """
    class ClassDetailsPrivate {
        """Initialize obviously."""
        def init(
            self: ClassDetailsPrivate, type_args: (list[TypeBase] | None) = None
        ) -> None {
            self.type_args = type_args or [];
        }
    }

    """Initialize the class type."""
    def init(
        self: ClassType,
        shared: ClassType.ClassDetailsShared,
        private: (ClassType.ClassDetailsPrivate | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None {
        super.init(flags=flags);
        self.shared = shared;
        self.private = private or ClassType.ClassDetailsPrivate();
    }

    """Return a string representation of the class type."""
    def __str__(self: ClassType) -> str {
        return f"<class {self.shared.class_name}>";
    }

    """Clone this class type as an instance type."""
    def clone_as_instance(self: ClassType) -> ClassType {
        if self.is_instance() {
            return self;
        }
        private = ClassType.ClassDetailsPrivate(type_args=self.private.type_args[:]);
        new_instance = ClassType(self.shared, private=private, flags=self.flags);
        new_flag = self.flags;
        new_flag = TypeFlags((new_flag & ~TypeFlags.Instantiable));
        new_flags = TypeFlags((new_flag | TypeFlags.Instance));
        new_instance.flags = new_flags;
        return new_instance;
    }

    def clone_as_class(self: ClassType) -> ClassType {
        if not self.is_instance() {
            return self;
        }
        private = ClassType.ClassDetailsPrivate(type_args=self.private.type_args[:]);
        new_flag = self.flags;
        new_flag = TypeFlags((new_flag & ~TypeFlags.Instance));
        new_flags = TypeFlags((new_flag | TypeFlags.Instantiable));
        new_class = ClassType(self.shared, private=private, flags=new_flags);
        return new_class;
    }

    """Return a new class type specialized with the given type arguments."""
    def specialize_generics(self: ClassType, type_args: list[TypeBase]) -> ClassType {
        new_private = ClassType.ClassDetailsPrivate(type_args=type_args);
        return ClassType(self.shared, private=new_private, flags=self.flags);
    }

    """Return the symbol representing the class."""
    def get_class_symbol(self: ClassType) -> Symbol {
        return self.shared.symbol_table.name.sym;
    }

    """Lookup a member in the class type."""
    def lookup_member_symbol(self: ClassType, member: str) -> (Symbol | None) {
        for cls in self.shared.mro {
            members = cls.shared.symbol_table.names_in_scope;
            if (member in members) {
                return members[member];
            }
        }
        return None;
    }

    """\n        Return true if this class is a builtin class.\n\n        If class_name is provided, also check if the class name matches.\n        """
    def is_builtin(self: ClassType, class_name: (str | None) = None) -> bool {
        if not self.shared.is_builtin_class {
            return False;
        }
        if (class_name is not None) {
            return (self.shared.class_name == class_name);
        }
        return True;
    }

    """Return true if this class is a data class."""
    def is_data_class(self: ClassType) -> bool {
        return self.shared.is_data_class;
    }

    """Return true if this class is the built-in Edge type."""
    def is_edge_type(self: ClassType) -> bool {
        import jaclang.pycore.unitree as uni;
        import from jaclang.pycore.constant { SymbolType }
        arch = self.shared.symbol_table;
        assert isinstance(arch, uni.Archetype);
        return (arch.sym_category == SymbolType.EDGE_ARCH);
    }

    """Return true if this class is the built-in Node type."""
    def is_node_type(self: ClassType) -> bool {
        import jaclang.pycore.unitree as uni;
        import from jaclang.pycore.constant { SymbolType }
        if self.shared.is_root_class {
            return True;
        }
        arch = self.shared.symbol_table;
        assert isinstance(arch, uni.Archetype);
        return (arch.sym_category == SymbolType.NODE_ARCH);
    }
}

"""Enumeration of parameter kinds."""
class ParamKind(IntEnum) {
    with entry {
        POSONLY = 0;
        NORMAL = 1;
        VARARG = 2;
        KWONLY = 3;
        KWARG = 4;
    }
}

"""Represents a function parameter."""
class Parameter {
    """Initialize obviously."""
    def init(
        self: Parameter,
        name: str,
        category: ParameterCategory,
        param_type: (TypeBase | None),
        default_value: (Expr | None) = None,
        is_self: bool = False,
        param_kind: ParamKind = ParamKind.NORMAL
    ) -> None {
        super.init();
        self.name = name;
        self.category = category;
        self.default_value = default_value;
        self.param_type = param_type;
        self.is_self = is_self;
        self.param_kind: ParamKind = param_kind;
    }
}

"""Represents a function type."""
class FunctionType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Function;
    }

    """Initialize obviously."""
    def init(
        self: FunctionType,
        func_name: str,
        return_type: (TypeBase | None) = None,
        parameters: (list[Parameter] | None) = None,
        flags: TypeFlags = TypeFlags.Null
    ) -> None {
        super.init(flags=flags);
        self.func_name = func_name;
        self.return_type = return_type;
        self.parameters = parameters or [];
    }

    """Specialize the function type based on the given class type."""
    def specialize(self: FunctionType, class_type: ClassType) -> FunctionType {
        clone = FunctionType(
            func_name=self.func_name,
            return_type=self.return_type,
            parameters=[
                Parameter(
                    name=param.name,
                    category=param.category,
                    param_type=param.param_type,
                    default_value=param.default_value,
                    is_self=param.is_self,
                    param_kind=param.param_kind
                ) for param in self.parameters
            ]
        );
        for param in clone.parameters {
            if (not param.param_type or not isinstance(param.param_type, TypeVarType)) {
                continue;
            }
            idx = self._index_of_type_param(class_type, param.param_type);
            if ((idx != -1) and (idx < len(class_type.private.type_args))) {
                ty = class_type.private.type_args[idx];
                ty = ty.clone_as_instance() if isinstance(ty, ClassType) else ty;
                param.param_type = ty;
            }
        }
        if (clone.return_type and isinstance(clone.return_type, TypeVarType)) {
            idx = self._index_of_type_param(class_type, clone.return_type);
            if ((idx != -1) and (idx < len(class_type.private.type_args))) {
                ty = class_type.private.type_args[idx];
                ty = ty.clone_as_instance() if isinstance(ty, ClassType) else ty;
                clone.return_type = ty;
            }
        }
        return clone;
    }

    """Return the index of the given type variable in the class type."""
    def _index_of_type_param(
        self: FunctionType, class_type: ClassType, type_var: TypeVarType
    ) -> int {
        for (idx, type_param) in enumerate(class_type.shared.type_params) {
            if (type_param is type_var) {
                return idx;
            }
        }
        return -1;
    }
}

"""Represents a union type."""
class UnionType(TypeBase) {
    with entry {
        CATEGORY: ClassVar[TypeCategory] = TypeCategory.Union;
    }

    """Initialize obviously."""
    def init(self: UnionType, types: list[TypeBase]) -> None {
        super.init();

        # Flatten nested union types
        flattened_types: list[TypeBase] = [];
        for ty in types {
            if isinstance(ty, UnionType) {
                flattened_types.extend(ty.types);
            } else {
                flattened_types.append(ty);
            }
        }

        self.types = flattened_types;
    }
}

enum MirPosition { VALUE, FIELD, SIGNATURE, ELEMENT, C_FIELD }

glob LIST_CLASSES: list[str] = ["list", "Sequence", "MutableSequence"],
     SET_CLASSES: list[str] = ["set", "frozenset", "AbstractSet", "MutableSet"];

glob ITERATOR_CLASSES: list[str] = [
         "Iterator",
         "_GeneratorContextManager",
         "Generator",
         "reversed",
         "map",
         "filter",
         "zip"
     ],
     ANY_BOXABLE: list[MirKind] = [
         MirKind.ANY,
         MirKind.INT,
         MirKind.ENUM,
         MirKind.FLOAT,
         MirKind.BOOL,
         MirKind.NONE,
         MirKind.STR,
         MirKind.STR_REF,
         MirKind.BYTES,
         MirKind.BYTEARRAY,
         MirKind.LIST,
         MirKind.DICT,
         MirKind.SET,
         MirKind.OBJ,
         MirKind.FN
     ];

glob C_ABI_KINDS: list[MirKind] = [
         MirKind.INT,
         MirKind.FLOAT,
         MirKind.BOOL,
         MirKind.C_PTR,
         MirKind.C_FN
     ];

class MirRefused(Exception) {}

def mir_refusal(
    kind: str,
    name: str,
    site: (uni.UniNode | None) = None,
    help: (str | None) = None,
    code: str = "E5092"
) -> NativeRefusal;

def refusal_of(err: MirRefused) -> NativeRefusal;

def mir_type_of(
    t: (TypeBase | None),
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
) -> MirType;

def mir_union_type(
    t: UnionType,
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
) -> MirType;

def mir_c_elem(t: (TypeBase | None), site: (uni.UniNode | None) = None) -> MirType;

def mir_class_type_named(name: str, site: (uni.UniNode | None) = None) -> MirType;

def mir_class_type(
    t: ClassType,
    position: MirPosition,
    site: (uni.UniNode | None) = None,
    env: (dict[str, TypeBase] | None) = None
) -> MirType;

def mir_class_value_type(
    t: ClassType, env: (dict[str, TypeBase] | None) = None
) -> MirType;

def mir_spec_type(spec: str) -> MirType;

def stub_archetype(scope: uni.Archetype) -> bool;

def stub_scope(scope: (uni.UniScopeNode | None)) -> bool;

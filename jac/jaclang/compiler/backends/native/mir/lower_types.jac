enum MirPosition { VALUE, FIELD, SIGNATURE, ELEMENT, C_FIELD }

glob ITERATOR_CLASSES: list[str] = ["Iterator", "Generator", "reversed"],
     ANY_BOXABLE: list[MirKind] = [
         MirKind.ANY,
         MirKind.INT,
         MirKind.ENUM,
         MirKind.FLOAT,
         MirKind.BOOL,
         MirKind.NONE,
         MirKind.STR,
         MirKind.STR_REF,
         MirKind.LIST,
         MirKind.DICT,
         MirKind.SET,
         MirKind.OBJ,
         MirKind.FN
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

def mir_spec_type(spec: str) -> MirType;

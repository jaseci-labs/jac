enum MirPosition { VALUE, FIELD, SIGNATURE, ELEMENT, C_FIELD }

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
    t: (TypeBase | None), position: MirPosition, site: (uni.UniNode | None) = None
) -> MirType;

def mir_c_elem(t: (TypeBase | None), site: (uni.UniNode | None) = None) -> MirType;

def mir_class_type_named(name: str, site: (uni.UniNode | None) = None) -> MirType;

def mir_class_type(
    t: ClassType, position: MirPosition, site: (uni.UniNode | None) = None
) -> MirType;

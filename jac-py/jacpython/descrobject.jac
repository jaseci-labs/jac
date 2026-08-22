# P3.2b — descriptor protocol helpers (classmethod / staticmethod / property).
#
# c2jac-assisted from ``jac-py/tools/p3_object_core/corpus/descrobject_core.c``
# (lift: ``jac-py/Objects/_lifted/descrobject_core.jac``).
#
# Full ``descriptor_get`` / ``PyProperty`` live in ``ceval.jac`` (callable layer).
# This module stays an objects-helper leaf: type-check + property guard predicates.
import from objects { PyObj, py_none, py_error, }

# CPython ``descr_check`` type-mismatch guard (descrobject.c).
def descr_type_applies(
    applies: bool,
    owner_type_name: str,
    obj_type_name: str,
    descr_name_val: str = ""
) -> PyObj {
    if applies {
        return py_none();
    }
    name_part = descr_name_val;
    if name_part != "" {
        name_part = "'" + name_part + "' ";
    }
    return py_error(
        "TypeError",
        "descriptor " + name_part + "for '" + owner_type_name + "' objects "
        + "doesn't apply to a '" + obj_type_name + "' object"
    );
}

# ``property_descr_get``: class/None access returns the property itself.
def property_returns_self(instance_is_none: bool) -> bool {
    return instance_is_none;
}

# ``property_descr_get``: missing getter → AttributeError.
def property_missing_getter(fget_is_none: bool) -> bool {
    return fget_is_none;
}

# Compose the AttributeError message for a property with no getter.
def property_no_getter_error -> PyObj {
    return py_error("AttributeError", "property has no getter");
}

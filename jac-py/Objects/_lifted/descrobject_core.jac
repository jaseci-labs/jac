# c2jac: hand-staged from ``jac-py/tools/p3_object_core/corpus/descrobject_core.c``
# (``descr_check`` + getset/property getter paths; runtime truth in ``ceval.jac``).

@__jac_value__
obj PyDescrObject {
    has d_type: PyTypeObject = PyTypeObject(),
        d_name: PyObj = PyObj(),
        d_qualname: PyObj = PyObj();
}

@__jac_value__
obj PyTypeObject {
    has tp_name: str = str();
}

@__jac_value__
obj PyObj {
    has ob_type: PyTypeObject = PyTypeObject();
}

@__jac_value__
obj PyGetSetDef {
    has get: object = object(),
        set: object = object(),
        closure: object = object();
}

@__jac_value__
obj PyGetSetDescrObject {
    has d_common: PyDescrObject = PyDescrObject(),
        d_getset: PyGetSetDef = PyGetSetDef();
}

@__jac_value__
obj propertyobject {
    has prop_get: PyObj = PyObj(),
        prop_set: PyObj = PyObj(),
        prop_del: PyObj = PyObj();
}


def descr_name(descr: PyDescrObject) -> PyObj {
    if descr.d_name != 0 {
        return descr.d_name;
    }
    return 0;
}

def _object_type_check(obj: PyObj, `type: PyTypeObject) -> bool {
    return obj.ob_type == `type;
}

def descr_check(descr: PyDescrObject, obj: PyObj) -> int {
    if not _object_type_check(obj, descr.d_type) {
        raise TypeError(
            "descriptor for '" + descr.d_type.tp_name + "' objects "
            + "doesn't apply to a '" + obj.ob_type.tp_name + "' object"
        );
        return -1;
    }
    return 0;
}

def descr_setcheck(descr: PyDescrObject, obj: PyObj, value: PyObj) -> int {
    if not _object_type_check(obj, descr.d_type) {
        raise TypeError(
            "descriptor for '" + descr.d_type.tp_name + "' objects "
            + "doesn't apply to a '" + obj.ob_type.tp_name + "' object"
        );
        return -1;
    }
    return 0;
}

def getset_get(`self: PyGetSetDescrObject, obj: PyObj, `type: PyObj) -> PyObj {
    if obj == 0 {
        return `self;
    }
    if descr_check(`self.d_common, obj) < 0 {
        return 0;
    }
    if `self.d_getset.get != 0 {
        return `self.d_getset.get;
    }
    raise AttributeError(
        "attribute of '" + `self.d_common.d_type.tp_name + "' objects is not readable"
    );
    return 0;
}

def property_descr_get(`self: propertyobject, obj: PyObj, `type: PyObj) -> PyObj {
    if (obj == 0) {
        return `self;
    }
    if `self.prop_get == 0 {
        raise AttributeError("property has no getter");
        return 0;
    }
    return `self.prop_get;
}

import from c {
    glob PyType_Type: PyTypeObject; glob:priv delta_as_number: PyNumberMethods = PyNumberMethods(
             nb_add=delta_add,
             nb_subtract=delta_subtract,
             nb_multiply=delta_multiply,
             nb_remainder=delta_remainder,
             nb_divmod=delta_divmod,
             nb_negative=delta_negative,
             nb_positive=delta_positive,
             nb_absolute=delta_abs,
             nb_bool=delta_bool,
             nb_floor_divide=delta_divide,
             nb_true_divide=delta_truedivide
         ),
         delta_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("days"),
                 type_=Py_T_INT,
                 offset=PY_DATETIME_DELTA_DAYS_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Number of days.")
             ),
             PyMemberDef(
                 name=ptr[u8]("seconds"),
                 type_=Py_T_INT,
                 offset=PY_DATETIME_DELTA_SECONDS_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Number of seconds (>= 0 and less than 1 day).")
             ),
             PyMemberDef(
                 name=ptr[u8]("microseconds"),
                 type_=Py_T_INT,
                 offset=PY_DATETIME_DELTA_MICROSECONDS_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("Number of microseconds (>= 0 and less than 1 second).")
             ),
             PyMemberDef()
         ]; glob PyDateTime_DeltaType: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("datetime.timedelta"),
             tp_basicsize=PY_DATETIME_DELTA_SIZE,
             tp_repr=delta_repr,
             tp_as_number=addressof(delta_as_number),
             tp_hash=delta_hash,
             tp_str=delta_str,
             tp_getattro=PyObject_GenericGetAttr,
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
             tp_doc=ptr[u8](
                 "Difference between two datetime values.\n\n"
                 "timedelta(days=0, seconds=0, microseconds=0, milliseconds=0, "
                 "minutes=0, hours=0, weeks=0)\n\n"
                 "All arguments are optional and default to 0.\n"
                 "Arguments may be integers or floats, and may be positive or negative."
             ),
             tp_richcompare=delta_richcompare,
             tp_members=addressof(delta_members),
             tp_new=delta_new
         ),
         zero_delta: PyDateTime_Delta = PyDateTime_Delta(
             ob_base=_object(
                 ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                 ob_type=addressof(PyDateTime_DeltaType)
             ),
             hashcode=-1
         );
}

def divide_nearest(m: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject];

def multiply_int_timedelta(
    intobj: ptr[PyObject], delta: ptr[PyObject]
) -> ptr[PyObject];

def get_float_as_integer_ratio(floatobj: ptr[PyObject]) -> ptr[PyObject];

def multiply_truedivide_timedelta_float(
    delta: ptr[PyObject], floatobj: ptr[PyObject], op: int
) -> ptr[PyObject];

def divide_timedelta_int(delta: ptr[PyObject], intobj: ptr[PyObject]) -> ptr[PyObject];

def truedivide_timedelta_timedelta(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject];

def truedivide_timedelta_int(delta: ptr[PyObject], i: ptr[PyObject]) -> ptr[PyObject];

def delta_add(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_positive(self: ptr[PyObject]) -> ptr[PyObject];

def delta_abs(self: ptr[PyObject]) -> ptr[PyObject];

def delta_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject];

def delta_getstate(self: ptr[PyObject]) -> ptr[PyObject];

def delta_hash(op: ptr[PyObject]) -> i64;

def delta_multiply(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_divide(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_truedivide(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_remainder(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def delta_divmod(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject];

def accum(
    tag: str,
    sofar: ptr[PyObject],
    num: ptr[PyObject],
    factor: ptr[PyObject],
    leftover: f64
) -> tuple[ptr[PyObject], f64];

def delta_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject];

glob:priv COMPONENTS: list[tuple[int, str, int]] = [
         (2, "microseconds", -1),
         (3, "milliseconds", STATE_US_PER_MS),
         (1, "seconds", STATE_US_PER_SECOND),
         (4, "minutes", STATE_US_PER_MINUTE),
         (5, "hours", STATE_US_PER_HOUR),
         (0, "days", STATE_US_PER_DAY),
         (6, "weeks", STATE_US_PER_WEEK)
     ];

def:priv delta_new_in(
    module: ptr[PyObject],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kw: ptr[PyObject]
) -> ptr[PyObject];

def delta_repr(self: ptr[PyObject]) -> ptr[PyObject];

def delta_str(self: ptr[PyObject]) -> ptr[PyObject];

def delta_total_seconds(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def delta_reduce(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

impl divide_nearest(m: ptr[PyObject], n: ptr[PyObject]) -> ptr[PyObject] {
    temp = _PyLong_DivmodNear(m, n);
    if not temp {
        return NULL;
    }
    result = Py_NewRef(PyTuple_GetItem(temp, 0));
    jacpy_release(temp);
    return result;
}

impl multiply_int_timedelta(
    intobj: ptr[PyObject], delta: ptr[PyObject]
) -> ptr[PyObject] {
    pyus_in = delta_to_microseconds(delta);
    if not pyus_in {
        return NULL;
    }
    pyus_out = PyNumber_Multiply(intobj, pyus_in);
    jacpy_release(pyus_in);
    if not pyus_out {
        return NULL;
    }
    result = microseconds_to_delta(pyus_out);
    jacpy_release(pyus_out);
    return result;
}

impl get_float_as_integer_ratio(floatobj: ptr[PyObject]) -> ptr[PyObject] {
    ratio = PyObject_CallMethod(floatobj, "as_integer_ratio", "");
    if not ratio {
        return NULL;
    }
    if jacpy_is_tuple(ratio) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            "unexpected return type from as_integer_ratio(): expected tuple, not '%.200s'",
            type_name_of(ratio)
        );
        jacpy_release(ratio);
        return NULL;
    }
    if PyTuple_Size(ratio) != 2 {
        PyErr_SetString(PyExc_ValueError, "as_integer_ratio() must return a 2-tuple");
        jacpy_release(ratio);
        return NULL;
    }
    return ratio;
}

impl multiply_truedivide_timedelta_float(
    delta: ptr[PyObject], floatobj: ptr[PyObject], op: int
) -> ptr[PyObject] {
    pyus_in = delta_to_microseconds(delta);
    if not pyus_in {
        return NULL;
    }
    ratio = get_float_as_integer_ratio(floatobj);
    if not ratio {
        jacpy_release(pyus_in);
        return NULL;
    }
    result: ptr[PyObject] = NULL;
    temp = PyNumber_Multiply(pyus_in, PyTuple_GetItem(ratio, i64(op)));
    jacpy_release(pyus_in);
    if temp {
        pyus_out = divide_nearest(temp, PyTuple_GetItem(ratio, i64(1 - op)));
        jacpy_release(temp);
        if pyus_out {
            result = microseconds_to_delta(pyus_out);
            jacpy_release(pyus_out);
        }
    }
    jacpy_release(ratio);
    return result;
}

impl divide_timedelta_int(
    delta: ptr[PyObject], intobj: ptr[PyObject]
) -> ptr[PyObject] {
    pyus_in = delta_to_microseconds(delta);
    if not pyus_in {
        return NULL;
    }
    pyus_out = PyNumber_FloorDivide(pyus_in, intobj);
    jacpy_release(pyus_in);
    if not pyus_out {
        return NULL;
    }
    result = microseconds_to_delta(pyus_out);
    jacpy_release(pyus_out);
    return result;
}

impl truedivide_timedelta_timedelta(
    left: ptr[PyObject], right: ptr[PyObject]
) -> ptr[PyObject] {
    pyus_left = delta_to_microseconds(left);
    if not pyus_left {
        return NULL;
    }
    pyus_right = delta_to_microseconds(right);
    if not pyus_right {
        jacpy_release(pyus_left);
        return NULL;
    }
    result = PyNumber_TrueDivide(pyus_left, pyus_right);
    jacpy_release(pyus_left);
    jacpy_release(pyus_right);
    return result;
}

impl truedivide_timedelta_int(delta: ptr[PyObject], i: ptr[PyObject]) -> ptr[PyObject] {
    pyus_in = delta_to_microseconds(delta);
    if not pyus_in {
        return NULL;
    }
    pyus_out = divide_nearest(pyus_in, i);
    jacpy_release(pyus_in);
    if not pyus_out {
        return NULL;
    }
    result = microseconds_to_delta(pyus_out);
    jacpy_release(pyus_out);
    return result;
}

impl delta_add(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) and delta_check(right) {
        return new_delta(
            td_days(left) + td_days(right),
            td_seconds(left) + td_seconds(right),
            td_microseconds(left) + td_microseconds(right),
            1
        );
    }
    return not_implemented();
}

impl delta_positive(self: ptr[PyObject]) -> ptr[PyObject] {
    return new_delta(td_days(self), td_seconds(self), td_microseconds(self), 0);
}

impl delta_abs(self: ptr[PyObject]) -> ptr[PyObject] {
    if td_days(self) < 0 {
        return delta_negative(self);
    }
    return delta_positive(self);
}

impl delta_richcompare(
    self: ptr[PyObject], other: ptr[PyObject], op: i32
) -> ptr[PyObject] {
    if delta_check(other) {
        return diff_to_bool(delta_cmp(self, other), int(op));
    }
    return not_implemented();
}

impl delta_getstate(self: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue(
        ptr[u8]("lll"), td_days(self), td_seconds(self), td_microseconds(self)
    );
}

impl delta_hash(op: ptr[PyObject]) -> i64 {
    record = ptr[PyDateTime_Delta](op).view(1);
    hash = record[0].hashcode;
    if hash == -1 {
        temp = delta_getstate(op);
        if temp {
            hash = PyObject_Hash(temp);
            record[0].hashcode = hash;
            jacpy_release(temp);
        }
    }
    return hash;
}

impl delta_multiply(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) {
        if jacpy_is_long(right) != 0 {
            return multiply_int_timedelta(right, left);
        }
        if jacpy_is_float(right) != 0 {
            return multiply_truedivide_timedelta_float(left, right, 0);
        }
    } elif jacpy_is_long(left) != 0 {
        return multiply_int_timedelta(left, right);
    } elif jacpy_is_float(left) != 0 {
        return multiply_truedivide_timedelta_float(right, left, 0);
    }
    return not_implemented();
}

impl delta_divide(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) {
        if jacpy_is_long(right) != 0 {
            return divide_timedelta_int(left, right);
        }
        if delta_check(right) {
            return divide_timedelta_timedelta(left, right);
        }
    }
    return not_implemented();
}

impl delta_truedivide(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if delta_check(left) {
        if delta_check(right) {
            return truedivide_timedelta_timedelta(left, right);
        }
        if jacpy_is_float(right) != 0 {
            return multiply_truedivide_timedelta_float(left, right, 1);
        }
        if jacpy_is_long(right) != 0 {
            return truedivide_timedelta_int(left, right);
        }
    }
    return not_implemented();
}

impl delta_remainder(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if not delta_check(left) or not delta_check(right) {
        return not_implemented();
    }
    pyus_left = delta_to_microseconds(left);
    if not pyus_left {
        return NULL;
    }
    pyus_right = delta_to_microseconds(right);
    if not pyus_right {
        jacpy_release(pyus_left);
        return NULL;
    }
    pyus_remainder = PyNumber_Remainder(pyus_left, pyus_right);
    jacpy_release(pyus_left);
    jacpy_release(pyus_right);
    if not pyus_remainder {
        return NULL;
    }
    remainder = microseconds_to_delta(pyus_remainder);
    jacpy_release(pyus_remainder);
    return remainder;
}

impl delta_divmod(left: ptr[PyObject], right: ptr[PyObject]) -> ptr[PyObject] {
    if not delta_check(left) or not delta_check(right) {
        return not_implemented();
    }
    pyus_left = delta_to_microseconds(left);
    if not pyus_left {
        return NULL;
    }
    pyus_right = delta_to_microseconds(right);
    if not pyus_right {
        jacpy_release(pyus_left);
        return NULL;
    }
    divmod = checked_divmod(pyus_left, pyus_right);
    jacpy_release(pyus_left);
    jacpy_release(pyus_right);
    if not divmod {
        return NULL;
    }
    delta = microseconds_to_delta(PyTuple_GetItem(divmod, 1));
    if not delta {
        jacpy_release(divmod);
        return NULL;
    }
    result = PyTuple_Pack(2, PyTuple_GetItem(divmod, 0), delta);
    jacpy_release(delta);
    jacpy_release(divmod);
    return result;
}

impl accum(
    tag: str,
    sofar: ptr[PyObject],
    num: ptr[PyObject],
    factor: ptr[PyObject],
    leftover: f64
) -> tuple[ptr[PyObject], f64] {
    if jacpy_is_long(num) != 0 {
        prod = PyNumber_Multiply(num, factor);
        if not prod {
            return (NULL, leftover);
        }
        sum = PyNumber_Add(sofar, prod);
        jacpy_release(prod);
        return (sum, leftover);
    }
    if jacpy_is_float(num) != 0 {
        dnum = PyFloat_AsDouble(num);
        if dnum == -1.0 and PyErr_Occurred() {
            return (NULL, leftover);
        }
        intpart = 0.0;
        fracpart = modf(dnum, &mut intpart);
        x = PyLong_FromDouble(intpart);
        if not x {
            return (NULL, leftover);
        }
        prod = PyNumber_Multiply(x, factor);
        jacpy_release(x);
        if not prod {
            return (NULL, leftover);
        }
        sum = PyNumber_Add(sofar, prod);
        jacpy_release(prod);
        if not sum {
            return (NULL, leftover);
        }
        if fracpart == 0.0 {
            return (sum, leftover);
        }

        dnum = PyLong_AsDouble(factor);
        dnum *= fracpart;
        fracpart = modf(dnum, &mut intpart);
        x = PyLong_FromDouble(intpart);
        if not x {
            jacpy_release(sum);
            return (NULL, leftover);
        }
        y = PyNumber_Add(sum, x);
        jacpy_release(sum);
        jacpy_release(x);
        return (y, leftover + fracpart);
    }
    PyErr_Format(
        PyExc_TypeError,
        "unsupported type for timedelta %s component: %s",
        tag,
        type_name_of(num)
    );
    return (NULL, leftover);
}

impl delta_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kw: ptr[PyObject]
) -> ptr[PyObject] {
    module = get_current_state();
    if not module {
        return NULL;
    }
    self = delta_new_in(module, type, args, kw);
    jacpy_release(module);
    return self;
}

impl delta_new_in(
    module: ptr[PyObject],
    type: ptr[PyTypeObject],
    args: ptr[PyObject],
    kw: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="__new__").parse_keywords(
            args,
            kw,
            "|OOOOOOO",
            [
                "days",
                "seconds",
                "microseconds",
                "milliseconds",
                "minutes",
                "hours",
                "weeks"
            ]
        );
    } except boundary_failure {
        return NULL;
    }

    x = PyLong_FromLong(0);
    if not x {
        return NULL;
    }
    leftover_us = 0.0;
    for (index, tag, unit) in COMPONENTS {
        if not values[index].given {
            continue;
        }
        factor = Py_GetConstantBorrowed(Py_CONSTANT_ONE)
            if unit < 0
            else state_value(module, unit);
        (y, leftover_us) = accum(tag, x, values[index].object, factor, leftover_us);
        jacpy_release(x);
        x = y;
        if not x {
            return NULL;
        }
    }
    if leftover_us != 0.0 {
        whole_us = round(leftover_us);
        if fabs(whole_us - leftover_us) == 0.5 {
            temp = PyNumber_And(x, Py_GetConstantBorrowed(Py_CONSTANT_ONE));
            if not temp {
                jacpy_release(x);
                return NULL;
            }
            x_is_odd = PyObject_IsTrue(temp);
            jacpy_release(temp);
            if x_is_odd == -1 {
                jacpy_release(x);
                return NULL;
            }
            odd = f64(x_is_odd);
            whole_us = 2.0 * round((leftover_us + odd) * 0.5) - odd;
        }
        temp = PyLong_FromLong(int(whole_us));
        if not temp {
            jacpy_release(x);
            return NULL;
        }
        y = PyNumber_Add(x, temp);
        jacpy_release(temp);
        jacpy_release(x);
        x = y;
        if not x {
            return NULL;
        }
    }
    self = microseconds_to_delta_ex(x, type);
    jacpy_release(x);
    return self;
}

impl delta_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    args = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    if not args {
        return NULL;
    }
    sep = "";
    if td_days(self) != 0 {
        jacpy_release(args);
        args = PyUnicode_FromFormat("days=%ld", td_days(self));
        if not args {
            return NULL;
        }
        sep = ", ";
    }
    if td_seconds(self) != 0 {
        previous = args;
        args = PyUnicode_FromFormat("%U%sseconds=%ld", previous, sep, td_seconds(self));
        jacpy_release(previous);
        if not args {
            return NULL;
        }
        sep = ", ";
    }
    if td_microseconds(self) != 0 {
        previous = args;
        args = PyUnicode_FromFormat(
            "%U%smicroseconds=%ld", previous, sep, td_microseconds(self)
        );
        jacpy_release(previous);
        if not args {
            return NULL;
        }
    }
    if PyUnicode_GetLength(args) == 0 {
        jacpy_release(args);
        args = PyUnicode_FromString(ptr[u8]("0"));
        if not args {
            return NULL;
        }
    }
    repr = PyUnicode_FromFormat("%s(%S)", type_name_of(self), args);
    jacpy_release(args);
    return repr;
}

impl delta_str(self: ptr[PyObject]) -> ptr[PyObject] {
    us = td_microseconds(self);
    seconds = td_seconds(self);
    minutes = seconds // 60;
    seconds = seconds % 60;
    hours = minutes // 60;
    minutes = minutes % 60;
    days = td_days(self);
    if days != 0 {
        plural = "" if days == 1 or days == -1 else "s";
        if us != 0 {
            return PyUnicode_FromFormat(
                "%ld day%s, %ld:%02ld:%02ld.%06ld",
                days,
                plural,
                hours,
                minutes,
                seconds,
                us
            );
        }
        return PyUnicode_FromFormat(
            "%ld day%s, %ld:%02ld:%02ld", days, plural, hours, minutes, seconds
        );
    }
    if us != 0 {
        return PyUnicode_FromFormat(
            "%ld:%02ld:%02ld.%06ld", hours, minutes, seconds, us
        );
    }
    return PyUnicode_FromFormat("%ld:%02ld:%02ld", hours, minutes, seconds);
}

impl delta_total_seconds(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    total_microseconds = delta_to_microseconds(op);
    if not total_microseconds {
        return NULL;
    }
    module = get_current_state();
    if not module {
        jacpy_release(total_microseconds);
        return NULL;
    }
    total_seconds = PyNumber_TrueDivide(
        total_microseconds, state_value(module, STATE_US_PER_SECOND)
    );
    jacpy_release(module);
    jacpy_release(total_microseconds);
    return total_seconds;
}

impl delta_reduce(op: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    return Py_BuildValue(ptr[u8]("ON"), type_of(op), delta_getstate(op));
}

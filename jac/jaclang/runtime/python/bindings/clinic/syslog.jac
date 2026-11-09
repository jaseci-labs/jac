glob:priv syslog_openlog_signature = CallSignature(
         "openlog", ["ident", "logoption", "facility"], 0, 3, 0, parser=PARSE_KEYWORDS
     );

def:priv syslog_openlog_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject];

def:priv syslog_openlog_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def:priv syslog_closelog_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject];

def:priv syslog_setlogmask_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv syslog_LOG_MASK_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def:priv syslog_LOG_UPTO_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

glob module_methods: list[MethodDefinition] = [
         MethodDefinition(
             "openlog",
             MethodCallbacks(fast_keywords=syslog_openlog_call),
             "openlog($module, /, ident=<unrepresentable>, logoption=0,\n        facility=LOG_USER)\n--\n\nSet logging options of subsequent syslog() calls.",
             130
         ),
         MethodDefinition(
             "closelog",
             MethodCallbacks(positional=syslog_closelog_call),
             "closelog($module, /)\n--\n\nReset the syslog module values and call the system library closelog().",
             4
         ),
         MethodDefinition(
             "setlogmask",
             MethodCallbacks(positional=syslog_setlogmask_call),
             "setlogmask($module, maskpri, /)\n--\n\nSet the priority mask to maskpri and return the previous mask value.",
             8
         ),
         MethodDefinition(
             "LOG_MASK",
             MethodCallbacks(positional=syslog_LOG_MASK_call),
             "LOG_MASK($module, pri, /)\n--\n\nCalculates the mask for the individual priority pri.",
             8
         ),
         MethodDefinition(
             "LOG_UPTO",
             MethodCallbacks(positional=syslog_LOG_UPTO_call),
             "LOG_UPTO($module, pri, /)\n--\n\nCalculates the mask for all priorities up to and including pri.",
             8
         ),

     ];

impl syslog_openlog_bound(
    receiver: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    clinic_args = stack.view(count);
    try {
        ident: ptr[PyObject] = NULL;
        if count > 0 and clinic_args[0] != NULL {
            value = clinic_args[0];
            ident = convert_unicode(value, "openlog", "argument 'ident'");
        }
        logoption: i64 = 0;
        if count > 1 and clinic_args[1] != NULL {
            value = clinic_args[1];
            logoption = convert_long(value);
        }
        facility: i64 = LOG_USER;
        if count > 2 and clinic_args[2] != NULL {
            value = clinic_args[2];
            facility = convert_long(value);
        }
        return syslog_openlog_impl(receiver, ident, logoption, facility);
    } except boundary_failure {
        return NULL;
    }
}

impl syslog_openlog_call(
    receiver: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    if kwnames == NULL and nargs >= 0 and nargs <= 3 {
        return syslog_openlog_bound(receiver, args, nargs);
    }
    return invoke_keywords(
        syslog_openlog_signature, args, nargs, kwnames, syslog_openlog_bound, receiver
    );
}

impl syslog_closelog_call(
    receiver: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return syslog_closelog_impl(receiver);
    } except boundary_failure {
        return NULL;
    }
}

impl syslog_setlogmask_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        maskpri: i64 = convert_long(value);
        return return_long(syslog_setlogmask_impl(receiver, maskpri));
    } except boundary_failure {
        return NULL;
    }
}

impl syslog_LOG_MASK_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        pri: i64 = convert_long(value);
        return return_long(syslog_LOG_MASK_impl(receiver, pri));
    } except boundary_failure {
        return NULL;
    }
}

impl syslog_LOG_UPTO_call(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        pri: i64 = convert_long(value);
        return return_long(syslog_LOG_UPTO_impl(receiver, pri));
    } except boundary_failure {
        return NULL;
    }
}

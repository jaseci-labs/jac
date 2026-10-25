glob:priv kCFNumberSInt32Type: Final[i64] = 3,
     kCFStringEncodingUTF8: Final[u32] = 0x08000100,
     KEY_EXCLUDE_SIMPLE_HOSTNAMES: Final[i32] = 0,
     KEY_EXCEPTIONS_LIST: Final[i32] = 1,
     KEY_HTTP_ENABLE: Final[i32] = 2,
     KEY_HTTPS_ENABLE: Final[i32] = 5,
     KEY_FTP_ENABLE: Final[i32] = 8,
     KEY_GOPHER_ENABLE: Final[i32] = 11,
     KEY_SOCKS_ENABLE: Final[i32] = 14;

def:priv cfnum_to_int32(num: ptr) -> i32;

def:priv cfstring_to_pystring(ref: ptr) -> ptr[PyObject];

def:priv copy_proxies -> ptr;

def:priv get_proxy_settings_error(
    proxy_dict: ptr, result: ptr[PyObject]
) -> ptr[PyObject];

def get_proxy_settings(mod: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def:priv set_proxy(
    proxies: ptr[PyObject], proto: ptr[u8], proxy_dict: ptr, enabled_key: i32
) -> i32;

def get_proxies(mod: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

impl cfnum_to_int32(num: ptr) -> i32 {
    return cf_number_int32(num);
}

impl cfstring_to_pystring(ref: ptr) -> ptr[PyObject] {
    s = cf_string_utf8_pointer(ref, kCFStringEncodingUTF8);
    if s {
        return PyUnicode_DecodeUTF8(s, i64(strlen(s)), ptr[u8]());
    }
    len = cf_string_length(ref);
    buf = ptr[u8](PyMem_Malloc(u64(len * 4)));
    if not buf {
        PyErr_NoMemory();
        return NULL;
    }
    ok = cf_string_copy(ref, buf, len * 4, kCFStringEncodingUTF8);
    if not ok {
        PyMem_Free(ptr(buf));
        return NULL;
    }
    result = PyUnicode_DecodeUTF8(buf, i64(strlen(buf)), ptr[u8]());
    PyMem_Free(ptr(buf));
    return result;
}

impl copy_proxies -> ptr {
    save = PyEval_SaveThread();
    proxy_dict = proxies_copy();
    PyEval_RestoreThread(save);
    return proxy_dict;
}

impl get_proxy_settings_error(proxy_dict: ptr, result: ptr[PyObject]) -> ptr[PyObject] {
    if proxy_dict {
        cf_release(proxy_dict);
    }
    object_xdecref(result);
    return NULL;
}

impl get_proxy_settings(mod: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    proxy_dict = copy_proxies();
    if not proxy_dict {
        return object_new_ref(Py_None);
    }

    result = PyDict_New();
    if not result {
        return get_proxy_settings_error(proxy_dict, result);
    }

    a_num = cf_dictionary_value(proxy_dict, proxy_key(KEY_EXCLUDE_SIMPLE_HOSTNAMES));
    v: ptr[PyObject] = NULL;
    if not a_num {
        v = PyBool_FromLong(0);
    } else {
        v = PyBool_FromLong(i64(cfnum_to_int32(a_num)));
    }
    if not v {
        return get_proxy_settings_error(proxy_dict, result);
    }

    r = PyDict_SetItemString(result, ptr[u8]("exclude_simple"), v);
    object_decref(v);
    if r == -1 {
        return get_proxy_settings_error(proxy_dict, result);
    }

    an_array = cf_dictionary_value(proxy_dict, proxy_key(KEY_EXCEPTIONS_LIST));
    if an_array {
        len = cf_array_count(an_array);
        v = PyTuple_New(len);
        if not v {
            return get_proxy_settings_error(proxy_dict, result);
        }

        r = PyDict_SetItemString(result, ptr[u8]("exceptions"), v);
        object_decref(v);
        if r == -1 {
            return get_proxy_settings_error(proxy_dict, result);
        }

        for i in range(len) {
            a_string = cf_array_value(an_array, i);
            if not a_string {
                PyTuple_SetItem(v, i, object_new_ref(Py_None));
            } else {
                t = cfstring_to_pystring(a_string);
                if not t {
                    PyTuple_SetItem(v, i, object_new_ref(Py_None));
                } else {
                    PyTuple_SetItem(v, i, t);
                }
            }
        }
    }

    cf_release(proxy_dict);
    return result;
}

impl set_proxy(
    proxies: ptr[PyObject], proto: ptr[u8], proxy_dict: ptr, enabled_key: i32
) -> i32 {
    a_num = cf_dictionary_value(proxy_dict, proxy_key(enabled_key));
    if a_num and cfnum_to_int32(a_num) != 0 {
        host_string = cf_dictionary_value(proxy_dict, proxy_key(enabled_key + 1));
        a_num = cf_dictionary_value(proxy_dict, proxy_key(enabled_key + 2));

        if host_string {
            h = cfstring_to_pystring(host_string);
            if h {
                v: ptr[PyObject] = NULL;
                if a_num {
                    port = i64(cfnum_to_int32(a_num));
                    v = PyUnicode_FromFormat("http://%U:%ld", h, port);
                } else {
                    v = PyUnicode_FromFormat("http://%U", h);
                }
                object_decref(h);
                if not v {
                    return i32(-1);
                }
                r = PyDict_SetItemString(proxies, proto, v);
                object_decref(v);
                return r;
            }
        }
    }
    return i32(0);
}

impl get_proxies(mod: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    proxy_dict = copy_proxies();
    if not proxy_dict {
        return PyDict_New();
    }

    result = PyDict_New();
    if not result
        or set_proxy(result, ptr[u8]("http"), proxy_dict, KEY_HTTP_ENABLE) == -1
        or set_proxy(result, ptr[u8]("https"), proxy_dict, KEY_HTTPS_ENABLE) == -1
        or set_proxy(result, ptr[u8]("ftp"), proxy_dict, KEY_FTP_ENABLE) == -1
        or set_proxy(result, ptr[u8]("gopher"), proxy_dict, KEY_GOPHER_ENABLE) == -1
        or set_proxy(result, ptr[u8]("socks"), proxy_dict, KEY_SOCKS_ENABLE) == -1 {
        cf_release(proxy_dict);
        object_xdecref(result);
        return NULL;
    }

    cf_release(proxy_dict);
    return result;
}

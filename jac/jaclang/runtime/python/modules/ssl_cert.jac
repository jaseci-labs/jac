glob:priv ERRORS_ERROR: ptr[u8] = ptr[u8]("error"),
     ERRORS_STRICT: ptr[u8] = ptr[u8]("strict");

def:priv pointer_at(record: ptr, offset: int) -> ptr;

def:priv int_at(record: ptr, offset: int) -> int;

def:priv bio_reset(bio: ptr);

def:priv memory_data(bio: ptr) -> tuple[ptr, i64];

def bytes_from_bio(bio: ptr) -> ptr[PyObject];

def unicode_from_bio(bio: ptr, errors: ptr[u8]) -> ptr[PyObject];

def asn1obj2py(module: ptr[PyObject], name: ptr, no_name: bool) -> ptr[PyObject];

def:priv attribute_tuple(
    module: ptr[PyObject], name: ptr, value: ptr
) -> ptr[PyObject];

def x509_name_tuple(module: ptr[PyObject], xname: ptr) -> ptr[PyObject];

def:priv pair_of(label: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject];

def:priv asn1_string_text(value: ptr) -> ptr[PyObject];

def:priv general_name_tuple(
    module: ptr[PyObject], name: ptr, biobuf: ptr
) -> ptr[PyObject];

def:priv peer_alt_names(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject];

def:priv aia_uri(certificate: ptr, nid: int) -> ptr[PyObject];

def:priv crl_dp(certificate: ptr) -> ptr[PyObject];

def:priv set_item(target: ptr[PyObject], key: str, value: ptr[PyObject]) -> bool;

def:priv printed_line(
    module: ptr[PyObject], biobuf: ptr, buf: ptr[u8], lineno: int
) -> ptr[PyObject];

def decode_certificate(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject];

def certificate_to_der(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject];

def certificate_from_x509(
    module: ptr[PyObject], cert: ptr, upref: bool
) -> ptr[PyObject];

def certificates_from_stack(
    module: ptr[PyObject], stack: ptr, upref: bool
) -> ptr[PyObject];

def x509name_print(
    module: ptr[PyObject], name: ptr, indent: int, flags: u64
) -> ptr[PyObject];

def type_name_address(instance: ptr[PyObject]) -> ptr[u8];

def pem_errors -> ptr[u8];

impl pointer_at(record: ptr, offset: int) -> ptr {
    return ptr[ptr](record + offset).view(1)[0];
}

impl int_at(record: ptr, offset: int) -> int {
    return int(ptr[i32](record + offset).view(1)[0]);
}

impl bio_reset(bio: ptr) {
    BIO_ctrl(bio, i32(BIO_CTRL_RESET), 0, ptr());
}

impl memory_data(bio: ptr) -> tuple[ptr, i64] {
    cell = ptr[ptr](PyMem_Malloc(u64(8)));
    if not cell {
        PyErr_NoMemory();
        return (ptr(), -1);
    }
    cell.view(1)[0] = ptr();
    size = BIO_ctrl(bio, i32(BIO_CTRL_INFO), 0, ptr(cell));
    data = cell.view(1)[0];
    PyMem_Free(cell);
    if not data or size < 0 {
        PyErr_SetString(PyExc_ValueError, "Not a memory BIO");
        return (ptr(), -1);
    }
    return (data, size);
}

impl bytes_from_bio(bio: ptr) -> ptr[PyObject] {
    (data, size) = memory_data(bio);
    if size < 0 {
        return NULL;
    }
    return jacpy_bytes_from_memory(data, size);
}

impl unicode_from_bio(bio: ptr, errors: ptr[u8]) -> ptr[PyObject] {
    (data, size) = memory_data(bio);
    if size < 0 {
        return NULL;
    }
    return PyUnicode_DecodeUTF8Stateful(data, size, errors, None);
}

impl asn1obj2py(module: ptr[PyObject], name: ptr, no_name: bool) -> ptr[PyObject] {
    namebuf = PyMem_Malloc(u64(X509_NAME_MAXLEN));
    if not namebuf {
        return PyErr_NoMemory();
    }
    buflen = int(OBJ_obj2txt(namebuf, i32(X509_NAME_MAXLEN), name, i32(no_name)));
    if buflen < 0 {
        PyMem_Free(namebuf);
        set_ssl_error(module, ptr[u8](), 1102);
        return NULL;
    }

    if buflen > X509_NAME_MAXLEN - 1 {
        PyMem_Free(namebuf);

        buflen = int(OBJ_obj2txt(ptr(), i32(0), name, i32(no_name)));
        namebuf = PyMem_Malloc(u64(buflen + 1));
        if not namebuf {
            return PyErr_NoMemory();
        }
        buflen = int(OBJ_obj2txt(namebuf, i32(buflen + 1), name, i32(no_name)));
        if buflen < 0 {
            set_ssl_error(module, ptr[u8](), 1117);
            PyMem_Free(namebuf);
            return NULL;
        }
    }
    name_obj = NULL;
    if not buflen and no_name {
        name_obj = Py_NewRef(Py_None);
    } else {
        name_obj = c_text(namebuf, buflen);
    }
    PyMem_Free(namebuf);
    return name_obj;
}

impl attribute_tuple(module: ptr[PyObject], name: ptr, value: ptr) -> ptr[PyObject] {
    pyname = asn1obj2py(module, name, False);
    if not pyname {
        set_ssl_error(module, ptr[u8](), 1144);
        return NULL;
    }
    if i64(ASN1_STRING_type(value)) == V_ASN1_BIT_STRING {
        buflen = i64(ASN1_STRING_length(value));
        return Py_BuildValue(
            ptr[u8]("Ny#"), pyname, ASN1_STRING_get0_data(value), buflen
        );
    }
    valuebuf = ptr[u8]();
    buflen = i64(ASN1_STRING_to_UTF8(&mut valuebuf, value));
    if buflen < 0 {
        set_ssl_error(module, ptr[u8](), 1155);
        jacpy_release(pyname);
        return NULL;
    }
    pyattr = Py_BuildValue(ptr[u8]("Ns#"), pyname, valuebuf, buflen);
    openssl_free(valuebuf);
    return pyattr;
}

impl x509_name_tuple(module: ptr[PyObject], xname: ptr) -> ptr[PyObject] {
    entry_count = int(X509_NAME_entry_count(xname));
    rdn_level = -1;
    dn = PyList_New(0);
    if not dn {
        return NULL;
    }

    rdn = PyList_New(0);
    if not rdn {
        jacpy_release(dn);
        return NULL;
    }
    for index_counter in range(entry_count) {
        name_entry = X509_NAME_get_entry(xname, i32(index_counter));

        if rdn_level >= 0 {
            if rdn_level != int(X509_NAME_ENTRY_set(name_entry)) {
                rdnt = PyList_AsTuple(rdn);
                jacpy_release(rdn);
                if not rdnt {
                    jacpy_release(dn);
                    return NULL;
                }
                retcode = PyList_Append(dn, rdnt);
                jacpy_release(rdnt);
                if retcode < 0 {
                    jacpy_release(dn);
                    return NULL;
                }

                rdn = PyList_New(0);
                if not rdn {
                    jacpy_release(dn);
                    return NULL;
                }
            }
        }
        rdn_level = int(X509_NAME_ENTRY_set(name_entry));

        attr = attribute_tuple(
            module,
            X509_NAME_ENTRY_get_object(name_entry),
            X509_NAME_ENTRY_get_data(name_entry)
        );
        if not attr {
            jacpy_release(rdn);
            jacpy_release(dn);
            return NULL;
        }
        retcode = PyList_Append(rdn, attr);
        jacpy_release(attr);
        if retcode < 0 {
            jacpy_release(rdn);
            jacpy_release(dn);
            return NULL;
        }
    }

    if PyList_Size(rdn) > 0 {
        rdnt = PyList_AsTuple(rdn);
        jacpy_release(rdn);
        if not rdnt {
            jacpy_release(dn);
            return NULL;
        }
        retcode = PyList_Append(dn, rdnt);
        jacpy_release(rdnt);
        if retcode < 0 {
            jacpy_release(dn);
            return NULL;
        }
    } else {
        jacpy_release(rdn);
    }

    result = PyList_AsTuple(dn);
    jacpy_release(dn);
    return result;
}

impl pair_of(label: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    if not label or not value {
        if label {
            jacpy_release(label);
        }
        if value {
            jacpy_release(value);
        }
        return NULL;
    }
    result = PyTuple_New(2);
    if not result {
        jacpy_release(label);
        jacpy_release(value);
        return NULL;
    }
    jacpy_tuple_set_owned(result, 0, label);
    jacpy_tuple_set_owned(result, 1, value);
    return result;
}

impl asn1_string_text(value: ptr) -> ptr[PyObject] {
    return c_text(ASN1_STRING_get0_data(value), i64(ASN1_STRING_length(value)));
}

impl general_name_tuple(
    module: ptr[PyObject], name: ptr, biobuf: ptr
) -> ptr[PyObject] {
    gntype = int_at(name, GENERAL_NAME_TYPE_OFFSET);
    d = pointer_at(name, GENERAL_NAME_D_OFFSET);
    if gntype == GEN_DIRNAME {
        label = PyUnicode_FromString(ptr[u8]("DirName"));
        if not label {
            return NULL;
        }
        return pair_of(label, x509_name_tuple(module, d));
    }
    if gntype == GEN_EMAIL or gntype == GEN_DNS or gntype == GEN_URI {
        label = NULL;
        if gntype == GEN_EMAIL {
            label = PyUnicode_FromString(ptr[u8]("email"));
        } elif gntype == GEN_DNS {
            label = PyUnicode_FromString(ptr[u8]("DNS"));
        } else {
            label = PyUnicode_FromString(ptr[u8]("URI"));
        }
        if not label {
            return NULL;
        }
        return pair_of(label, asn1_string_text(d));
    }
    if gntype == GEN_RID {
        label = PyUnicode_FromString(ptr[u8]("Registered ID"));
        if not label {
            return NULL;
        }
        buf = PyMem_Malloc(u64(2048));
        if not buf {
            jacpy_release(label);
            return PyErr_NoMemory();
        }
        length = int(i2t_ASN1_OBJECT(buf, i32(2047), d));
        value = NULL;
        if length < 0 {
            PyMem_Free(buf);
            jacpy_release(label);
            set_ssl_error(module, ptr[u8](), 1385);
            return NULL;
        } elif length >= 2048 {
            value = PyUnicode_FromString(ptr[u8]("<INVALID>"));
        } else {
            value = c_text(buf, length);
        }
        PyMem_Free(buf);
        return pair_of(label, value);
    }
    if gntype == GEN_IPADD {
        label = PyUnicode_FromString(ptr[u8]("IP Address"));
        if not label {
            return NULL;
        }
        length = int(ASN1_STRING_length(d));
        value = NULL;
        if length == 4 {
            p = ASN1_STRING_get0_data(d).view(4);
            value = PyUnicode_FromFormat(
                "%d.%d.%d.%d", i32(p[0]), i32(p[1]), i32(p[2]), i32(p[3])
            );
        } elif length == 16 {
            p = ASN1_STRING_get0_data(d).view(16);
            value = PyUnicode_FromFormat(
                "%X:%X:%X:%X:%X:%X:%X:%X",
                u32(p[0]) << u32(8) | u32(p[1]),
                u32(p[2]) << u32(8) | u32(p[3]),
                u32(p[4]) << u32(8) | u32(p[5]),
                u32(p[6]) << u32(8) | u32(p[7]),
                u32(p[8]) << u32(8) | u32(p[9]),
                u32(p[10]) << u32(8) | u32(p[11]),
                u32(p[12]) << u32(8) | u32(p[13]),
                u32(p[14]) << u32(8) | u32(p[15])
            );
        } else {
            value = PyUnicode_FromString(ptr[u8]("<invalid>"));
        }
        return pair_of(label, value);
    }

    if gntype != GEN_OTHERNAME and gntype != GEN_X400 and gntype != GEN_EDIPARTY {
        if PyErr_WarnFormat(
            PyExc_RuntimeWarning, 1, "Unknown general name type %d", c_int(gntype)
        )
            == -1 {
            return NULL;
        }
    }
    bio_reset(biobuf);
    GENERAL_NAME_print(biobuf, name);
    buf = ptr[u8](PyMem_Malloc(u64(2048)));
    if not buf {
        return PyErr_NoMemory();
    }
    length = int(BIO_gets(biobuf, buf, i32(2047)));
    if length < 0 {
        PyMem_Free(buf);
        set_ssl_error(module, ptr[u8](), 1465);
        return NULL;
    }

    colon = -1;
    position = 0;
    characters = buf.view(2048);
    while characters[position] != u8(0) {
        if characters[position] == u8(58) {
            colon = position;
            break;
        }
        position += 1;
    }
    if colon < 0 {
        PyErr_Format(PyExc_ValueError, "Invalid value %.200s", buf);
        PyMem_Free(buf);
        return NULL;
    }
    label = c_text(buf, colon);
    if not label {
        PyMem_Free(buf);
        return NULL;
    }
    value = c_text(buf + (colon + 1), length - (colon + 1));
    PyMem_Free(buf);
    return pair_of(label, value);
}

impl peer_alt_names(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject] {
    if not certificate {
        return Py_NewRef(Py_None);
    }

    biobuf = BIO_new(BIO_s_mem());
    if not biobuf {
        PyErr_SetString(state_ref(module, STATE_SSL_ERROR), "failed to allocate BIO");
        return NULL;
    }
    names = X509_get_ext_d2i(certificate, i32(NID_subject_alt_name), ptr(), ptr());
    if not names {
        BIO_free(biobuf);
        return Py_NewRef(Py_None);
    }
    result = PyList_New(0);
    if result {
        for j in range(int(OPENSSL_sk_num(names))) {
            t = general_name_tuple(module, OPENSSL_sk_value(names, i32(j)), biobuf);
            if not t {
                jacpy_release(result);
                result = NULL;
                break;
            }
            status = PyList_Append(result, t);
            jacpy_release(t);
            if status < 0 {
                jacpy_release(result);
                result = NULL;
                break;
            }
        }
    }
    GENERAL_NAMES_free(names);
    BIO_free(biobuf);
    if not result {
        return NULL;
    }
    names_tuple = PyList_AsTuple(result);
    jacpy_release(result);
    return names_tuple;
}

impl aia_uri(certificate: ptr, nid: int) -> ptr[PyObject] {
    info = X509_get_ext_d2i(certificate, i32(NID_info_access), ptr(), ptr());
    if not info {
        return Py_NewRef(Py_None);
    }
    count = int(OPENSSL_sk_num(info));
    if count == 0 {
        AUTHORITY_INFO_ACCESS_free(info);
        return Py_NewRef(Py_None);
    }
    lst = PyList_New(0);
    if not lst {
        AUTHORITY_INFO_ACCESS_free(info);
        return NULL;
    }
    for i in range(count) {
        ad = OPENSSL_sk_value(info, i32(i));
        location = pointer_at(ad, ACCESS_DESCRIPTION_LOCATION_OFFSET);
        if int(OBJ_obj2nid(pointer_at(ad, ACCESS_DESCRIPTION_METHOD_OFFSET))) != nid
            or int_at(location, GENERAL_NAME_TYPE_OFFSET) != GEN_URI {
            continue;
        }
        ostr = asn1_string_text(pointer_at(location, GENERAL_NAME_D_OFFSET));
        if not ostr {
            AUTHORITY_INFO_ACCESS_free(info);
            jacpy_release(lst);
            return NULL;
        }
        result = PyList_Append(lst, ostr);
        jacpy_release(ostr);
        if result < 0 {
            AUTHORITY_INFO_ACCESS_free(info);
            jacpy_release(lst);
            return NULL;
        }
    }
    AUTHORITY_INFO_ACCESS_free(info);

    if PyList_Size(lst) == 0 {
        jacpy_release(lst);
        return Py_NewRef(Py_None);
    }
    tup = PyList_AsTuple(lst);
    jacpy_release(lst);
    return tup;
}

impl crl_dp(certificate: ptr) -> ptr[PyObject] {
    dps = X509_get_ext_d2i(certificate, i32(NID_crl_distribution_points), ptr(), ptr());
    if not dps {
        return Py_NewRef(Py_None);
    }
    res = NULL;
    lst = PyList_New(0);
    failed = not lst;
    if not failed {
        for i in range(int(OPENSSL_sk_num(dps))) {
            dp = OPENSSL_sk_value(dps, i32(i));
            distpoint = pointer_at(dp, DIST_POINT_DISTPOINT_OFFSET);
            if not distpoint {
                continue;
            }
            gns = pointer_at(distpoint, DIST_POINT_NAME_NAME_OFFSET);
            for j in range(int(OPENSSL_sk_num(gns))) {
                gn = OPENSSL_sk_value(gns, i32(j));
                if int_at(gn, GENERAL_NAME_TYPE_OFFSET) != GEN_URI {
                    continue;
                }
                ouri = asn1_string_text(pointer_at(gn, GENERAL_NAME_D_OFFSET));
                if not ouri {
                    failed = True;
                    break;
                }
                err = PyList_Append(lst, ouri);
                jacpy_release(ouri);
                if err < 0 {
                    failed = True;
                    break;
                }
            }
            if failed {
                break;
            }
        }
    }
    if not failed {
        res = PyList_AsTuple(lst) if PyList_Size(lst) > 0 else Py_NewRef(Py_None);
    }
    if lst {
        jacpy_release(lst);
    }
    CRL_DIST_POINTS_free(dps);
    return res;
}

impl set_item(target: ptr[PyObject], key: str, value: ptr[PyObject]) -> bool {
    if not value {
        return False;
    }
    status = dict_set_text(target, key, value);
    jacpy_release(value);
    return status >= 0;
}

impl printed_line(
    module: ptr[PyObject], biobuf: ptr, buf: ptr[u8], lineno: int
) -> ptr[PyObject] {
    length = int(BIO_gets(biobuf, buf, i32(2047)));
    if length < 0 {
        set_ssl_error(module, ptr[u8](), lineno);
        return NULL;
    }
    return c_text(buf, length);
}

impl decode_certificate(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject] {
    retval = PyDict_New();
    if not retval {
        return NULL;
    }
    if not set_item(
        retval, "subject", x509_name_tuple(module, X509_get_subject_name(certificate))
    )
        or not set_item(
            retval, "issuer", x509_name_tuple(module, X509_get_issuer_name(certificate))
        )
        or not set_item(
            retval, "version", PyLong_FromLong(X509_get_version(certificate) + 1)
        ) {
        jacpy_release(retval);
        return NULL;
    }

    biobuf = BIO_new(BIO_s_mem());
    if not biobuf {
        PyErr_SetString(state_ref(module, STATE_SSL_ERROR), "failed to allocate BIO");
        jacpy_release(retval);
        return NULL;
    }
    buf = ptr[u8](PyMem_Malloc(u64(2048)));
    ok = bool(buf);
    if not ok {
        PyErr_NoMemory();
    }
    if ok {
        bio_reset(biobuf);

        i2a_ASN1_INTEGER(biobuf, X509_get_serialNumber(certificate));
        ok = set_item(retval, "serialNumber", printed_line(module, biobuf, buf, 1707));
    }
    if ok {
        bio_reset(biobuf);
        ASN1_TIME_print(biobuf, X509_get0_notBefore(certificate));
        ok = set_item(retval, "notBefore", printed_line(module, biobuf, buf, 1724));
    }
    if ok {
        bio_reset(biobuf);
        ASN1_TIME_print(biobuf, X509_get0_notAfter(certificate));
        ok = set_item(retval, "notAfter", printed_line(module, biobuf, buf, 1741));
    }
    if buf {
        PyMem_Free(buf);
    }

    for (key, kind) in [
        ("subjectAltName", 0),
        ("OCSP", 1),
        ("caIssuers", 2),
        ("crlDistributionPoints", 3)
    ] {
        if not ok {
            break;
        }
        value = NULL;
        if kind == 0 {
            value = peer_alt_names(module, certificate);
        } elif kind == 1 {
            value = aia_uri(certificate, NID_ad_OCSP);
        } elif kind == 2 {
            value = aia_uri(certificate, NID_ad_ca_issuers);
        } else {
            value = crl_dp(certificate);
        }
        if not value {
            ok = False;
        } elif value == Py_None {
            jacpy_release(value);
        } else {
            ok = set_item(retval, key, value);
        }
    }
    BIO_free(biobuf);
    if not ok {
        jacpy_release(retval);
        return NULL;
    }
    return retval;
}

impl certificate_to_der(module: ptr[PyObject], certificate: ptr) -> ptr[PyObject] {
    bytes_buf = ptr[u8]();
    length = i64(i2d_X509(certificate, &mut bytes_buf));
    if length < 0 {
        set_ssl_error(module, ptr[u8](), 1823);
        return NULL;
    }

    retval = jacpy_bytes_from_memory(bytes_buf, length);
    openssl_free(bytes_buf);
    return retval;
}

impl certificate_from_x509(
    module: ptr[PyObject], cert: ptr, upref: bool
) -> ptr[PyObject] {
    type = state_ref(module, STATE_CERTIFICATE_TYPE);
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    if upref {
        X509_up_ref(cert);
    }
    state = CertificateState(cert=cert);
    if jacpy_binding_native_set(instance, Certificate_token.definition_of(type), state)
        < 0 {
        state.cert = ptr();
        if upref {
            X509_free(cert);
        }
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

impl certificates_from_stack(
    module: ptr[PyObject], stack: ptr, upref: bool
) -> ptr[PyObject] {
    length = int(OPENSSL_sk_num(stack));
    result = PyList_New(length);
    if not result {
        return NULL;
    }
    for i in range(length) {
        ocert = certificate_from_x509(module, OPENSSL_sk_value(stack, i32(i)), upref);
        if not ocert {
            jacpy_release(result);
            return NULL;
        }
        PyList_SetItem(result, i, ocert);
    }
    return result;
}

impl x509name_print(
    module: ptr[PyObject], name: ptr, indent: int, flags: u64
) -> ptr[PyObject] {
    biobuf = BIO_new(BIO_s_mem());
    if not biobuf {
        PyErr_SetString(PyExc_MemoryError, "failed to allocate BIO");
        return NULL;
    }
    if X509_NAME_print_ex(biobuf, name, i32(indent), flags) <= 0 {
        set_ssl_error(module, ptr[u8](), 143);
        BIO_free(biobuf);
        return NULL;
    }
    res = unicode_from_bio(biobuf, ERRORS_STRICT);
    BIO_free(biobuf);
    return res;
}

impl type_name_address(instance: ptr[PyObject]) -> ptr[u8] {
    return ptr[PyTypeObject](Py_TYPE(instance)).view(1)[0].tp_name;
}

impl pem_errors -> ptr[u8] {
    return ERRORS_ERROR;
}

import from c {
    def strlen(text: ptr[u8]) -> u64;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def memset(target: ptr, value: i32, size: u64) -> ptr;  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  def wcslen(text: ptr[i32]) -> u64;  def wcsncpy(
        target: ptr[i32], source: ptr[i32], size: u64
    ) -> ptr[i32];  def wcscpy(target: ptr[i32], source: ptr[i32]) -> ptr[i32];  def mbstowcs(
        dest: ptr[i32], src: ptr[u8], n: u64
    ) -> u64;  def mbrtowc(pwc: ptr[i32], src: ptr[u8], n: u64, ps: ptr) -> u64;  def wcstombs(
        dest: ptr[u8], src: ptr[i32], n: u64
    ) -> u64;  def setlocale(category: i32, locale: ptr[u8]) -> ptr[u8];  def nl_langinfo(
        item: i32
    ) -> ptr[u8];  def isatty(fd: i32) -> i32;  def fcntl(
        fd: i32, cmd: i32, *args: any
    ) -> i32;  def ioctl(fd: i32, request: u64, *args: any) -> i32;  def open(
        path: ptr[u8], flags: i32, *args: any
    ) -> i32;  def close(fd: i32) -> i32;  def read(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def write(fd: i32, buf: ptr, count: u64) -> i64;  def fopen(
        path: ptr[u8], mode: ptr[u8]
    ) -> ptr[FILE];  def fclose(stream: ptr[FILE]) -> i32;  def fileno(
        stream: ptr[FILE]
    ) -> i32;  def readlink(path: ptr[u8], buffer: ptr[u8], size: u64) -> i64;  def realpath(
        path: ptr[u8], resolved_path: ptr[u8]
    ) -> ptr[u8];  def getcwd(buffer: ptr[u8], size: u64) -> ptr[u8];  def sysconf(
        name: i32
    ) -> i64;  def jacpy_fstat(fd: i32, status: ptr[_Py_stat_struct]) -> i32;  def jacpy_stat(
        path: ptr[u8], status: ptr
    ) -> i32;  def _Py_normalize_encoding(
        encoding: ptr[u8], lower: ptr[u8], lower_len: u64
    ) -> i32;  def _Py_DecodeUTF8Ex(
        s: ptr[u8],
        size: i64,
        wstr: ptr[ptr[i32]],
        wlen: ptr[u64],
        reason: ptr[ptr[u8]],
        errors: i32
    ) -> i32;  def _Py_EncodeUTF8Ex(
        text: ptr[i32],
        out_str: ptr[ptr[u8]],
        error_pos: ptr[u64],
        reason: ptr[ptr[u8]],
        raw_malloc: i32,
        errors: i32
    ) -> i32;  def PyBytes_AsStringAndSize(
        op: ptr[PyObject], s: ptr[ptr[u8]], length: ptr[i64]
    ) -> i32;  def jacpy_stack_address(slots: &mut FileStack) -> int;  obj FileStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0,
            w18: u64 = 0,
            w19: u64 = 0,
            w20: u64 = 0,
            w21: u64 = 0,
            w22: u64 = 0,
            w23: u64 = 0;
    }  glob _Py_open_cloexec_works: i32 = -1; glob:priv ioctl_works: i32 = -1;
}

glob:priv MAX_UNICODE: Final[i32] = 0x10ffff,
     PY_SSIZE_T_MAX: Final[i64] = 9223372036854775807,
     _Py_ERROR_STRICT: Final[i32] = 1,
     _Py_ERROR_SURROGATEESCAPE: Final[i32] = 2,
     SEP: Final[i32] = 47,
     DOT: Final[i32] = 46,
     STACK_MBSTATE: Final[i64] = 0,
     MBSTATE_SIZE: Final[u64] = 128,
     STACK_SCRATCH: Final[i64] = 128,
     STACK_SLOT2: Final[i64] = 160;

def decode_error -> u64;

def incomplete_character -> u64;

def runtime_i32(offset: i64) -> ptr[i32];

def utf8_mode -> i32;

def force_ascii_slot -> ptr[i32];

def set_reason(reason: ptr[ptr[u8]], text: ptr[u8]);

def get_surrogateescape(errors: i32) -> tuple[i32, i32];

def is_valid_wide_char(ch: i32) -> bool;

def _Py_mbstowcs(dest: ptr[i32], src: ptr[u8], n: u64) -> u64;

def _Py_mbrtowc(pwc: ptr[i32], src: ptr[u8], length: u64, pmbs: ptr) -> u64;

def is_ascii_alias(encoding: ptr[u8]) -> bool;

def check_force_ascii -> i32;

def get_force_ascii -> i32;

def encode_ascii(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    errors: i32
) -> i32;

def decode_ascii(
    arg: ptr[u8], wstr: ptr[ptr[i32]], wlen: ptr[u64], reason: ptr[ptr[u8]], errors: i32
) -> i32;

def decode_current_locale(
    arg: ptr[u8], wstr: ptr[ptr[i32]], wlen: ptr[u64], reason: ptr[ptr[u8]], errors: i32
) -> i32;

def decode_locale_ex(
    arg: ptr[u8],
    wstr: ptr[ptr[i32]],
    wlen: ptr[u64],
    reason: ptr[ptr[u8]],
    current_locale: i32,
    errors: i32
) -> i32;

def decode_locale(arg: ptr[u8], wlen: ptr[u64]) -> ptr[i32];

def encode_current_locale(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    errors: i32
) -> i32;

def encode_locale_ex(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    current_locale: i32,
    errors: i32
) -> i32;

def encode_locale(
    text: ptr[i32], error_pos: ptr[u64], raw_malloc: i32, current_locale: i32
) -> ptr[u8];

def utf8_wide_name -> ptr[i32];

def get_locale_encoding -> ptr[i32];

def get_inheritable(fd: i32, raise_: i32) -> i32;

def set_inheritable(
    fd: i32, inheritable: i32, raise_: i32, atomic_flag_works: ptr[i32]
) -> i32;

def make_non_inheritable(fd: i32) -> i32;

def open_impl(pathname: ptr[u8], flags: i32, gil_held: i32) -> i32;

def write_impl(fd: i32, buf: ptr, count: u64, gil_held: i32) -> i64;

def is_abs(path: ptr[i32]) -> bool;

def skiproot(path: ptr[i32]) -> tuple[i64, i64];

def join_relfile(
    buffer: ptr[i32], bufsize: u64, dirname: ptr[i32], relfile: ptr[i32]
) -> i32;

def normpath_and_size(path: ptr[i32], size: i64) -> tuple[ptr[i32], i64];

def normpath_is_end(path: ptr[i32], index: i64, has_end: bool, size: i64) -> bool;

def normpath_sep_or_end(path: ptr[i32], index: i64, has_end: bool, size: i64) -> bool;

def decode_into(cbuf: ptr[u8], buf: ptr[i32], buflen: u64) -> i64;

def wgetcwd(buf: ptr[i32], buflen: u64) -> ptr[i32];

def cwd_copy -> tuple[i32, ptr[i32]];

import from c {
    def _Py_device_encoding(fd: i32) -> ptr[PyObject] {
        save = PyEval_SaveThread();
        valid = isatty(fd);
        PyEval_RestoreThread(save);
        if valid == 0 {
            return object_new_ref(Py_None);
        }
        if utf8_mode() != 0 {
            return py_id(_Py_STR_utf_8);
        }
        return _Py_GetLocaleEncodingObject();
    }  def _Py_GetForceASCII -> i32 {
        if _Py_FORCE_UTF8_FS_ENCODING != 0 {
            return 0;
        }
        return get_force_ascii();
    }  def _Py_ResetForceASCII {
        if _Py_FORCE_UTF8_FS_ENCODING == 0 {
            force_ascii_slot().view(1)[0] = -1;
        }
        return;
    }  def _Py_DecodeLocaleEx(
        arg: ptr[u8],
        wstr: ptr[ptr[i32]],
        wlen: ptr[u64],
        reason: ptr[ptr[u8]],
        current_locale: i32,
        errors: i32
    ) -> i32 {
        return decode_locale_ex(arg, wstr, wlen, reason, current_locale, errors);
    }  def Py_DecodeLocale(arg: ptr[u8], wlen: ptr[u64]) -> ptr[i32] {
        return decode_locale(arg, wlen);
    }  def Py_EncodeLocale(text: ptr[i32], error_pos: ptr[u64]) -> ptr[u8] {
        return encode_locale(text, error_pos, 0, 0);
    }  def _Py_EncodeLocaleRaw(text: ptr[i32], error_pos: ptr[u64]) -> ptr[u8] {
        return encode_locale(text, error_pos, 1, 0);
    }  def _Py_EncodeLocaleEx(
        text: ptr[i32],
        out_str: ptr[ptr[u8]],
        error_pos: ptr[u64],
        reason: ptr[ptr[u8]],
        current_locale: i32,
        errors: i32
    ) -> i32 {
        return encode_locale_ex(
            text, out_str, error_pos, reason, 1, current_locale, errors
        );
    }  def _Py_GetLocaleEncoding -> ptr[i32] {
        return get_locale_encoding();
    }  def _Py_GetLocaleEncodingObject -> ptr[PyObject] {
        encoding = get_locale_encoding();
        if not encoding {
            PyErr_NoMemory();
            return NULL;
        }
        text = PyUnicode_FromWideChar(encoding, -1);
        PyMem_RawFree(ptr(encoding));
        return text;
    }  def _Py_fstat_noraise(fd: i32, status: ptr[_Py_stat_struct]) -> i32 {
        return jacpy_fstat(fd, status);
    }  def _Py_fstat(fd: i32, status: ptr[_Py_stat_struct]) -> i32 {
        save = PyEval_SaveThread();
        res = jacpy_fstat(fd, status);
        err = jacpy_errno();
        PyEval_RestoreThread(save);

        if res != 0 {
            jacpy_set_errno(err);
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        return 0;
    }  def _Py_wstat(path: ptr[i32], buf: ptr) -> i32 {
        fname = encode_locale(path, ptr[u64](), 1, 0);
        if not fname {
            jacpy_set_errno(i64(EINVAL));
            return -1;
        }
        err = jacpy_stat(fname, buf);
        PyMem_RawFree(ptr(fname));
        return err;
    }  def _Py_stat(path: ptr[PyObject], statbuf: ptr) -> i32 {
        bytes_obj = PyUnicode_EncodeFSDefault(path);
        if not bytes_obj {
            return -2;
        }

        slots: own FileStack = FileStack();
        cpath = ptr[ptr[u8]](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
        if PyBytes_AsStringAndSize(bytes_obj, cpath, ptr[i64]()) == -1 {
            object_decref(bytes_obj);
            return -2;
        }

        ret = jacpy_stat(cpath.view(1)[0], statbuf);
        object_decref(bytes_obj);
        return ret;
    }  def _Py_get_inheritable(fd: i32) -> i32 {
        return get_inheritable(fd, 1);
    }  def _Py_set_inheritable(
        fd: i32, inheritable: i32, atomic_flag_works: ptr[i32]
    ) -> i32 {
        return set_inheritable(fd, inheritable, 1, atomic_flag_works);
    }  def _Py_set_inheritable_async_safe(
        fd: i32, inheritable: i32, atomic_flag_works: ptr[i32]
    ) -> i32 {
        return set_inheritable(fd, inheritable, 0, atomic_flag_works);
    }  def _Py_open(pathname: ptr[u8], flags: i32) -> i32 {
        return open_impl(pathname, flags, 1);
    }  def _Py_open_noraise(pathname: ptr[u8], flags: i32) -> i32 {
        return open_impl(pathname, flags, 0);
    }  def _Py_wfopen(path: ptr[i32], mode: ptr[i32]) -> ptr[FILE] {
        if PySys_Audit("open", "uui", path, mode, i32(0)) < 0 {
            return ptr[FILE]();
        }
        slots: own FileStack = FileStack();
        cmode = ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH;
        r = wcstombs(cmode, mode, u64(10));
        if r == decode_error() or r >= u64(10) {
            jacpy_set_errno(i64(EINVAL));
            return ptr[FILE]();
        }
        cpath = encode_locale(path, ptr[u64](), 1, 0);
        if not cpath {
            return ptr[FILE]();
        }
        f = fopen(cpath, cmode);
        PyMem_RawFree(ptr(cpath));
        if not f {
            return ptr[FILE]();
        }
        if make_non_inheritable(fileno(f)) < 0 {
            fclose(f);
            return ptr[FILE]();
        }
        return f;
    }  def Py_fopen(path: ptr[PyObject], mode: ptr[u8]) -> ptr[FILE] {
        if PySys_Audit("open", "Osi", path, mode, i32(0)) < 0 {
            return ptr[FILE]();
        }

        f = ptr[FILE]();
        async_err: i32 = 0;
        saved_errno: i64 = 0;
        bytes_obj = NULL;
        if PyUnicode_FSConverter(path, &mut bytes_obj) == 0 {
            return ptr[FILE]();
        }
        path_bytes = ptr[u8](bytes_obj) + PyBytesObject_OB_SVAL;

        while True {
            save = PyEval_SaveThread();
            f = fopen(path_bytes, mode);
            saved_errno = jacpy_errno();
            PyEval_RestoreThread(save);
            if f or saved_errno != i64(EINTR) {
                break;
            }
            async_err = PyErr_CheckSignals();
            if async_err != 0 {
                break;
            }
        }
        object_decref(bytes_obj);

        if async_err != 0 {
            return ptr[FILE]();
        }

        if not f {
            jacpy_set_errno(saved_errno);
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, path);
            return ptr[FILE]();
        }

        if set_inheritable(fileno(f), 0, 1, ptr[i32]()) < 0 {
            fclose(f);
            return ptr[FILE]();
        }
        return f;
    }  def Py_fclose(file: ptr[FILE]) -> i32 {
        return fclose(file);
    }  def _Py_read(fd: i32, buf: ptr, count: u64) -> i64 {
        n: i64 = 0;
        err: i64 = 0;
        async_err: i32 = 0;

        if count > u64(PY_SSIZE_T_MAX) {
            count = u64(PY_SSIZE_T_MAX);
        }

        while True {
            save = PyEval_SaveThread();
            jacpy_set_errno(0);
            n = read(fd, buf, count);

            err = jacpy_errno();
            PyEval_RestoreThread(save);
            if n >= 0 or err != i64(EINTR) {
                break;
            }
            async_err = PyErr_CheckSignals();
            if async_err != 0 {
                break;
            }
        }

        if async_err != 0 {
            jacpy_set_errno(err);
            return -1;
        }
        if n < 0 {
            jacpy_set_errno(err);
            PyErr_SetFromErrno(PyExc_OSError);
            jacpy_set_errno(err);
            return -1;
        }
        return n;
    }  def _Py_write(fd: i32, buf: ptr, count: u64) -> i64 {
        return write_impl(fd, buf, count, 1);
    }  def _Py_write_noraise(fd: i32, buf: ptr, count: u64) -> i64 {
        return write_impl(fd, buf, count, 0);
    }  def _Py_wreadlink(path: ptr[i32], buf: ptr[i32], buflen: u64) -> i32 {
        cpath = encode_locale(path, ptr[u64](), 1, 0);
        if not cpath {
            jacpy_set_errno(i64(EINVAL));
            return -1;
        }
        cbuf_len = u64(MAXPATHLEN);
        cbuf = ptr[u8](PyMem_RawMalloc(cbuf_len));
        if not cbuf {
            PyMem_RawFree(ptr(cpath));
            jacpy_set_errno(i64(ENOMEM));
            return -1;
        }
        res = readlink(cpath, cbuf, cbuf_len);
        PyMem_RawFree(ptr(cpath));
        if res == -1 {
            PyMem_RawFree(ptr(cbuf));
            return -1;
        }
        if u64(res) == cbuf_len {
            PyMem_RawFree(ptr(cbuf));
            jacpy_set_errno(i64(EINVAL));
            return -1;
        }

        (cbuf + res).view(1)[0] = u8(0);
        r1 = decode_into(cbuf, buf, buflen);
        PyMem_RawFree(ptr(cbuf));
        if r1 < 0 {
            jacpy_set_errno(i64(EINVAL));
            return -1;
        }
        return i32(r1);
    }  def _Py_wrealpath(
        path: ptr[i32], resolved_path: ptr[i32], resolved_path_len: u64
    ) -> ptr[i32] {
        cpath = encode_locale(path, ptr[u64](), 1, 0);
        if not cpath {
            jacpy_set_errno(i64(EINVAL));
            return ptr[i32]();
        }
        cresolved_path = ptr[u8](PyMem_RawMalloc(u64(MAXPATHLEN)));
        if not cresolved_path {
            PyMem_RawFree(ptr(cpath));
            jacpy_set_errno(i64(ENOMEM));
            return ptr[i32]();
        }
        res = realpath(cpath, cresolved_path);
        PyMem_RawFree(ptr(cpath));
        if not res {
            PyMem_RawFree(ptr(cresolved_path));
            return ptr[i32]();
        }

        r = decode_into(cresolved_path, resolved_path, resolved_path_len);
        PyMem_RawFree(ptr(cresolved_path));
        if r < 0 {
            jacpy_set_errno(i64(EINVAL));
            return ptr[i32]();
        }
        return resolved_path;
    }  def _Py_isabs(path: ptr[i32]) -> i32 {
        if is_abs(path) {
            return 1;
        }
        return 0;
    }  def _Py_abspath(path: ptr[i32], abspath_p: ptr[ptr[i32]]) -> i32 {
        if path.view(1)[0] == 0
            or (path.view(1)[0] == DOT and (path + 1).view(1)[0] == 0) {
            (status, cwd) = cwd_copy();
            if status < 0 {
                return -1;
            }
            if not cwd {
                abspath_p.view(1)[0] = ptr[i32]();
                return 0;
            }
            abspath_p.view(1)[0] = _PyMem_RawWcsdup(cwd);
            PyMem_RawFree(ptr(cwd));
            return 0;
        }

        if is_abs(path) {
            abspath_p.view(1)[0] = _PyMem_RawWcsdup(path);
            return 0;
        }

        (cwd_status, cwd_text) = cwd_copy();
        if cwd_status < 0 {
            return -1;
        }
        if not cwd_text {
            abspath_p.view(1)[0] = ptr[i32]();
            return 0;
        }

        cwd_len = wcslen(cwd_text);
        path_len = wcslen(path);
        length = cwd_len + 1 + path_len + 1;
        result = ptr[i32]();
        if length <= u64(PY_SSIZE_T_MAX) // 4 {
            result = ptr[i32](PyMem_RawMalloc(length * 4));
        }
        abspath_p.view(1)[0] = result;
        if not result {
            PyMem_RawFree(ptr(cwd_text));
            return 0;
        }

        abspath = result;
        memcpy(ptr(abspath), ptr(cwd_text), cwd_len * 4);
        abspath = abspath + i64(cwd_len);

        abspath.view(1)[0] = SEP;
        abspath = abspath + 1;

        memcpy(ptr(abspath), ptr(path), path_len * 4);
        abspath = abspath + i64(path_len);

        abspath.view(1)[0] = 0;
        PyMem_RawFree(ptr(cwd_text));
        return 0;
    }  def _Py_skiproot(
        path: ptr[i32], size: i64, drvsize: ptr[i64], rootsize: ptr[i64]
    ) {
        (drive, root_size) = skiproot(path);
        drvsize.view(1)[0] = drive;
        rootsize.view(1)[0] = root_size;
        return;
    }  def _Py_join_relfile(dirname: ptr[i32], relfile: ptr[i32]) -> ptr[i32] {
        maxlen = wcslen(dirname) + 1 + wcslen(relfile);
        bufsize = maxlen + 1;
        filename = ptr[i32](PyMem_RawMalloc(bufsize * 4));
        if not filename {
            return ptr[i32]();
        }
        if join_relfile(filename, bufsize, dirname, relfile) < 0 {
            PyMem_RawFree(ptr(filename));
            return ptr[i32]();
        }
        return filename;
    }  def _Py_add_relfile(dirname: ptr[i32], relfile: ptr[i32], bufsize: u64) -> i32 {
        return join_relfile(dirname, bufsize, dirname, relfile);
    }  def _Py_find_basename(filename: ptr[i32]) -> u64 {
        i = wcslen(filename);
        while i > 0 {
            if (filename + i64(i)).view(1)[0] == SEP {
                return i + 1;
            }
            i = i - 1;
        }
        return 0;
    }  def _Py_normpath_and_size(
        path: ptr[i32], size: i64, normsize: ptr[i64]
    ) -> ptr[i32] {
        (result, length) = normpath_and_size(path, size);
        normsize.view(1)[0] = length;
        return result;
    }  def _Py_normpath(path: ptr[i32], size: i64) -> ptr[i32] {
        (result, length) = normpath_and_size(path, size);
        return result;
    }  def _Py_wgetcwd(buf: ptr[i32], buflen: u64) -> ptr[i32] {
        return wgetcwd(buf, buflen);
    }  def _Py_dup(fd: i32) -> i32 {
        save = PyEval_SaveThread();
        new_fd = fcntl(fd, F_DUPFD_CLOEXEC, i32(0));
        err = jacpy_errno();
        PyEval_RestoreThread(save);
        if new_fd < 0 {
            jacpy_set_errno(err);
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        return new_fd;
    }  def _Py_get_blocking(fd: i32) -> i32 {
        flags = fcntl(fd, F_GETFL, i32(0));
        if flags < 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        if (flags & O_NONBLOCK) == 0 {
            return 1;
        }
        return 0;
    }  def _Py_set_blocking(fd: i32, blocking: i32) -> i32 {
        slots: own FileStack = FileStack();
        arg = ptr[i32](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
        arg.view(1)[0] = 0;
        if blocking == 0 {
            arg.view(1)[0] = 1;
        }
        if ioctl(fd, FIONBIO, arg) < 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            return -1;
        }
        return 0;
    }  def _Py_GetLocaleconvNumeric(
        lc: ptr[lconv],
        decimal_point: ptr[ptr[PyObject]],
        thousands_sep: ptr[ptr[PyObject]]
    ) -> i32 {
        change_locale = False;
        point = lc.view(1)[0].decimal_point;
        if strlen(point) > 1 or point.view(1)[0] > u8(127) {
            change_locale = True;
        }
        sep = lc.view(1)[0].thousands_sep;
        if strlen(sep) > 1 or sep.view(1)[0] > u8(127) {
            change_locale = True;
        }

        oldloc = ptr[u8]();
        loc = ptr[u8]();
        if change_locale {
            oldloc = setlocale(LC_CTYPE, ptr[u8]());
            if not oldloc {
                PyErr_SetString(PyExc_RuntimeWarning, ptr[u8]("failed to get LC_CTYPE locale"));
                return -1;
            }

            oldloc = _PyMem_Strdup(oldloc);
            if not oldloc {
                PyErr_NoMemory();
                return -1;
            }

            loc = setlocale(LC_NUMERIC, ptr[u8]());
            if loc and strcmp(loc, oldloc) == 0 {
                loc = ptr[u8]();
            }

            if loc {
                setlocale(LC_CTYPE, loc);
            }
        }

        res: i32 = -1;
        decimal_point.view(1)[0] = PyUnicode_DecodeLocale(
            ptr(lc.view(1)[0].decimal_point), ptr[u8]()
        );
        if decimal_point.view(1)[0] {
            thousands_sep.view(1)[0] = PyUnicode_DecodeLocale(
                ptr(lc.view(1)[0].thousands_sep), ptr[u8]()
            );
            if thousands_sep.view(1)[0] {
                res = 0;
            }
        }

        if loc {
            setlocale(LC_CTYPE, oldloc);
        }
        PyMem_Free(ptr(oldloc));
        return res;
    }  def _Py_closerange(first: i32, last: i32) {
        i = i64(first);
        if i < 0 {
            i = 0;
        }
        while i <= i64(last) {
            close(i32(i));
            i = i + 1;
        }
        return;
    }  def _Py_GetTicksPerSecond(ticks_per_second: ptr[i64]) -> i32 {
        value = sysconf(_SC_CLK_TCK);
        if value < 1 {
            return -1;
        }
        ticks_per_second.view(1)[0] = value;
        return 0;
    }  def _Py_IsValidFD(fd: i32) -> i32 {
        if fd < 0 {
            return 0;
        }
        if fcntl(fd, F_GETFD, i32(0)) >= 0 {
            return 1;
        }
        return 0;
    }
}

impl decode_error -> u64 {
    return u64.wrap(i64(-1));
}

impl incomplete_character -> u64 {
    return u64.wrap(i64(-2));
}

impl runtime_i32(offset: i64) -> ptr[i32] {
    return ptr[i32](ptr[u8](addressof(_PyRuntime)) + offset);
}

impl utf8_mode -> i32 {
    return runtime_i32(_PyRuntimeState_PRECONFIG_UTF8_MODE).view(1)[0];
}

impl force_ascii_slot -> ptr[i32] {
    return runtime_i32(_PyRuntimeState_FILEUTILS_FORCE_ASCII);
}

impl set_reason(reason: ptr[ptr[u8]], text: ptr[u8]) {
    if reason {
        reason.view(1)[0] = text;
    }
}

impl get_surrogateescape(errors: i32) -> tuple[i32, i32] {
    if errors == _Py_ERROR_STRICT {
        return (i32(0), i32(0));
    }
    if errors == _Py_ERROR_SURROGATEESCAPE {
        return (i32(0), i32(1));
    }
    return (i32(-1), i32(0));
}

impl is_valid_wide_char(ch: i32) -> bool {
    if (u32.wrap(ch) & u32(0xFFFFF800)) == u32(0xD800) {
        return False;
    }
    if ch > MAX_UNICODE {
        return False;
    }
    return True;
}

impl _Py_mbstowcs(dest: ptr[i32], src: ptr[u8], n: u64) -> u64 {
    count = mbstowcs(dest, src, n);
    if dest and count != decode_error() {
        i: u64 = 0;
        while i < count {
            if not is_valid_wide_char((dest + i64(i)).view(1)[0]) {
                return decode_error();
            }
            i = i + 1;
        }
    }
    return count;
}

impl _Py_mbrtowc(pwc: ptr[i32], src: ptr[u8], length: u64, pmbs: ptr) -> u64 {
    count = mbrtowc(pwc, src, length, pmbs);
    if count != 0 and count != decode_error() and count != incomplete_character() {
        if not is_valid_wide_char(pwc.view(1)[0]) {
            return decode_error();
        }
    }
    return count;
}

impl is_ascii_alias(encoding: ptr[u8]) -> bool {
    return strcmp(encoding, ptr[u8]("ascii")) == 0
        or strcmp(encoding, ptr[u8]("646")) == 0
        or strcmp(encoding, ptr[u8]("ansi_x3.4_1968")) == 0
        or strcmp(encoding, ptr[u8]("ansi_x3.4_1986")) == 0
        or strcmp(encoding, ptr[u8]("ansi_x3_4_1968")) == 0
        or strcmp(encoding, ptr[u8]("cp367")) == 0
        or strcmp(encoding, ptr[u8]("csascii")) == 0
        or strcmp(encoding, ptr[u8]("ibm367")) == 0
        or strcmp(encoding, ptr[u8]("iso646_us")) == 0
        or strcmp(encoding, ptr[u8]("iso_646.irv_1991")) == 0
        or strcmp(encoding, ptr[u8]("iso_ir_6")) == 0
        or strcmp(encoding, ptr[u8]("us")) == 0
        or strcmp(encoding, ptr[u8]("us_ascii")) == 0;
}

impl check_force_ascii -> i32 {
    loc = setlocale(LC_CTYPE, ptr[u8]());
    if not loc {
        return 1;
    }
    if strcmp(loc, ptr[u8]("C")) != 0 and strcmp(loc, ptr[u8]("POSIX")) != 0 {
        return 0;
    }

    codeset = nl_langinfo(CODESET);
    if not codeset or codeset.view(1)[0] == u8(0) {
        return 1;
    }

    slots: own FileStack = FileStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));

    encoding = base + STACK_SCRATCH;
    if _Py_normalize_encoding(codeset, encoding, u64(20)) == 0 {
        return 1;
    }
    if not is_ascii_alias(encoding) {
        return 0;
    }

    wch = ptr[i32](base + STACK_SLOT2);
    ch = base + STACK_SLOT2 + 8;
    i: i32 = 0x80;
    while i <= 0xff {
        ch.view(1)[0] = u8.wrap(i);
        res = _Py_mbstowcs(wch, ch, u64(1));
        if res != decode_error() {
            return 1;
        }
        i = i + 1;
    }

    return 0;
}

impl get_force_ascii -> i32 {
    slot = force_ascii_slot();
    if slot.view(1)[0] == -1 {
        slot.view(1)[0] = check_force_ascii();
    }
    return slot.view(1)[0];
}

impl encode_ascii(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    errors: i32
) -> i32 {
    (status, surrogateescape) = get_surrogateescape(errors);
    if status < 0 {
        return -3;
    }

    length = wcslen(text);

    result = ptr[u8]();
    if raw_malloc != 0 {
        result = ptr[u8](PyMem_RawMalloc(length + 1));
    } else {
        result = ptr[u8](PyMem_Malloc(length + 1));
    }
    if not result {
        return -1;
    }

    out = result;
    i: u64 = 0;
    while i < length {
        ch = (text + i64(i)).view(1)[0];
        if ch <= 0x7f {
            out.view(1)[0] = u8.wrap(ch);
            out = out + 1;
        } elif surrogateescape != 0 and 0xdc80 <= ch and ch <= 0xdcff {
            out.view(1)[0] = u8.wrap(ch - 0xdc00);
            out = out + 1;
        } else {
            if raw_malloc != 0 {
                PyMem_RawFree(ptr(result));
            } else {
                PyMem_Free(ptr(result));
            }
            if error_pos {
                error_pos.view(1)[0] = i;
            }
            set_reason(reason, ptr[u8]("encoding error"));
            return -2;
        }
        i = i + 1;
    }
    out.view(1)[0] = u8(0);
    out_str.view(1)[0] = result;
    return 0;
}

impl decode_ascii(
    arg: ptr[u8], wstr: ptr[ptr[i32]], wlen: ptr[u64], reason: ptr[ptr[u8]], errors: i32
) -> i32 {
    argsize = strlen(arg) + 1;

    (status, surrogateescape) = get_surrogateescape(errors);
    if status < 0 {
        return -3;
    }

    if argsize > u64(PY_SSIZE_T_MAX) // 4 {
        return -1;
    }
    res = ptr[i32](PyMem_RawMalloc(argsize * 4));
    if not res {
        return -1;
    }

    out = res;
    in_ = arg;
    while in_.view(1)[0] != u8(0) {
        ch = in_.view(1)[0];
        if ch < u8(128) {
            out.view(1)[0] = i32(ch);
            out = out + 1;
        } else {
            if surrogateescape == 0 {
                PyMem_RawFree(ptr(res));
                if wlen {
                    wlen.view(1)[0] = u64(int(in_) - int(arg));
                }
                set_reason(reason, ptr[u8]("decoding error"));
                return -2;
            }
            out.view(1)[0] = 0xdc00 + i32(ch);
            out = out + 1;
        }
        in_ = in_ + 1;
    }
    out.view(1)[0] = 0;

    if wlen {
        wlen.view(1)[0] = u64((int(out) - int(res)) // 4);
    }
    wstr.view(1)[0] = res;
    return 0;
}

impl decode_current_locale(
    arg: ptr[u8], wstr: ptr[ptr[i32]], wlen: ptr[u64], reason: ptr[ptr[u8]], errors: i32
) -> i32 {
    (status, surrogateescape) = get_surrogateescape(errors);
    if status < 0 {
        return -3;
    }

    argsize = _Py_mbstowcs(ptr[i32](), arg, u64(0));
    if argsize != decode_error() {
        if argsize > u64(PY_SSIZE_T_MAX) // 4 - 1 {
            return -1;
        }
        res = ptr[i32](PyMem_RawMalloc((argsize + 1) * 4));
        if not res {
            return -1;
        }

        count = _Py_mbstowcs(res, arg, argsize + 1);
        if count != decode_error() {
            wstr.view(1)[0] = res;
            if wlen {
                wlen.view(1)[0] = count;
            }
            return 0;
        }
        PyMem_RawFree(ptr(res));
    }

    argsize = strlen(arg) + 1;
    if argsize > u64(PY_SSIZE_T_MAX) // 4 {
        return -1;
    }
    res = ptr[i32](PyMem_RawMalloc(argsize * 4));
    if not res {
        return -1;
    }

    slots: own FileStack = FileStack();
    mbs = ptr[u8](jacpy_stack_address(&mut slots)) + STACK_MBSTATE;
    in_ = arg;
    out = res;
    memset(ptr(mbs), 0, MBSTATE_SIZE);
    while argsize != 0 {
        converted = _Py_mbrtowc(out, in_, argsize, ptr(mbs));
        if converted == 0 {
            break;
        }

        if converted == decode_error() or converted == incomplete_character() {
            if surrogateescape == 0 {
                PyMem_RawFree(ptr(res));
                if wlen {
                    wlen.view(1)[0] = u64(int(in_) - int(arg));
                }
                set_reason(reason, ptr[u8]("decoding error"));
                return -2;
            }

            out.view(1)[0] = 0xdc00 + i32(in_.view(1)[0]);
            out = out + 1;
            in_ = in_ + 1;
            argsize = argsize - 1;
            memset(ptr(mbs), 0, MBSTATE_SIZE);
            continue;
        }

        in_ = in_ + i64(converted);
        argsize = argsize - converted;
        out = out + 1;
    }
    if wlen {
        wlen.view(1)[0] = u64((int(out) - int(res)) // 4);
    }
    wstr.view(1)[0] = res;
    return 0;
}

impl decode_locale_ex(
    arg: ptr[u8],
    wstr: ptr[ptr[i32]],
    wlen: ptr[u64],
    reason: ptr[ptr[u8]],
    current_locale: i32,
    errors: i32
) -> i32 {
    if current_locale != 0 {
        return decode_current_locale(arg, wstr, wlen, reason, errors);
    }

    if _Py_FORCE_UTF8_FS_ENCODING != 0 {
        return _Py_DecodeUTF8Ex(arg, i64(strlen(arg)), wstr, wlen, reason, errors);
    }

    if utf8_mode() >= 1 {
        return _Py_DecodeUTF8Ex(arg, i64(strlen(arg)), wstr, wlen, reason, errors);
    }

    if get_force_ascii() != 0 {
        return decode_ascii(arg, wstr, wlen, reason, errors);
    }

    return decode_current_locale(arg, wstr, wlen, reason, errors);
}

impl decode_locale(arg: ptr[u8], wlen: ptr[u64]) -> ptr[i32] {
    slots: own FileStack = FileStack();
    wstr = ptr[ptr[i32]](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
    res = decode_locale_ex(
        arg, wstr, wlen, ptr[ptr[u8]](), 0, _Py_ERROR_SURROGATEESCAPE
    );
    if res != 0 {
        if wlen {
            wlen.view(1)[0] = u64.wrap(i64(res));
        }
        return ptr[i32]();
    }
    return wstr.view(1)[0];
}

impl encode_current_locale(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    errors: i32
) -> i32 {
    length = wcslen(text);
    result = ptr[u8]();
    bytes_ = ptr[u8]();
    size: u64 = 0;
    i: u64 = 0;

    (status, surrogateescape) = get_surrogateescape(errors);
    if status < 0 {
        return -3;
    }

    slots: own FileStack = FileStack();
    buf = ptr[i32](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);

    (buf + 1).view(1)[0] = 0;
    failed = False;
    while True {
        i = 0;
        while i < length {
            c = (text + i64(i)).view(1)[0];
            if c >= 0xdc80 and c <= 0xdcff {
                if surrogateescape == 0 {
                    failed = True;
                    break;
                }

                if bytes_ {
                    bytes_.view(1)[0] = u8.wrap(c - 0xdc00);
                    bytes_ = bytes_ + 1;
                    size = size - 1;
                } else {
                    size = size + 1;
                }
                i = i + 1;
                continue;
            }
            buf.view(1)[0] = c;
            converted: u64 = 0;
            if bytes_ {
                converted = wcstombs(bytes_, buf, size);
            } else {
                converted = wcstombs(ptr[u8](), buf, u64(0));
            }
            if converted == decode_error() {
                failed = True;
                break;
            }
            if bytes_ {
                bytes_ = bytes_ + i64(converted);
                size = size - converted;
            } else {
                size = size + converted;
            }
            i = i + 1;
        }
        if failed {
            break;
        }
        if result {
            bytes_.view(1)[0] = u8(0);
            break;
        }

        size = size + 1;
        if raw_malloc != 0 {
            result = ptr[u8](PyMem_RawMalloc(size));
        } else {
            result = ptr[u8](PyMem_Malloc(size));
        }
        if not result {
            return -1;
        }
        bytes_ = result;
    }
    if failed {
        if raw_malloc != 0 {
            PyMem_RawFree(ptr(result));
        } else {
            PyMem_Free(ptr(result));
        }
        if error_pos {
            error_pos.view(1)[0] = i;
        }
        set_reason(reason, ptr[u8]("encoding error"));
        return -2;
    }
    out_str.view(1)[0] = result;
    return 0;
}

impl encode_locale_ex(
    text: ptr[i32],
    out_str: ptr[ptr[u8]],
    error_pos: ptr[u64],
    reason: ptr[ptr[u8]],
    raw_malloc: i32,
    current_locale: i32,
    errors: i32
) -> i32 {
    if current_locale != 0 {
        return encode_current_locale(
            text, out_str, error_pos, reason, raw_malloc, errors
        );
    }

    if _Py_FORCE_UTF8_FS_ENCODING != 0 {
        return _Py_EncodeUTF8Ex(text, out_str, error_pos, reason, raw_malloc, errors);
    }

    if utf8_mode() >= 1 {
        return _Py_EncodeUTF8Ex(text, out_str, error_pos, reason, raw_malloc, errors);
    }

    if get_force_ascii() != 0 {
        return encode_ascii(text, out_str, error_pos, reason, raw_malloc, errors);
    }

    return encode_current_locale(text, out_str, error_pos, reason, raw_malloc, errors);
}

impl encode_locale(
    text: ptr[i32], error_pos: ptr[u64], raw_malloc: i32, current_locale: i32
) -> ptr[u8] {
    slots: own FileStack = FileStack();
    out_str = ptr[ptr[u8]](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
    res = encode_locale_ex(
        text,
        out_str,
        error_pos,
        ptr[ptr[u8]](),
        raw_malloc,
        current_locale,
        _Py_ERROR_SURROGATEESCAPE
    );
    if res != -2 and error_pos {
        error_pos.view(1)[0] = decode_error();
    }
    if res != 0 {
        return ptr[u8]();
    }
    return out_str.view(1)[0];
}

impl utf8_wide_name -> ptr[i32] {
    copy = ptr[i32](PyMem_RawMalloc(u64(6 * 4)));
    if copy {
        copy.view(6)[0] = 117;
        copy.view(6)[1] = 116;
        copy.view(6)[2] = 102;
        copy.view(6)[3] = 45;
        copy.view(6)[4] = 56;
        copy.view(6)[5] = 0;
    }
    return copy;
}

impl get_locale_encoding -> ptr[i32] {
    encoding = nl_langinfo(CODESET);
    if not encoding or encoding.view(1)[0] == u8(0) {
        return utf8_wide_name();
    }

    slots: own FileStack = FileStack();
    wstr = ptr[ptr[i32]](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
    res = decode_current_locale(
        encoding, wstr, ptr[u64](), ptr[ptr[u8]](), _Py_ERROR_SURROGATEESCAPE
    );
    if res < 0 {
        return ptr[i32]();
    }
    return wstr.view(1)[0];
}

impl get_inheritable(fd: i32, raise_: i32) -> i32 {
    flags = fcntl(fd, F_GETFD, i32(0));
    if flags == -1 {
        if raise_ != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
        }
        return -1;
    }
    if (flags & FD_CLOEXEC) == 0 {
        return 1;
    }
    return 0;
}

impl set_inheritable(
    fd: i32, inheritable: i32, raise_: i32, atomic_flag_works: ptr[i32]
) -> i32 {
    if atomic_flag_works and inheritable == 0 {
        works = int(atomic_flag_works);
        if __atomic_load_i32(works, 0) == -1 {
            is_inheritable = get_inheritable(fd, raise_);
            if is_inheritable == -1 {
                return -1;
            }
            works_value: i32 = 0;
            if is_inheritable == 0 {
                works_value = 1;
            }
            __atomic_store_i32(works, works_value, 0);
        }

        if __atomic_load_i32(works, 0) != 0 {
            return 0;
        }
    }

    ioctl_slot = int(addressof(ioctl_works));
    if raise_ != 0 and __atomic_load_i32(ioctl_slot, 0) != 0 {
        request = FIOCLEX;
        if inheritable != 0 {
            request = FIONCLEX;
        }
        err = ioctl(fd, request, ptr[u8]());
        if err == 0 {
            if __atomic_load_i32(ioctl_slot, 0) == -1 {
                __atomic_store_i32(ioctl_slot, 1, 0);
            }
            return 0;
        }

        code = jacpy_errno();

        if not (HAVE_O_PATH != 0 and code == i64(EBADF)) {
            if code != i64(ENOTTY) and code != i64(EACCES) {
                if raise_ != 0 {
                    PyErr_SetFromErrno(PyExc_OSError);
                }
                return -1;
            }

            __atomic_store_i32(ioctl_slot, 0, 0);
        }
    }

    flags = fcntl(fd, F_GETFD, i32(0));
    if flags < 0 {
        if raise_ != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
        }
        return -1;
    }

    new_flags: i32 = 0;
    if inheritable != 0 {
        new_flags = flags & ~FD_CLOEXEC;
    } else {
        new_flags = flags | FD_CLOEXEC;
    }

    if new_flags == flags {
        return 0;
    }

    res = fcntl(fd, F_SETFD, new_flags);
    if res < 0 {
        if raise_ != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
        }
        return -1;
    }
    return 0;
}

impl make_non_inheritable(fd: i32) -> i32 {
    return set_inheritable(fd, 0, 0, ptr[i32]());
}

impl open_impl(pathname: ptr[u8], flags: i32, gil_held: i32) -> i32 {
    fd: i32 = -1;
    atomic_flag_works = ptr[i32](addressof(_Py_open_cloexec_works));
    flags = flags | O_CLOEXEC;

    if gil_held != 0 {
        pathname_obj = PyUnicode_DecodeFSDefault(pathname);
        if not pathname_obj {
            return -1;
        }
        if PySys_Audit("open", "OOi", pathname_obj, Py_None, flags) < 0 {
            object_decref(pathname_obj);
            return -1;
        }

        async_err: i32 = 0;
        err: i64 = 0;
        while True {
            save = PyEval_SaveThread();
            fd = open(pathname, flags);
            err = jacpy_errno();
            PyEval_RestoreThread(save);
            if fd >= 0 or err != i64(EINTR) {
                break;
            }
            async_err = PyErr_CheckSignals();
            if async_err != 0 {
                break;
            }
        }
        if async_err != 0 {
            object_decref(pathname_obj);
            return -1;
        }
        if fd < 0 {
            jacpy_set_errno(err);
            PyErr_SetFromErrnoWithFilenameObjects(PyExc_OSError, pathname_obj, NULL);
            object_decref(pathname_obj);
            return -1;
        }
        object_decref(pathname_obj);
    } else {
        fd = open(pathname, flags);
        if fd < 0 {
            return -1;
        }
    }

    if set_inheritable(fd, 0, gil_held, atomic_flag_works) < 0 {
        close(fd);
        return -1;
    }
    return fd;
}

impl write_impl(fd: i32, buf: ptr, count: u64, gil_held: i32) -> i64 {
    n: i64 = 0;
    err: i64 = 0;
    async_err: i32 = 0;

    if count > u64(PY_SSIZE_T_MAX) {
        count = u64(PY_SSIZE_T_MAX);
    }

    if gil_held != 0 {
        while True {
            save = PyEval_SaveThread();
            jacpy_set_errno(0);
            n = write(fd, buf, count);

            err = jacpy_errno();
            PyEval_RestoreThread(save);
            if n >= 0 or err != i64(EINTR) {
                break;
            }
            async_err = PyErr_CheckSignals();
            if async_err != 0 {
                break;
            }
        }
    } else {
        while True {
            jacpy_set_errno(0);
            n = write(fd, buf, count);
            err = jacpy_errno();
            if n >= 0 or err != i64(EINTR) {
                break;
            }
        }
    }

    if async_err != 0 {
        jacpy_set_errno(err);
        return -1;
    }
    if n < 0 {
        if gil_held != 0 {
            jacpy_set_errno(err);
            PyErr_SetFromErrno(PyExc_OSError);
        }
        jacpy_set_errno(err);
        return -1;
    }
    return n;
}

impl is_abs(path: ptr[i32]) -> bool {
    return path.view(1)[0] == SEP;
}

impl skiproot(path: ptr[i32]) -> tuple[i64, i64] {
    if path.view(1)[0] != SEP {
        return (i64(0), i64(0));
    }
    if (path + 1).view(1)[0] != SEP or (path + 2).view(1)[0] == SEP {
        return (i64(0), i64(1));
    }

    return (i64(0), i64(2));
}

impl join_relfile(
    buffer: ptr[i32], bufsize: u64, dirname: ptr[i32], relfile: ptr[i32]
) -> i32 {
    dirlen = wcslen(dirname);
    rellen = wcslen(relfile);
    maxlen = bufsize - 1;
    if maxlen > u64(MAXPATHLEN) or dirlen >= maxlen or rellen >= maxlen - dirlen {
        return -1;
    }
    if dirlen == 0 {
        wcscpy(buffer, relfile);
    } else {
        if dirname != buffer {
            wcscpy(buffer, dirname);
        }
        relstart = dirlen;
        if dirlen > 1 and (dirname + i64(dirlen - 1)).view(1)[0] != SEP {
            (buffer + i64(dirlen)).view(1)[0] = SEP;
            relstart = relstart + 1;
        }
        wcscpy(buffer + i64(relstart), relfile);
    }
    return 0;
}

impl normpath_and_size(path: ptr[i32], size: i64) -> tuple[ptr[i32], i64] {
    if (size < 0 and path.view(1)[0] == 0) or size == 0 {
        return (path, i64(0));
    }
    has_end = size >= 0;

    p1: i64 = 0;
    p2: i64 = 0;
    min_p2: i64 = 0;
    last_c: i32 = 0;

    (drvsize, rootsize) = skiproot(path);
    if drvsize != 0 or rootsize != 0 {
        p1 = drvsize + rootsize;
        p2 = p1;
        min_p2 = p2 - 1;
        last_c = (path + min_p2).view(1)[0];
    }
    if (path + p1).view(1)[0] == DOT
        and normpath_sep_or_end(path, p1 + 1, has_end, size) {
        p1 = p1 + 1;
        last_c = (path + p1).view(1)[0];
        while (path + p1).view(1)[0] == SEP {
            p1 = p1 + 1;
        }
    }

    while not normpath_is_end(path, p1, has_end, size) {
        c = (path + p1).view(1)[0];
        if last_c == SEP {
            if c == DOT {
                sep_at_1 = normpath_sep_or_end(path, p1 + 1, has_end, size);
                sep_at_2 = not sep_at_1
                    and normpath_sep_or_end(path, p1 + 2, has_end, size);
                if sep_at_2 and (path + p1 + 1).view(1)[0] == DOT {
                    p3 = p2;
                    while p3 != min_p2 {
                        p3 = p3 - 1;
                        if (path + p3).view(1)[0] != SEP {
                            break;
                        }
                    }
                    while p3 != min_p2 and (path + p3 - 1).view(1)[0] != SEP {
                        p3 = p3 - 1;
                    }
                    if p2 == min_p2
                        or (
                            (path + p3).view(1)[0] == DOT
                            and (path + p3 + 1).view(1)[0] == DOT
                            and (path + p3 + 2).view(1)[0] == SEP
                        ) {
                        (path + p2).view(1)[0] = DOT;
                        (path + p2 + 1).view(1)[0] = DOT;
                        p2 = p2 + 2;
                        last_c = DOT;
                    } elif (path + p3).view(1)[0] == SEP {
                        p2 = p3 + 1;
                    } else {
                        p2 = p3;
                    }
                    p1 = p1 + 1;
                } elif not sep_at_1 {
                    (path + p2).view(1)[0] = c;
                    p2 = p2 + 1;
                    last_c = c;
                }
            } elif c != SEP {
                (path + p2).view(1)[0] = c;
                p2 = p2 + 1;
                last_c = c;
            }
        } else {
            (path + p2).view(1)[0] = c;
            p2 = p2 + 1;
            last_c = c;
        }
        p1 = p1 + 1;
    }
    (path + p2).view(1)[0] = 0;
    if p2 != min_p2 {
        while True {
            p2 = p2 - 1;
            if p2 == min_p2 or (path + p2).view(1)[0] != SEP {
                break;
            }
            (path + p2).view(1)[0] = 0;
        }
    } else {
        p2 = p2 - 1;
    }
    return (path, p2 + 1);
}

impl normpath_is_end(path: ptr[i32], index: i64, has_end: bool, size: i64) -> bool {
    if has_end {
        return index == size;
    }
    return (path + index).view(1)[0] == 0;
}

impl normpath_sep_or_end(path: ptr[i32], index: i64, has_end: bool, size: i64) -> bool {
    return (path + index).view(1)[0] == SEP
        or normpath_is_end(path, index, has_end, size);
}

impl decode_into(cbuf: ptr[u8], buf: ptr[i32], buflen: u64) -> i64 {
    slots: own FileStack = FileStack();
    length = ptr[u64](ptr[u8](jacpy_stack_address(&mut slots)) + STACK_SCRATCH);
    wbuf = decode_locale(cbuf, length);
    if not wbuf {
        return -1;
    }

    if buflen <= length.view(1)[0] {
        PyMem_RawFree(ptr(wbuf));
        return -1;
    }
    wcsncpy(buf, wbuf, buflen);
    PyMem_RawFree(ptr(wbuf));
    return i64(length.view(1)[0]);
}

impl wgetcwd(buf: ptr[i32], buflen: u64) -> ptr[i32] {
    fname = ptr[u8](PyMem_RawMalloc(u64(MAXPATHLEN)));
    if not fname {
        return ptr[i32]();
    }
    if not getcwd(fname, u64(MAXPATHLEN)) {
        PyMem_RawFree(ptr(fname));
        return ptr[i32]();
    }
    res = decode_into(fname, buf, buflen);
    PyMem_RawFree(ptr(fname));
    if res < 0 {
        return ptr[i32]();
    }
    return buf;
}

impl cwd_copy -> tuple[i32, ptr[i32]] {
    cwd = ptr[i32](PyMem_RawMalloc(u64(MAXPATHLEN + 1) * 4));
    if not cwd {
        return (i32(0), ptr[i32]());
    }
    (cwd + MAXPATHLEN).view(1)[0] = 0;
    if not wgetcwd(cwd, u64(MAXPATHLEN)) {
        PyMem_RawFree(ptr(cwd));
        return (i32(-1), ptr[i32]());
    }
    return (i32(0), cwd);
}

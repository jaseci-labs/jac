def _uchar(c: int) -> int {
    return c & 0xFF;
}

def c_strcmp(a: str, b: str) -> int {
    while (
        _uchar(ord(a[0]) if a else 0)
        and (_uchar(ord(a[0]) if a else 0) == _uchar(ord(b[0]) if b else 0))
    ) {
        a = a[1:];
        b = b[1:];
    }

    return _uchar(ord(a[0]) if a else 0) - _uchar(ord(b[0]) if b else 0);
}

def c_strcpy(dst: list[int], src: str) {
    i: int = 0;
    while ((ord(src[i]) if i < len(src) else 0) != 0) {
        dst[i] = ord(src[i]);
        i += 1;
    }

    dst[i] = 0;
}

def c_strcat(dst: list[int], src: str) {
    i: int = 0;
    while (i < len(dst) and dst[i] != 0) {
        i += 1;
    }

    j: int = 0;
    while ((ord(src[j]) if j < len(src) else 0) != 0) {
        dst[(i + j)] = ord(src[j]);
        j += 1;
    }

    dst[(i + j)] = 0;
}


def _buf_to_str(buf: list[int]) -> str {
    s: str = "";
    i: int = 0;
    while (i < len(buf) and buf[i] != 0) {
        s = s + chr(buf[i]);
        i += 1;
    }

    return s;
}


glob initialized: int = 0,
     buildinfo: list[int] = [0] * 128;

def Py_GetBuildInfo -> str {
    ;

    if initialized {
        return _buf_to_str(buildinfo);
    }

    initialized = 1;
    revision: str = _Py_gitversion();
    gitid: str = _Py_gitidentifier();
    if ((ord(gitid[0]) if gitid else 0) == 0) {
        gitid = "main";
    }

    buildinfo[0] = 0;
    c_strcpy(buildinfo, gitid);
    if ((ord(revision[0]) if revision else 0) != 0) {
        c_strcat(buildinfo, ":");
        c_strcat(buildinfo, revision);
    }

    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, "Jan 01 1970");
    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, "00:00:00");
    return _buf_to_str(buildinfo);
}

def _Py_gitversion -> str {
    return "";
}

def _Py_gitidentifier -> str {
    gittag: str = str();
    gitid: str = str();
    gittag = "";
    if (
        ((ord(gittag[0]) if gittag else 0) != 0)
        and (c_strcmp(gittag, "undefined") != 0)
    ) {
        gitid = gittag;
    } else {
        gitid = "";
    }
    return gitid;
}

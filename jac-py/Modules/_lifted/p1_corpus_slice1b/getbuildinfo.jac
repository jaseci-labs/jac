# c2jac: Tier-B clean (no best-effort fidelity sites).

def c_strcmp(a: str, b: str) -> int {
    while (
        (ord(a[0]) if a else 0) and ((ord(a[0]) if a else 0) == (ord(b[0]) if b else 0))
    ) {
        a = a[1:];
        b = b[1:];
    }

    return (((ord(a[0]) if a else 0) & 255) - ((ord(b[0]) if b else 0) & 255));
}

def c_strcpy(dst: str, src: str) {
    i: int = 0;
    while (src[i] != 0) {
        dst[i] = src[i];
        i += 1;
    }

    dst[i] = 0;
}

def c_strcat(dst: str, src: str) {
    i: int = 0;
    while (dst[i] != 0) {
        i += 1;
    }

    j: int = 0;
    while (src[j] != 0) {
        dst[(i + j)] = src[j];
        j += 1;
    }

    dst[(i + j)] = 0;
}


glob initialized: int = 0,
     buildinfo: list[int] = [0] * 128;

def Py_GetBuildInfo -> str {
    ;

    if initialized {
        return buildinfo;
    }

    initialized = 1;
    revision: str = _Py_gitversion();
    gitid: str = _Py_gitidentifier();
    if (gitid[0] == 0) {
        gitid = "main";
    }

    buildinfo[0] = 0;
    c_strcpy(buildinfo, gitid);
    if (revision[0] != 0) {
        c_strcat(buildinfo, ":");
        c_strcat(buildinfo, revision);
    }

    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, "Jan 01 1970");
    c_strcat(buildinfo, ", ");
    c_strcat(buildinfo, "00:00:00");
    return buildinfo;
}

def _Py_gitversion -> str {
    return "";
}

def _Py_gitidentifier -> str {
    gittag: str = str();
    gitid: str = str();
    gittag = "";
    if ((gittag[0] != 0) and (c_strcmp(gittag, "undefined") != 0)) {
        gitid = gittag;
    } else {
        gitid = "";
    }
    return gitid;
}

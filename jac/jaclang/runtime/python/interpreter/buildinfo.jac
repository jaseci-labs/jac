import from c {
    obj BuildText {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0),
            w20: u64 = u64(0),
            w21: u64 = u64(0),
            w22: u64 = u64(0),
            w23: u64 = u64(0),
            w24: u64 = u64(0),
            w25: u64 = u64(0),
            w26: u64 = u64(0),
            w27: u64 = u64(0),
            w28: u64 = u64(0),
            w29: u64 = u64(0),
            w30: u64 = u64(0),
            w31: u64 = u64(0),
            w32: u64 = u64(0),
            w33: u64 = u64(0),
            w34: u64 = u64(0),
            w35: u64 = u64(0),
            w36: u64 = u64(0),
            w37: u64 = u64(0);
    }  def PyOS_snprintf(buf: ptr[u8], size: u64, format: ptr[u8], *args: any) -> i32;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  glob Py_Version: u64 = PY_VERSION_HEX; glob:priv version_initialized:
             i32 = 0,
         buildinfo_initialized: i32 = 0,
         compiler_initialized: i32 = 0,
         python_version_initialized: i32 = 0,
         version_text: BuildText = BuildText(),
         buildinfo_text: BuildText = BuildText(),
         compiler_text: BuildText = BuildText(),
         python_version_text: BuildText = BuildText(); def _Py_InitVersion {
        init_version();
    }  def Py_GetVersion -> ptr[u8] {
        init_version();
        return ptr[u8](addressof(version_text));
    }  def Py_GetPlatform -> ptr[u8] {
        if MI_PLATFORM_LINUX != 0 {
            return ptr[u8]("linux");
        }
        return ptr[u8]("darwin");
    }  def Py_GetCompiler -> ptr[u8] {
        return compiler();
    }  def Py_GetCopyright -> ptr[u8] {
        return ptr[u8](
            "Copyright (c) 2001 Python Software Foundation.\nAll Rights Reserved.\n\nCopyright (c) 2000 BeOpen.com.\nAll Rights Reserved.\n\nCopyright (c) 1995-2001 Corporation for National Research Initiatives.\nAll Rights Reserved.\n\nCopyright (c) 1991-1995 Stichting Mathematisch Centrum, Amsterdam.\nAll Rights Reserved."
        );
    }  def Py_GetBuildInfo -> ptr[u8] {
        return build_info();
    }  def _Py_gitversion -> ptr[u8] {
        return git_version();
    }  def _Py_gitidentifier -> ptr[u8] {
        return git_identifier();
    }
}

glob:priv VERSION_SIZE: Final[u64] = 300,
     BUILDINFO_SIZE: Final[u64] = 52,
     COMPILER_SIZE: Final[u64] = 64,
     PY_VERSION_SIZE: Final[u64] = 32,
     PY_RELEASE_LEVEL_ALPHA: Final[i32] = 10,
     PY_RELEASE_LEVEL_BETA: Final[i32] = 11,
     PY_RELEASE_LEVEL_GAMMA: Final[i32] = 12;

def:priv git_version -> ptr[u8];

def:priv git_identifier -> ptr[u8];

def:priv python_version -> ptr[u8];

def:priv compiler -> ptr[u8];

def:priv build_info -> ptr[u8];

def:priv init_version;

impl git_version -> ptr[u8] {
    return ptr[u8]("");
}

impl git_identifier -> ptr[u8] {
    gittag = ptr[u8]("");
    if gittag.view(1)[0] != u8(0) and strcmp(gittag, ptr[u8]("undefined")) != 0 {
        return gittag;
    }
    return ptr[u8]("");
}

impl python_version -> ptr[u8] {
    text = ptr[u8](addressof(python_version_text));
    flag = addressof(python_version_initialized);
    if flag.view(1)[0] != 0 {
        return text;
    }
    flag.view(1)[0] = 1;
    if PY_RELEASE_LEVEL == PY_RELEASE_LEVEL_ALPHA {
        PyOS_snprintf(
            text,
            PY_VERSION_SIZE,
            ptr[u8]("%d.%d.%da%d"),
            PY_MAJOR_VERSION,
            PY_MINOR_VERSION,
            PY_MICRO_VERSION,
            PY_RELEASE_SERIAL
        );
    } elif PY_RELEASE_LEVEL == PY_RELEASE_LEVEL_BETA {
        PyOS_snprintf(
            text,
            PY_VERSION_SIZE,
            ptr[u8]("%d.%d.%db%d"),
            PY_MAJOR_VERSION,
            PY_MINOR_VERSION,
            PY_MICRO_VERSION,
            PY_RELEASE_SERIAL
        );
    } elif PY_RELEASE_LEVEL == PY_RELEASE_LEVEL_GAMMA {
        PyOS_snprintf(
            text,
            PY_VERSION_SIZE,
            ptr[u8]("%d.%d.%drc%d"),
            PY_MAJOR_VERSION,
            PY_MINOR_VERSION,
            PY_MICRO_VERSION,
            PY_RELEASE_SERIAL
        );
    } else {
        PyOS_snprintf(
            text,
            PY_VERSION_SIZE,
            ptr[u8]("%d.%d.%d"),
            PY_MAJOR_VERSION,
            PY_MINOR_VERSION,
            PY_MICRO_VERSION
        );
    }
    return text;
}

impl compiler -> ptr[u8] {
    text = ptr[u8](addressof(compiler_text));
    flag = addressof(compiler_initialized);
    if flag.view(1)[0] != 0 {
        return text;
    }
    flag.view(1)[0] = 1;
    PyOS_snprintf(
        text,
        COMPILER_SIZE,
        ptr[u8]("[Clang %d.%d.%d ]"),
        JAC_CLANG_MAJOR,
        JAC_CLANG_MINOR,
        JAC_CLANG_PATCHLEVEL
    );
    return text;
}

impl build_info -> ptr[u8] {
    text = ptr[u8](addressof(buildinfo_text));
    flag = addressof(buildinfo_initialized);
    if flag.view(1)[0] != 0 {
        return text;
    }
    flag.view(1)[0] = 1;
    revision = git_version();
    sep = ptr[u8]("");
    if revision.view(1)[0] != u8(0) {
        sep = ptr[u8](":");
    }
    gitid = git_identifier();
    if gitid.view(1)[0] == u8(0) {
        gitid = ptr[u8]("main");
    }
    PyOS_snprintf(
        text,
        BUILDINFO_SIZE,
        ptr[u8]("%s%s%s, %.20s, %.9s"),
        gitid,
        sep,
        revision,
        ptr[u8]("Jan  1 1970"),
        ptr[u8]("00:00:00")
    );
    return text;
}

impl init_version {
    flag = addressof(version_initialized);
    if flag.view(1)[0] != 0 {
        return;
    }
    flag.view(1)[0] = 1;
    PyOS_snprintf(
        ptr[u8](addressof(version_text)),
        VERSION_SIZE,
        ptr[u8]("%.80s (%.80s) %.80s"),
        python_version(),
        build_info(),
        compiler()
    );
}

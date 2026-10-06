"""macOS has no <libintl.h> in its C library and follows POSIX nl_langinfo.

CPython's configure leaves HAVE_LIBINTL_H undefined there, so _locale has no
gettext functions; the binding leaves them out and these are never called.
"""

glob HAS_LIBINTL: bool = False,
     GLIBC: bool = False;

def gettext(msgid: str) -> ptr[u8] {
    return ptr[u8]();
}

def dgettext(domainname: ptr[u8], msgid: str) -> ptr[u8] {
    return ptr[u8]();
}

def dcgettext(domainname: ptr[u8], msgid: str, category: i32) -> ptr[u8] {
    return ptr[u8]();
}

def textdomain(domainname: ptr[u8]) -> ptr[u8] {
    return ptr[u8]();
}

def bindtextdomain(domainname: str, dirname: ptr[u8]) -> ptr[u8] {
    return ptr[u8]();
}

def bind_textdomain_codeset(domainname: str, codeset: ptr[u8]) -> ptr[u8] {
    return ptr[u8]();
}

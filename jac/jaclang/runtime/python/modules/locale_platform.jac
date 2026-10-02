"""Message catalogs (<libintl.h>) and nl_langinfo conventions as glibc provides them.

glibc's libc has the gettext functions, and its nl_langinfo(ALT_DIGITS) and
nl_langinfo(ERA) return NUL-separated lists rather than POSIX's
semicolon-separated ones.
"""

import from c {
    def gettext(msgid: str) -> ptr[u8];  def dgettext(
        domainname: ptr[u8], msgid: str
    ) -> ptr[u8];  def dcgettext(
        domainname: ptr[u8], msgid: str, category: i32
    ) -> ptr[u8];  def textdomain(domainname: ptr[u8]) -> ptr[u8];  def bindtextdomain(
        domainname: str, dirname: ptr[u8]
    ) -> ptr[u8];  def bind_textdomain_codeset(
        domainname: str, codeset: ptr[u8]
    ) -> ptr[u8];
}

glob HAS_LIBINTL: bool = True,
     GLIBC: bool = True;

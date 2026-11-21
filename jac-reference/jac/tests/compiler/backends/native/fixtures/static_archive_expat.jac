# Multi-member gate fixture (#6978 Phase 0.1a): XML_ExpatVersion returns expat's
# version string (a `const char *`). Selecting it from libexpat.a pulls several
# members that reference each other, exercising cross-member symbol resolution
# and GOT references to libc -- a step up from the single leaf member.
import from expat { def XML_ExpatVersion() -> str;  }

with entry {
    print(XML_ExpatVersion());
}

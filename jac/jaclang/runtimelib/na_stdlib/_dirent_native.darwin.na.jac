import from c { def strdup(s: int) -> str;  }

def:pub dirent_name(ent: int) -> str {
    return strdup(ent + 21);
}

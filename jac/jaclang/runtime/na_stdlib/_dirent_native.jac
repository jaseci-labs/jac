import from c { def strdup(s: int) -> str;  }
import from c { def __jac_dirent_name(ent: int) -> int;  }
import from c { def __jac_dirent_type(ent: int) -> int;  }

def:pub dirent_name(ent: int) -> str;

def:pub dirent_type(ent: int) -> int;

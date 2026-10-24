import from c { def __jac_opendir(path: str) -> int;  }
import from c { def __jac_readdir(dirp: int) -> int;  }
import from c { def __jac_closedir(dirp: int) -> i32;  }

def:pub directory_names(path: str) -> list[str];

def:pub try_directory_names(path: str) -> list[str];

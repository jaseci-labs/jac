import from c { def __jac_opendir(path: str) -> int;  }
import from c { def __jac_readdir(dirp: int) -> int;  }
import from c { def __jac_closedir(dirp: int) -> i32;  }

def:pub directory_names(path: str) -> list[str];

def:pub try_directory_names(path: str) -> list[str];

glob DIRENT_UNKNOWN: int = 0,
     DIRENT_DIRECTORY: int = 4,
     DIRENT_LINK: int = 10;

obj:pub DirectoryEntry {
    has name: str,
        kind: int;
}

def:pub directory_entries(path: str) -> list[DirectoryEntry];

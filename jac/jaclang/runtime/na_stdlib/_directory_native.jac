import from c { def opendir(path: str) -> int;  }
import from c { def readdir(dirp: int) -> int;  }
import from c { def closedir(dirp: int) -> i32;  }
import from _dirent_native { dirent_name }
import from _errno_native { clear_errno, last_errno, raise_os_error }

def:pub directory_names(path: str) -> list[str] {
    directory = opendir(path);
    if directory == 0 {
        raise_os_error("opendir", path, last_errno());
    }
    names: list[str] = [];
    try {
        while True {
            clear_errno();
            ent = readdir(directory);
            if ent == 0 {
                error = last_errno();
                if error != 0 {
                    raise_os_error("readdir", path, error);
                }
                break;
            }
            name = dirent_name(ent);
            if name != "." and name != ".." {
                names.append(name);
            }
        }
    } finally {
        closedir(directory);
    }
    return names;
}

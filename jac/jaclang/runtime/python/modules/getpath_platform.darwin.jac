import from jaclang.runtime.python.cpython_api { PyMem_RawFree, PyMem_RawMalloc }

import from c { def _NSGetExecutablePath(buf: ptr[u8], bufsize: &mut u32) -> i32;  }

def getpath_os_name -> ptr[u8];

def getpath_executable_path -> tuple[i32, ptr[u8]];

impl getpath_os_name -> ptr[u8] {
    return ptr[u8]("darwin");
}

impl getpath_executable_path -> tuple[i32, ptr[u8]] {
    path_len: u32 = 256;
    while path_len != 0 {
        path = ptr[u8](PyMem_RawMalloc(u64(path_len) + 1));
        if not path {
            return (i32(-1), ptr[u8]());
        }
        if _NSGetExecutablePath(path, &mut path_len) != 0 {
            PyMem_RawFree(ptr(path));
            continue;
        }

        if path.view(1)[0] == u8(47) {
            return (i32(1), path);
        }

        PyMem_RawFree(ptr(path));
        break;
    }
    return (i32(0), ptr[u8]());
}

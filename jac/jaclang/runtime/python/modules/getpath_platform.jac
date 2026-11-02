def getpath_os_name -> ptr[u8];

def getpath_executable_path -> tuple[i32, ptr[u8]];

impl getpath_os_name -> ptr[u8] {
    return ptr[u8]("posix");
}

impl getpath_executable_path -> tuple[i32, ptr[u8]] {
    return (i32(0), ptr[u8]());
}

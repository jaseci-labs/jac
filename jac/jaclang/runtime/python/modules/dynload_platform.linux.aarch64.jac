import from c {
    glob _PyImport_DynLoadFiletab: list[ptr[u8]] = [
             ptr[u8](".cpython-314-aarch64-linux-gnu.so"),
             ptr[u8](".abi3.so"),
             ptr[u8](".so"),
             ptr[u8]()
         ];
}

---
description: The native Windows modules, as CPython's - msvcrt, the C runtime's console and descriptors, and winreg, the registry - and the predefined keys winreg leaves out.
keywords: windows modules, msvcrt, msvcrt.getch, msvcrt.getwch, msvcrt.kbhit, msvcrt.putch, msvcrt.locking, msvcrt.setmode, msvcrt.get_osfhandle, msvcrt.open_osfhandle, winreg, winreg.OpenKey, winreg.OpenKeyEx, winreg.CreateKey, winreg.CreateKeyEx, winreg.QueryValueEx, winreg.SetValueEx, winreg.EnumKey, winreg.EnumValue, winreg.DeleteKey, winreg.DeleteValue, winreg.HKEYType, winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE, winreg.REG_SZ, winreg.REG_DWORD
---
# The Windows modules: msvcrt and winreg

`msvcrt` and `winreg` are CPython's Windows-only modules: the Universal C Runtime's console input
and output, descriptor locks and modes, and the registry, for a program built for Windows
(`--target windows-x86_64`). They are native (see [The library](index.md), `jac docs library`), and reach Windows only through
jac's platform layer: each call is the C runtime's or advapi32's, and a failure raises the
`OSError` of its error, with `winerror` set for the registry's.

<!-- example: not checked: it runs on Windows only -->
```jac
import msvcrt;
import winreg;

glob HKEY_CURRENT_USER: int = -2147483647;

with entry {
    key = winreg.CreateKey(HKEY_CURRENT_USER, "Software\\JacDocs");
    winreg.SetValueEx(key, "count", 0, winreg.REG_DWORD, 3);
    winreg.SetValueEx(key, "name", 0, winreg.REG_SZ, "demo");
    print(winreg.QueryValueEx(key, "count"), winreg.QueryValueEx(key, "name"));
    print([winreg.EnumValue(key, i)[0] for i in range(winreg.QueryInfoKey(key)[1])]);
    winreg.CloseKey(key);
    winreg.DeleteKey(HKEY_CURRENT_USER, "Software\\JacDocs");
    print("press a key");
    print(msvcrt.getwch());
}
```

## msvcrt

`getch`, `getwch`, `getche`, `getwche`, `kbhit`, `putch`, `putwch`, `ungetch`, `ungetwch`
(console input and output without a newline), `locking` with the `LK_*` modes, `setmode`,
`open_osfhandle`, `get_osfhandle`, `heapmin`, `SetErrorMode`, `GetErrorMode` and the `SEM_*`
flags. `CRT_ASSEMBLY_VERSION` is left out (E5142): a jac program links the Universal C
Runtime alone, and no Visual C++ runtime version.

## winreg

Every function of CPython's `winreg`: `OpenKey`, `OpenKeyEx`, `CreateKey`, `CreateKeyEx`,
`DeleteKey`, `DeleteKeyEx`, `DeleteTree`, `DeleteValue`, `EnumKey`, `EnumValue`, `QueryValue`,
`QueryValueEx`, `SetValue`, `SetValueEx`, `QueryInfoKey`, `FlushKey`, `LoadKey`, `SaveKey`,
`ConnectRegistry`, `ExpandEnvironmentStrings`, the reflection functions, `HKEYType` (a context
manager, closed with `Close` or `Detach`), and the `KEY_*`, `REG_*` constants. A value is
converted to and from its registry type as CPython converts it: `REG_SZ` and `REG_EXPAND_SZ` to
`str`, `REG_DWORD` and `REG_QWORD` to `int`, `REG_MULTI_SZ` to `list[str]`, `REG_BINARY` to
`bytes`.

**The predefined keys are left out** (E5142): CPython gives `HKEY_CLASSES_ROOT`,
`HKEY_CURRENT_USER`, `HKEY_LOCAL_MACHINE`, `HKEY_USERS`, `HKEY_PERFORMANCE_DATA`,
`HKEY_CURRENT_CONFIG` and `HKEY_DYN_DATA` as unsigned pointers, 18446744071562067968 and up,
wider than a 64-bit int. Every function takes the handle as the signed int it is: `-2147483648`
for `HKEY_CLASSES_ROOT`, `-2147483647` for `HKEY_CURRENT_USER`, `-2147483646` for
`HKEY_LOCAL_MACHINE`, `-2147483645` for `HKEY_USERS`, and so on up the list. The example above
declares the one it uses.

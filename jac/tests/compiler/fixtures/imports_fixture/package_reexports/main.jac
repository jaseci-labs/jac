import from mylib { CORE_VALUE, core_function, UTIL_VALUE, PACKAGE_VERSION }

with entry {
    print(f"Package module import - CORE_VALUE: {CORE_VALUE}");
    print(f"Package module import - core_function(): {core_function()}");
    print(f"Package module import - UTIL_VALUE: {UTIL_VALUE}");
}

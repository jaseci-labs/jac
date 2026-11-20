import from mypackage { PACKAGE_NAME, greet, Helper }

with entry {
    print(f"Init basic - PACKAGE_NAME: {PACKAGE_NAME}");
    print(f"Init basic - greet('World'): {greet('World')}");
    helper = Helper();
    print(f"Init basic - Helper.get_info(): {helper.get_info()}");
}

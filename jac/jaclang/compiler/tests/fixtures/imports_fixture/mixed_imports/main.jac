import from library.base { BASE_ID }
import from library.extended { EXTENDED_ID, get_extended_id }
import library.base as lib_base;

with entry {
    print(f"Mixed - BASE_ID (from import): {BASE_ID}");
    print(f"Mixed - EXTENDED_ID: {EXTENDED_ID}");
    print(f"Mixed - get_extended_id(): {get_extended_id()}");
    print(f"Mixed - lib_base.BASE_ID (alias): {lib_base.BASE_ID}");
}

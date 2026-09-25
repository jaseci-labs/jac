def:pub typename(v: any) -> str {
    if v is None {
        return "NoneType";
    } elif isinstance(v, bytearray) {
        return "bytearray";
    } elif isinstance(v, bytes) {
        return "bytes";
    } elif isinstance(v, str) {
        return "str";
    } elif isinstance(v, float) {
        return "float";
    } elif isinstance(v, bool) {
        return "bool";
    } elif isinstance(v, list) {
        return "list";
    } elif isinstance(v, tuple) {
        return "tuple";
    } elif isinstance(v, set) {
        return "set";
    } elif isinstance(v, dict) {
        return "dict";
    } elif isinstance(v, int) {
        return "int";
    }
    return "object";
}

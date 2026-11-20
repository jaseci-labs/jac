impl native_node -> Path {
    return tool_path("node");
}

impl build_environment(base: dict[str, str]) -> dict[str, str] {
    node_path = native_node();
    result: dict[str, str] = dict(base);
    result["PATH"] = str(node_path.parent) + os.pathsep + result.get("PATH", "");
    result["NODE_BINARY"] = str(node_path);
    if offline() {
        result["EXPO_OFFLINE"] = "1";
    }
    return result;
}

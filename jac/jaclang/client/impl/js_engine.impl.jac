impl engine_dir -> str {
    found = require("js-engine").found;
    assert found is not None;
    return found.path;
}

impl node_executable -> str {
    return ensure_node_link(engine_dir());
}

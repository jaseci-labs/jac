impl jcir_is_test_path(path: str) -> bool {
    return path.endswith(".test.jac");
}

impl jcir_python_version -> int {
    return (JCIR_PYTHON_MAJOR << 8) | JCIR_PYTHON_MINOR;
}

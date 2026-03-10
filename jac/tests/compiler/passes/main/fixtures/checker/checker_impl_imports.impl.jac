impl use_imported_types{
    # Should resolve to jaclang types, not Python stdlib
    x: types.ClassType = 90;  # <-- Error: Cannot assign int to ClassType
    y: types.FunctionType = "wrong";  # <-- Error: Cannot assign str to FunctionType
    # Internal builtins imports should NOT be visible (resolves to UnknownType, no error)
    var = 9;
    var = SupportsAdd;  # <-- No error: SupportsAdd is not visible
}

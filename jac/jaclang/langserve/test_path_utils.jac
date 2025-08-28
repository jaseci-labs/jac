"""Test script for path utilities."""

import from path_utils {
    normalize_fs_path,
    uri_to_fs_path,
    fs_path_to_uri,
    paths_equal,
    extract_fs_path
}


"""Test the path utilities with various inputs."""
def test_path_utilities() -> None {
    print("=== Testing Path Utilities ===");
    
    # Test normalize_fs_path
    print("\n--- Testing normalize_fs_path ---");
    test_path1 = "/home/user/file.jac";  # Unix absolute path
    test_path2 = "relative/path/file.jac";  # Relative path
    test_path3 = "c:/Users/USER/file.jac";  # Windows absolute path
    test_path4 = "c:\\Users\\USER\\file.jac";  # Windows path with backslashes
    
    normalized1 = normalize_fs_path(test_path1);
    normalized2 = normalize_fs_path(test_path2);
    normalized3 = normalize_fs_path(test_path3);
    normalized4 = normalize_fs_path(test_path4);
    
    print(f"Unix absolute: {test_path1} -> {normalized1}");
    print(f"Relative: {test_path2} -> {normalized2}");
    print(f"Windows path: {test_path3} -> {normalized3}");
    print(f"Windows backslashes: {test_path4} -> {normalized4}");
    
    # Test URI conversion
    print("\n--- Testing URI to FS path ---");
    test_uri1 = "file:///c%3A/Users/USER/jaseci/jac/jaclang/tests/fixtures/hello.jac";
    test_uri2 = "file:///home/user/test.jac";
    
    fs_path1 = uri_to_fs_path(test_uri1);
    fs_path2 = uri_to_fs_path(test_uri2);
    
    print(f"Windows URI: {test_uri1} -> {fs_path1}");
    print(f"Unix URI: {test_uri2} -> {fs_path2}");
    
    # Test URI creation
    print("\n--- Testing FS path to URI ---");
    test_fs_path1 = "c:/Users/USER/jaseci/jac/jaclang/tests/fixtures/hello.jac";
    test_fs_path2 = "/home/user/test.jac";
    
    uri_path1 = fs_path_to_uri(test_fs_path1);
    uri_path2 = fs_path_to_uri(test_fs_path2);
    
    print(f"Windows FS: {test_fs_path1} -> {uri_path1}");
    print(f"Unix FS: {test_fs_path2} -> {uri_path2}");
    
    # Test paths_equal
    print("\n--- Testing paths_equal ---");
    path1 = "c:\\Users\\USER\\jaseci\\jac\\jaclang\\tests\\fixtures\\hello.jac";
    path2 = "/c%3A/Users/USER/jaseci/jac/jaclang/tests/fixtures/hello.jac";
    path3 = "file:///c%3A/Users/USER/jaseci/jac/jaclang/tests/fixtures/hello.jac";
    path4 = "c:/Users/USER/jaseci/jac/jaclang/tests/fixtures/hello.jac";
    
    are_equal_1_2 = paths_equal(path1, path2);
    are_equal_1_3 = paths_equal(path1, path3);
    are_equal_1_4 = paths_equal(path1, path4);
    are_equal_2_3 = paths_equal(path2, path3);
    
    print(f"Windows backslash vs encoded: {are_equal_1_2} ✓");
    print(f"Windows backslash vs URI: {are_equal_1_3} ✓");
    print(f"Windows backslash vs forward: {are_equal_1_4} ✓");
    print(f"Encoded vs URI: {are_equal_2_3} ✓");
    
    # Test extract_fs_path
    print("\n--- Testing extract_fs_path ---");
    extracted1 = extract_fs_path("file:///c%3A/Users/USER/test.jac");
    extracted2 = extract_fs_path("/home/user/test.jac");
    extracted3 = extract_fs_path("c:\\Windows\\test.jac");
    
    print(f"Extract from URI: {extracted1}");
    print(f"Extract from Unix: {extracted2}");
    print(f"Extract from Windows: {extracted3}");
    
    print("\n=== Test Complete ===");
}


# Test the functions
with entry {
    test_path_utilities();
}

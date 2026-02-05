# File I/O tests for native LLVM IR codegen.

# Test 1: open() returns a non-null File for writable files
def test_open_write() -> int {
    f: File = open("/tmp/jac_native_test.txt", "w");
    if f is not None {
        f.close();
        return 1;
    }
    return 0;
}

# Test 2: Write a string to a file and return bytes written
def test_write_file() -> int {
    f: File = open("/tmp/jac_native_test_write.txt", "w");
    if f is None {
        return -1;
    }
    n: int = f.write("Hello, Jac!");
    f.close();
    return n;  # Should be 11 (length of "Hello, Jac!")
}

# Test 3: Write then read back
def test_write_read() -> str {
    # Write
    f: File = open("/tmp/jac_native_test_rw.txt", "w");
    if f is None {
        return "open_write_failed";
    }
    f.write("NativeIO");
    f.close();

    # Read back
    f2: File = open("/tmp/jac_native_test_rw.txt", "r");
    if f2 is None {
        return "open_read_failed";
    }
    content: str = f2.read();
    f2.close();
    return content;
}

# Test 4: readline reads one line
def test_readline() -> str {
    # Write multi-line file
    f: File = open("/tmp/jac_native_test_readline.txt", "w");
    if f is None {
        return "open_failed";
    }
    f.write("line1\nline2\nline3\n");
    f.close();

    # Read first line
    f2: File = open("/tmp/jac_native_test_readline.txt", "r");
    if f2 is None {
        return "open_failed";
    }
    first_line: str = f2.readline();
    f2.close();
    return first_line;
}

# Test 5: close is idempotent (calling twice doesn't crash)
def test_close_idempotent() -> int {
    f: File = open("/tmp/jac_native_test_close.txt", "w");
    if f is None {
        return -1;
    }
    f.close();
    f.close();  # Should not crash
    return 1;
}

# Test 6: open non-existent file for reading returns None
def test_open_nonexistent() -> int {
    f: File = open("/tmp/jac_nonexistent_98765.txt", "r");
    if f is None {
        return 1;
    }
    f.close();
    return 0;
}

# Test 7: Verify File methods exist (compilation test)
def test_file_methods_exist() -> int {
    f: File = open("/tmp/jac_native_test_methods.txt", "w");
    if f is None {
        return 0;
    }
    f.write("test");
    f.flush();
    f.close();
    return 1;
}

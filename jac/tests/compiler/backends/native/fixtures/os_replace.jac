import os;
import os as filesystem;
import from os { replace as move }

with entry {
    with open("source", "w") as stream {
        stream.write("new");
    }
    with open("target", "w") as stream {
        stream.write("old");
    }
    os.replace(src="source", dst="target");
    assert not os.path.exists("source");
    with open("target", "r") as stream {
        assert stream.read() == "new";
    }
    filesystem.replace("target", "fresh");
    assert not os.path.exists("target");
    move("fresh", "source");
    assert os.path.exists("source");
    missing = False;
    try {
        os.replace("absent", "source");
    } except FileNotFoundError {
        missing = True;
    }
    assert missing;
    with open("source", "r") as stream {
        assert stream.read() == "new";
    }
    missing = False;
    try {
        move("source", "absent/target");
    } except FileNotFoundError {
        missing = True;
    }
    assert missing and os.path.exists("source");
    invalid = False;
    try {
        filesystem.replace("source\x00hidden", "target");
    } except ValueError {
        invalid = True;
    }
    assert invalid and os.path.exists("source");
    invalid = False;
    try {
        os.replace("source", "target", src_dir_fd=-1);
    } except OSError {
        invalid = True;
    }
    assert invalid;
    invalid = False;
    try {
        os.replace("source", "target", dst_dir_fd=2147483648);
    } except OverflowError {
        invalid = True;
    }
    assert invalid;
    os.mkdir("destination-dir");
    invalid = False;
    try {
        os.replace("source", "destination-dir");
    } except IsADirectoryError {
        invalid = True;
    }
    assert invalid and os.path.exists("source");
    os.rmdir("destination-dir");
    source_fd = int(os.getenv("REPLACE_SOURCE_FD", "-1"));
    target_fd = int(os.getenv("REPLACE_TARGET_FD", "-1"));
    if source_fd >= 0 {
        with open("src-dir/relative", "w") as stream {
            stream.write("relative");
        }
        os.replace("relative", "moved", src_dir_fd=source_fd, dst_dir_fd=target_fd);
        assert not os.path.exists("src-dir/relative");
        with open("dst-dir/moved", "r") as stream {
            assert stream.read() == "relative";
        }
        os.remove("dst-dir/moved");
    }
    assert "a-b".replace("-", ":") == "a:b";
    assert isinstance(os.listdir("."), list);
    os.remove("source");

    print("replace success and errors pass");
}

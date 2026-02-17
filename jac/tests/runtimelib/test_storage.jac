"""Tests for the core storage module."""

import os;
import shutil;
import from tempfile { mkdtemp, mkstemp }
import from jaclang.runtimelib.storage { LocalStorage, Storage }
import from jaclang.runtimelib.builtin { store }
import from jaclang.project.config { JacConfig, StorageConfig }

# --- LocalStorage tests ---
test "import storage" {
    assert Storage is not None;
    assert LocalStorage is not None;
}

test "create local storage" {
    tmp = mkdtemp();
    try {
        strg = LocalStorage(base_path=tmp);
        assert strg.base_path == tmp;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "upload and download" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        result = strg.upload(fpath, "test/uploaded.txt");
        assert result is not None;

        content = strg.download("test/uploaded.txt");
        assert content == b"Test content for storage";

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "exists" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        assert not strg.exists("nonexistent.txt");
        strg.upload(fpath, "exists_test.txt");
        assert strg.exists("exists_test.txt");

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "delete" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        strg.upload(fpath, "to_delete.txt");
        assert strg.exists("to_delete.txt");

        result = strg.delete("to_delete.txt");
        assert result is True;
        assert not strg.exists("to_delete.txt");

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "list files" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        strg.upload(fpath, "list_test/file1.txt");
        strg.upload(fpath, "list_test/file2.txt");

        files = list(strg.list_files("list_test/"));
        assert len(files) == 2;
        assert "list_test/file1.txt" in files;
        assert "list_test/file2.txt" in files;

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "copy" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        strg.upload(fpath, "original.txt");
        result = strg.copy("original.txt", "copied.txt");

        assert result is True;
        assert strg.exists("original.txt");
        assert strg.exists("copied.txt");

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "move" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        strg.upload(fpath, "to_move.txt");
        result = strg.move("to_move.txt", "moved.txt");

        assert result is True;
        assert not strg.exists("to_move.txt");
        assert strg.exists("moved.txt");

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "get metadata" {
    tmp = mkdtemp();
    try {
        (fd, fpath) = mkstemp();
        os.write(fd, b"Test content for storage");
        os.close(fd);

        strg = LocalStorage(base_path=tmp);
        strg.upload(fpath, "meta.txt");

        metadata = strg.get_metadata("meta.txt");
        assert metadata["size"] == len(b"Test content for storage");
        assert "modified" in metadata;
        assert "created" in metadata;
        assert metadata["is_dir"] is False;
        assert metadata["name"] == "meta.txt";

        os.remove(fpath);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# --- store builtin tests ---
test "store default" {
    strg = store();
    # Re-import to avoid dual class loading under xdist (_fresh_jac_state
    # can reload .jac modules, creating a new class object while the
    # module-level import still holds the old one).
    import from jaclang.runtimelib.storage.local_storage { LocalStorage as LS }
    assert isinstance(strg, LS);
}

test "store with config" {
    tmp = mkdtemp();
    try {
        strg = store(base_path=tmp);
        assert strg.base_path == tmp;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# --- JacConfig storage tests ---
test "storage config in jac config" {
    config = JacConfig();
    assert hasattr(config, "storage");
    assert isinstance(config.storage, StorageConfig);
}

test "storage config defaults" {
    config = JacConfig();
    assert config.storage.storage_type == "local";
    assert config.storage.base_path == "./storage";
    assert config.storage.create_dirs is True;
}

test "storage config from toml" {
    toml_str = "\n[project]\nname = \"test\"\n\n[storage]\ntype = \"s3\"\nbase_path = \"/custom/storage\"\ncreate_dirs = false\n";
    config = JacConfig.from_toml_str(toml_str);
    assert config.storage.storage_type == "s3";
    assert config.storage.base_path == "/custom/storage";
    assert config.storage.create_dirs is False;
}

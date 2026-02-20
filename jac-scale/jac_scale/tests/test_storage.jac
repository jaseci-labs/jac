"""Tests for the storage abstraction."""

import io;
import os;
import shutil;
import from tempfile { mkdtemp }
import from pathlib { Path }

import pytest;

import from jaclang.runtimelib.storage { LocalStorage }

"""Create a temporary directory and LocalStorage instance."""
def make_temp_storage -> tuple[str, LocalStorage] {
    temp_dir = mkdtemp();
    storage = LocalStorage(base_path=temp_dir);
    return (temp_dir, storage);
}

"""Clean up a temporary directory."""
def cleanup_temp(temp_dir: str) -> None {
    if os.path.exists(temp_dir) {
        shutil.rmtree(temp_dir);
    }
}

test "upload from file path" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        source_file = Path(temp_dir) / "source.txt";
        source_file.write_text("Hello, World!");

        result = local_storage.upload(str(source_file), "uploaded/file.txt");

        assert local_storage.exists("uploaded/file.txt");
        assert Path(result).exists();
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "upload from file object" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Binary content here");

        local_storage.upload(file_obj, "binary/data.bin");

        assert local_storage.exists("binary/data.bin");
        content = local_storage.download("binary/data.bin");
        assert content == b"Binary content here";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "download returns bytes" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Test content");
        local_storage.upload(file_obj, "test.txt");

        content = local_storage.download("test.txt");

        assert content == b"Test content";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "download to file path" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Download me");
        local_storage.upload(file_obj, "source.txt");
        dest_path = Path(temp_dir) / "downloaded.txt";

        local_storage.download("source.txt", str(dest_path));

        assert dest_path.exists();
        assert dest_path.read_bytes() == b"Download me";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "download to file object" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Stream me");
        local_storage.upload(file_obj, "stream.txt");
        output = io.BytesIO();

        local_storage.download("stream.txt", output);

        output.seek(0);
        assert output.read() == b"Stream me";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "download nonexistent file raises" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        with pytest.raises(FileNotFoundError) {
            local_storage.download("nonexistent.txt");
        }
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "delete existing file" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Delete me");
        local_storage.upload(file_obj, "to_delete.txt");
        assert local_storage.exists("to_delete.txt");

        result = local_storage.delete("to_delete.txt");

        assert result is True;
        assert not local_storage.exists("to_delete.txt");
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "delete nonexistent file" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        result = local_storage.delete("nonexistent.txt");

        assert result is False;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "exists returns true for existing" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"I exist");
        local_storage.upload(file_obj, "exists.txt");

        assert local_storage.exists("exists.txt") is True;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "exists returns false for nonexistent" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        assert local_storage.exists("nonexistent.txt") is False;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "list files non recursive" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        local_storage.upload(io.BytesIO(b"1"), "folder/file1.txt");
        local_storage.upload(io.BytesIO(b"2"), "folder/file2.txt");
        local_storage.upload(io.BytesIO(b"3"), "folder/sub/file3.txt");

        files = list(local_storage.list_files("folder", recursive=False));

        # Should include file1, file2, and sub directory
        assert len(files) == 3;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "list files recursive" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        local_storage.upload(io.BytesIO(b"1"), "folder/file1.txt");
        local_storage.upload(io.BytesIO(b"2"), "folder/file2.txt");
        local_storage.upload(io.BytesIO(b"3"), "folder/sub/file3.txt");

        files = list(local_storage.list_files("folder", recursive=True));

        # Should only include files (not directories) recursively
        assert len(files) == 3;
        assert any("file1.txt" in f for f in files);
        assert any("file2.txt" in f for f in files);
        assert any("file3.txt" in f for f in files);
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "get metadata" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        content = b"Metadata test content";
        local_storage.upload(io.BytesIO(content), "meta.txt");

        metadata = local_storage.get_metadata("meta.txt");

        assert metadata["size"] == len(content);
        assert "modified" in metadata;
        assert "created" in metadata;
        assert metadata["is_dir"] is False;
        assert metadata["name"] == "meta.txt";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "get metadata nonexistent raises" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        with pytest.raises(FileNotFoundError) {
            local_storage.get_metadata("nonexistent.txt");
        }
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "copy file" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        local_storage.upload(io.BytesIO(b"Copy me"), "original.txt");

        result = local_storage.copy("original.txt", "copied.txt");

        assert result is True;
        assert local_storage.exists("original.txt");
        assert local_storage.exists("copied.txt");
        assert local_storage.download("copied.txt") == b"Copy me";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "copy nonexistent returns false" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        result = local_storage.copy("nonexistent.txt", "dest.txt");

        assert result is False;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "move file" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        local_storage.upload(io.BytesIO(b"Move me"), "to_move.txt");

        result = local_storage.move("to_move.txt", "moved.txt");

        assert result is True;
        assert not local_storage.exists("to_move.txt");
        assert local_storage.exists("moved.txt");
        assert local_storage.download("moved.txt") == b"Move me";
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "move nonexistent returns false" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        result = local_storage.move("nonexistent.txt", "dest.txt");

        assert result is False;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "creates directories automatically" {
    temp_dir = mkdtemp();
    try {
        new_path = os.path.join(temp_dir, "new", "nested", "dir");
        LocalStorage(base_path=new_path, create_dirs=True);

        assert os.path.exists(new_path);
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "upload creates parent directories" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        file_obj = io.BytesIO(b"Nested content");

        local_storage.upload(file_obj, "deep/nested/folder/file.txt");

        assert local_storage.exists("deep/nested/folder/file.txt");
    } finally {
        cleanup_temp(temp_dir);
    }
}

# Integration tests
test "full file lifecycle" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        # Upload
        content = b"Lifecycle test content";
        local_storage.upload(io.BytesIO(content), "lifecycle.txt");
        assert local_storage.exists("lifecycle.txt");

        # Read
        downloaded = local_storage.download("lifecycle.txt");
        assert downloaded == content;

        # Copy
        local_storage.copy("lifecycle.txt", "lifecycle_copy.txt");
        assert local_storage.exists("lifecycle_copy.txt");

        # Move
        local_storage.move("lifecycle_copy.txt", "lifecycle_moved.txt");
        assert not local_storage.exists("lifecycle_copy.txt");
        assert local_storage.exists("lifecycle_moved.txt");

        # Delete
        local_storage.delete("lifecycle.txt");
        local_storage.delete("lifecycle_moved.txt");
        assert not local_storage.exists("lifecycle.txt");
        assert not local_storage.exists("lifecycle_moved.txt");
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "upload large file" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        large_content = b"x" * (1024 * 1024);  # 1MB
        file_obj = io.BytesIO(large_content);

        local_storage.upload(file_obj, "large_file.bin");

        metadata = local_storage.get_metadata("large_file.bin");
        assert metadata["size"] == 1024 * 1024;

        downloaded = local_storage.download("large_file.bin");
        assert downloaded == large_content;
    } finally {
        cleanup_temp(temp_dir);
    }
}

test "special characters in filename" {
    (temp_dir, local_storage) = make_temp_storage();
    try {
        content = b"Special chars";
        local_storage.upload(io.BytesIO(content), "file-with_special.chars.txt");

        assert local_storage.exists("file-with_special.chars.txt");
        assert local_storage.download("file-with_special.chars.txt") == content;
    } finally {
        cleanup_temp(temp_dir);
    }
}

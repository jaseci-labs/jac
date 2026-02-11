"""Tests for the storage abstraction."""

import io
import os
import shutil
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest

try:
    from jaclang.runtimelib.storage import LocalStorage  # type: ignore[attr-defined]
except ImportError as e:
    pytest.skip(f"Jac modules not compiled: {e}", allow_module_level=True)


@pytest.fixture
def temp_storage_dir() -> Generator[str, None, None]:
    """Create a temporary directory for storage tests."""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)


@pytest.fixture
def local_storage(temp_storage_dir: str) -> Generator[LocalStorage, None, None]:
    """Create a LocalStorage instance with temp directory."""
    storage = LocalStorage(base_path=temp_storage_dir)
    yield storage


class TestLocalStorage:
    """Tests for LocalStorage implementation."""

    def test_upload_from_file_path(
        self, local_storage: LocalStorage, temp_storage_dir: str
    ) -> None:
        """Test uploading a file from a file path."""
        source_file = Path(temp_storage_dir) / "source.txt"
        source_file.write_text("Hello, World!")

        result = local_storage.upload(str(source_file), "uploaded/file.txt")

        assert local_storage.exists("uploaded/file.txt")
        assert Path(result).exists()

    def test_upload_from_file_object(self, local_storage: LocalStorage) -> None:
        """Test uploading from a file-like object."""
        file_obj = io.BytesIO(b"Binary content here")

        local_storage.upload(file_obj, "binary/data.bin")

        assert local_storage.exists("binary/data.bin")
        content = local_storage.download("binary/data.bin")
        assert content == b"Binary content here"

    def test_download_returns_bytes(self, local_storage: LocalStorage) -> None:
        """Test download returns bytes when no destination specified."""
        file_obj = io.BytesIO(b"Test content")
        local_storage.upload(file_obj, "test.txt")

        content = local_storage.download("test.txt")

        assert content == b"Test content"

    def test_download_to_file_path(
        self, local_storage: LocalStorage, temp_storage_dir: str
    ) -> None:
        """Test download to a file path."""
        file_obj = io.BytesIO(b"Download me")
        local_storage.upload(file_obj, "source.txt")
        dest_path = Path(temp_storage_dir) / "downloaded.txt"

        local_storage.download("source.txt", str(dest_path))

        assert dest_path.exists()
        assert dest_path.read_bytes() == b"Download me"

    def test_download_to_file_object(self, local_storage: LocalStorage) -> None:
        """Test download to a file-like object."""
        file_obj = io.BytesIO(b"Stream me")
        local_storage.upload(file_obj, "stream.txt")
        output = io.BytesIO()

        local_storage.download("stream.txt", output)

        output.seek(0)
        assert output.read() == b"Stream me"

    def test_download_nonexistent_file_raises(
        self, local_storage: LocalStorage
    ) -> None:
        """Test that downloading a non-existent file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            local_storage.download("nonexistent.txt")

    def test_delete_existing_file(self, local_storage: LocalStorage) -> None:
        """Test deleting an existing file."""
        file_obj = io.BytesIO(b"Delete me")
        local_storage.upload(file_obj, "to_delete.txt")
        assert local_storage.exists("to_delete.txt")

        result = local_storage.delete("to_delete.txt")

        assert result is True
        assert not local_storage.exists("to_delete.txt")

    def test_delete_nonexistent_file(self, local_storage: LocalStorage) -> None:
        """Test deleting a non-existent file returns False."""
        result = local_storage.delete("nonexistent.txt")

        assert result is False

    def test_exists_returns_true_for_existing(
        self, local_storage: LocalStorage
    ) -> None:
        """Test exists returns True for existing file."""
        file_obj = io.BytesIO(b"I exist")
        local_storage.upload(file_obj, "exists.txt")

        assert local_storage.exists("exists.txt") is True

    def test_exists_returns_false_for_nonexistent(
        self, local_storage: LocalStorage
    ) -> None:
        """Test exists returns False for non-existent file."""
        assert local_storage.exists("nonexistent.txt") is False

    def test_list_files_non_recursive(self, local_storage: LocalStorage) -> None:
        """Test listing files non-recursively."""
        local_storage.upload(io.BytesIO(b"1"), "folder/file1.txt")
        local_storage.upload(io.BytesIO(b"2"), "folder/file2.txt")
        local_storage.upload(io.BytesIO(b"3"), "folder/sub/file3.txt")

        files = list(local_storage.list_files("folder", recursive=False))

        # Should include file1, file2, and sub directory
        assert len(files) == 3

    def test_list_files_recursive(self, local_storage: LocalStorage) -> None:
        """Test listing files recursively."""
        local_storage.upload(io.BytesIO(b"1"), "folder/file1.txt")
        local_storage.upload(io.BytesIO(b"2"), "folder/file2.txt")
        local_storage.upload(io.BytesIO(b"3"), "folder/sub/file3.txt")

        files = list(local_storage.list_files("folder", recursive=True))

        # Should only include files (not directories) recursively
        assert len(files) == 3
        assert any("file1.txt" in f for f in files)
        assert any("file2.txt" in f for f in files)
        assert any("file3.txt" in f for f in files)

    def test_get_metadata(self, local_storage: LocalStorage) -> None:
        """Test getting file metadata."""
        content = b"Metadata test content"
        local_storage.upload(io.BytesIO(content), "meta.txt")

        metadata = local_storage.get_metadata("meta.txt")

        assert metadata["size"] == len(content)
        assert "modified" in metadata
        assert "created" in metadata
        assert metadata["is_dir"] is False
        assert metadata["name"] == "meta.txt"

    def test_get_metadata_nonexistent_raises(self, local_storage: LocalStorage) -> None:
        """Test that getting metadata of non-existent file raises error."""
        with pytest.raises(FileNotFoundError):
            local_storage.get_metadata("nonexistent.txt")

    def test_copy_file(self, local_storage: LocalStorage) -> None:
        """Test copying a file."""
        local_storage.upload(io.BytesIO(b"Copy me"), "original.txt")

        result = local_storage.copy("original.txt", "copied.txt")

        assert result is True
        assert local_storage.exists("original.txt")
        assert local_storage.exists("copied.txt")
        assert local_storage.download("copied.txt") == b"Copy me"

    def test_copy_nonexistent_returns_false(self, local_storage: LocalStorage) -> None:
        """Test copying non-existent file returns False."""
        result = local_storage.copy("nonexistent.txt", "dest.txt")

        assert result is False

    def test_move_file(self, local_storage: LocalStorage) -> None:
        """Test moving a file."""
        local_storage.upload(io.BytesIO(b"Move me"), "to_move.txt")

        result = local_storage.move("to_move.txt", "moved.txt")

        assert result is True
        assert not local_storage.exists("to_move.txt")
        assert local_storage.exists("moved.txt")
        assert local_storage.download("moved.txt") == b"Move me"

    def test_move_nonexistent_returns_false(self, local_storage: LocalStorage) -> None:
        """Test moving non-existent file returns False."""
        result = local_storage.move("nonexistent.txt", "dest.txt")

        assert result is False

    def test_creates_directories_automatically(self, temp_storage_dir: str) -> None:
        """Test that directories are created when create_dirs is True."""
        new_path = os.path.join(temp_storage_dir, "new", "nested", "dir")
        LocalStorage(base_path=new_path, create_dirs=True)

        assert os.path.exists(new_path)

    def test_upload_creates_parent_directories(
        self, local_storage: LocalStorage
    ) -> None:
        """Test that upload creates parent directories as needed."""
        file_obj = io.BytesIO(b"Nested content")

        local_storage.upload(file_obj, "deep/nested/folder/file.txt")

        assert local_storage.exists("deep/nested/folder/file.txt")


class TestStorageIntegration:
    """Integration tests for storage operations."""

    def test_full_file_lifecycle(self, local_storage: LocalStorage) -> None:
        """Test complete file lifecycle: upload, read, copy, move, delete."""
        # Upload
        content = b"Lifecycle test content"
        local_storage.upload(io.BytesIO(content), "lifecycle.txt")
        assert local_storage.exists("lifecycle.txt")

        # Read
        downloaded = local_storage.download("lifecycle.txt")
        assert downloaded == content

        # Copy
        local_storage.copy("lifecycle.txt", "lifecycle_copy.txt")
        assert local_storage.exists("lifecycle_copy.txt")

        # Move
        local_storage.move("lifecycle_copy.txt", "lifecycle_moved.txt")
        assert not local_storage.exists("lifecycle_copy.txt")
        assert local_storage.exists("lifecycle_moved.txt")

        # Delete
        local_storage.delete("lifecycle.txt")
        local_storage.delete("lifecycle_moved.txt")
        assert not local_storage.exists("lifecycle.txt")
        assert not local_storage.exists("lifecycle_moved.txt")

    def test_upload_large_file(self, local_storage: LocalStorage) -> None:
        """Test uploading a larger file (1MB)."""
        large_content = b"x" * (1024 * 1024)  # 1MB
        file_obj = io.BytesIO(large_content)

        local_storage.upload(file_obj, "large_file.bin")

        metadata = local_storage.get_metadata("large_file.bin")
        assert metadata["size"] == 1024 * 1024

        downloaded = local_storage.download("large_file.bin")
        assert downloaded == large_content

    def test_special_characters_in_filename(self, local_storage: LocalStorage) -> None:
        """Test handling files with special characters in name."""
        content = b"Special chars"
        local_storage.upload(io.BytesIO(content), "file-with_special.chars.txt")

        assert local_storage.exists("file-with_special.chars.txt")
        assert local_storage.download("file-with_special.chars.txt") == content

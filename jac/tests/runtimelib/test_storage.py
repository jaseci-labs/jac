"""Tests for the core storage module."""

import os
import shutil
import tempfile
from collections.abc import Generator

import pytest


@pytest.fixture
def temp_storage_dir() -> Generator[str, None, None]:
    """Create a temporary directory for storage tests."""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)


@pytest.fixture
def temp_file() -> Generator[str, None, None]:
    """Create a temporary file for upload tests."""
    fd, path = tempfile.mkstemp()
    os.write(fd, b"Test content for storage")
    os.close(fd)
    yield path
    if os.path.exists(path):
        os.remove(path)


class TestLocalStorage:
    """Tests for LocalStorage implementation."""

    def test_import_storage(self) -> None:
        """Test that storage classes can be imported from core."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
            Storage,
        )

        assert Storage is not None
        assert LocalStorage is not None

    def test_create_local_storage(self, temp_storage_dir: str) -> None:
        """Test creating a LocalStorage instance."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)
        assert storage.base_path == temp_storage_dir

    def test_upload_and_download(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test uploading and downloading a file."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        # Upload
        result = storage.upload(temp_file, "test/uploaded.txt")
        assert result is not None

        # Download
        content = storage.download("test/uploaded.txt")
        assert content == b"Test content for storage"

    def test_exists(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test checking if a file exists."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        assert not storage.exists("nonexistent.txt")

        storage.upload(temp_file, "exists_test.txt")
        assert storage.exists("exists_test.txt")

    def test_delete(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test deleting a file."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        storage.upload(temp_file, "to_delete.txt")
        assert storage.exists("to_delete.txt")

        result = storage.delete("to_delete.txt")
        assert result is True
        assert not storage.exists("to_delete.txt")

    def test_list_files(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test listing files in a directory."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        storage.upload(temp_file, "list_test/file1.txt")
        storage.upload(temp_file, "list_test/file2.txt")

        files = list(storage.list_files("list_test/"))
        assert len(files) == 2
        assert "list_test/file1.txt" in files
        assert "list_test/file2.txt" in files

    def test_copy(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test copying a file."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        storage.upload(temp_file, "original.txt")
        result = storage.copy("original.txt", "copied.txt")

        assert result is True
        assert storage.exists("original.txt")
        assert storage.exists("copied.txt")

    def test_move(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test moving a file."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)

        storage.upload(temp_file, "to_move.txt")
        result = storage.move("to_move.txt", "moved.txt")

        assert result is True
        assert not storage.exists("to_move.txt")
        assert storage.exists("moved.txt")

    def test_get_metadata(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test getting file metadata."""
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = LocalStorage(base_path=temp_storage_dir)
        storage.upload(temp_file, "meta.txt")

        metadata = storage.get_metadata("meta.txt")
        assert metadata["size"] == len(b"Test content for storage")
        assert "modified" in metadata
        assert "created" in metadata
        assert metadata["is_dir"] is False
        assert metadata["name"] == "meta.txt"


class TestStoreBuiltin:
    """Tests for the store builtin function."""

    def test_store_default(self) -> None:
        """Test store returns LocalStorage by default."""
        from jaclang.runtimelib.builtin import store
        from jaclang.runtimelib.storage import (  # type: ignore[attr-defined]
            LocalStorage,
        )

        storage = store()
        assert isinstance(storage, LocalStorage)

    def test_store_with_config(self, temp_storage_dir: str) -> None:
        """Test store with custom config."""
        from jaclang.runtimelib.builtin import store

        storage = store(base_path=temp_storage_dir)
        assert storage.base_path == temp_storage_dir


class TestJacConfigStorage:
    """Tests for StorageConfig in JacConfig."""

    def test_storage_config_in_jac_config(self) -> None:
        """Test that JacConfig includes StorageConfig."""
        from jaclang.project.config import JacConfig, StorageConfig

        config = JacConfig()
        assert hasattr(config, "storage")
        assert isinstance(config.storage, StorageConfig)

    def test_storage_config_defaults(self) -> None:
        """Test StorageConfig default values."""
        from jaclang.project.config import JacConfig

        config = JacConfig()
        assert config.storage.storage_type == "local"
        assert config.storage.base_path == "./storage"
        assert config.storage.create_dirs is True

    def test_storage_config_from_toml(self) -> None:
        """Test parsing storage config from TOML."""
        from jaclang.project.config import JacConfig

        toml_str = """
[project]
name = "test"

[storage]
type = "s3"
base_path = "/custom/storage"
create_dirs = false
"""
        config = JacConfig.from_toml_str(toml_str)
        assert config.storage.storage_type == "s3"
        assert config.storage.base_path == "/custom/storage"
        assert config.storage.create_dirs is False

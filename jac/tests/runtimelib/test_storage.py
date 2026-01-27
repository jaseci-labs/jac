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
        from jaclang.runtimelib.storage import (
            BaseStorageConfig,
            LocalStorage,
            LocalStorageConfig,
            Storage,
        )

        assert Storage is not None
        assert LocalStorage is not None
        assert BaseStorageConfig is not None
        assert LocalStorageConfig is not None

    def test_create_local_storage(self, temp_storage_dir: str) -> None:
        """Test creating a LocalStorage instance."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})
        assert storage.base_path == temp_storage_dir

    def test_upload_and_download(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test uploading and downloading a file."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        # Upload
        result = storage.upload(temp_file, "test/uploaded.txt")
        assert result is not None

        # Download
        content = storage.download("test/uploaded.txt")
        assert content == b"Test content for storage"

    def test_exists(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test checking if a file exists."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        assert not storage.exists("nonexistent.txt")

        storage.upload(temp_file, "exists_test.txt")
        assert storage.exists("exists_test.txt")

    def test_delete(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test deleting a file."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        storage.upload(temp_file, "to_delete.txt")
        assert storage.exists("to_delete.txt")

        result = storage.delete("to_delete.txt")
        assert result is True
        assert not storage.exists("to_delete.txt")

    def test_list_files(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test listing files in a directory."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        storage.upload(temp_file, "list_test/file1.txt")
        storage.upload(temp_file, "list_test/file2.txt")

        files = list(storage.list_files("list_test/"))
        assert len(files) == 2
        assert "list_test/file1.txt" in files
        assert "list_test/file2.txt" in files

    def test_copy(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test copying a file."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        storage.upload(temp_file, "original.txt")
        result = storage.copy("original.txt", "copied.txt")

        assert result is True
        assert storage.exists("original.txt")
        assert storage.exists("copied.txt")

    def test_move(self, temp_storage_dir: str, temp_file: str) -> None:
        """Test moving a file."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})

        storage.upload(temp_file, "to_move.txt")
        result = storage.move("to_move.txt", "moved.txt")

        assert result is True
        assert not storage.exists("to_move.txt")
        assert storage.exists("moved.txt")

    def test_is_available(self, temp_storage_dir: str) -> None:
        """Test checking if storage is available."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})
        assert storage.is_available() is True

    def test_get_info(self, temp_storage_dir: str) -> None:
        """Test getting storage info."""
        from jaclang.runtimelib.storage import LocalStorage

        storage = LocalStorage({"base_path": temp_storage_dir})
        info = storage.get_info()

        assert info["type"] == "local"
        assert info["base_path"] == temp_storage_dir


class TestStorageConfig:
    """Tests for storage configuration classes."""

    def test_local_storage_config_defaults(self) -> None:
        """Test LocalStorageConfig with default values."""
        from jaclang.runtimelib.storage import LocalStorageConfig

        config = LocalStorageConfig()
        assert config.storage_type == "local"
        assert config.base_path == "./storage"
        assert config.create_dirs is True

    def test_local_storage_config_from_dict(self) -> None:
        """Test LocalStorageConfig.from_dict method."""
        from jaclang.runtimelib.storage import LocalStorageConfig

        config = LocalStorageConfig.from_dict(
            {"base_path": "/custom/path", "create_dirs": False}
        )
        assert config.base_path == "/custom/path"
        assert config.create_dirs is False

    def test_local_storage_config_to_dict(self) -> None:
        """Test LocalStorageConfig.to_dict method."""
        from jaclang.runtimelib.storage import LocalStorageConfig

        config = LocalStorageConfig(base_path="/test/path")
        config_dict = config.to_dict()

        assert config_dict["storage_type"] == "local"
        assert config_dict["base_path"] == "/test/path"
        assert config_dict["create_dirs"] is True


class TestGetStorageBuiltin:
    """Tests for the get_storage builtin function."""

    def test_get_storage_default(self) -> None:
        """Test get_storage returns LocalStorage by default."""
        from jaclang.runtimelib.builtin import get_storage
        from jaclang.runtimelib.storage import LocalStorage

        storage = get_storage()
        assert isinstance(storage, LocalStorage)

    def test_get_storage_with_config(self, temp_storage_dir: str) -> None:
        """Test get_storage with custom config."""
        from jaclang.runtimelib.builtin import get_storage

        storage = get_storage({"base_path": temp_storage_dir})
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

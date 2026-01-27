"""Base storage abstraction for Jac core.

This provides a standard interface for file/blob storage operations that can be
overridden by plugins (like jac-scale) to provide cloud storage backends.
"""
import from typing { Any, BinaryIO, Generator }

"""Abstract base class for all storage implementations.

Storage backends must implement all methods to provide a consistent
interface for file operations across local filesystem and cloud storage.
"""
class Storage {
    """Upload a file to storage.

    Args:
        source: Local file path or file-like object to upload
        destination: Remote path/key where file will be stored
        metadata: Optional metadata to attach to the file

    Returns:
        The path/URL of the uploaded file
    """
    def upload(
        self: Storage,
        source: (str | BinaryIO),
        destination: str,
        metadata: dict[str, str] = {}
    ) -> str abs;

    """Download a file from storage.

    Args:
        source: Remote path/key of the file to download
        destination: Local path, file-like object, or None to return bytes

    Returns:
        File contents as bytes if destination is None, otherwise None
    """
    def download(
        self: Storage, source: str, destination: (str | BinaryIO | None) = None
    ) -> (bytes | None) abs;

    """Delete a file or directory from storage.

    Args:
        path: Path to delete

    Returns:
        True if deletion was successful, False otherwise
    """
    def delete(self: Storage, path: str) -> bool abs;

    """Check if a path exists in storage.

    Args:
        path: Path to check

    Returns:
        True if the path exists, False otherwise
    """
    def exists(self: Storage, path: str) -> bool abs;

    """List files in storage.

    Args:
        prefix: Filter results to paths starting with this prefix
        recursive: If True, list files in subdirectories

    Yields:
        File paths relative to the storage root
    """
    def list_files(
        self: Storage, prefix: str = "", recursive: bool = False
    ) -> Generator[str, None, None] abs;

    """Get metadata for a file.

    Args:
        path: Path to the file

    Returns:
        Dictionary containing file metadata (size, modified, created, etc.)
    """
    def get_metadata(self: Storage, path: str) -> dict[str, Any] abs;

    """Get a URL or path to access the file.

    Args:
        path: Path to the file
        expiry_seconds: For cloud storage, how long the URL should be valid

    Returns:
        URL or absolute path to access the file
    """
    def get_url(self: Storage, path: str, expiry_seconds: int = 3600) -> str abs;

    """Copy a file within storage.

    Args:
        source: Source path
        destination: Destination path

    Returns:
        True if copy was successful, False otherwise
    """
    def copy(self: Storage, source: str, destination: str) -> bool abs;

    """Move a file within storage.

    Args:
        source: Source path
        destination: Destination path

    Returns:
        True if move was successful, False otherwise
    """
    def move(self: Storage, source: str, destination: str) -> bool abs;

    """Get information about the storage backend.

    Returns:
        Dictionary with storage type and configuration info
    """
    def get_info(self: Storage) -> dict[str, Any] abs;

    """Check if storage backend is available and ready.

    Returns:
        True if storage is available, False otherwise
    """
    def is_available(self: Storage) -> bool abs;

    """Close and cleanup storage resources."""
    def close(self: Storage) -> None abs;
}

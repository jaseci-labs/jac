"""Base storage abstraction for Jac.

This provides a standard interface for file/blob storage operations that can be
overridden by plugins (like jac-scale) to provide cloud storage backends.
"""
import from typing { Any, BinaryIO, Generator }

"""Abstract base class for storage implementations."""
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
        metadata: (dict[str, str] | None) = None
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

    """Delete a file or directory from storage."""
    def delete(self: Storage, path: str) -> bool abs;

    """Check if a path exists in storage."""
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

    """Get metadata for a file (size, modified, created, is_dir, name)."""
    def get_metadata(self: Storage, path: str) -> dict[str, Any] abs;

    """Copy a file within storage."""
    def copy(self: Storage, source: str, destination: str) -> bool abs;

    """Move a file within storage."""
    def move(self: Storage, source: str, destination: str) -> bool abs;
}

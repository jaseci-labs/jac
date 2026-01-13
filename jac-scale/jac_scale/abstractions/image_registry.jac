"""Base image registry abstraction for jac_scale.

All image registry implementations should inherit from this class.
"""

"""Base class for all image registry implementations."""
class ImageRegistry {
    """Build a Docker image from code folder.

    Args:
        code_folder: Path to the code directory
        image_name: Name for the image (optional)

    Returns:
        Full image name/tag
    """
    def build_image(
        self: ImageRegistry, code_folder: str, image_name: (str | None) = None
    ) -> str;

    """Push an image to the registry.

    Args:
        image_name: Full image name to push
    """
    def push_image(self: ImageRegistry, image_name: str) -> None;

    """Get the full image URL for a given image name.

    Args:
        image_name: Base image name

    Returns:
        Full image URL including registry
    """
    def get_image_url(self: ImageRegistry, image_name: str) -> str;

    """Build and push an image in one operation.

    Args:
        code_folder: Path to the code directory
        image_name: Name for the image (optional)

    Returns:
        Full image URL
    """
    def build_and_push(
        self: ImageRegistry, code_folder: str, image_name: (str | None) = None
    ) -> str {
        image = self.build_image(code_folder, image_name);
        self.push_image(image);
        return self.get_image_url(image);
    }
}

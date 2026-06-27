class ImageRegistry {
    def build_image(
        self: ImageRegistry, code_folder: str, image_name: (str | None) = None
    ) -> str;

    def push_image(self: ImageRegistry, image_name: str) -> None;
    def get_image_url(self: ImageRegistry, image_name: str) -> str;
    def build_and_push(
        self: ImageRegistry, code_folder: str, image_name: (str | None) = None
    ) -> str {
        image = self.build_image(code_folder, image_name);
        self.push_image(image);
        return self.get_image_url(image);
    }
}

import from pathlib { Path }


class ImageDistributor {
    def build_and_distribute(
        self: ImageDistributor, project_dir: Path, image_tag: str
    ) -> str;
}

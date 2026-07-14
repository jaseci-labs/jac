import from pathlib { Path }
import from jaclang.project.config { JacConfig }


obj NpmBuilder {
    has config: JacConfig,
        project_root: Path | None = None;

    def postinit -> None;
    def build -> bytes;
    def build_to(output_dir: Path) -> Path;
}

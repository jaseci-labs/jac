import from pathlib { Path }


def client_dist_index(client_dist: str) -> (Path | None);

def sibling_app_dist(config: any, name: str, base_path: str) -> (Path | None);

def sibling_app_file(dist: Path, rel: str) -> Path;

def sibling_app_names(config: any, base_path: str) -> list[str];

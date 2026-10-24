import os;
import site;
import from pathlib { Path }


def jac_global_prefix -> Path;


def python_project_site(config: JacConfig | None = None) -> Path | None;


def python_global_site -> Path | None;


def node_root(scope: str, config: JacConfig | None = None) -> Path | None;


def node_bin_dir(scope: str, config: JacConfig | None = None) -> Path | None;

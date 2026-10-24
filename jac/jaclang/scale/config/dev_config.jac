import os;
import from pathlib { Path }


enum Channel {
    STABLE = "stable",
    DEV = "dev",
    LOCAL = "local",
    EXPERIMENTAL = "experimental"
}


def local_pod_binary(project_dir: str) -> str;


def resolve_dev_channel(project_dir: str) -> Channel;


def resolve_experimental_pr(project_dir: str) -> str;


def resolve_pinned_spec(project_dir: str) -> str;

import re;
import sys;

import from pathlib { Path }

glob POD_GLIBC: tuple[int, int] = (2, 36),
     _LEGACY_PLATFORM_TAG = re.compile(r"^manylinux(?:\d+|_\d+_\d+)_(.+)$");


def pod_wheel_target(pod_arch: str) -> (WheelTarget | None);


def pod_arch_from_argv(raw: str) -> str;


obj WheelVendor {
    has config: JacConfig,
        app_dir: Path,
        target: (WheelTarget | None) = None;

    def resolve_specs -> list[str];
    def run;
}


def main;

with entry:__main__ {
    main();
}

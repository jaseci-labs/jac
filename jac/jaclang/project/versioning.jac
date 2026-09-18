import re;


def vtuple(version: str) -> tuple[int, int, int] {
    parts: list[int] = [];
    for piece in re.findall(r"\d+", version.split("+")[0].split("-")[0])[:3] {
        parts.append(int(piece));
    }
    while len(parts) < 3 {
        parts.append(0);
    }
    return (parts[0], parts[1], parts[2]);
}


def parse_release(version: str) -> tuple[int, int, int] {
    parts = version.strip().split(".");
    if len(parts) > 3 {
        raise ValueError(f"not a release tuple: {version!r}");
    }
    nums: list[int] = [];
    for part in parts {
        if not part.isdigit() {
            raise ValueError(f"not a release tuple: {version!r}");
        }
        nums.append(int(part));
    }
    while len(nums) < 3 {
        nums.append(0);
    }
    return (nums[0], nums[1], nums[2]);
}


def caret_upper(base: tuple[int, int, int]) -> tuple[int, int, int] {
    if base[0] > 0 {
        return (base[0] + 1, 0, 0);
    }
    if base[1] > 0 {
        return (0, base[1] + 1, 0);
    }
    return (0, 0, base[2] + 1);
}


def fmt3(v: tuple[int, int, int]) -> str {
    return f"{v[0]}.{v[1]}.{v[2]}";
}


def norm_pkg_name(name: str) -> str {
    return re.sub(r"[-_.]+", "-", str(name)).lower();
}

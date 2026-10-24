glob NONE: int = 0,
     PATCH: int = 1,
     MINOR: int = 2,
     MAJOR: int = 3,
     LEVEL_NAMES: dict[int, str] = {0: "none", 1: "patch", 2: "minor", 3: "major"},
     SCHEMA_KINDS: tuple[str, ...] = ("node", "edge");

obj ApiChange {
    has path: str,
        level: int,
        reason: str,
        schema: bool = False;

    def describe -> str;
}

def _positional(sig: dict[str, any]) -> list[str];

def diff_signature(
    path: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange];

def _diff_members(
    path: str, kind: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange];

def _diff_symbol(
    path: str, old: dict[str, any], new: dict[str, any]
) -> list[ApiChange];

def diff_surfaces(old: dict[str, any], new: dict[str, any]) -> list[ApiChange];

def required_level(changes: list[ApiChange]) -> int;

def bump_level(old: Version, new: Version) -> int;

def check_bump(old: Version, new: Version, changes: list[ApiChange]) -> str;

def minimum_next(old: Version, changes: list[ApiChange]) -> Version;

glob _ENTRIES: dict[str, Artifact] = {},
     _RESOLVED: dict[str, Resolution] = {},
     _ANNOUNCED: set[str] = set();

def names -> list[str];
def artifact_named(name: str) -> Artifact;
def resolve(name: str) -> Resolution;
def require(name: str) -> Resolution;
def forget(name: str = "") -> None;
def building_now -> frozenset[str];
def building(names: list[str]) -> _BuildingSpan;
def build_order(requested: list[str]) -> list[str];
def publish(stage: str, destination: str, companions: tuple[str, ...] = ()) -> None;
def tiers(name: str) -> list[tuple[str, Probe]];
def release_set -> list[str];
def shipped_floors -> list[str];
def build(
    requested: list[str],
    log: Callable[[str], None],
    force: bool = False,
    exact: bool = False,
    strict: bool = False
) -> list[str];

def unmet(required: list[str]) -> list[str];

obj _BuildingSpan {
    has added: list[str];

    def __enter__ -> _BuildingSpan;
    def __exit__(_exc_type: object, _exc_value: object, _traceback: object) -> bool;
}

def _decide(artifact: Artifact) -> Resolution;

def omitted_by_image -> frozenset[str];

def _omitted(sealed_image: bool) -> frozenset[str];

def _provision(artifact: Artifact, resolution: Resolution) -> Resolution;

def _to_stderr(line: str);

def _announce(artifact: Artifact, resolution: Resolution);

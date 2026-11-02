def dget(blob: any, key: str) -> dict[str, any];


def lget(blob: any, key: str) -> list[any];


def sget(blob: any, key: str) -> str | None;


def bget(blob: any, key: str, fallback: bool) -> bool;


def iget(blob: any, key: str, fallback: int) -> int;


def fget(blob: any, key: str, fallback: float) -> float;


def pod_spec(deployment: any) -> dict[str, any];


def effective_resources(
    deployment: any
) -> tuple[str | None, str | None, str | None, str | None];

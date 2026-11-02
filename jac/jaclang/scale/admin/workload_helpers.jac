def phase_to_status(ready: int, desired: int, restarts: int) -> str;

def owner_name_from_pod(pod: str) -> str;

def match_owner(pod: str, names: list[str]) -> str;

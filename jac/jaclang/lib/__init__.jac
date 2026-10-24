glob __all__ = _jaclib.__all__;

def __getattr__(name: str) -> object;

def __dir__ -> list[str];

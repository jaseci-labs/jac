"""A module whose name ends in 'c', for scope name resolution."""

obj BasicInfo {
    has name: str;
}

def get_basic -> BasicInfo by llm();

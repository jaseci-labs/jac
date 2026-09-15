"""A module whose name ends in 'j', for scope name resolution."""

obj Project {
    has title: str;
}

def create_proj -> Project by llm();

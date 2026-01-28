"""Fixture with module name ending in 'j' to test scope name resolution."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj Project {
    has title: str;
}

def create_proj -> Project by llm();

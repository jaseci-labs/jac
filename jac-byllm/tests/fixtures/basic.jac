"""Fixture with module name ending in 'c' to test scope name resolution."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj BasicInfo {
    has name: str;
}

def get_basic -> BasicInfo by llm();

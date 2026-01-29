"""Fixture with module name ending in 'a' to test scope name resolution."""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj DataItem {
    has value: str;
}

def generate_data -> DataItem by llm();

"""A module whose name ends in 'a', for scope name resolution."""

import from jaclang.byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");

obj DataItem {
    has value: str;
}

def generate_data -> DataItem by llm();

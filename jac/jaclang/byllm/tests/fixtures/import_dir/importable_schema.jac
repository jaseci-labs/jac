"""A `by llm()` function imported from another module; the module name ends in 'a'."""

import from jaclang.byllm.lib { MockLLM }

obj ImportedData {
    has name: str;
}

glob llm = MockLLM(
         model_name="mockllm",
         config={"outputs": [ImportedData(name="test_import")], "verbose": False}
     );

def get_imported_data(txt: str) -> ImportedData by llm();

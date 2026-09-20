"""A module whose name ends in 'j', for scope name resolution."""

import from jaclang.byllm.lib { MockLLM }

obj Project {
    has title: str;
}

glob llm = MockLLM(
         model_name="mockllm",
         config={"outputs": [Project(title="test_project")], "verbose": False}
     );

def create_proj -> Project by llm();

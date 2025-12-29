"""Semstrings: Semantic string definitions for LLM-guided functions."""

import from byllm.lib { Model }

glob llm = Model(model_name="mockllm", outputs=["SecureP@ss1"]);

# Function implemented by LLM
def generate_password -> str by llm();

# Semantic definition for the LLM
sem generate_password= """
Password is at least 8 characters, has one uppercase letter,
one lowercase letter, one digit, and one special character.
""";

glob pwd = generate_password();

with entry {
    print(f"Generated: {pwd}");
}

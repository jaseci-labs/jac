"""Semstrings: Semantic string definitions for LLM-guided functions."""

from __future__ import annotations
from jaclang.lib import call_llm, get_mtir, sem
from byllm.lib import Model

llm = Model(model_name="mockllm", outputs=["SecureP@ss1"])


@sem(
    "\nPassword is at least 8 characters, has one uppercase letter,\none lowercase letter, one digit, and one special character.\n",
    {},
)
def generate_password() -> str:
    return call_llm(
        model=llm(),
        mtir=get_mtir(caller=generate_password, args={}, call_params=llm().call_params),
    )


pwd = generate_password()
print(f"Generated: {pwd}")

"""Program under test for jac.toml system-prompt config.

Lives in its own directory because the `[byllm]` block in the jac.toml beside it
is the subject: config is resolved from the module's own location. The test
assigns `llm` and asserts on what was sent.
"""

glob llm: any = None;

def say_hello(name: str) -> str by llm();

# A per-call system_prompt extends the jac.toml base, it does not replace it.
def say_hello_brief(name: str) -> str by llm(
    system_prompt="Respond in three words maximum."
);

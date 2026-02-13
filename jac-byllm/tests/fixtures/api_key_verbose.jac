import from byllm.lib { Model }

def greet(name: str) -> str by Model(
    model_name="gpt-4o-mini",
    api_key="sk-secret-test-key-do-not-leak",
    config={"verbose": True},
)();

with entry {
    print(greet("Alice"));
}

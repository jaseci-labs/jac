import from byllm { Model }
glob llm = Model(model_name="gemini/gemini-2.0-flash");

enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert",
    AMBIVERT = "Ambivert"
}

def get_personality(name: str) -> Personality by llm();

with entry {
    name = "Albert Einstein";
    result = get_personality(name);
    print(f"{result.value} personality detected for {name}");
}
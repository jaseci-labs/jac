import from byllm { Model }

glob llm = Model(model_name="gemini/gemini-2.5-flash");
def this_is_you_agent(input_1: str, input_2: dict[str, list]) -> tuple[int, str] by llm();
def detect_language(text: str) -> str by llm();
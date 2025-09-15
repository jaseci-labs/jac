from byllm import Model, by

llm = Model(model_name="gemini/gemini-2.5-flash")


@by(llm)
def detect_language(text: str) -> str: ...

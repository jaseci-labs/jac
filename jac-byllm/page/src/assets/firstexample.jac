import from byllm { Model }
glob llm = Model(model_name="gemini/gemini-2.5-flash");

#                                 byLLM here
#                                     ||
def detect_language(text: str) -> str by llm();
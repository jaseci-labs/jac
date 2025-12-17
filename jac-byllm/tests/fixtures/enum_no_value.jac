import from byllm.lib { Model }

enum Tell { YES, NO }

glob llm = Model(model_name="gemini/gemini-1.5-flash", config={"verbose": True});

"""Yes/No answering Bot"""
def yes_or_no(question: str) -> Tell by llm();

with entry {
    question: str = "Are you a Human?";
    answer: Tell = yes_or_no(question);
}

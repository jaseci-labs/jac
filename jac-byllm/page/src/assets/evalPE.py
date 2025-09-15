import from byllm {Model}

glob llm = Model(model_name="gpt-4o-mini");

enum Tell {
    YES = "yes", NO = "no"
}

"""Yes/No answering Bot"""
def yes_or_no(question:str) -> Tell by llm();

with entry {
    question: str = "Are you an AI?";
    answer: Tell = yes_or_no(question);
    print(f"Question: {question}");
    print("The bot answered " + answer.value);
}
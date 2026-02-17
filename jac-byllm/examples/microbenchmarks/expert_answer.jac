import from byllm.lib { Model }

glob llm = Model();

def get_expert(question: str) -> str by llm();
def get_answer(question: str, expert: str) -> str by llm();

glob question = "What are Large Language Models?",
     expert = get_expert(question),
     answer = get_answer(question, expert);

with entry {
    print(f"{expert} says: '{answer}' ");
}

import from byllm { Model }

glob llm: Model = Model(model_name="gpt-4o");

enum Priority { LOW, MEDIUM, HIGH, URGENT }

sem assess = "Assess the priority of a support ticket.";

def assess(ticket: str) -> Priority by llm();

with entry {
    print(assess("Checkout is down and customers are leaving!"));
    # Priority.URGENT
}

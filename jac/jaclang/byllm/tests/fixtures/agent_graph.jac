"""Program under test for a supervisor routing to specialist agent nodes.

Shape only. Each agent carries its own `by llm()` method, so a run makes both a
routing call and a generation call through the same model.
"""

glob llm: any = None;

node Team {}

walker supervisor {
    has user_input: str = "",
        answers: list = [];

    # Triggered on Team, not Root: `root` accumulates across tests in a file, so
    # a Root-triggered walker would route over every other test's nodes too.
    can execute with Team entry {
        visit [-->] by llm(incl_info={"User input": self.user_input});
    }
}

node PoemAgent {
    def write_poem(topic: str) -> str by llm();
    can respond with supervisor entry {
        visitor.answers.append(("poem", self.write_poem(visitor.user_input)));
    }
}

node MathAgent {
    def do_math(user_message: str) -> str by llm();
    can respond with supervisor entry {
        visitor.answers.append(("math", self.do_math(visitor.user_input)));
    }
}

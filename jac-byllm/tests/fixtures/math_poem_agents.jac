import from byllm.lib { MockLLM }

glob llm: MockLLM = MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 [0],
                 """In circuits bright, with purpose clear,
        Agentic minds, we hold dear.
        Crafting futures, weaving dreams,
        In digital realms, boundless schemes.
        """,
                 [1],
                 "35"
             ]
         }
     );

walker supervisor {
    has user_input: str = "";

    can execute with `root entry {
        visit [-->] by llm(incl_info={"User input": self.user_input});
    }
}

node PoemAgent {
    def generate_poem_for_topic(topic: str) -> str by llm();
    can create_poem with supervisor entry {
        peom = self.generate_poem_for_topic(visitor.user_input);
        print("Generated Poem:\n" + peom);
    }
}

node MathAgent {
    def do_math(user_message: str) -> str by llm();
    can calculate with supervisor entry {
        result = self.do_math(visitor.user_input);
        print("Math Result: " + result);
    }
}

with entry {
    root ++> PoemAgent();
    root ++> MathAgent();

    user_input_poem = "Write a 4 lines of short poem about Agentic AI";
    supervisor(user_input=user_input_poem) spawn root;

    user_input_math = "What is the result of (15 + 5) * 2 - (10 / 2)?";
    supervisor(user_input=user_input_math) spawn root;
}

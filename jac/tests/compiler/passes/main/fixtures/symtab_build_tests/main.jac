import from action { actions }

with entry {
    openai = actions.LLM();
    agent = actions.Agent();
    print("openai: response: ", openai.testing_infer());
}

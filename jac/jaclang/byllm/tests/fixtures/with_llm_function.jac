import from jaclang.byllm.lib { MockLLM }

glob llm = MockLLM(model_name="mockllm", config={"outputs": ["👤➡️🗼"]}),
     emoji_examples: list[dict[(str, str)]] = [
         {"input": "I love tp drink pina coladas", "output": "👤❤️🥤🍍🥥"},
         {"input": "Mime Person", "output": "👤🤲🚷"}
     ];

def get_emoji(input: str) -> str by llm(
    temperature=0.7, incl_info={"examples": emoji_examples},
);

with entry {
    print(get_emoji('Lets move to paris'));
}

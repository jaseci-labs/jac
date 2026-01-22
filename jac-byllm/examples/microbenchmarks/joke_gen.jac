import from byllm.lib { Model }

glob llm = Model(
         # model_name="gpt-4o",
         model_name="gemini/gemini-2.5-flash",
     );

obj PunclineJokes {
    has jokes: list[dict] = [
        {
            "joke": "How does a penguin build its house?",
            "punchline": "Igloos it together."
        },
        {
            "joke": "Which knight invented King Arthur's Round Table?",
            "punchline": "Sir Cumference."
        }
    ];

    def generate_joke -> dict[str, str] by llm();
    def generate {
        joke_punchline = self.generate_joke();
        self.jokes.append(joke_punchline);
    }
}

sem PunclineJokes.joke = 'Jokes with Punchlines';

glob joke_gen = PunclineJokes();

with entry {
    for i in range(5) {
        joke_gen.generate();
    }
    print(joke_gen.jokes);
}

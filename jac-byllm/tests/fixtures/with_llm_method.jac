import from byllm.lib { MockLLM }

class PersonalityIndex {
    has index: int;
}

enum Personality { INTROVERT, EXTROVERT }

glob llm = MockLLM(
         model_name="mockllm", config={"outputs": [Personality.INTROVERT]}
     ),
     personality_examples: dict[(str, Personality | None)] = {Personality.INTROVERT,Personality.EXTROVERT};

obj Person {
    has name: str,
        age: int;
}

obj outer {
    obj inner {
        has diary_entries: list[str];

        def get_personality(person: list[Person]) -> Personality by llm(
            incl_info={
                "personality_examples": personality_examples,
                "diary_entries": self.diary_entries,

            }
        );
    }
}

glob einstein = Person('Albert Einstein', 76),
     inner_inst = outer.inner(
         ["I won noble prize in Physics", "I am popular for my theory of relativity"]
     );

with entry {
    print(inner_inst.get_personality(einstein));
}

import from byllm.lib { MockLLM }

enum Personality { INTROVERT = "Introvert", EXTROVERT = "Extrovert" }

obj Person {
    has full_name: str,
        yod: int,
        personality: Personality;
}

glob personality_examples: dict[str, Personality] = {Personality.INTROVERT,Personality.EXTROVERT};

glob llm = MockLLM(
         model_name="mockllm",
         config={
             "verbose": True,
             "outputs": [
                 # '[Reasoning] J. Robert Oppenheimer, also known as the "father of the atomic bomb," was a brilliant '
                 # 'theoretical physicist and the director of the Manhattan Project during World War II. He played a crucial '
                 # 'role in developing the first nuclear weapons. However, after witnessing the devastation caused by the '
                 # 'atomic bombs dropped on Hiroshima and Nagasaki, he expressed deep regret and became an advocate for nuclear '
                 # 'disarmament. While he was an exceptional scientist, he was also known for his introspective and philosophical '
                 # 'nature, which suggests an introverted personality.\n'
                 Person(
                     full_name="J. Robert Oppenheimer",
                     yod=1967,
                     personality=Personality.INTROVERT
                 ),

             ]
         },
     );

def get_person_info(name: str) -> Person by llm();

with entry {
    person_obj = get_person_info('Oppenheimer');
    print(
        f"{person_obj.full_name} was a {person_obj.personality.value} person who died in {person_obj.yod}"
    );
}

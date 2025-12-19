import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o");

enum Personality { INTROVERT, EXTROVERT, AMBIVERT }

obj Person {
    has full_name: str,
        yod: int,
        personality: Personality;
}

def get_person_info(img_of_person: Image) -> Person by llm();

glob person_obj = get_person_info(Image("person.png"));

with entry {
    print(
        f"{person_obj.full_name} was a {person_obj.personality} person who died in {person_obj.yod}"
    );
}

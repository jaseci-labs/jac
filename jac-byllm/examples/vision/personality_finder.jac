import from byllm { Model, Image }

glob llm = Model(model_name="gpt-4o");

enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert"
}

obj Person {
    has full_name: str,
        yod: int,
        personality: Personality;
}

can get_person_info(img_of_person: Image) -> Person by llm();

with entry {
    person_obj = get_person_info(Image("person.png"));
    print(
        f"{person_obj.full_name} was a {person_obj.personality.value} person who died in {person_obj.yod}"
    );
}

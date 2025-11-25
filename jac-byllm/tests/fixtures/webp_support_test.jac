import from byllm.lib {MockLLM, Image}
import os;

'Personality of the Person'
enum Personality {
    INTROVERT = "Introvert",
    EXTROVERT = "Extrovert"
}

obj Person {
    has full_name: str,
    year_of_death: str,
    personality: Personality;
}

glob llm = MockLLM(
    # model_name="gpt-4o-mini",
    model_name="mockllm",
    outputs=[
        Person(
            full_name='Albert Einstein',
            year_of_death='1955',
            personality=Personality.EXTROVERT,
        ),
    ],
);

def get_person_info(image_content: Image) -> Person by llm();

with entry {

    person_image = Image(
        os.path.join(
            os.path.dirname(__file__),
            'webp_image_of_person.webp'
        )
    );
    person_obj = get_person_info(person_image);
    print(person_obj);
}

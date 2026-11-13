from dataclasses import dataclass

from jaclang.byllm.lib import Image, MockLLM, by


@dataclass
class Person:
    name: str
    birth_year: int
    description: str


llm = MockLLM(
    # model_name="gpt-4o",
    model_name="mockllm",
    config={
        "outputs": [
            Person(
                name="Alan Turing",
                birth_year=1912,
                description=(
                    "A pioneering mathematician and computer scientist, known for "
                    "his work in developing the concept of a Turing machine and "
                    "for his crucial role in breaking the Enigma code during World "
                    "War II."
                ),
            )
        ]
    },
)


@by(llm)
def get_person_info(img: Image) -> Person: ...


def test_get_person_info(image_path: str) -> Person:
    person = get_person_info(img=Image(image_path))
    return person

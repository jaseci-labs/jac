import from byllm.lib { Model }

obj Employer {
    has employer_name: str,
        location: str;
}

obj Person {
    has name: str,
        age: int,
        employer: Employer,
        job: str;
}

glob llm = Model(
    # model_name="gpt-4o",
    model_name="mockllm",
    print_prompt=True,
    outputs=[
        Person(
            name='Steve Jobs',
            age=56,
            employer=Employer(employer_name='Apple Inc.', location='California'),
            job='CEO'
        )
    ]
);

def generate_person(info: str) -> Person by llm();

glob person = generate_person(
    "Steve Jobs was 56 years old and worked as the CEO of Apple Inc. in California."
);

with entry {
    print(
        f"Person's name is {person.name} and works at {person.employer.employer_name} which is located in {person.employer.location}."
    );
}

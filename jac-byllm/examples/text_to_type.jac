import from byllm { Model }

glob llm = Model(
    # model_name="gpt-4o",
    model_name="mockllm",
    print_prompt=True,
    outputs=[
        Person(name='Chandra', age=28, employer=Employer(employer_name='Jaseci Labs', location='Sri Lanka'), job='ML Engineer')
    ]
);


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

def generate_person() -> Person by llm(
    incl_info={
        "info": "Chandra is a 28 years old and works as an ML engineer at Jaseci Labs in Sri Lanka."
    }
);

with entry {
    person = generate_person();
    print(
        f"Person's name is {person.name} and works at {person.employer.employer_name} which is located in {person.employer.location}."
    );
}

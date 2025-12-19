import from byllm.lib { MockLLM }

obj Person {
    has name: str,
        dob: str,
        age: int;
}

obj University {
    has name: str,
        location: str,
        departments: list[self.Department] = [];

    obj Department {
        has name: str,
            head: Person;
    }
}

glob llm1 = MockLLM(
         model_name="mockllm",
         config={"outputs": [Person(name='Albert Einstein', dob='14/03/1879', age=76)]}
     ),
     llm2 = MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 University.Department(
                     name='Computer Science',
                     head=Person(name='Jason Mars', dob='1994-01-01', age=30)
                 ),
                 University.Department(
                     name='Computer Science',
                     head=Person(name='Jason Mars', dob='1994-01-01', age=30)
                 )
             ]
         }
     );

def make_person(name: str) -> Person by llm1();
def make_department(name: str) -> University.Department by llm2();

glob einstein: Person = make_person("Albert Einstein");

with entry {
    print(einstein.dob);  #14/03/1879
}

glob umich: University = University(
         name="University of Michigan", location="Ann Arbor, Michigan"
     ),
     cs_department: University.Department = make_department("Computer Science");

with entry {
    print(cs_department.head);  # Person(name='Jason Mars', dob='1994-01-01', age=30)
    umich.departments.append(make_department("Computer Science"));
    print(umich.departments[0].head);  # Person(name='Jason Mars', dob='1994-01-01', age=30)
}

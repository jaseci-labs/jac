# Edge reference chain with subscripted start expression
node Person {
    has name: str;
}

edge Knows;

glob people = root ++> Person(name="Alice"),
     friends = [people[0]->:Knows:->(?:Person)];

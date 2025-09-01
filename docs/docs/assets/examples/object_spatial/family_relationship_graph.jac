node Person {
    has name: str;
    has age: int;
}

edge FamilyRelation {
    # Edges can also have properties
    has relationship_type: str;
}

with entry {
    # First, let's create our family members as nodes
    parent = root ++> Person(name="John", age=45);
    child1 = root ++> Person(name="Alice", age=20);
    child2 = root ++> Person(name="Bob", age=18);

    # Now, let's create the relationships between them
    parent +>:FamilyRelation(relationship_type="parent"):+> child1;
    parent +>:FamilyRelation(relationship_type="parent"):+> child2;
    child1 +>:FamilyRelation(relationship_type="sibling"):+> child2;

     # You can now ask questions about these relationships
    children = [parent[0]->:FamilyRelation:relationship_type=="parent":->(`?Person)];

    print(f"{parent[0].name} has {len(children)} children:");
    for child in children {
        print(f"  - {child.name} (age {child.age})");
    }
}
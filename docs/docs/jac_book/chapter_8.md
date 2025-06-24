# Chapter 8: OSP Introduction and Paradigm Shift

Object-Spatial Programming (OSP) represents a fundamental shift in how we think about and organize computation. Instead of the traditional approach of moving data to computation, OSP moves computation to data. This chapter introduces this revolutionary paradigm through simple examples that demonstrate the power and elegance of spatial thinking.

!!! topic "The Core Paradigm Shift"
    Traditional programming brings all data to a central location for processing. OSP sends computation to where the data lives, creating more natural, efficient, and scalable programs.

## From "Data to Computation" to "Computation to Data"

!!! topic "Traditional vs Object-Spatial"
    Understanding the difference between these approaches is key to unlocking the power of Jac's unique programming model.

### Traditional Programming: Centralized Processing

In traditional programming, we gather all data in one place and then process it:

!!! example "Traditional Data Processing"
    === "Jac (Traditional Style)"
        <div class="code-block">
        ```jac
        # Traditional approach - bring all data to one place
        obj FamilyTraditional {
            has members: list[dict] = [];

            def add_member(name: str, age: int, generation: int) -> None {
                self.members.append({
                    "name": name,
                    "age": age,
                    "generation": generation
                });
            }

            def count_by_generation() -> dict[int, int] {
                counts = {};
                # Process all data in one loop
                for member in self.members {
                    gen = member["generation"];
                    counts[gen] = counts.get(gen, 0) + 1;
                }
                return counts;
            }
        }

        with entry {
            family = FamilyTraditional();

            # Add all family members
            family.add_member("Grandpa Joe", 75, 1);
            family.add_member("Grandma Sue", 72, 1);
            family.add_member("Dad Mike", 45, 2);
            family.add_member("Mom Lisa", 43, 2);
            family.add_member("Son Alex", 16, 3);
            family.add_member("Daughter Emma", 14, 3);

            # Process all data centrally
            generation_counts = family.count_by_generation();
            print(f"Generation counts: {generation_counts}");
        }
        ```
        </div>
    === "Python"
        ```python
        class FamilyTraditional:
            def __init__(self):
                self.members = []

            def add_member(self, name: str, age: int, generation: int):
                self.members.append({
                    "name": name,
                    "age": age,
                    "generation": generation
                })

            def count_by_generation(self):
                counts = {}
                # Process all data in one loop
                for member in self.members:
                    gen = member["generation"]
                    counts[gen] = counts.get(gen, 0) + 1
                return counts

        if __name__ == "__main__":
            family = FamilyTraditional()

            # Add all family members
            family.add_member("Grandpa Joe", 75, 1)
            family.add_member("Grandma Sue", 72, 1)
            family.add_member("Dad Mike", 45, 2)
            family.add_member("Mom Lisa", 43, 2)
            family.add_member("Son Alex", 16, 3)
            family.add_member("Daughter Emma", 14, 3)

            # Process all data centrally
            generation_counts = family.count_by_generation()
            print(f"Generation counts: {generation_counts}")
        ```

### Object-Spatial Programming: Distributed Processing

In OSP, computation moves to where the data naturally lives:

!!! example "Object-Spatial Family Tree"
    === "Jac"
        <div class="code-block">
        ```jac
        # OSP approach - computation goes to data
        node Person {
            has name: str;
            has age: int;
            has generation: int;
        }

        edge Relationship{}
        edge MarriedTo(Relationship){}
        edge ParentOf(Relationship){}

        walker GenerationCounter {
            has generation_counts: dict[int, int] = {};
            has visited: set[Person] = set();

            can count with Person entry {
                if here in self.visited {
                    return;  # Skip if already visited
                }

                self.visited.add(here);  # Mark this person as visited

                # Computation happens AT each person
                gen = here.generation;
                self.generation_counts[gen] = self.generation_counts.get(gen, 0) + 1;

                visit [<-:MarriedTo:->];  # Visit married partners

                print(f"Counted {here.name} (Generation {gen})");

                # Visit children
                visit [->:ParentOf:->];
            }
        }

        with entry {
            # Create family tree structure
            grandpa = root ++> Person(name="Grandpa Joe", age=75, generation=1);
            grandma = root ++> Person(name="Grandma Sue", age=72, generation=1);

            grandpa <+:MarriedTo:+> grandma;  # Connect grandparents

            # Second generation
            dad = grandpa[0] +>:ParentOf:+> Person(name="Dad Mike", age=45, generation=2);
            mom = grandma[0] +>:ParentOf:+> Person(name="Mom Lisa", age=43, generation=2);
            dad <+:MarriedTo:+> mom;  # Connect parents

            # Third generation
            son = dad[0] +>:ParentOf:+> Person(name="Son Alex", age=16, generation=3);
            daughter = mom[0] +>:ParentOf:+> Person(name="Daughter Emma", age=14, generation=3);

            # Send computation to the data
            counter = GenerationCounter();
            counter spawn grandpa[0];  # Start traversal from grandpa

            print(f"Final counts: {counter.generation_counts}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python simulation of OSP concepts
        class Person:
            def __init__(self, name: str, age: int, generation: int):
                self.name = name
                self.age = age
                self.generation = generation
                self.children = []

            def add_child(self, child):
                self.children.append(child)

        class GenerationCounter:
            def __init__(self):
                self.generation_counts = {}

            def count(self, person):
                # Simulate "computation goes to data"
                gen = person.generation
                self.generation_counts[gen] = self.generation_counts.get(gen, 0) + 1

                print(f"Counted {person.name} (Generation {gen})")

                # Visit children recursively
                for child in person.children:
                    self.count(child)

        if __name__ == "__main__":
            # Create family tree structure
            grandpa = Person("Grandpa Joe", 75, 1)
            grandma = Person("Grandma Sue", 72, 1)

            # Second generation
            dad = Person("Dad Mike", 45, 2)
            mom = Person("Mom Lisa", 43, 2)
            grandpa.add_child(dad)
            grandma.add_child(mom)

            # Third generation
            son = Person("Son Alex", 16, 3)
            daughter = Person("Daughter Emma", 14, 3)
            dad.add_child(son)
            mom.add_child(daughter)

            # Send computation to the data
            counter = GenerationCounter()
            counter.count(grandpa)  # Start traversal from grandpa

            print(f"Final counts: {counter.generation_counts}")
        ```

## Data Spatial Programming Foundation

!!! topic "Spatial Awareness"
    In OSP, data structures are inherently spatial - they know their relationships and can react to visitors. This creates more intuitive and natural program organization.

### Spatial Relationships in Data

!!! example "Family Relationships"
    === "Jac"
        <div class="code-block">
        ```jac
        node FamilyMember {
            has name: str;
            has birth_year: int;

            def get_age() -> int {
                return 2024 - self.birth_year;
            }
        }

        edge MarriedTo {
            has marriage_year: int;

            def get_marriage_duration() -> int {
                return 2024 - self.marriage_year;
            }
        }

        edge ChildOf {
            has birth_order: int;  # 1st child, 2nd child, etc.
        }

        walker RelationshipFinder {
            has relationships: list[str] = [];

            can find_relationships with FamilyMember entry {
                name = here.name;

                # Find spouse
                spouses= [->:MarriedTo:->];
                for spouse in spouses {
                    duration = [edge here --> spouse][0].get_marriage_duration();
                    self.relationships.append(f"{name} married to {spouse.name} for {duration} years");
                }

                # Find children
                children = [->:ChildOf:->];
                if children {
                    child_names = [child.name for child in children];
                    self.relationships.append(f"{name} has children: {', '.join(child_names)}");
                }

                # Continue exploring family tree
                visit [-->];
            }
        }

        with entry {
            # Create a simple family
            john = root ++> FamilyMember(name="John", birth_year=1980);
            mary = root ++> FamilyMember(name="Mary", birth_year=1982);

            # Marriage relationship
            john[0] +>:MarriedTo(marriage_year=2005):+> mary;

            # Children
            alice = john[0] +>:ChildOf(birth_order=1):+> FamilyMember(name="Alice", birth_year=2008);
            bob = john[0] +>:ChildOf(birth_order=2):+> FamilyMember(name="Bob", birth_year=2010);

            # Explore relationships
            finder = RelationshipFinder();
            finder spawn john[0];

            for relationship in finder.relationships {
                print(relationship);
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        class FamilyMember:
            def __init__(self, name: str, birth_year: int):
                self.name = name
                self.birth_year = birth_year
                self.spouse = None
                self.children = []
                self.marriage_year = None

            def get_age(self) -> int:
                return 2024 - self.birth_year

            def marry(self, spouse, marriage_year: int):
                self.spouse = spouse
                self.marriage_year = marriage_year
                spouse.spouse = self
                spouse.marriage_year = marriage_year

            def add_child(self, child):
                self.children.append(child)

        class RelationshipFinder:
            def __init__(self):
                self.relationships = []
                self.visited = set()

            def find_relationships(self, person: FamilyMember):
                if person in self.visited:
                    return

                self.visited.add(person)
                name = person.name

                # Find spouse
                if person.spouse:
                    duration = 2024 - person.marriage_year
                    self.relationships.append(f"{name} married to {person.spouse.name} for {duration} years")

                # Find children
                if person.children:
                    child_names = [child.name for child in person.children]
                    self.relationships.append(f"{name} has children: {', '.join(child_names)}")

                # Continue exploring family tree
                if person.spouse:
                    self.find_relationships(person.spouse)
                for child in person.children:
                    self.find_relationships(child)

        if __name__ == "__main__":
            # Create a simple family
            john = FamilyMember("John", 1980)
            mary = FamilyMember("Mary", 1982)

            # Marriage relationship
            john.marry(mary, 2005)

            # Children
            alice = FamilyMember("Alice", 2008)
            bob = FamilyMember("Bob", 2010)
            john.add_child(alice)
            john.add_child(bob)

            # Explore relationships
            finder = RelationshipFinder()
            finder.find_relationships(john)

            for relationship in finder.relationships:
                print(relationship)
        ```

## Graph Thinking vs Object Thinking

!!! topic "Mental Models"
    OSP encourages thinking in terms of connections and relationships rather than isolated objects. This leads to more natural representations of real-world problems.

### Object-Oriented Thinking

In traditional OOP, we think about individual objects with their own data and methods:

```python
# Traditional OO thinking - isolated objects
class Student:
    def __init__(self, name):
        self.name = name
        self.grades = []

    def add_grade(self, grade):
        self.grades.append(grade)

class Teacher:
    def __init__(self, name):
        self.name = name
        self.students = []  # List of student references

    def add_student(self, student):
        self.students.append(student)
```

### Graph-Oriented Thinking

In OSP, we think about entities and their relationships as a connected graph:

!!! example "Classroom as a Graph"
    === "Jac"
        <div class="code-block">
        ```jac
        # Graph thinking - connected entities
        node Student {
            has name: str;
            has grade_level: int;
        }

        node Teacher {
            has name: str;
            has subject: str;
        }

        edge Teaches {
            has semester: str;
            has classroom: str;
        }

        edge Attends {
            has grade: str = "Not Set";
        }

        walker ClassroomAnalyzer {
            has teacher_student_count: dict[str, int] = {};
            has student_subjects: dict[str, list[str]] = {};

            can analyze_teacher with Teacher entry {
                # Count students for this teacher
                students = [->:Teaches:->];
                self.teacher_student_count[here.name] = len(students);

                print(f"{here.name} teaches {here.subject} to {len(students)} students");

                # Visit students to gather more info
                visit students;
            }

            can analyze_student with Student entry {
                # Find what subjects this student takes
                teachers = [<-:Teaches:<-];
                subjects = [teacher.subject for teacher in teachers];
                self.student_subjects[here.name] = subjects;

                print(f"{here.name} (Grade {here.grade_level}) takes: {', '.join(subjects)}");
            }
        }

        with entry {
            # Create classroom graph
            ms_smith = Teacher(name="Ms. Smith", subject="Math");
            mr_jones = Teacher(name="Mr. Jones", subject="Science");

            # Create students
            alice = Student(name="Alice", grade_level=9);
            bob = Student(name="Bob", grade_level=9);
            charlie = Student(name="Charlie", grade_level=10);

            # Create teaching relationships
            ms_smith +>:Teaches(semester="Fall 2024", classroom="Room 101"):+> alice;
            ms_smith +>:Teaches(semester="Fall 2024", classroom="Room 101"):+> bob;
            mr_jones +>:Teaches(semester="Fall 2024", classroom="Room 205"):+> alice;
            mr_jones +>:Teaches(semester="Fall 2024", classroom="Room 205"):+> charlie;

            # Analyze the classroom network
            analyzer = ClassroomAnalyzer();
            analyzer spawn ms_smith;
            analyzer spawn mr_jones;



            print(f"Teacher-student counts: {analyzer.teacher_student_count}");
            print(f"Student subjects: {analyzer.student_subjects}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict

        class Student:
            def __init__(self, name: str, grade_level: int):
                self.name = name
                self.grade_level = grade_level
                self.teachers = []  # References to teachers

        class Teacher:
            def __init__(self, name: str, subject: str):
                self.name = name
                self.subject = subject
                self.students = []  # References to students

            def add_student(self, student: Student):
                self.students.append(student)
                student.teachers.append(self)

        class ClassroomAnalyzer:
            def __init__(self):
                self.teacher_student_count = {}
                self.student_subjects = {}
                self.visited = set()

            def analyze(self, entity):
                if entity in self.visited:
                    return

                self.visited.add(entity)

                if isinstance(entity, Teacher):
                    # Count students for this teacher
                    self.teacher_student_count[entity.name] = len(entity.students)
                    print(f"{entity.name} teaches {entity.subject} to {len(entity.students)} students")

                    # Visit students
                    for student in entity.students:
                        self.analyze(student)

                elif isinstance(entity, Student):
                    # Find what subjects this student takes
                    subjects = [teacher.subject for teacher in entity.teachers]
                    self.student_subjects[entity.name] = subjects
                    print(f"{entity.name} (Grade {entity.grade_level}) takes: {', '.join(subjects)}")

        if __name__ == "__main__":
            # Create classroom network
            ms_smith = Teacher("Ms. Smith", "Math")
            mr_jones = Teacher("Mr. Jones", "Science")

            # Create students
            alice = Student("Alice", 9)
            bob = Student("Bob", 9)
            charlie = Student("Charlie", 10)

            # Create teaching relationships
            ms_smith.add_student(alice)
            ms_smith.add_student(bob)
            mr_jones.add_student(alice)
            mr_jones.add_student(charlie)

            # Analyze the classroom network
            analyzer = ClassroomAnalyzer()
            analyzer.analyze(ms_smith)
            analyzer.analyze(mr_jones)

            print(f"Teacher-student counts: {analyzer.teacher_student_count}")
            print(f"Student subjects: {analyzer.student_subjects}")
        ```

## Benefits of the OSP Paradigm

!!! topic "Why OSP Matters"
    The spatial approach to programming offers several key advantages over traditional centralized processing.

### Natural Problem Modeling

OSP allows you to model problems the way they naturally exist in the real world:

!!! example "Three-Generation Family Tree"
    === "Jac"
        <div class="code-block">
        ```jac
        node Person {
            has name: str;
            has birth_year: int;
            has generation: int;

            def get_age() -> int {
                return 2024 - self.birth_year;
            }
        }

        edge ParentChild {
            has relationship: str;  # "father", "mother", "son", "daughter"
        }

        walker FamilyTreeExplorer {
            has family_info: list[str] = [];

            can explore with Person entry {
                age = here.get_age();
                gen = here.generation;

                # Find parents
                parents = [<-:ParentChild:<-];
                parent_names = [p.name for p in parents];

                # Find children
                children = [->:ParentChild:->];
                child_names = [c.name for c in children];

                info = f"Generation {gen}: {here.name} (age {age})";
                if parent_names {
                    info += f" - Parents: {', '.join(parent_names)}";
                }
                if child_names {
                    info += f" - Children: {', '.join(child_names)}";
                }

                self.family_info.append(info);

                # Continue exploring
                visit [->:ParentChild:->];
            }
        }

        with entry {
            # Generation 1 (Grandparents)
            grandpa = root ++> Person(name="Robert", birth_year=1945, generation=1);
            grandma = root ++> Person(name="Helen", birth_year=1948, generation=1);

            # Generation 2 (Parents)
            dad = grandpa[0] +>:ParentChild(relationship="father"):+> Person(name="Michael", birth_year=1975, generation=2);
            mom = grandma[0] +>:ParentChild(relationship="mother"):+> Person(name="Sarah", birth_year=1977, generation=2);

            # Generation 3 (Children)
            son = dad[0] +>:ParentChild(relationship="father"):+> Person(name="David", birth_year=2005, generation=3);
            daughter = mom[0] +>:ParentChild(relationship="mother"):+> Person(name="Emma", birth_year=2007, generation=3);
            youngest = dad[0] +>:ParentChild(relationship="father"):+> Person(name="Luke", birth_year=2010, generation=3);

            # Explore the family tree
            explorer = FamilyTreeExplorer();
            explorer spawn grandpa[0];

            print("=== Family Tree ===");
            for info in explorer.family_info {
                print(info);
            }
        }
        ```
        </div>
    === "Python"
        ```python
        class Person:
            def __init__(self, name: str, birth_year: int, generation: int):
                self.name = name
                self.birth_year = birth_year
                self.generation = generation
                self.parents = []
                self.children = []

            def get_age(self) -> int:
                return 2024 - self.birth_year

            def add_child(self, child):
                self.children.append(child)
                child.parents.append(self)

        class FamilyTreeExplorer:
            def __init__(self):
                self.family_info = []
                self.visited = set()

            def explore(self, person: Person):
                if person in self.visited:
                    return

                self.visited.add(person)

                age = person.get_age()
                gen = person.generation

                # Find family relationships
                parent_names = [p.name for p in person.parents]
                child_names = [c.name for c in person.children]

                info = f"Generation {gen}: {person.name} (age {age})"
                if parent_names:
                    info += f" - Parents: {', '.join(parent_names)}"
                if child_names:
                    info += f" - Children: {', '.join(child_names)}"

                self.family_info.append(info)

                # Continue exploring
                for child in person.children:
                    self.explore(child)

        if __name__ == "__main__":
            # Generation 1 (Grandparents)
            grandpa = Person("Robert", 1945, 1)
            grandma = Person("Helen", 1948, 1)

            # Generation 2 (Parents)
            dad = Person("Michael", 1975, 2)
            mom = Person("Sarah", 1977, 2)
            grandpa.add_child(dad)
            grandma.add_child(mom)

            # Generation 3 (Children)
            son = Person("David", 2005, 3)
            daughter = Person("Emma", 2007, 3)
            youngest = Person("Luke", 2010, 3)
            dad.add_child(son)
            mom.add_child(daughter)
            dad.add_child(youngest)

            # Explore the family tree
            explorer = FamilyTreeExplorer()
            explorer.explore(grandpa)

            print("=== Family Tree ===")
            for info in explorer.family_info:
                print(info)
        ```

## Key Takeaways

!!! summary "OSP Paradigm Fundamentals"
    - **Computation to Data**: Instead of gathering data centrally, send computation to where data lives
    - **Spatial Relationships**: Model data with its natural connections and relationships
    - **Graph Thinking**: Think in terms of nodes, edges, and traversal patterns
    - **Natural Modeling**: Represent real-world problems in their natural graph structure
    - **Distributed Processing**: Each piece of data can be processed independently where it lives

The Object-Spatial Programming paradigm opens up new ways of thinking about and solving problems. By modeling the world as connected entities rather than isolated objects, we create more intuitive, efficient, and scalable programs.

In the next chapter, we'll dive deeper into the building blocks of OSP: nodes and edges, and learn how to create rich, connected data structures that form the foundation of your spatial programs.

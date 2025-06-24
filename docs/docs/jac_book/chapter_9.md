# Chapter 9: Nodes and Edges

**Nodes** and **Edges** are the fundamental building blocks of Object-Spatial Programming. Nodes represent data locations in your graph, while edges represent the relationships between them. This chapter shows you how to create, connect, and work with these spatial constructs using a simple classroom management system.

!!! topic "Graph-Based Data Modeling"
    Instead of storing data in isolated objects, OSP organizes data as connected nodes in a graph. This makes relationships explicit and enables powerful traversal patterns.

## Node Creation and Properties
Nodes are the primary objects in Jac, representing entities like students, teachers, classrooms, etc. They can have properties and can be connected to other nodes through edges. Nodes can be created with the `node` keyword, and they automatically persist when connected to the root node.


!!! topic "What are Nodes?"
    Nodes are special objects that can be connected to other nodes through edges. They automatically persist when connected to the root node and can react to visiting walkers.

### Basic Node Declaration


!!! example "Simple Node Types"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic node for representing students
        node Student {
            has name: str;
            has age: int;
            has grade_level: int;
            has student_id: str;
        }

        # Basic node for representing teachers
        node Teacher {
            has name: str;
            has subject: str;
            has years_experience: int;
            has email: str;
        }

        with entry {
            # Create student nodes
            alice = Student(
                name="Alice Johnson",
                age=16,
                grade_level=10,
                student_id="S001"
            );

            bob = Student(
                name="Bob Smith",
                age=15,
                grade_level=9,
                student_id="S002"
            );

            # Create teacher node
            ms_brown = Teacher(
                name="Ms. Brown",
                subject="Mathematics",
                years_experience=8,
                email="brown@school.edu"
            );

            print(f"Created student: {alice.name} (Grade {alice.grade_level})");
            print(f"Created teacher: {ms_brown.name} teaches {ms_brown.subject}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python equivalent using regular classes
        class Student:
            def __init__(self, name: str, age: int, grade_level: int, student_id: str):
                self.name = name
                self.age = age
                self.grade_level = grade_level
                self.student_id = student_id

        class Teacher:
            def __init__(self, name: str, subject: str, years_experience: int, email: str):
                self.name = name
                self.subject = subject
                self.years_experience = years_experience
                self.email = email

        if __name__ == "__main__":
            # Create student objects
            alice = Student(
                name="Alice Johnson",
                age=16,
                grade_level=10,
                student_id="S001"
            )

            bob = Student(
                name="Bob Smith",
                age=15,
                grade_level=9,
                student_id="S002"
            )

            # Create teacher object
            ms_brown = Teacher(
                name="Ms. Brown",
                subject="Mathematics",
                years_experience=8,
                email="brown@school.edu"
            )

            print(f"Created student: {alice.name} (Grade {alice.grade_level})")
            print(f"Created teacher: {ms_brown.name} teaches {ms_brown.subject}")
        ```

### Node Persistence with Root

!!! topic "The Root Node"
    Nodes connected to `root` (directly or indirectly) automatically persist between program runs. This gives you a database-like behavior without setup.

!!! example "Persistent Classroom Data"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic node for representing students
        node Student {
            has name: str;
            has age: int;
            has grade_level: int;
            has student_id: str;
        }

        node Classroom {
            has room_number: str;
            has capacity: int;
            has has_projector: bool = True;
        }

        with entry {
            # Connect to root for persistence
            math_room = root ++> Classroom(
                room_number="101",
                capacity=30,
                has_projector=True
            );

            # Also persistent (connected through math_room)
            alice = math_room ++> Student(
                name="Alice Johnson",
                age=16,
                grade_level=10,
                student_id="S001"
            );

            # Temporary node (not connected to root)
            temp_student = Student(
                name="Temporary",
                age=15,
                grade_level=9,
                student_id="TEMP"
            );

            print(f"Persistent classroom: {math_room[0].room_number}");
            print(f"Persistent student: {alice[0].name}");
            print(f"Temporary student: {temp_student.name} (will not persist)");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python simulation using a simple registry
        class NodeRegistry:
            def __init__(self):
                self.nodes = {}
                self.connections = {}

            def add_node(self, node_id: str, node):
                self.nodes[node_id] = node
                self.connections[node_id] = []

            def connect(self, from_id: str, to_id: str):
                if from_id in self.connections:
                    self.connections[from_id].append(to_id)

        class Classroom:
            def __init__(self, room_number: str, capacity: int, has_projector: bool = True):
                self.room_number = room_number
                self.capacity = capacity
                self.has_projector = has_projector

        if __name__ == "__main__":
            # Simulate persistence with a registry
            registry = NodeRegistry()

            # Create classroom
            math_room = Classroom(
                room_number="101",
                capacity=30,
                has_projector=True
            )
            registry.add_node("math_room", math_room)

            # Create student connected to classroom
            alice = Student(
                name="Alice Johnson",
                age=16,
                grade_level=10,
                student_id="S001"
            )
            registry.add_node("alice", alice)
            registry.connect("math_room", "alice")

            # Temporary object (not in registry)
            temp_student = Student(
                name="Temporary",
                age=15,
                grade_level=9,
                student_id="TEMP"
            )

            print(f"Registered classroom: {math_room.room_number}")
            print(f"Registered student: {alice.name}")
            print(f"Temporary student: {temp_student.name} (not registered)")
        ```

## Edge Types and Relationships
Edges in Jac represent relationships between nodes. They are first-class objects with their own properties and behaviors, allowing you to model complex interactions like enrollment, teaching, and friendships. Edges can be created using the `edge` keyword, and they connect nodes in meaningful ways.

!!! topic "First-Class Relationships"
    Edges in Jac are not just connections - they're full objects with their own properties and behaviors. This makes relationships as important as the data they connect.

### Basic Edge Declaration

!!! example "Classroom Relationships"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "docs/examples/chapter_10_school.jac:1:158"
        ```
        </div>
    === "Python"
        ```python
        from typing import List, Dict
        import uuid

        class Edge:
            def __init__(self, edge_type: str, from_node, to_node, **properties):
                self.id = str(uuid.uuid4())
                self.edge_type = edge_type
                self.from_node = from_node
                self.to_node = to_node
                self.properties = properties

        class EnrolledIn(Edge):
            def __init__(self, from_node, to_node, enrollment_date: str, grade: str = "Not Assigned", attendance_rate: float = 100.0):
                super().__init__("EnrolledIn", from_node, to_node)
                self.enrollment_date = enrollment_date
                self.grade = grade
                self.attendance_rate = attendance_rate

        class Teaches(Edge):
            def __init__(self, from_node, to_node, start_date: str, schedule: str, is_primary: bool = True):
                super().__init__("Teaches", from_node, to_node)
                self.start_date = start_date
                self.schedule = schedule
                self.is_primary = is_primary

        class FriendsWith(Edge):
            def __init__(self, from_node, to_node, since: str, closeness: int = 5):
                super().__init__("FriendsWith", from_node, to_node)
                self.since = since
                self.closeness = closeness

        class GraphDatabase:
            def __init__(self):
                self.nodes = {}
                self.edges = []

            def add_node(self, node):
                node.id = str(uuid.uuid4())
                self.nodes[node.id] = node
                return node

            def add_edge(self, edge):
                self.edges.append(edge)
                return edge

        if __name__ == "__main__":
            db = GraphDatabase()

            # Create nodes
            math_class = db.add_node(Classroom(room_number="101", capacity=30))
            alice = db.add_node(Student(name="Alice", age=16, grade_level=10, student_id="S001"))
            bob = db.add_node(Student(name="Bob", age=16, grade_level=10, student_id="S002"))
            ms_brown = db.add_node(Teacher(name="Ms. Brown", subject="Math", years_experience=8, email="brown@school.edu"))

            # Create edges with properties
            db.add_edge(EnrolledIn(
                alice, math_class,
                enrollment_date="2024-08-15",
                grade="A",
                attendance_rate=95.0
            ))

            db.add_edge(EnrolledIn(
                bob, math_class,
                enrollment_date="2024-08-15",
                grade="B+",
                attendance_rate=88.0
            ))

            db.add_edge(Teaches(
                ms_brown, math_class,
                start_date="2024-08-01",
                schedule="MWF 9:00-10:00",
                is_primary=True
            ))

            db.add_edge(FriendsWith(
                alice, bob,
                since="2023-09-01",
                closeness=8
            ))

            print("Classroom connections created successfully!")
            print(f"Database has {len(db.nodes)} nodes and {len(db.edges)} edges")
        ```

## Graph Creation Syntax

!!! topic "Connection Operators"
    Jac provides intuitive syntax for connecting nodes: `++>` creates a new connection, while `-->` references existing connections.

### Connection Patterns
Let's see how to create and connect nodes using Jac's syntax. You can create nodes and connect them in a single expression, which makes it easy to build complex relationships. The example below shows how to create a classroom, add a teacher, and enroll students in that classroom.

!!! example "Building a Complete Classroom"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "docs/examples/chapter_10_school.jac:1:158"
        ```
        </div>
    === "Python"
        ```python
        if __name__ == "__main__":
            db = GraphDatabase()

            # Create the main classroom
            science_lab = db.add_node(Classroom(
                room_number="Lab-A",
                capacity=24,
                has_projector=True
            ))

            # Create teacher
            dr_smith = db.add_node(Teacher(
                name="Dr. Smith",
                subject="Chemistry",
                years_experience=12,
                email="smith@school.edu"
            ))

            # Connect teacher to classroom
            db.add_edge(Teaches(
                dr_smith, science_lab,
                start_date="2024-08-01",
                schedule="TR 10:00-11:30"
            ))

            # Create students and enroll them
            students = [
                ("Charlie", 17, 11, "S003"),
                ("Diana", 16, 11, "S004"),
                ("Eve", 17, 11, "S005")
            ]

            for name, age, grade, id in students:
                student = db.add_node(Student(
                    name=name,
                    age=age,
                    grade_level=grade,
                    student_id=id
                ))

                db.add_edge(EnrolledIn(
                    student, science_lab,
                    enrollment_date="2024-08-15",
                    attendance_rate=92.0
                ))

                print(f"Enrolled {student.name} in {science_lab.room_number}")

            print(f"Created classroom {science_lab.room_number} with {dr_smith.name}")
            print(f"Total nodes: {len(db.nodes)}, Total edges: {len(db.edges)}")
        ```

## Graph Navigation and Filtering

!!! topic "Traversal Syntax"
    Jac provides powerful syntax for navigating graphs: `[-->]` gets outgoing connections, `[<--]` gets incoming connections, and filters can be applied to find specific nodes or edges.

### Basic Navigation

!!! example "Finding Connected Nodes"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "docs/examples/chapter_10_school.jac:1:166"
        ```
        </div>
    === "Python"
        ```python
        class ClassroomExplorer:
            def __init__(self, db: GraphDatabase):
                self.db = db

            def explore_classroom(self, classroom):
                print(f"=== Exploring {classroom.room_number} ===")

                # Find all students enrolled in this classroom
                students = []
                for edge in self.db.edges:
                    if (isinstance(edge, EnrolledIn) and
                        edge.to_node == classroom):
                        students.append(edge.from_node)

                print(f"Students enrolled: {len(students)}")
                for student in students:
                    print(f"  - {student.name} (ID: {student.student_id})")

                # Find the teacher
                teachers = []
                for edge in self.db.edges:
                    if (isinstance(edge, Teaches) and
                        edge.to_node == classroom):
                        teachers.append(edge.from_node)

                if teachers:
                    teacher = teachers[0]
                    print(f"Teacher: {teacher.name} ({teacher.subject})")

                # Show classroom info
                equipment = "Projector" if classroom.has_projector else "No projector"
                print(f"Equipment: {equipment}")
                print(f"Capacity: {classroom.capacity} students")

        if __name__ == "__main__":
            # Continuing from previous example...
            explorer = ClassroomExplorer(db)

            # Find all classrooms and explore them
            classrooms = [node for node in db.nodes.values()
                         if isinstance(node, Classroom)]

            for classroom in classrooms:
                explorer.explore_classroom(classroom)
        ```

### Advanced Filtering

!!! example "Filtered Graph Queries"
    === "Jac"
        <div class="code-block">
        ```jac
        --8<-- "docs/examples/chapter_10_school.jac:1:177"
        ```
        </div>
    === "Python"
        ```python
        class StudentAnalyzer:
            def __init__(self, db: GraphDatabase):
                self.db = db
                self.high_performers = []
                self.needs_help = []

            def analyze_all_students(self):
                # Find all students
                students = [node for node in self.db.nodes.values()
                           if isinstance(node, Student)]

                for student in students:
                    self.analyze_student(student)

                self.generate_report()

            def analyze_student(self, student):
                # Find enrollment information for this student
                for edge in self.db.edges:
                    if (isinstance(edge, EnrolledIn) and
                        edge.from_node == student):

                        grade = edge.grade
                        attendance = edge.attendance_rate

                        # Categorize students
                        if grade in ["A", "A-", "B+"] and attendance >= 90.0:
                            self.high_performers.append({
                                "name": student.name,
                                "grade": grade,
                                "attendance": attendance
                            })
                        elif attendance < 85.0 or grade in ["D", "F"]:
                            self.needs_help.append({
                                "name": student.name,
                                "grade": grade,
                                "attendance": attendance
                            })

            def generate_report(self):
                print("=== Student Analysis Report ===")

                print(f"High Performers ({len(self.high_performers)}):")
                for student in self.high_performers:
                    print(f"  {student['name']}: {student['grade']} grade, {student['attendance']:.1f}% attendance")

                print(f"Needs Support ({len(self.needs_help)}):")
                for student in self.needs_help:
                    print(f"  {student['name']}: {student['grade']} grade, {student['attendance']:.1f}% attendance")

        if __name__ == "__main__":
            # Continuing from previous example...
            analyzer = StudentAnalyzer(db)
            analyzer.analyze_all_students()
        ```

## Best Practices for Nodes and Edges

!!! summary "Design Guidelines"
    - **Nodes for Entities**: Use nodes for things that exist independently (students, teachers, classrooms)
    - **Edges for Relationships**: Use edges for connections between entities (enrollment, teaching, friendship)
    - **Rich Edge Properties**: Store relationship-specific data in edges (grades, dates, status)
    - **Consistent Naming**: Use clear, descriptive names for node and edge types
    - **Connect to Root**: Always connect important nodes to root for persistence

## Key Takeaways

!!! summary "Chapter Summary"
    - **Nodes** are spatial objects that can be connected and persisted automatically
    - **Edges** are first-class relationships with their own properties and behaviors
    - **Root Connection** provides automatic persistence for connected nodes
    - **Navigation Syntax** makes finding related data intuitive with `[-->]` and `[<--]`
    - **Filtering** enables powerful queries directly in the traversal syntax
    - **Walkers** can traverse and analyze the graph structure effectively

Nodes and edges form the foundation of Object-Spatial Programming. By modeling your data as connected entities rather than isolated objects, you create more natural representations that enable powerful traversal and analysis patterns.

In the next chapter, we'll explore walkers and abilities - the mobile computational entities that bring your graphs to life by moving through and processing your spatial data structures.

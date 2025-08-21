# Chapter 10: Walkers and Abilities

Walkers are the heart of Object-Spatial Programming - they are mobile computational entities that traverse your graph and execute code at each location. Combined with abilities, they enable reactive, event-driven programming where computation happens exactly where and when it's needed.

!!! topic "Mobile Computation Philosophy"
    Unlike traditional functions that operate on data passed to them, walkers travel to where data lives, making computation truly spatial and enabling powerful distributed processing patterns.

## Walker Creation

!!! topic "What are Walkers?"
    Walkers are special objects that can move through your graph, carrying state and executing abilities when they encounter different types of nodes and edges.

### Basic Walker Declaration

!!! example "Simple Walker"
    === "Jac"
        <div class="code-block">
        ```jac
        # Simple walker for visiting nodes
        walker MessageDelivery {
            has message: str;
            has delivery_count: int = 0;
            has visited_locations: list[str] = [];

            # Regular methods work like normal
            def get_status() -> str {
                return f"Delivered {self.delivery_count} messages to {len(self.visited_locations)} locations";
            }
        }

        with entry {
            # Create walker instance (but don't activate it yet)
            messenger = MessageDelivery(message="Hello from the principal!");

            # Check initial state
            print(f"Initial status: {messenger.get_status()}");
        }
        ```
        </div>
    === "Python"
        ```python
        class MessageDelivery:
            def __init__(self, message: str):
                self.message = message
                self.delivery_count = 0
                self.visited_locations = []

            def get_status(self) -> str:
                return f"Delivered {self.delivery_count} messages to {len(self.visited_locations)} locations"

        class Student:
            def __init__(self, name: str):
                self.name = name
                self.messages = []

        class Teacher:
            def __init__(self, name: str, subject: str):
                self.name = name
                self.subject = subject

        if __name__ == "__main__":
            # Create messenger instance
            messenger = MessageDelivery(message="Hello from the principal!")

            # Check initial state
            print(f"Initial status: {messenger.get_status()}")
        ```

## Ability Definitions and Triggers

!!! topic "Event-Driven Execution"
    Abilities are methods that execute automatically when certain events occur during graph traversal. They create reactive, context-aware behavior.

### Entry and Exit Abilities

!!! example "Basic Abilities"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic classroom nodes
        node Student {
            has name: str;
            has messages: list[str] = [];
        }

        node Teacher {
            has name: str;
            has subject: str;
        }

        walker MessageDelivery {
            has message: str;
            has delivery_count: int = 0;
            has visited_locations: list[str] = [];

            # Entry ability - triggered when entering any Student
            can deliver_to_student with Student entry {
                print(f"Delivering message to student {here.name}");
                here.messages.append(self.message);
                self.delivery_count += 1;
                self.visited_locations.append(here.name);
            }

            # Entry ability - triggered when entering any Teacher
            can deliver_to_teacher with Teacher entry {
                print(f"Delivering message to teacher {here.name} ({here.subject})");
                # Teachers just acknowledge the message
                print(f"  {here.name} says: 'Message received!'");
                self.delivery_count += 1;
                self.visited_locations.append(here.name);
            }

            # Exit ability - triggered when leaving any node
            can log_visit with entry {
                node_type = type(here).__name__;
                print(f"  Visited {node_type}");
            }
        }

        with entry {
            # Create simple classroom
            alice = root ++> Student(name="Alice");
            bob = root ++> Student(name="Bob");
            ms_smith = root ++> Teacher(name="Ms. Smith", subject="Math");

            # Create and activate messenger
            messenger = MessageDelivery(message="School assembly at 2 PM");

            # Spawn walker on Alice - this activates it
            alice[0] spawn messenger;

            # Check Alice's messages
            print(f"Alice's messages: {alice[0].messages}");
        }
        ```
        </div>
    === "Python"
        ```python
        class MessageDelivery:
            def __init__(self, message: str):
                self.message = message
                self.delivery_count = 0
                self.visited_locations = []

            def deliver_to_student(self, student):
                print(f"Delivering message to student {student.name}")
                student.messages.append(self.message)
                self.delivery_count += 1
                self.visited_locations.append(student.name)

            def deliver_to_teacher(self, teacher):
                print(f"Delivering message to teacher {teacher.name} ({teacher.subject})")
                print(f"  {teacher.name} says: 'Message received!'")
                self.delivery_count += 1
                self.visited_locations.append(teacher.name)

            def visit_node(self, node):
                node_type = type(node).__name__
                print(f"  Visited {node_type}")

                # Manually check type and call appropriate method
                if isinstance(node, Student):
                    self.deliver_to_student(node)
                elif isinstance(node, Teacher):
                    self.deliver_to_teacher(node)

        if __name__ == "__main__":
            # Create simple classroom
            alice = Student("Alice")
            bob = Student("Bob")
            ms_smith = Teacher("Ms. Smith", "Math")

            # Create and use messenger manually
            messenger = MessageDelivery("School assembly at 2 PM")

            # Manually visit nodes (simulating walker spawn)
            messenger.visit_node(alice)

            # Check Alice's messages
            print(f"Alice's messages: {alice.messages}")
        ```

## Walker Spawn and Visit

!!! topic "Graph Traversal"
    Walkers move through graphs using `spawn` (to start) and `visit` (to continue to connected nodes). This enables complex traversal patterns with simple syntax.

### Basic Traversal Patterns

!!! example "Classroom Message Delivery"
    === "Jac"
        <div class="code-block">
        ```jac
        # Basic classroom nodes
        node Student {
            has name: str;
            has messages: list[str] = [];
        }

        node Teacher {
            has name: str;
            has subject: str;
        }

        walker MessageDelivery {
            has message: str;
            has delivery_count: int = 0;
            has visited_locations: list[str] = [];

            # Entry ability - triggered when entering any Student
            can deliver_to_student with Student entry {
                print(f"Delivering message to student {here.name}");
                here.messages.append(self.message);
                self.delivery_count += 1;
                self.visited_locations.append(here.name);
            }

            # Entry ability - triggered when entering any Teacher
            can deliver_to_teacher with Teacher entry {
                print(f"Delivering message to teacher {here.name} ({here.subject})");
                # Teachers just acknowledge the message
                print(f"  {here.name} says: 'Message received!'");
                self.delivery_count += 1;
                self.visited_locations.append(here.name);
            }

            # Exit ability - triggered when leaving any node
            can log_visit with entry {
                node_type = type(here).__name__;
                print(f"  Visited {node_type}");
            }
        }

        edge InClass {
            has room: str;
        }

        walker ClassroomMessenger {
            has announcement: str;
            has rooms_visited: set[str] = {};
            has people_reached: int = 0;

            can deliver_student with Student entry {
                print(f" Student {here.name}: {self.announcement}");
                self.people_reached += 1;

                # Continue to connected nodes
                visit [-->];
            }

            can deliver_teacher with Teacher entry {
                print(f" Teacher {here.name}: {self.announcement}");
                self.people_reached += 1;

                # Continue to connected nodes
                visit [-->];
            }

            can track_room with InClass entry {
                room = here.room;
                if room not in self.rooms_visited {
                    self.rooms_visited.add(room);
                    print(f" Now in {room}");
                }
            }

            can summarize with Student exit {
                # Only report once at the end
                if len([-->]) == 0 {  # At a node with no outgoing connections
                    print(f" Delivery complete!");
                    print(f"   People reached: {self.people_reached}");
                    print(f"   Rooms visited: {list(self.rooms_visited)}");
                }
            }
        }

        with entry {
            # Create classroom structure
            alice = root ++> Student(name="Alice");
            bob = root ++> Student(name="Bob");
            charlie = root ++> Student(name="Charlie");
            ms_jones = root ++> Teacher(name="Ms. Jones", subject="Science");

            # Connect them in the same classroom
            alice +>:InClass(room="Room 101"):+> bob;
            bob +>:InClass(room="Room 101"):+> charlie;
            charlie +>:InClass(room="Room 101"):+> ms_jones;

            # Send a message through the classroom
            messenger = ClassroomMessenger(announcement="Fire drill in 5 minutes");
            alice[0] spawn messenger;
        }
        ```
        </div>
    === "Python"
        ```python
        class InClass:
            def __init__(self, from_node, to_node, room: str):
                self.from_node = from_node
                self.to_node = to_node
                self.room = room

        class ClassroomMessenger:
            def __init__(self, announcement: str):
                self.announcement = announcement
                self.rooms_visited = set()
                self.people_reached = 0
                self.visited_nodes = set()

            def deliver_to_student(self, student):
                print(f" Student {student.name}: {self.announcement}")
                self.people_reached += 1

            def deliver_to_teacher(self, teacher):
                print(f" Teacher {teacher.name}: {self.announcement}")
                self.people_reached += 1

            def track_room(self, edge):
                if edge.room not in self.rooms_visited:
                    self.rooms_visited.add(edge.room)
                    print(f"   Now in {edge.room}")

            def visit_network(self, node, connections):
                # Avoid infinite loops
                if node in self.visited_nodes:
                    return

                self.visited_nodes.add(node)

                # Process current node
                if isinstance(node, Student):
                    self.deliver_to_student(node)
                elif isinstance(node, Teacher):
                    self.deliver_to_teacher(node)

                # Visit connected nodes
                for edge in connections.get(node, []):
                    self.track_room(edge)
                    self.visit_network(edge.to_node, connections)

                # Check if we're at the end
                if not connections.get(node, []):
                    print(f" Delivery complete!")
                    print(f"   People reached: {self.people_reached}")
                    print(f"   Rooms visited: {list(self.rooms_visited)}")

        if __name__ == "__main__":
            # Create classroom structure
            alice = Student("Alice")
            bob = Student("Bob")
            charlie = Student("Charlie")
            ms_jones = Teacher("Ms. Jones", "Science")

            # Create connections manually
            connections = {
                alice: [InClass(alice, bob, "Room 101")],
                bob: [InClass(bob, charlie, "Room 101")],
                charlie: [InClass(charlie, ms_jones, "Room 101")],
                ms_jones: []
            }

            # Send message through classroom
            messenger = ClassroomMessenger("Fire drill in 5 minutes")
            messenger.visit_network(alice, connections)
        ```

### Advanced Traversal Control

!!! example "Selective Message Delivery"
    === "Jac"
        <div class="code-block">
        ```jac
        import random;

        node Student {
            has name: str;
            has grade_level: int;
            has messages: list[str] = [];
        }

        edge StudyGroup {
            has subject: str;
        }

        walker AttendanceChecker {
            has present_students: list[str] = [];
            has absent_students: list[str] = [];
            has max_checks: int = 5;
            has checks_done: int = 0;

            can check_attendance with Student entry {
                self.checks_done += 1;

                # Simulate checking if student is present (random for demo)
                is_present = random.choice([True, False]);

                if is_present {
                    print(f"{here.name} is present");
                    self.present_students.append(here.name);
                } else {
                    print(f"{here.name} is absent");
                    self.absent_students.append(here.name);
                }

                # Control flow based on conditions
                if self.checks_done >= self.max_checks {
                    print(f"Reached maximum checks ({self.max_checks})");
                    self.report_final();
                    disengage;  # Stop the walker
                }

                # Skip if no more connections
                connections = [-->];
                if not connections {
                    print("No more students to check");
                    self.report_final();
                    disengage;
                }

                # Continue to next student
                visit [-->];
            }

            def report_final() -> None {
                print(f" Attendance Report:");
                print(f"   Present: {self.present_students}");
                print(f"   Absent: {self.absent_students}");
                print(f"   Total checked: {self.checks_done}");
            }
        }

        with entry {
            # Create a chain of students
            alice = root ++> Student(name="Alice", grade_level=9);
            bob = alice ++> Student(name="Bob", grade_level=9);
            charlie = bob ++> Student(name="Charlie", grade_level=9);
            diana = charlie ++> Student(name="Diana", grade_level=9);
            eve = diana ++> Student(name="Eve", grade_level=9);

            # Start attendance check
            checker = AttendanceChecker(max_checks=3);
            alice[0] spawn checker;
        }
        ```
        </div>
    === "Python"
        ```python
        class StudyGroup:
            def __init__(self, from_node, to_node, subject: str):
                self.from_node = from_node
                self.to_node = to_node
                self.subject = subject

        class Student:
            def __init__(self, name: str, grade_level: int):
                self.name = name
                self.grade_level = grade_level
                self.messages = []

        class GradeSpecificMessenger:
            def __init__(self, message: str, target_grade: int):
                self.message = message
                self.target_grade = target_grade
                self.delivered_to = []
                self.visited = set()

            def visit_student(self, student, connections):
                if student in self.visited:
                    return

                self.visited.add(student)

                if student.grade_level == self.target_grade:
                    print(f"Delivering to {student.name} (Grade {student.grade_level}): {self.message}")
                    student.messages.append(self.message)
                    self.delivered_to.append(student.name)
                else:
                    print(f"Skipping {student.name} (Grade {student.grade_level}) - not target grade")

                # Visit connected students
                for edge in connections.get(student, []):
                    print(f"  Moving through {edge.subject} study group")
                    self.visit_student(edge.to_node, connections)

                # Report if at end
                if not connections.get(student, []):
                    print(f" Delivery Summary:")
                    print(f"   Target: Grade {self.target_grade} students")
                    print(f"   Message: '{self.message}'")
                    print(f"   Delivered to: {self.delivered_to}")

        if __name__ == "__main__":
            # Create multi-grade study network
            alice = Student("Alice", 9)
            bob = Student("Bob", 10)
            charlie = Student("Charlie", 9)
            diana = Student("Diana", 11)

            # Create connections
            connections = {
                alice: [StudyGroup(alice, bob, "Math")],
                bob: [StudyGroup(bob, charlie, "Science")],
                charlie: [StudyGroup(charlie, diana, "History")],
                diana: []
            }

            # Send grade-specific message
            messenger = GradeSpecificMessenger(
                "Grade 9 field trip permission slips due Friday!",
                9
            )

            messenger.visit_student(alice, connections)

            # Check who got the message
            print(f"Alice's messages: {alice.messages}")
            print(f"Bob's messages: {bob.messages}")
            print(f"Charlie's messages: {charlie.messages}")
        ```

## Walker Control Flow

!!! topic "Traversal Control"
    Walkers can control their movement through the graph using special statements like `visit` and `disengage`.

### Controlling Walker Behavior

!!! example "Smart Walker Control"
    === "Jac"
        <div class="code-block">
        ```jac
        node Student {
            has name: str;
            has grade_level: int;
        }

        walker AttendanceChecker {
            has present_students: list[str] = [];
            has absent_students: list[str] = [];
            has max_checks: int = 5;
            has checks_done: int = 0;

            can check_attendance with Student entry {
                self.checks_done += 1;

                # Simulate checking if student is present (random for demo)
                import random;
                is_present = random.choice([True, False]);

                if is_present {
                    print(f"{here.name} is present");
                    self.present_students.append(here.name);
                } else {
                    print(f"{here.name} is absent");
                    self.absent_students.append(here.name);
                }

                # Control flow based on conditions
                if self.checks_done >= self.max_checks {
                    print(f"Reached maximum checks ({self.max_checks})");
                    self.report_final();
                    disengage;  # Stop the walker
                }

                # Skip if no more connections
                connections = [-->];
                if not connections {
                    print("No more students to check");
                    self.report_final();
                    disengage;
                }

                # Continue to next student
                visit [-->];
            }

            def report_final() -> None {
                print(f" Attendance Report:");
                print(f"   Present: {self.present_students}");
                print(f"   Absent: {self.absent_students}");
                print(f"   Total checked: {self.checks_done}");
            }
        }

        with entry {
            # Create a chain of students
            alice = root ++> Student(name="Alice", grade_level=9);
            bob = alice ++> Student(name="Bob", grade_level=9);
            charlie = bob ++> Student(name="Charlie", grade_level=9);
            diana = charlie ++> Student(name="Diana", grade_level=9);
            eve = diana ++> Student(name="Eve", grade_level=9);

            # Start attendance check
            checker = AttendanceChecker(max_checks=3);
            alice[0] spawn checker;
        }
        ```
        </div>
    === "Python"
        ```python
        import random

        class AttendanceChecker:
            def __init__(self, max_checks: int = 5):
                self.present_students = []
                self.absent_students = []
                self.max_checks = max_checks
                self.checks_done = 0
                self.should_stop = False

            def check_student(self, student, connections):
                if self.should_stop:
                    return

                self.checks_done += 1

                # Simulate checking if student is present
                is_present = random.choice([True, False])

                if is_present:
                    print(f" {student.name} is present")
                    self.present_students.append(student.name)
                else:
                    print(f" {student.name} is absent")
                    self.absent_students.append(student.name)

                # Control flow based on conditions
                if self.checks_done >= self.max_checks:
                    print(f" Reached maximum checks ({self.max_checks})")
                    self.report_final()
                    return  # Stop checking

                # Continue to next student if available
                next_students = connections.get(student, [])
                if not next_students:
                    print(" No more students to check")
                    self.report_final()
                    return

                # Visit next student
                for next_student in next_students:
                    self.check_student(next_student, connections)

            def report_final(self):
                print(f" Attendance Report:")
                print(f"   Present: {self.present_students}")
                print(f"   Absent: {self.absent_students}")
                print(f"   Total checked: {self.checks_done}")

        if __name__ == "__main__":
            # Create a chain of students
            alice = Student("Alice", 9)
            bob = Student("Bob", 9)
            charlie = Student("Charlie", 9)
            diana = Student("Diana", 9)
            eve = Student("Eve", 9)

            # Create connections (linear chain)
            connections = {
                alice: [bob],
                bob: [charlie],
                charlie: [diana],
                diana: [eve],
                eve: []
            }

            # Start attendance check
            checker = AttendanceChecker(max_checks=3)
            checker.check_student(alice, connections)
        ```

## Key Concepts Summary

!!! summary "Walker and Ability Fundamentals"
    - **Walkers** are mobile computational entities that traverse graphs
    - **Abilities** are event-driven methods that execute automatically during traversal
    - **Entry abilities** trigger when a walker arrives at a node
    - **Exit abilities** trigger when a walker leaves a node
    - **Spawn** activates a walker at a specific starting location
    - **Visit** moves a walker to connected nodes
    - **Disengage** stops a walker's execution

## Best Practices

!!! summary "Walker Design Guidelines"
    - **Keep abilities focused**: Each ability should have a single, clear purpose
    - **Use descriptive names**: Make it clear what each walker and ability does
    - **Handle edge cases**: Check for empty connections before visiting
    - **Control traversal flow**: Use conditions to avoid infinite loops
    - **Report results**: Use exit abilities to summarize walker activities
    - **Manage state**: Use walker properties to track progress and results

## Key Takeaways

!!! summary "What We've Learned"
    **Walker System:**

    - **Mobile computation**: Walkers bring processing directly to data locations
    - **State management**: Walkers carry their own state as they traverse
    - **Traversal control**: Fine-grained control over movement patterns
    - **Spawning mechanism**: Activate walkers at specific graph locations

    **Ability System:**

    - **Event-driven execution**: Abilities trigger automatically based on walker location
    - **Entry/exit patterns**: React to walker arrival and departure events
    - **Context awareness**: Abilities have access to current node (`here`) and walker state
    - **Conditional execution**: Abilities can include logic to control when they execute

    **Traversal Patterns:**

    - **Visit statements**: Direct walker movement to connected nodes
    - **Filtering support**: Visit only nodes that match specific criteria
    - **Flow control**: Use `disengage` to stop walker execution
    - **Recursive traversal**: Walkers can spawn other walkers for complex patterns

    **Practical Applications:**

    - **Data processing**: Process distributed data where it lives
    - **Graph analysis**: Analyze relationships and connections
    - **Message delivery**: Distribute information through networks
    - **State propagation**: Update related nodes based on changes

!!! tip "Try It Yourself"
    Master walkers and abilities by building:
    - A message delivery system that traverses social networks
    - An attendance checker that visits classrooms
    - A family tree explorer that analyzes relationships
    - A network analyzer that processes organizational structures

    Remember: Walkers bring computation to data - think about how your processing can move through your graph!

---

*Walkers and abilities are now part of your toolkit. Let's master advanced graph operations and sophisticated traversal patterns!*

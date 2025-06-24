# Chapter 3: Variables, Types, and Basic Syntax

Jac emphasizes type safety and clear variable declarations. Unlike Python's optional typing, Jac requires type annotations for all variables and function parameters, preventing runtime type errors and improving code clarity.

## Variable Declarations with Mandatory Typing

!!! topic "Type Safety"
    Jac requires explicit type annotations for all variables, making your code more reliable and self-documenting.

### Basic Variable Declaration

!!! example "Variable Declaration"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Basic type annotations (mandatory)
            student_name: str = "Alice";
            grade: int = 95;
            gpa: float = 3.8;
            is_honor_student: bool = True;

            # Type inference (type can be inferred from value)
            total_points = 285.5;  # Inferred as float
            course_count = 3;      # Inferred as int
            print(f"{student_name} has GPA: {gpa}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python equivalent (typing is optional)
        student_name: str = "Alice"  # Optional typing
        grade: int = 95
        gpa: float = 3.8
        is_honor_student: bool = True

        # Python also supports type inference
        total_points = 285.5  # Inferred as float
        course_count = 3      # Inferred as int
        print(f"{student_name} has GPA: {gpa}")
        ```

### Global Variables

!!! example "Global Variables"
    === "Jac"
        <div class="code-block">
        ```jac
        glob school_name: str = "Jac High School";
        glob passing_grade: int = 60;
        glob honor_threshold: float = 3.5;

        def get_school_info() -> str {
            :g: school_name;
            return f"Welcome to {school_name}";
        }

        with entry {
            print(get_school_info());
            print(f"Honor threshold is {honor_threshold}");
        }
        ```
        </div>
    === "Python"
        ```python
        # Python global variables
        school_name: str = "Jac High School"
        passing_grade: int = 60
        honor_threshold: float = 3.5

        def get_school_info() -> str:
            global school_name
            return f"Welcome to {school_name}"

        if __name__ == "__main__":
            print(get_school_info())
            print(f"Honor threshold is {honor_threshold}")
        ```

## Basic Data Types and Type Inference

!!! topic "Data Types"
    Jac supports all standard data types with mandatory type annotations for clarity and safety.

### Primitive Types

!!! example "Basic Data Types"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Student information
            student_id: int = 12345;
            gpa: float = 3.85;
            student_name: str = "Alice Johnson";
            is_enrolled: bool = True;

            # Optional values
            middle_name: str | None = None;
            graduation_year: int | None = 2024;

            print(f"Student: {student_name} (ID: {student_id})");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Optional

        # Student information
        student_id: int = 12345
        gpa: float = 3.85
        student_name: str = "Alice Johnson"
        is_enrolled: bool = True

        # Optional values
        middle_name: Optional[str] = None
        graduation_year: Optional[int] = 2024

        print(f"Student: {student_name} (ID: {student_id})")
        ```

### Any Type for Flexibility

!!! example "Dynamic Typing with Any"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Flexible grade storage
            grade_data: any = 95;
            print(f"Grade as number: {grade_data}");

            grade_data = "A";  # Now a letter grade
            print(f"Grade as letter: {grade_data}");

            # Mixed student data
            student_info: dict[str, any] = {
                "name": "Bob Smith",
                "age": 16,
                "grades": [88, 92, 85],
                "is_active": True
            };
            print(student_info);
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Any, Dict, List

        # Flexible grade storage
        grade_data: Any = 95
        print(f"Grade as number: {grade_data}")

        grade_data = "A"  # Now a letter grade
        print(f"Grade as letter: {grade_data}")

        # Mixed student data
        student_info: Dict[str, Any] = {
            "name": "Bob Smith",
            "age": 16,
            "grades": [88, 92, 85],
            "is_active": True
        }
        print(student_info)
        ```

## Collections and Data Structures

!!! topic "Collections"
    Jac provides type-safe collections that are perfect for managing student data like grades, names, and course information.

### Lists for Student Data

!!! example "Working with Student Lists"
    === "Jac"
        <div class="code-block">
        ```jac
        def calculate_average(grades: list[int]) -> float {
            if len(grades) == 0 {
                return 0.0;
            }
            return sum(grades) / len(grades);
        }

        with entry {
            # Student grades
            alice_grades: list[int] = [88, 92, 85, 90];
            student_names: list[str] = ["Alice", "Bob", "Charlie"];

            # Calculate Alice's average
            average = calculate_average(alice_grades);
            print(f"Alice's average: {average}");

            # Add new grade
            alice_grades.append(95);
            print(f"Updated average: {calculate_average(alice_grades)}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        def calculate_average(grades: List[int]) -> float:
            if len(grades) == 0:
                return 0.0
            return sum(grades) / len(grades)

        if __name__ == "__main__":
            # Student grades
            alice_grades: List[int] = [88, 92, 85, 90]
            student_names: List[str] = ["Alice", "Bob", "Charlie"]

            # Calculate Alice's average
            average = calculate_average(alice_grades)
            print(f"Alice's average: {average}")

            # Add new grade
            alice_grades.append(95)
            print(f"Updated average: {calculate_average(alice_grades)}")
        ```

### Dictionaries for Grade Books

!!! example "Student Grade Dictionary"
    === "Jac"
        <div class="code-block">
        ```jac
        def get_student_grade(gradebook: dict[str, int], student: str) -> str {
            grade = gradebook.get(student, 0);
            if grade >= 90 {
                return "A";
            } elif grade >= 80 {
                return "B";
            } elif grade >= 70 {
                return "C";
            } else {
                return "F";
            }
        }

        with entry {
            # Class gradebook
            math_grades: dict[str, int] = {
                "Alice": 92,
                "Bob": 85,
                "Charlie": 78
            };

            # Get letter grades
            for (student, score) in math_grades.items() {
                letter = get_student_grade(math_grades, student);
                print(f"{student}: {score} ({letter})");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Dict

        def get_student_grade(gradebook: Dict[str, int], student: str) -> str:
            grade = gradebook.get(student, 0)
            if grade >= 90:
                return "A"
            elif grade >= 80:
                return "B"
            elif grade >= 70:
                return "C"
            else:
                return "F"

        if __name__ == "__main__":
            # Class gradebook
            math_grades: Dict[str, int] = {
                "Alice": 92,
                "Bob": 85,
                "Charlie": 78
            }

            # Get letter grades
            for student, score in math_grades.items():
                letter = get_student_grade(math_grades, student)
                print(f"{student}: {score} ({letter})")
        ```

### Sets for Course Management

!!! example "Unique Course Tracking"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Track unique courses
            alice_courses: set[str] = {"Math", "Science", "English"};
            bob_courses: set[str] = {"Math", "History", "Art"};

            # Find common courses
            common_courses = alice_courses.intersection(bob_courses);
            print(f"Common courses: {common_courses}");

            # All unique courses
            all_courses = alice_courses.union(bob_courses);
            print(f"All courses: {all_courses}");
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Set

        if __name__ == "__main__":
            # Track unique courses
            alice_courses: Set[str] = {"Math", "Science", "English"}
            bob_courses: Set[str] = {"Math", "History", "Art"}

            # Find common courses
            common_courses = alice_courses.intersection(bob_courses)
            print(f"Common courses: {common_courses}")

            # All unique courses
            all_courses = alice_courses.union(bob_courses)
            print(f"All courses: {all_courses}")
        ```

## Collection Comprehensions

!!! topic "Comprehensions"
    Use comprehensions to process student data efficiently and readably.

### List Comprehensions for Grade Processing

!!! example "Grade Processing with Comprehensions"
    === "Jac"
        <div class="code-block">
        ```jac
        with entry {
            # Raw test scores
            test_scores = [78, 85, 92, 69, 88, 95, 72];

            # Get passing grades (70 and above)
            passing_scores = [score for score in test_scores if score >= 70];
            print(f"Passing scores: {passing_scores}");

            # Apply curve (+5 points)
            curved_scores = [score + 5 for score in test_scores];
            print(f"Curved scores: {curved_scores}");

            # Get letter grades
            letter_grades = ["A" if score >= 90 else "B" if score >= 80 else "C" if score >= 70 else "F" for score in test_scores];
            print(f"Letter grades: {letter_grades}");
        }
        ```
        </div>
    === "Python"
        ```python
        if __name__ == "__main__":
            # Raw test scores
            test_scores = [78, 85, 92, 69, 88, 95, 72]

            # Get passing grades (70 and above)
            passing_scores = [score for score in test_scores if score >= 70]
            print(f"Passing scores: {passing_scores}")

            # Apply curve (+5 points)
            curved_scores = [score + 5 for score in test_scores]
            print(f"Curved scores: {curved_scores}")

            # Get letter grades
            letter_grades = ["A" if score >= 90 else "B" if score >= 80 else "C" if score >= 70 else "F" for score in test_scores]
            print(f"Letter grades: {letter_grades}")
        ```

## Control Flow with Curly Braces

!!! topic "Control Flow"
    Jac uses curly braces for all code blocks, making the structure clear and consistent.

### Conditional Logic for Grading

!!! example "Grade Classification"
    === "Jac"
        <div class="code-block">
        ```jac
        def classify_grade(score: int) -> str {
            if score >= 97 {
                return "A+";
            } elif score >= 93 {
                return "A";
            } elif score >= 90 {
                return "A-";
            } elif score >= 87 {
                return "B+";
            } elif score >= 83 {
                return "B";
            } elif score >= 80 {
                return "B-";
            } elif score >= 70 {
                return "C";
            } else {
                return "F";
            }
        }

        with entry {
            student_score = 94;
            grade = classify_grade(student_score);
            status = "Excellent!" if grade.startswith("A") else "Good job!" if grade.startswith("B") else "Needs improvement";
            print(f"Score: {student_score} -> Grade: {grade} ({status})");
        }
        ```
        </div>
    === "Python"
        ```python
        def classify_grade(score: int) -> str:
            if score >= 97:
                return "A+"
            elif score >= 93:
                return "A"
            elif score >= 90:
                return "A-"
            elif score >= 87:
                return "B+"
            elif score >= 83:
                return "B"
            elif score >= 80:
                return "B-"
            elif score >= 70:
                return "C"
            else:
                return "F"

        if __name__ == "__main__":
            student_score = 94
            grade = classify_grade(student_score)
            status = "Excellent!" if grade.startswith("A") else "Good job!" if grade.startswith("B") else "Needs improvement"
            print(f"Score: {student_score} -> Grade: {grade} ({status})")
        ```

### Loops for Processing Student Data

!!! example "Processing Multiple Students"
    === "Jac"
        <div class="code-block">
        ```jac
        def process_class_grades(grades: dict[str, list[int]]) -> None {
            for (student, student_grades) in grades.items() {
                total = 0;
                for grade in student_grades {
                    total += grade;
                }
                average = total / len(student_grades);
                print(f"{student}: Average = {average}");
            }
        }

        with entry {
            class_grades = {
                "Alice": [88, 92, 85],
                "Bob": [79, 83, 77],
                "Charlie": [95, 89, 92]
            };

            # Process all students
            process_class_grades(class_grades);

            # Jac's unique for-to-by loop for grade scaling
            print("Scaled scores (0-100 to 0-4.0 GPA):");
            for score = 60 to score <= 100 by score += 10 {
                gpa = (score - 60) * 4.0 / 40.0;
                print(f"Score {score} -> GPA {gpa}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Dict, List

        def process_class_grades(grades: Dict[str, List[int]]) -> None:
            for student, student_grades in grades.items():
                total = 0
                for grade in student_grades:
                    total += grade
                average = total / len(student_grades)
                print(f"{student}: Average = {average}")

        if __name__ == "__main__":
            class_grades = {
                "Alice": [88, 92, 85],
                "Bob": [79, 83, 77],
                "Charlie": [95, 89, 92]
            }

            # Process all students
            process_class_grades(class_grades)

            # Python equivalent of for-to-by loop
            print("Scaled scores (0-100 to 0-4.0 GPA):")
            score = 60
            while score <= 100:
                gpa = (score - 60) * 4.0 / 40.0
                print(f"Score {score} -> GPA {gpa:.1f}")
                score += 10
        ```

## Pattern Matching for Complex Logic

!!! topic "Pattern Matching"
    Use pattern matching to handle complex grading scenarios elegantly.

!!! example "Advanced Grade Processing"
    === "Jac"
        <div class="code-block">
        ```jac
        def process_grade_input(input: any) -> str {
            match input {
                case int() if 90 <= input <= 100:
                    return f"Excellent work! Score: {input}";
                case int() if 80 <= input < 90:
                    return f"Good job! Score: {input}";
                case int() if 70 <= input < 80:
                    return f"Satisfactory. Score: {input}";
                case int() if 0 <= input < 70:
                    return f"Needs improvement. Score: {input}";
                case str() if input in ["A", "B", "C", "D", "F"]:
                    return f"Letter grade received: {input}";
                case list() if len(input) > 0:
                    avg = sum(input) / len(input);
                    return f"Average of {len(input)} grades: {avg}";
                case _:
                    return "Invalid grade input";
            }
        }

        with entry {
            print(process_grade_input(95));        # Number grade
            print(process_grade_input("A"));       # Letter grade
            print(process_grade_input([88, 92, 85])); # List of grades
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Any, List, Union

        def process_grade_input(input: Any) -> str:
            match input:
                case int(x) if 90 <= x <= 100:
                    return f"Excellent work! Score: {x}"
                case int(x) if 80 <= x < 90:
                    return f"Good job! Score: {x}"
                case int(x) if 70 <= x < 80:
                    return f"Satisfactory. Score: {x}"
                case int(x) if 0 <= x < 70:
                    return f"Needs improvement. Score: {x}"
                case str(x) if x in ["A", "B", "C", "D", "F"]:
                    return f"Letter grade received: {x}"
                case list(x) if len(x) > 0:
                    avg = sum(x) / len(x)
                    return f"Average of {len(x)} grades: {avg:.1f}"
                case _:
                    return "Invalid grade input"

        if __name__ == "__main__":
            print(process_grade_input(95))        # Number grade
            print(process_grade_input("A"))       # Letter grade
            print(process_grade_input([88, 92, 85])) # List of grades
        ```

## Exception Handling

!!! topic "Error Handling"
    Handle errors gracefully when processing student data.

!!! example "Safe Grade Calculations"
    === "Jac"
        <div class="code-block">
        ```jac
        def safe_calculate_gpa(grades: list[int]) -> float {
            try {
                if len(grades) == 0 {
                    raise ValueError("No grades provided");
                }
                total = sum(grades);
                return total / len(grades);
            } except ValueError as e {
                print(f"Error: {e}");
                return 0.0;
            }
        }

        def validate_grade(grade: int) -> None {
            if grade < 0 or grade > 100 {
                raise ValueError(f"Grade {grade} is out of valid range (0-100)");
            }
        }

        with entry {
            # Test safe calculation
            valid_grades = [85, 90, 78];
            gpa = safe_calculate_gpa(valid_grades);
            print(f"GPA: {gpa}");

            # Test error handling
            try {
                validate_grade(150);  # Invalid grade
            } except ValueError as e {
                print(f"Validation error: {e}");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import List

        def safe_calculate_gpa(grades: List[int]) -> float:
            try:
                if len(grades) == 0:
                    raise ValueError("No grades provided")
                total = sum(grades)
                return total / len(grades)
            except ValueError as e:
                print(f"Error: {e}")
                return 0.0

        def validate_grade(grade: int) -> None:
            if grade < 0 or grade > 100:
                raise ValueError(f"Grade {grade} is out of valid range (0-100)")

        if __name__ == "__main__":
            # Test safe calculation
            valid_grades = [85, 90, 78]
            gpa = safe_calculate_gpa(valid_grades)
            print(f"GPA: {gpa:.2f}")

            # Test error handling
            try:
                validate_grade(150)  # Invalid grade
            except ValueError as e:
                print(f"Validation error: {e}")
        ```

## Complete Example: Simple Grade Book System

!!! example "Grade Book System"
    === "Jac"
        <div class="code-block">
        ```jac
        obj GradeBook {
            has students: dict[str, list[int]] = {};

            def add_student(name: str) -> None;
            def add_grade(student: str, grade: int) -> None;
            def get_average(student: str) -> float;
            def get_all_averages() -> dict[str, float];
        }

        impl GradeBook.add_student(name: str) -> None {
            if name not in self.students {
                self.students[name] = [];
                print(f"Added student: {name}");
            } else {
                print(f"Student {name} already exists");
            }
        }

        impl GradeBook.add_grade(student: str, grade: int) -> None {
            if grade < 0 or grade > 100 {
                print(f"Invalid grade: {grade}");
                return;
            }

            if student in self.students {
                self.students[student].append(grade);
                print(f"Added grade {grade} for {student}");
            } else {
                print(f"Student {student} not found");
            }
        }

        impl GradeBook.get_average(student: str) -> float {
            if student not in self.students or len(self.students[student]) == 0 {
                return 0.0;
            }
            grades = self.students[student];
            return sum(grades) / len(grades);
        }

        impl GradeBook.get_all_averages() -> dict[str, float] {
            averages: dict[str, float] = {};
            for (student, grades) in self.students.items() {
                if len(grades) > 0 {
                    averages[student] = sum(grades) / len(grades);
                }
            }
            return averages;
        }

        with entry {
            # Create gradebook
            gradebook = GradeBook();

            # Add students
            gradebook.add_student("Alice");
            gradebook.add_student("Bob");

            # Add grades
            gradebook.add_grade("Alice", 88);
            gradebook.add_grade("Alice", 92);
            gradebook.add_grade("Bob", 85);
            gradebook.add_grade("Bob", 79);

            # Get results
            all_averages = gradebook.get_all_averages();
            for (student, avg) in all_averages.items() {
                letter = "A" if avg >= 90 else "B" if avg >= 80 else "C" if avg >= 70 else "F";
                print(f"{student}: {avg} ({letter})");
            }
        }
        ```
        </div>
    === "Python"
        ```python
        from typing import Dict, List

        class GradeBook:
            def __init__(self):
                self.students: Dict[str, List[int]] = {}

            def add_student(self, name: str) -> None:
                if name not in self.students:
                    self.students[name] = []
                    print(f"Added student: {name}")
                else:
                    print(f"Student {name} already exists")

            def add_grade(self, student: str, grade: int) -> None:
                if grade < 0 or grade > 100:
                    print(f"Invalid grade: {grade}")
                    return

                if student in self.students:
                    self.students[student].append(grade)
                    print(f"Added grade {grade} for {student}")
                else:
                    print(f"Student {student} not found")

            def get_average(self, student: str) -> float:
                if student not in self.students or len(self.students[student]) == 0:
                    return 0.0
                grades = self.students[student]
                return sum(grades) / len(grades)

            def get_all_averages(self) -> Dict[str, float]:
                averages: Dict[str, float] = {}
                for student, grades in self.students.items():
                    if len(grades) > 0:
                        averages[student] = sum(grades) / len(grades)
                return averages

        if __name__ == "__main__":
            # Create gradebook
            gradebook = GradeBook()

            # Add students
            gradebook.add_student("Alice")
            gradebook.add_student("Bob")

            # Add grades
            gradebook.add_grade("Alice", 88)
            gradebook.add_grade("Alice", 92)
            gradebook.add_grade("Bob", 85)
            gradebook.add_grade("Bob", 79)

            # Get results
            all_averages = gradebook.get_all_averages()
            for student, avg in all_averages.items():
                letter = "A" if avg >= 90 else "B" if avg >= 80 else "C" if avg >= 70 else "F"
                print(f"{student}: {avg:.1f} ({letter})")
        ```

## Key Takeaways

!!! summary "Chapter Summary"
    - **Mandatory Typing**: All variables require type annotations for safety and clarity
    - **Type Inference**: Types can be inferred when obvious from the assigned value
    - **Collections**: Lists, dicts, sets, and tuples provide type-safe data structures
    - **Comprehensions**: Process data efficiently with list, dict, and set comprehensions
    - **Control Flow**: Use curly braces for clear, consistent code structure
    - **Pattern Matching**: Handle complex conditional logic elegantly
    - **Error Handling**: Use try/except blocks to handle errors gracefully

!!! topic "Coming Up"
    Next, we'll explore Jac's function system and decorators to build more modular and reusable code. You'll learn about function definitions with type annotations, parameter handling, decorators in the Jac context, lambda functions, and async programming patterns.

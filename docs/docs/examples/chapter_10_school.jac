# Basic node for representing teachers
node Teacher {
    has name: str,
        subject: str,
        years_experience: int,
        email: str;
}

# Basic node for representing students
node Student {
    has name: str,
        age: int,
        grade_level: int,
        student_id: str;
}

node Classroom {
    has room_number: str,
        capacity: int,
        has_projector: bool = True;
}

# Edge for student enrollment
edge EnrolledIn {
    has enrollment_date: str,
        grade: str = "Not Assigned",
        attendance_rate: float = 100.0;
}

# Edge for teaching assignments
edge Teaches {
    has start_date: str,
        schedule: str,
        is_primary: bool = True;
}

# Edge for friendship between students
edge FriendsWith {
    has since: str,
        closeness: int = 5;
}

walker ClassroomExplorer {
    can explore with Classroom entry {
        print(f"=== Exploring {here.room_number} ===");

        # Find all students in this classroom
        students = [<-:EnrolledIn:<-];
        print(f"Students enrolled: {len(students)}");
        for student in students {
            print(f"  - {student.name} (ID: {student.student_id})");
        }

        # Find the teacher
        teachers = [<-:Teaches:<-];
        if teachers {
            teacher = teachers[0];
            print(f"Teacher: {teacher.name} ({teacher.subject})");
        }

        # Find classroom equipment info
        equipment = "Projector" if here.has_projector else "No projector";
        print(f"Equipment: {equipment}");
        print(f"Capacity: {here.capacity} students");
    }
}

walker StudentAnalyzer {
    has high_performers: list = [],
        needs_help: list = [];

    can analyze with Student entry {
        # Find enrollment information
        enrollments = [->:EnrolledIn:->];

        for enrollment_edge in [->:EnrolledIn:->] {
            grade = enrollment_edge.grade;
            attendance = enrollment_edge.attendance_rate;

            # Categorize students
            if grade in ["A", "A-", "B+"] and attendance >= 90.0 {
                self.high_performers.append(
                    {"name": here.name, "grade": grade, "attendance": attendance}
                );
            } elif attendance < 85.0 or grade in ["D", "F"] {
                self.needs_help.append(
                    {"name": here.name, "grade": grade, "attendance": attendance}
                );
            }
        }
    }

    can report with Student exit {
        # Only report once at the end
        if len([-->]) == 0 {  # At the last student

            print("=== Student Analysis Report ===");
            print(f"High Performers ({len(self.high_performers)}):");
            for student in self.high_performers {
                print(
                    f"  {student['name']}: {student['grade']} grade, {student[
                        'attendance'
                    ]}% attendance"
                );
            }
            print(f"Needs Support ({len(self.needs_help)}):");
            for student in self.needs_help {
                print(
                    f"  {student['name']}: {student['grade']} grade, {student[
                        'attendance'
                    ]}% attendance"
                );
            }
        }
    }
}

# Create the main classroom
glob science_lab = root ++> Classroom(
         room_number="Lab-A", capacity=24, has_projector=True
     ),
     dr_smith = science_lab +>: Teaches(
         start_date="2024-08-01", schedule="TR 10:00-11:30"
     ) :+> Teacher(
         name="Dr. Smith",
         subject="Chemistry",
         years_experience=12,
         email="smith@school.edu"
     ),
     students = [
         ("Charlie", 17, 11, "S003"),
         ("Diana", 16, 11, "S004"),
         ("Eve", 17, 11, "S005")
     ];

with entry {
    for (name, age, grade, id) in students {
        student = science_lab +>: EnrolledIn(
            enrollment_date="2024-08-15", attendance_rate=92.0
        ) :+> Student(name=name, age=age, grade_level=grade, student_id=id);

        print(f"Enrolled {student[0].name} in {science_lab[0].room_number}");
    }

    print(f"Created classroom {science_lab[0].room_number} with {dr_smith[0].name}");
}

# Find all classrooms and explore them
glob classrooms = [root-->(?:Classroom)];

with entry {
    for classroom in classrooms {
        classroom spawn ClassroomExplorer();
    }
}

# Analyze all students
glob students = [root-->-->(?:Student)];  # Find all students in the graph

with entry {
    if students {
        analyzer = StudentAnalyzer();
        for student in students {
            student spawn analyzer;
        }
    }
}
# "MWF 9:00-10:00"

# 1-10 scale

# Create teacher and connect to classroom

# Create students and enroll them

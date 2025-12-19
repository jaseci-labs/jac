import from byllm.lib { MockLLM }

glob llm = MockLLM(
    # model_name="gpt-4o-mini",
    model_name="mockllm", config={"outputs": ["Average marks for Alice : 86.75"]}
);

obj Student {
    has name: str,
        marks: list[int] = [];

    def set_marks(subject: str, marks: int) -> str {
        # Ignorning the subject for simplicity
        self.marks.append(marks);
    }

    """Calculate the average of the marks."""
    def get_average -> float by llm();
}

glob student = Student(name="Alice");

with entry {
    student.set_marks("English", 81);
    student.set_marks("Maths", 99);
    student.set_marks("Science", 77);
    student.set_marks("History", 90);
}

glob average = student.get_average();

with entry {
    print("Average marks for", student.name, ":", average);
}

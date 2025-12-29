import from byllm.lib { Model, Image }

glob llm = Model(model_name="gpt-4o", config={"verbose": True});

def solve_math_question(question_img: Image) -> str by llm();

with entry {
    print(solve_math_question(Image.open('math_question.jpg')));
}

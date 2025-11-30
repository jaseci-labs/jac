import from byllm.lib { Model, Image }

glob llm = Model(verbose=True, model_name="gpt-4o");

def solve_math_question(question_img: Image) -> str by llm();

with entry {
    print(solve_math_question(Image.open('math_question.jpg')));
}

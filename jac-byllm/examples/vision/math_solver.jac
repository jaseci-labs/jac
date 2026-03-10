import from byllm.lib { Image }

def solve_math_question(question_img: Image) -> str by llm();

with entry {
    print(solve_math_question(Image.open('math_question.jpg')));
}

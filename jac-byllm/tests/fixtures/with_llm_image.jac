import from byllm.lib { MockLLM, Image }
import os;

glob llm = MockLLM(
         model_name="gpt-4o",
         config={
             "show_params": True,
             "verbose": True,
             "outputs": ["The answer to the math question is 42."]
         },
     );

def solve_math_question(question_img: Image) -> str by llm();

glob question_img = Image(
         os.path.join(os.path.dirname(__file__), 'math_question.jpg')
     );

with entry {
    print(solve_math_question(question_img));
}

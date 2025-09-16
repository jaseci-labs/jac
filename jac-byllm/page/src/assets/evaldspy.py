import dspy
from enum import Enum

# Load the model
llm = dspy.OpenAI(model="gpt-4o-mini")
dspy.configure(lm=llm)


# Enum for yes/no answers
class Tell(str, Enum):
    YES = "yes"
    NO = "no"


# Define the signature with typed output
class YesOrNo(dspy.Signature):
    """Yes/No answering Bot"""

    question: str = dspy.InputField()
    answer: Tell = dspy.OutputField(desc="Must be either 'yes' or 'no'")


# Create a TypedPredictor that ensures correct enum output
yes_or_no = dspy.TypedPredict(YesOrNo)


question = "Are you an AI?"
result = yes_or_no(question=question)

# result.answer is already a Tell enum
print(f"Question: {question}")
print("The bot answered " + result.answer.value)

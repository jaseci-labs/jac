import os
from enum import Enum
from openai import OpenAI

# Initialize OpenAI client (make sure you set OPENAI_API_KEY in your env)
client = OpenAI()


# Enum for Yes/No
class Tell(str, Enum):
    YES = "yes"
    NO = "no"


def yes_or_no(question: str) -> Tell:
    """Yes/No answering Bot using pure prompt engineering."""
    prompt = f"""
You are a strict Yes/No answering bot.
Only respond with one word: "yes" or "no".

Question: {question}
Answer:
"""
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0,  # deterministic output
        max_tokens=1,  # keep it super tight
    )

    # Extract model output
    raw_answer = response.choices[0].message.content.strip().lower()

    # Validate against enum
    try:
        return Tell(raw_answer)
    except ValueError:
        # fallback in case the model still deviates
        return Tell.NO


question = "Are you an AI?"
answer = yes_or_no(question)
print(f"Question: {question}")
print("The bot answered " + answer.value)

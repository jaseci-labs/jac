"""A Number Guessing Game"""

import random;
import from mtllm.llm { Model }
# glob llm = Model(model_name="gpt-4o",verbose=False);
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

"""Provide a fun hint if guess is incorrect"""
def give_hint(guess: int, correct_number: int) -> str by llm();

walker GuessGame {
    has correct_number: int = random.randint(1, 10);

    can start_game with `root entry;
    def process_guess(guess: int);
}

node turn {
    can check with GuessGame entry;
}

# Run the game
 with entry:__main__ {
    GuessGame() spawn root;
}
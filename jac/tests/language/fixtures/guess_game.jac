"""A Number Guessing Game"""

import random;

glob guesses = [50, 25, 35, 30];

walker GuessGame {
    has correct_number: int = 30;

    can start_game with `root entry;
    def process_guess(guess: int);
}

node turn {
    can check with GuessGame entry;
}

impl turn.check{
    guess = guesses.pop(0);
    guess |> visitor.process_guess;
    visit [-->];
}

impl GuessGame.start_game{
    end = here;
    for i = 0 to i < 10 by i += 1 {
        end ++> (end := :> turn);
    }
    visit [-->];
}

impl GuessGame.process_guess(guess: int) {
    if guess > self.correct_number {
        "Too high!" |> print;
    } elif guess < self.correct_number {
        "Too low!" |> print;
    } else {
        "Congratulations! You guessed correctly." |> print;
        disengage;
    }
}
# Run the game
with entry {
    root spawn GuessGame();
}

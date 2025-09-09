"""A Number Guessing Game"""

import random;


class Game {
    def init(self: Game, attempts: int = 10) {
        self.attempts = attempts;
        self.won = False;
    }

    def play(self: Game) {
        raise NotImplementedError("Subclasses must implement this method.") ;
    }
}


class GuessTheNumberGame(Game) {
    def init(self: GuessTheNumberGame, attempts: int = 10) {
        super.init(attempts);
        self.correct_number = random.randint(1, 10);
    }

    def play(self: GuessTheNumberGame) {
        while self.attempts > 0 {
            guess = input("Guess a number between 1 and 10: ");
            if guess.isdigit() {
                self.process_guess(int(guess));
                if self.won {
                    break;
                }
            } else {
                print("That's not a valid number! Try again.");
            }
        }
        if not self.won {
            print("Sorry, you didn't guess the number. Better luck next time!");
        }
    }

    def process_guess(self: GuessTheNumberGame, guess: int) {
        if guess > self.correct_number {
            print("Too high!");
        } elif guess < self.correct_number {
            print("Too low!");
        } else {
            print("Congratulations! You guessed correctly.");
            self.won = True;
            return;
        }
        self.attempts -= 1;
        print(f"You have {self.attempts} attempts left.");
    }
}


with entry {
    game = GuessTheNumberGame();
    game.play();
}
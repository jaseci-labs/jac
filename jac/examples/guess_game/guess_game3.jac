"""A Number Guessing Game"""
import random;

obj Game {
    has attempts: int,
        won: bool = False;

    def play;
}

obj GuessTheNumberGame(Game) {
    has attempts: int = 10,
        correct_number: int = random.randint(1, 10);

    override def play;
    def process_guess(guess: int);
}

# Run the game
glob game = GuessTheNumberGame();

with entry {
    game.play();
}

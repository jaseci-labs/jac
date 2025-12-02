impl turn.check{
    guess = input("Guess a number between 1 and 10: ");
    if guess.isdigit() {
        visitor.process_guess(int(guess));
    } else {
        print("That's not a valid number! Try again.");
    }
    visit [-->];
}

impl GuessGame.start_game{
    end: `root | turn = here;
    for i = 0 to i < 10 by i += 1 {
        end ++> (end := turn());
    }
    visit [-->];
}

impl GuessGame.process_guess(guess: int) {
    if guess > self.correct_number {
        print("Too high!");
    } elif guess < self.correct_number {
        print("Too low!");
    } else {
        print("Congratulations! You guessed correctly.");
        disengage;
    }
}

"""Testing ignore."""

walker GuessGame {
    can start_game with `root entry;
}

walker GuessGame2 {
    can start_game with `root entry;
}

node turn {
    can check with GuessGame|GuessGame2 entry;
}


impl GuessGame.start_game {
    for i=0 to i<10 by i+=1 {
        here ++> turn();
    }
    visit [-->];
}

impl GuessGame2.start_game {
    for i=0 to i<10 by i+=1 {
        here ++> turn();
    }
    visit [-->][15:];
}

impl turn.check {
    print("here", end=", ");
}

# # Run the game
with entry {
    root spawn GuessGame();
    print('');
    root spawn GuessGame2();
    print('');
}

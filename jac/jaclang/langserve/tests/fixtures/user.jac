"""User's Greeting!"""

import greet;

def still_there -> greet.Greet {
    print("im still here");
    return "yes";
}

with entry {
    a = still_there();
    a.try_to_greet().pass_message("World");
}

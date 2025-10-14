"""A Friend Finder Program with AI-Generated Greetings"""

import from byllm.lib { Model }

glob llm = Model(model_name="gpt-4o-mini");


node Person {
    has name: str;
    has visited: bool = False;
    has interests: list[str] = [];

    can greet with FriendFinder entry {
        if not self.visited {
            self.visited = True;

            # Generate AI-powered personalized greeting
            greeting = generate_greeting(self.name, self.interests);
            print(f"\n{greeting}");

            visitor.found_friends.append(self.name);
            visit [-->];
        }
    }
}

edge Friends {}


walker FriendFinder {
    has found_friends: list[str] = [];

    can find_network with `root entry {
        print("Starting friend search with AI-generated greetings...\n");
        visit [-->];
        print(f"\n{'='*50}");
        print(f"Total friends found: {len(self.found_friends)}");
    }
}


def generate_greeting(person_name: str, interests: list[str]) -> str by llm(
    reason=True,
    incl_info=(interests,)
);


with entry {
    # Create people with interests
    alice = root ++> Person(name="Alice", interests=["reading", "hiking"]);
    bob = root ++> Person(name="Bob", interests=["gaming", "coding"]);
    charlie = root ++> Person(name="Charlie", interests=["music", "art"]);
    diana = root ++> Person(name="Diana", interests=["sports", "travel"]);

    # Build friend network
    alice +>:Friends:+> bob;
    alice +>:Friends:+> charlie;
    bob +>:Friends:+> diana;
    charlie +>:Friends:+> diana;

    # Spawn walker starting from Alice
    FriendFinder() spawn alice[0];
}

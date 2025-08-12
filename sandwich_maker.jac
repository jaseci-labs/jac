import from mtllm {Model, visit_by}

glob llm: Model = Model(model_name = "gemini/gemini-2.5-flash");


obj BreadSlice {
    has contents: list[str] = [];

    def add(item: str){
        self.contents.append(item);
    }

    def __str__(){
        return "Slice with " + ", ".join(self.contents) if self.contents else "Empty Slice";
    }
}

obj Sandwich {
    has slice1: BreadSlice = None;
    has slice2: BreadSlice = None;
    has assembled: bool = False;

    def __str__(){
        has_ingredients = (self.slice1 and self.slice1.contents != []) or (self.slice2 and self.slice2.contents != []);
        if not has_ingredients {
            return "Incomplete Sandwich";
        } elif self.assembled {
            return "Sandwich with " + str(self.slice1) + " and " + str(self.slice2);
        } else {
            return "Open-faced sandwich with " + str(self.slice1) + " and " + str(self.slice2);
        }
    }
}

node BakerBob{
    can act with SandwichMaker entry {
        print("👨‍🍳 Baker Bob: Prepping two fresh slices of bread.");
        visitor.sandwich.slice1 = BreadSlice();
        visitor.sandwich.slice2 = BreadSlice();
    }
}

node PeanutbutterPam {
    can act with SandwichMaker entry {
        print("👨‍🍳 Peanut Butter Pam: Adding peanut butter to the first slice.");
        visitor.sandwich.slice1.add("peanut butter");
    }
}

node JellyJenny {
    can act with SandwichMaker entry {
        print("👩‍🍳 Jelly Jenny: Spreading jelly on the second slice.");
        visitor.sandwich.slice2.add("jelly");
    }
}

node VeggieVicky {
    can act with SandwichMaker entry {
        print("👩‍🍳 Veggie Vicky: Layering lettuce and tomato.");
        visitor.sandwich.slice1.add("lettuce");
        visitor.sandwich.slice1.add("tomato");
    }
}

node SalamiSam {
    can act with SandwichMaker entry {
        print("👨‍🍳 Salami Sam: Adding salami to the first slice.");
        visitor.sandwich.slice1.add("salami");
    }
}

node TunaTina {
    can act with SandwichMaker entry {
        print("👩‍🍳 Tuna Tina: Spreading tuna on the second slice.");
        visitor.sandwich.slice2.add("tuna");
    }
}

node PlatingPat {
    can act with SandwichMaker entry {
        print("👨‍🍳 Plating Pat: Closing and plating the sandwich.");
        visitor.sandwich.assembled = True;
    }
}

walker SandwichMaker{
    has sandwich: Sandwich  = Sandwich() ;
    has request: str = input("What kind of a sandwich do you want to make? (Options: 'peanut butter and jelly', 'veggie', 'salami and tuna')\n");

    can start_making_the_sandwitch with `root entry {
        print("👨‍🍳 Starting the sandwich-making process!");
        self.sandwich = Sandwich();
        visit visit_by(llm, self, here, [-->]);
        # visit [-->] by llm();
    }
}


with entry{
    print("👨‍🍳 Let's make a delicious sandwich!");

    root ++> BakerBob();
    root ++> PeanutbutterPam();
    root ++> JellyJenny();
    root ++> VeggieVicky();
    root ++> PlatingPat();
    root ++> SalamiSam();
    root ++> TunaTina();

    maker = SandwichMaker();
    root spawn maker;

    if maker.sandwich.assembled {
        print("🥪 Sandwich is ready to be served!");
        print(maker.sandwich);
    } else {
        print("😢 The sandwich could not be assembled.");
    }
}
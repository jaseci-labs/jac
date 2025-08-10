import from mtllm {Model, __by__}

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
        if self.assembled {
            return "Sandwich with " + str(self.slice1) + " and " + str(self.slice2);
        } else {
            return "Incomplete Sandwich";
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

node SpreadSam {
    can act with SandwichMaker entry {
        print("👨‍🍳 Spread Sam: Adding peanut butter to the first slice.");
        visitor.sandwich.slice1.add("peanut_butter");
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

node PlatingPat {
    can act with SandwichMaker entry {
        print("👨‍🍳 Plating Pat: Closing and plating the sandwich.");
        visitor.sandwich.assembled = True;
    }
}

walker SandwichMaker{
    has sandwich: Sandwich  = Sandwich() ;

    can start_making_the_sandwitch with `root entry {
        print("👨‍🍳 Starting the sandwich-making process!");
        self.sandwich = Sandwich();
        # visit __by__(llm, self, here);
        visit here by llm();
    }
}


with entry{
    print("👨‍🍳 Let's make a delicious sandwich!");

    root ++> BakerBob();
    root ++> SpreadSam();
    root ++> JellyJenny();
    root ++> VeggieVicky();
    root ++> PlatingPat();

    maker = SandwichMaker();
    root spawn maker;

    if maker.sandwich.assembled {
        print("🥪 Sandwich is ready to be served!");
        print(maker.sandwich);
    } else {
        print("😢 The sandwich could not be assembled.");
    }
}
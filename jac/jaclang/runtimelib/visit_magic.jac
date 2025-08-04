import from jaclang.runtimelib.constructs {
    AccessLevel,
    Anchor,
    Archetype,
    EdgeAnchor,
    EdgeArchetype,
    GenericEdge,
    JacTestCheck,
    NodeAnchor,
    NodeArchetype,
    Root,
    WalkerAnchor,
    WalkerArchetype,
}


"""
This function goes through the available nodes and decides which next nodes to visit based on their semantics using an llm.
Walker is a transitioning agent while the nodes are agents that can be visited.

It returns the list of indexes  of the next nodes to visit in order to complete the task of the walker.
If no suitable node is found, it returns [].
"""
def get_where_to_visit_next(walker: WalkerArchetype, current_node: NodeArchetype, connected_nodes: dict) -> list[int] by llm();


"""
    This function goes through the available nodes and decides which next nodes to visit based on their semantics using an llm
"""
def __by__(model: Model, walker:WalkerArchetype, node: NodeArchetype) -> (
        list[NodeArchetype | EdgeArchetype]
        | list[NodeArchetype]
        | list[EdgeArchetype]
        | NodeArchetype
        | EdgeArchetype
    ) {

    
    if not isinstance(model, Model) {
        raise TypeError("Invalid llm object");
    }

    connected_nodes = [root-->];
    if not connected_nodes {
        raise ValueError("No connected agents found for the walker");
    }

    next_node_indexes = get_where_to_visit_next(walker, node, connected_nodes);

    ordered_list = [];
    for index in next_node_indexes {
        if index < len(connected_nodes) and index >= 0 {
            ordered_list.append(connected_nodes[index]);
        } else {
            raise IndexError("Index out of range for connected nodes");
        }
    }
    return ordered_list;
}

import from mtllm {Model}

glob llm = Model(model_name="gpt-4o");


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
        visit __by__(llm, self, here);
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
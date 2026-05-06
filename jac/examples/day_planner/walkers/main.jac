"""AI Day Planner -- walker-based version with OSP."""

to cl:

import from frontend { app as ClientApp }

def:pub app -> JsxElement {
    return
        <ClientApp/>;
}

to sv:

# --- Enums ---
enum Category { WORK, PERSONAL, SHOPPING, HEALTH, FITNESS, OTHER }

enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, BUNCH }

# --- AI Types ---
obj Ingredient {
    has name: str,
        quantity: float,
        unit: Unit,
        cost: float,
        carby: bool;
}

sem Ingredient.cost = "Estimated cost in USD";
sem Ingredient.carby = "True if this ingredient is high in carbohydrates";

def categorize(title: str) -> Category by llm();
sem categorize = "Categorize a task based on its title";

def generate_shopping_list(meal_description: str) -> list[Ingredient] by llm();
sem generate_shopping_list = "Generate a shopping list of ingredients needed for a described meal";

# --- Data Nodes ---
node Task {
    has title: str,
        done: bool = False,
        category: str = "other";
}

node ShoppingItem {
    has name: str,
        quantity: float,
        unit: str,
        cost: float,
        carby: bool;
}

# --- Task Walkers ---
walker:priv AddTask {
    has title: str;

    can create with Root entry {
        category = str(categorize(self.title)).split(".")[-1].lower();
        new_task = here ++> Task(title=self.title, category=category);
        report new_task[0];
    }
}

walker:priv ListTasks {
    has results: list[Task] = [];

    can start with Root entry {
        visit [-->];
    }

    can collect with Task entry {
        self.results.append(here);
    }

    can done with Root exit {
        report self.results;
    }
}

walker:priv ToggleTask {
    has task_id: str;

    can search with Root entry {
        visit [-->];
    }

    can toggle with Task entry {
        if jid(here) == self.task_id {
            here.done = not here.done;
            report here;
            disengage;
        }
    }
}

walker:priv DeleteTask {
    has task_id: str;

    can search with Root entry {
        visit [-->];
    }

    can remove with Task entry {
        if jid(here) == self.task_id {
            del here;
            report {"deleted": self.task_id};
            disengage;
        }
    }
}

# --- Shopping List Walkers ---
walker:priv GenerateShoppingList {
    has meal_description: str;

    can generate with Root entry {
        visit [-->];
        ingredients = generate_shopping_list(self.meal_description);
        for ing in ingredients {
            here ++> ShoppingItem(
                name=ing.name,
                quantity=ing.quantity,
                unit=str(ing.unit).split(".")[-1].lower(),
                cost=ing.cost,
                carby=ing.carby
            );
        }
        report [here-->][?:ShoppingItem];
    }

    can clear_old with ShoppingItem entry {
        del here;
    }
}

walker:priv GetShoppingList {
    has items: list[ShoppingItem] = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with ShoppingItem entry {
        self.items.append(here);
    }

    can done with Root exit {
        report self.items;
    }
}

walker:priv ClearShoppingList {
    can collect with Root entry {
        visit [-->];
    }

    can clear with ShoppingItem entry {
        del here;
        report {"cleared": True};
    }
}

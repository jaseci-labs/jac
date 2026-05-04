"""AI Day Planner -- authenticated, multi-file version."""

to cl:

import from frontend { app as ClientApp }

def:pub app -> JsxElement {
    return
        <ClientApp/>;
}

to sv:

import from byllm.lib { Model }

glob llm = Model(model_name="claude-sonnet-4-20250514");

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

# --- Task Endpoints ---
"""Add a task with AI categorization."""
def:priv add_task(title: str) -> Task {
    category = str(categorize(title)).split(".")[-1].lower();
    task = root() ++> Task(title=title, category=category);
    return task[0];
}

"""Get all tasks."""
def:priv get_tasks -> list[Task] {
    return [root()-->][?:Task];
}

"""Toggle a task's done status."""
def:priv toggle_task(id: str) -> Task | None {
    for task in [root()-->][?:Task] {
        if jid(task) == id {
            task.done = not task.done;
            return task;
        }
    }
    return None;
}

"""Delete a task."""
def:priv delete_task(id: str) -> dict {
    for task in [root()-->][?:Task] {
        if jid(task) == id {
            del task;
            return {"deleted": id};
        }
    }
    return {};
}

# --- Shopping List Endpoints ---
"""Generate a shopping list from a meal description."""
def:priv generate_list(meal: str) -> list[ShoppingItem] {
    for item in [root()-->][?:ShoppingItem] {
        del item;
    }
    ingredients = generate_shopping_list(meal);
    for ing in ingredients {
        root() ++> ShoppingItem(
            name=ing.name,
            quantity=ing.quantity,
            unit=str(ing.unit).split(".")[-1].lower(),
            cost=ing.cost,
            carby=ing.carby
        );
    }
    return [root()-->][?:ShoppingItem];
}

"""Get the current shopping list."""
def:priv get_shopping_list -> list[ShoppingItem] {
    return [root()-->][?:ShoppingItem];
}

"""Clear the shopping list."""
def:priv clear_shopping_list -> dict {
    for item in [root()-->][?:ShoppingItem] {
        del item;
    }
    return {"cleared": True};
}

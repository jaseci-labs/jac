"""AI Day Planner -- authenticated, multi-file version."""

import from jaclang.comptime { fields, get_field }
import from frontend { app as ClientApp }

def:pub app -> JsxElement {
    <ClientApp/>
}

enum Category { WORK, PERSONAL, SHOPPING, HEALTH, FITNESS, OTHER }

enum Unit { PIECE, LB, OZ, CUP, TBSP, TSP, BUNCH }

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

"""Add a task with AI categorization."""
def:protect add_task(title: str) -> Task {
    category = str(categorize(title)).split(".")[-1].lower();
    task = root ++> Task(title=title, category=category);
    return task;
}

"""Get all tasks."""
def:protect get_tasks -> list[Task] {
    return [root-->][?:Task];
}

"""Toggle a task's done status."""
def:protect toggle_task(id: str) -> Task | None {
    for task in [root-->][?:Task] {
        if jid(task) == id {
            task.done = not task.done;
            return task;
        }
    }
    return None;
}

"""Delete a task."""
def:protect delete_task(id: str) -> dict[str, str] {
    for task in [root-->][?:Task] {
        if jid(task) == id {
            del task;
            return {"deleted": id};
        }
    }
    return {};
}

"""Generate a shopping list from a meal description."""
def:protect generate_list(meal: str) -> list[ShoppingItem] {
    for item in [root-->][?:ShoppingItem] {
        del item;
    }
    ingredients = generate_shopping_list(meal);
    for ing in ingredients {
        item: dict[str, any] = {"unit": str(ing.unit).split(".")[-1].lower()};
        comptime for f in fields(ShoppingItem) {
            comptime if f.name != "unit" {
                item[f.name] = get_field(ing, f.name);
            }
        }
        root ++> ShoppingItem(**item);
    }
    return [root-->][?:ShoppingItem];
}

"""Get the current shopping list."""
def:protect get_shopping_list -> list[ShoppingItem] {
    return [root-->][?:ShoppingItem];
}

"""Clear the shopping list."""
def:protect clear_shopping_list -> dict[str, bool] {
    for item in [root-->][?:ShoppingItem] {
        del item;
    }
    return {"cleared": True};
}

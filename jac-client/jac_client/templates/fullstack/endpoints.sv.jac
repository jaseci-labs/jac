"""Todo App - Server-Side Data Layer.

Each user gets their own todo list automatically!
When authenticated, `root spawn` uses the user's personal root node.
"""

# ========================================
# Data Models
# ========================================
node Todo {
    has id: str,
        title: str,
        completed: bool = False;
}

glob todo_counter: int = 0;

# ========================================
# Walkers (API Operations)
# ========================================
walker:priv AddTodo {
    """Add a new todo item to the user's list."""
    has title: str;

    can create with Root entry {
        global todo_counter;
        todo_counter += 1;
        new_id = "todo_" + str(todo_counter);
        new_todo = here ++> Todo(id=new_id, title=self.title, completed=False);
        if new_todo {
            report new_todo[0];
        }
    }
}

walker:priv ListTodos {
    """List all todo items for the current user."""
    has todos: list = [];

    can collect with Root entry {
        visit [-->];
    }

    can gather with Todo entry {
        self.todos.append(
            {"id": here.id, "title": here.title, "completed": here.completed}
        );
    }

    can report_all with Root exit {
        report self.todos;
    }
}

walker:priv ToggleTodo {
    """Toggle a todo's completed status."""
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can toggle with Todo entry {
        if here.id == self.todo_id {
            here.completed = not here.completed;
            report {"id": here.id, "completed": here.completed};
        }
    }
}

walker:priv DeleteTodo {
    """Delete a todo item."""
    has todo_id: str;

    can search with Root entry {
        visit [-->];
    }

    can delete with Todo entry {
        if here.id == self.todo_id {
            del here;
            report {"deleted": self.todo_id};
        }
    }
}

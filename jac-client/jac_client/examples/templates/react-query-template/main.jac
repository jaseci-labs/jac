node Todo {
    has text: str;
    has done: bool = False;
}

# Backend - Walkers
walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}

walker read_todos {
    can read with `root entry {
        visit [-->(`?Todo)];
    }

    can report_todos with Todo entry {
        report here ;
    }
}

walker toggle_todo {
    can toggle with Todo entry {
        here.done = not here.done;
        report here ;
    }
}


walker delete_todo {
    can remove with Todo entry {
        del here;
        report {"message": "Todo deleted"};
    }
}

cl import from .components.QueryProvider {
    QueryProvider
}

cl import from "@tanstack/react-query" {
    useQuery,
    useMutation,
    useQueryClient
}
cl import from react { useState }


cl {

async def getTodos() -> any {
    result = root spawn read_todos();

    return result.reports || [];
}

async def create_todo(text: str) -> any {
    result = root spawn create_todo(text=text);

    return result.reports[0][0];
}

async def toggle_todo(id: int) -> any {
    result = id spawn toggle_todo();

    return result.reports[0];
}

async def delete_todo(id: str) -> any {
    result = id spawn delete_todo();
    console.log("Delete result:", result);

    return result.reports[0];
}

def useTodo() -> dict {
    qc = useQueryClient();



    # -------------------------
    # READ TODOS
    # -------------------------
    todosQuery = useQuery({
        "queryKey": ["todos"],
        "queryFn":  getTodos
    });

    # -------------------------
    # CREATE TODO
    # -------------------------
    createTodo = useMutation({
        "mutationFn": create_todo,
        "onSuccess": lambda -> None {
            console.log("Todo created successfully");
            qc.invalidateQueries({ "queryKey": ["todos"] });
        },
        "onError": lambda err:str -> None {
            console.error("Error creating todo:", err);
        },
        "onSettled": lambda -> None {
            console.log("Create todo mutation settled");
        },
        "onMutate": lambda newText:str -> None {
            console.log("Creating todo with text:", newText);
        }

    });

    # -------------------------
    # TOGGLE TODO (OPTIMISTIC)
    # -------------------------
    toggleTodo = useMutation({

        # Actual backend mutation
        "mutationFn": toggle_todo,

        # Optimistic update
        "onMutate": lambda id:int -> dict {
            qc.cancelQueries({ "queryKey": ["todos"] });

            previous = qc.getQueryData(["todos"]);

            qc.setQueryData(
                ["todos"],
                lambda old:any -> any {
                    return old.map(lambda t:any -> any {
                        if t._jac_id == id {
                            return {
                                "_jac_id": t._jac_id,
                                "text": t.text,
                                "done": not t.done
                            };
                        }
                        return t;
                    });
                }
            );

            return { "previous": previous };
        },

        # Rollback if error
        "onError": lambda err:str, id:int, ctx:dict -> None {
            qc.setQueryData(
                ["todos"],
                ctx["previous"]
            );
        },

        # Final truth sync
        "onSettled": lambda -> None {
            qc.invalidateQueries({ "queryKey": ["todos"] });
        }
    });

    deleteTodo = useMutation({
        "mutationFn": delete_todo,
        "onSuccess": lambda -> None {
            console.log("Todo deleted successfully");
            qc.invalidateQueries({ "queryKey": ["todos"] });
        },
        "onError": lambda err:str -> None {
            console.error("Error deleting todo:", err);
        }
    });

    return {
        "todosQuery": todosQuery,
        "createTodo": createTodo,
        "toggleTodo": toggleTodo,
        "deleteTodo": deleteTodo
    };
}





def TodoApp() -> any {
    [inputValue, setInputValue] = useState("");
    [filters, setFilters] = useState("all");

    todo = useTodo();
    todosQuery = todo["todosQuery"];
    createTodo = todo["createTodo"];
    toggleTodo = todo["toggleTodo"];

    if todosQuery.isLoading {
        return <div>Loading todos…</div>;
    }

    todos = todosQuery.data or [];

    def addTodo() -> None {
        if not inputValue.trim() {
            return;
        }
        createTodo.mutate(inputValue.trim());
        setInputValue("");
    }

    def deleteTodo(id: str) -> None {
        todo["deleteTodo"].mutate(id);
    }


    def filteredTodos() -> list {
        if filters == "active" {
            return todos.filter(lambda t:any -> bool { return not t.done; });
        } elif filters == "completed" {
            return todos.filter(lambda t:any -> bool { return t.done; });
        }
        return todos;
    }

    activeCount = todos.filter(
        lambda t:any -> bool { return not t.done; }
    ).length;

    return <div>
        <input
            value={inputValue}
            onChange={lambda e:any -> None {
                setInputValue(e.target.value);
            }}
            onKeyDown={lambda e:any -> None {
                if e.key == "Enter" {
                    addTodo();
                }
            }}
        />

        <button onClick={addTodo}>Add</button>

        {filteredTodos().map(lambda todo:any -> any {
            return <div key={todo._jac_id}>
                <input
                    type="checkbox"
                    checked={todo.done}
                    onChange={lambda -> None {
                        toggleTodo.mutate(todo._jac_id);
                    }}
                />
                <span
                    style={{
                        "textDecoration": (
                            "line-through" if todo.done else "none"
                        )
                    }}
                >
                    {todo.text}
                   
                </span>
                 <button onClick={lambda -> None {
                        deleteTodo(todo._jac_id);
                    }}>Delete</button>
            </div>;
        })}

        <div>
            {activeCount} items left
        </div>

    </div>;
}


def:pub app -> any {
    return <QueryProvider>
        <TodoApp />
    </QueryProvider>;
}




}
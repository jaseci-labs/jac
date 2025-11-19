cl import from "@reduxjs/toolkit" {createSlice}



cl {
    let todoSlice = createSlice({
        "name": "todos",
        "initialState": {
            "items": [],
            "filter": "all"
        },
        "reducers": {
            "addTodo": lambda state: any, action: any -> None {
                let newTodo = {
                    "id": Date.now(),
                    "text": action.payload,
                    "completed": false
                };
                state.items.push(newTodo);
            },
            "toggleTodo": lambda state: any, action: any -> None {
                let todo = state.items.find(lambda t: any -> bool {
                    return t.id == action.payload;
                });

                # if todo {
                #     todo.completed = not todo.completed;
                # }
            },
            "deleteTodo": lambda state: any, action: any -> None {
                
                # state.items = state.items.filter(lambda t: any -> bool {
                #     return t.id != action.payload;
                # });
            },
            "setFilter": lambda state: any, action: any -> None {
                # state.filter = action.payload;
            },
            "clearCompleted": lambda state: any -> None {
                # state.items = state.items.filter(lambda t: any -> bool {
                #     return t.completed == false;
                # });
            }
        }
    });

    def getTodoActions() -> any {
        return todoSlice.actions;
    }

    def getTodoReducer() -> any {
        return todoSlice.reducer;
    }
}
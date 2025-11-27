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
                let index = state.items.findIndex(lambda t: any -> bool {
                    return t.id == action.payload;
                });


                if todo && index != -1 {
                    new_todo = {**todo, "completed":not todo.completed};

                    #  Only array mutation only works here, immutable methods like map or filter do not work
                    state.items.splice(index, 1, new_todo);
                }
            },
            "deleteTodo": lambda state: any, action: any -> None {
                let todo = state.items.find(lambda t: any -> bool {
                    return t.id == action.payload;
                });
                let index = state.items.findIndex(lambda t: any -> bool {
                    return t.id == action.payload;
                });

                if todo && index != -1 {
                    #  Only array mutation only works here, immutable methods like map or filter do not work
                    state.items.splice(index, 1);
                }

            },
            "setFilter": lambda state: any, action: any -> None {
                # state.filter=action.payload;


            },
            "clearCompleted": lambda state: any -> None {
                let new_items = state.items.filter(lambda t: any -> bool {
                    return t.completed == false;
                });
                state.items.splice(0, state.items.length);
                for item in new_items {
                    state.items.push(item);
                }
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

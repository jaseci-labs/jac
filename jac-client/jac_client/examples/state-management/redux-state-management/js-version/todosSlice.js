import { createSlice } from "@reduxjs/toolkit";

const todosSlice = createSlice({
  name: "todos",
  initialState: {
    items: [],
    filter: "all", // all, active, completed
  },
  reducers: {
    addTodo: (state, action) => {
      const newTodo = {
        id: Date.now(),
        text: action.payload,
        completed: false,
      };
      state.items.push(newTodo);
    },
    toggleTodo: (state, action) => {
      const todo = state.items.find((t) => t.id === action.payload);
      if (todo) {
        todo.completed = !todo.completed;
      }
    },
    deleteTodo: (state, action) => {
      state.items = state.items.filter((t) => t.id !== action.payload);
    },
    setFilter: (state, action) => {
      state.filter = action.payload;
    },
    clearCompleted: (state) => {
      state.items = state.items.filter((t) => !t.completed);
    },
  },
});

export const { addTodo, toggleTodo, deleteTodo, setFilter, clearCompleted } =
  todosSlice.actions;
export default todosSlice.reducer;

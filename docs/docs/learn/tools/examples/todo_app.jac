import streamlit as st;

def todo_app {
    st.title("📋 Todo App");
    st.write("A simple todo application built with Jac and Streamlit");

    # Initialize session state
    if "todos" not in st.session_state {
        st.session_state.todos = [];
    }

    # Add new todo
    with st.form("add_todo") {
        new_todo = st.text_input("Add a new todo:");
        if st.form_submit_button("Add Todo") and new_todo {
            st.session_state.todos.append(new_todo);
            st.success("Todo added!");
        }
    }

    # Display todos
    if st.session_state.todos {
        st.subheader("📝 Your Todos");
        todos_to_remove = [];
        for todo in st.session_state.todos {
            columns = st.columns([4, 1]);

            with columns[0] {
                st.write(f"• {todo}");
            }

            with columns[1] {
                if st.button("Remove", key=todo) {
                    todos_to_remove.append(todo);
                }
            }
        }
        # Remove completed todos
        for todo in todos_to_remove {
            st.session_state.todos.remove(todo);
        }
        if todos_to_remove {
            st.rerun();
        }
        # Clear all button
        if st.button("Clear All") {
            st.session_state.todos = [];
            st.rerun();
        }
    } else {
        st.info("No todos yet! Add one above.");
    }

    # Show count
    if st.session_state.todos {
        st.write(f"Total todos: {len(st.session_state.todos)}");
    }
}

with entry {
    todo_app();
}

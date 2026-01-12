# Jac Streamlit Plugin

The Jac Streamlit plugin enables you to create interactive web applications using Streamlit with Jac code. This plugin seamlessly integrates Jac's powerful features with Streamlit's web app capabilities, allowing you to build data science applications, dashboards, and interactive tools.

## Installation

The Jac Streamlit plugin needs to be installed separately using pip:

```bash
pip install jac-streamlit
```

This will install the plugin and make the `jac streamlit` command available.

## Quick Start

To run a Jac file as a Streamlit application, use the `jac streamlit` command:

```bash
jac streamlit your_app.jac
```

This command will:

1. Compile your Jac code
2. Launch a Streamlit web server
3. Open your app in the default web browser

### Example Applications

We've included several example applications to help you get started:

#### Simple Calculator

A basic calculator demonstrating form handling and user interaction:

```jac
import streamlit as st;

def simple_calculator() {
    st.title(" Simple Calculator");
    st.write("A basic calculator built with Jac and Streamlit");

    # Create two columns for inputs
    columns = st.columns(2);
    col1 = columns[0];
    col2 = columns[1];

    with col1 {
        num1 = st.number_input("First number:", value=0.0);
    }

    with col2 {
        num2 = st.number_input("Second number:", value=0.0);
    }

    # Operation selection
    operation = st.selectbox(
        "Choose operation:",
        ["Add", "Subtract", "Multiply", "Divide"]
    );

    # Calculate result
    if st.button("Calculate") {
        if operation == "Add" {
            result = num1 + num2;
        } elif operation == "Subtract" {
            result = num1 - num2;
        } elif operation == "Multiply" {
            result = num1 * num2;
        } elif operation == "Divide" {
            if num2 != 0 {
                result = num1 / num2;
            } else {
                st.error("Cannot divide by zero!");
                return;
            }
        }

        st.success("Result: " + str(result));

        # Add to history
        if "history" not in st.session_state {
            st.session_state.history = [];
        }

        st.session_state.history.append(
            str(num1) + " " + operation.lower() + " " + str(num2) + " = " + str(result)
        );
    }

    # Show calculation history
    if "history" in st.session_state and st.session_state.history {
        st.subheader(" History");
        for calc in st.session_state.history {
            st.write("• " + calc);
        }

        if st.button("Clear History") {
            st.session_state.history = [];
            st.rerun();
        }
    }
}

with entry {
    simple_calculator();
}
```

Run this example with:

```bash
jac streamlit simple_calculator.jac
```

#### Todo App

A todo application showcasing session state management:

```jac
import streamlit as st;

def todo_app() {
    st.title(" Todo App");
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
        st.subheader(" Your Todos");

        todos_to_remove = [];

        for todo in st.session_state.todos {
            columns = st.columns([4, 1]);

            with columns[0] {
                st.write("• " + todo);
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
        st.write("Total todos: " + str(len(st.session_state.todos)));
    }
}

with entry {
    todo_app();
}
```

Run this example with:

```bash
jac streamlit todo_app.jac
```

## Features

### 1. Full Streamlit API Access

You can use all Streamlit components and features in your Jac applications:

```jac
import streamlit as st;
import pandas as pd;
import numpy as np;

with entry {
    st.title("Data Dashboard");

    # Create sample data
    data = pd.DataFrame({
        'x': np.random.randn(100),
        'y': np.random.randn(100)
    });

    # Display chart
    st.line_chart(data);

    # Add sidebar
    st.sidebar.header("Controls");
    chart_type = st.sidebar.selectbox("Chart Type", ["line", "bar", "area"]);

    if chart_type == "bar" {
        st.bar_chart(data);
    } elif chart_type == "area" {
        st.area_chart(data);
    }
}
```

### 2. Session State Management

Streamlit's session state works seamlessly with Jac:

```jac
import streamlit as st;

with entry {
    st.title("Counter App");

    # Initialize session state
    if "counter" not in st.session_state {
        st.session_state.counter = 0;
    }

    # Display current count
    st.write("Current count: " + str(st.session_state.counter));

    # Buttons to modify counter
    col1, col2, col3 = st.columns(3);

    with col1 {
        if st.button("Increment") {
            st.session_state.counter += 1;
        }
    }

    with col2 {
        if st.button("Decrement") {
            st.session_state.counter -= 1;
        }
    }

    with col3 {
        if st.button("Reset") {
            st.session_state.counter = 0;
        }
    }
}
```

## Advanced Usage

### Integration with Jac Cloud

You can build Streamlit frontends that interact with Jac Cloud APIs:

```jac
import streamlit as st;
import requests;

def make_api_call(token: str, endpoint: str, payload: dict) -> dict {
    response = requests.post(
        "http://localhost:8000/" + endpoint,
        json=payload,
        headers={"Authorization": "Bearer " + token}
    );
    return response.json() if response.status_code == 200 else {};
}

with entry {
    st.title("Jac Cloud Frontend");

    # Authentication
    if "token" not in st.session_state {
        st.session_state.token = None;
    }

    if not st.session_state.token {
        with st.form("login_form") {
            email = st.text_input("Email");
            password = st.text_input("Password", type="password");

            if st.form_submit_button("Login") {
                # Attempt login
                response = requests.post(
                    "http://localhost:8000/user/login",
                    json={"email": email, "password": password}
                );

                if response.status_code == 200 {
                    st.session_state.token = response.json()["token"];
                    st.rerun();
                } else {
                    st.error("Login failed!");
                }
            }
        }
    } else {
        st.success("Logged in successfully!");

        # Your app content here
        user_input = st.text_input("Enter your message:");

        if st.button("Send") and user_input {
            result = make_api_call(
                st.session_state.token,
                "walker/interact",
                {"message": user_input}
            );

            if result {
                st.write("Response:", result);
            }
        }
    }
}
```

## Next Steps

- Check out the [jac-scale documentation](../../production/index.md) for backend integration
- Try building a complete application using Jac + Streamlit + jac-scale

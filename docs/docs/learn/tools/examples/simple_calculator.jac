import streamlit as st;

def simple_calculator {
    st.title("🧮 Simple Calculator");
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
        "Choose operation:", ["Add", "Subtract", "Multiply", "Divide"]
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
        st.success(f"Result: {result}");
        # Add to history
        if "history" not in st.session_state {
            st.session_state.history = [];
        }
        st.session_state.history.append(
            f"{num1} {operation.lower()} {num2} = {result}"
        );
    }

    # Show calculation history
    if "history" in st.session_state and st.session_state.history {
        st.subheader("📝 History");
        for calc in st.session_state.history {
            st.write(f"• {calc}");
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

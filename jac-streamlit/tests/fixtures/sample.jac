import streamlit as st;

with entry {
    st.title("Simple Streamlit App");
    name = st.text_input("Enter your name");
    age = st.number_input("Enter your age", min_value=0);
    if st.button("Greet me") and name and age {
        st.success(f"Hello, {name}! You are {age} years old.");
    } else {
        st.error("Please enter your name and age.");
    }
    st.write("Select a number using the slider:");
    slider_value = st.slider("Pick a number", 0, 100);
    st.write(f"{"You selected: "}{slider_value}");
}

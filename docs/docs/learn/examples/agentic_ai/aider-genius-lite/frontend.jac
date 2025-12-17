import streamlit as st;
import requests;

def bootstrap_frontend(token: str) {
    st.set_page_config(
        page_title="Genius Lite - AI Coding Assistant", page_icon="💻", layout="wide"
    );

    st.title("🚀 Genius Lite - AI Coding Assistant");
    st.markdown("✨ Simple, structured code generation with validation");

    # Initialize session state
    if "results" not in st.session_state {
        st.session_state.results = None;
    }
    if "loading" not in st.session_state {
        st.session_state.loading = False;
    }

    # Main interface
    st.markdown("### 💡 What would you like me to code for you?");

    # Examples
    with st.expander("💫 Example Requests") {
        if st.button("🧮 Create a Python calculator") {
            st.session_state.user_request = "Create a Python calculator with basic math operations";
        }
        if st.button("🎮 Make a simple game") {
            st.session_state.user_request = "Create a simple number guessing game in Python";
        }
    }

    # Text input
    user_request = st.text_area(
        "📝 Describe your coding request:",
        value=st.session_state.get("user_request", ""),
        height=100,
        placeholder="e.g., Create a Python script that sorts a list of numbers 📊"
    );

    # Generate button
    if st.button("🚀 Generate Code") {
        if user_request.strip() {
            st.session_state.loading = True;
            st.session_state.results = None;
            st.rerun();
        } else {
            st.warning("⚠️ Please enter a coding request!");
        }
    }

    # Show loading state
    if st.session_state.loading {
        with st.spinner("🧠 AI is thinking and generating code...") {
            try {
                response = requests.post(
                    "http://localhost:8000/walker/GeniusAgent",
                    json={"request": user_request},
                    headers={"Authorization": f"Bearer {token}"}
                );

                if response.status_code == 200 {
                    result = response.json();
                    st.session_state.results = result.get("reports", [{}])[0];
                    st.session_state.loading = False;
                    st.success("✅ Code generation completed!");
                    st.rerun();
                } else {
                    st.error(f"❌ Generation failed: {response.text}");
                    st.session_state.loading = False;
                }
            } except requests.exceptions.Timeout {
                st.error(
                    "⏰ Request timed out. Please try again with a simpler request."
                );
                st.session_state.loading = False;
            } except Exception as e {
                st.error(f"❌ Error: {str(e)}");
                st.session_state.loading = False;
            }
        }
    }

    # Display results
    if st.session_state.results {
        results = st.session_state.results;
        st.markdown("---");
        st.markdown("## 🎯 Generated Code Results");
        if "total_tasks" in results {
            st.info(f"📋 Completed {results['total_tasks']} tasks");
        }
        if "tasks" in results and results["tasks"] {
            i = 1;
            for task in results["tasks"] {
                task_name = task.get('name', 'Unnamed Task');
                with st.expander(f"📝 Task {i}: {task_name}") {
                    # Task status
                    status = task.get("status", "unknown");
                    if status == "success" {
                        st.success("✅ Completed successfully");
                    } else {
                        st.error("❌ Failed");
                    }
                    # Generated code
                    if task.get("code") {
                        st.markdown("**🔧 Generated Code:**");
                        st.code(task["code"]);
                        # Copy button
                        if st.button(f"📋 Copy Code {i}") {
                            st.write(
                                "📋 Code copied to clipboard! (Use Ctrl+C to copy manually)"
                            );
                        }
                    }
                    # Feedback
                    if task.get("feedback") {
                        st.markdown("**💬 AI Feedback:**");
                        st.info(task["feedback"]);
                    }
                }
                i += 1;
            }
        }
        # Clear results button
        if st.button("🗑️ Clear Results") {
            st.session_state.results = None;
            st.session_state.user_request = "";
            st.rerun();
        }
    }

    # Footer
    st.markdown("---");
    st.markdown("**🤖 Powered by Genius Lite AI Assistant**");
    st.markdown("✨ Features: 📋 Task planning • 🔧 Code generation • ✅ Validation");
}

glob INSTANCE_URL = "http://localhost:8000" , TEST_USER_EMAIL = "test@mail.com" , TEST_USER_PASSWORD = "password" , response = requests.post(
    f"{INSTANCE_URL}/user/login",
    json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
);

with entry {
    if response.status_code != 200 {
        # Try registering the user if login fails
        response = requests.post(
            f"{INSTANCE_URL}/user/register",
            json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
        );
        assert response.status_code == 201;
        response = requests.post(
            f"{INSTANCE_URL}/user/login",
            json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
        );
        assert response.status_code == 200;
    }
}

glob token = response.json()["token"];

with entry {
    bootstrap_frontend(token);
}

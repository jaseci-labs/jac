import streamlit as st;
import requests;

def bootstrap_frontend(token: str) {
    st.set_page_config(
        page_title="Task Manager Lite - AI Assistant", page_icon="📋", layout="wide"
    );

    st.title("📋 Task Manager Lite - AI Assistant");
    st.markdown("✨ Intelligent task management, email writing, and general chat");

    # Initialize session state
    if "task_results" not in st.session_state {
        st.session_state.task_results = [];
    }
    if "loading" not in st.session_state {
        st.session_state.loading = False;
    }

    # Main interface
    st.markdown("### 💭 What can I help you with today?");

    # Examples
    with st.expander("💫 Example Requests") {
        st.markdown("**📋 Task Management**");
        if st.button("➕ Add a task") {
            st.session_state.user_input = "Add a task to buy groceries tomorrow at 3 PM";
        }
        if st.button("📝 Summarize tasks") {
            st.session_state.user_input = "Summarize all my tasks";
        }
        st.markdown("**📧 Email Writing**");
        if st.button("✉️ Write a meeting email") {
            st.session_state.user_input = "Write an email to schedule a meeting with my team for next Friday";
        }
        if st.button("📬 Write follow-up email") {
            st.session_state.user_input = "Write a follow-up email for the project update";
        }
        st.markdown("**💬 General Chat**");
        if st.button("🤔 Ask a question") {
            st.session_state.user_input = "What are the best practices for time management?";
        }
        if st.button("🌟 Get advice") {
            st.session_state.user_input = "How can I be more productive at work?";
        }
    }

    # Text input
    user_input = st.text_area(
        "💬 Enter your request:",
        value=st.session_state.get("user_input", ""),
        height=100,
        placeholder="e.g., Add a task to review the presentation by 5 PM tomorrow 📊"
    );

    # Process button
    if st.button("🚀 Process Request") {
        if user_input.strip() {
            st.session_state.loading = True;
            st.rerun();
        } else {
            st.warning("⚠️ Please enter a request!");
        }
    }

    # Show loading state
    if st.session_state.loading {
        with st.spinner("🧠 AI is processing your request...") {
            try {
                response = requests.post(
                    "http://localhost:8000/walker/task_manager",
                    json={"utterance": user_input},
                    headers={"Authorization": f"Bearer {token}"}
                );

                if response.status_code == 200 {
                    result = response.json();
                    task_result = result.get("reports", [{}])[0];
                    # Add to results history
                    st.session_state.task_results.insert(0, task_result);
                    # Keep only last 10 results
                    if len(st.session_state.task_results) > 10 {
                        st.session_state.task_results = st.session_state.task_results[:10];
                    }
                    st.session_state.loading = False;
                    st.success("✅ Request processed successfully!");
                    st.rerun();
                } else {
                    st.error(f"❌ Processing failed: {response.text}");
                    st.session_state.loading = False;
                }
            } except requests.exceptions.Timeout {
                st.error("⏰ Request timed out. Please try again.");
                st.session_state.loading = False;
            } except Exception as e {
                st.error(f"❌ Error: {str(e)}");
                st.session_state.loading = False;
            }
        }
    }

    # Display results
    if st.session_state.task_results {
        st.markdown("---");
        st.markdown("## 📊 Recent Activity");
        i = 0;
        for result in st.session_state.task_results {
            # Determine node type icon and color
            node_type = result.get("node_type", "Unknown");
            routed_to = result.get("routed_to", "");

            if node_type == "TaskHandling" {
                icon = "📋";
                color = "blue";
            } elif node_type == "EmailHandling" {
                icon = "📧";
                color = "green";
            } elif node_type == "GeneralChat" {
                icon = "💬";
                color = "orange";
            } else {
                icon = "🤖";
                color = "gray";
            }

            with st.expander(f"{icon} {node_type} - Request {i + 1}") {
                # Request details
                st.markdown(f"**🔀 Routed to:** `{routed_to}`");
                # User input
                st.markdown("**👤 Your Request:**");
                st.info(result.get("utterance", "No input recorded"));
                # AI response
                st.markdown("**🤖 AI Response:**");
                response_text = result.get("response", "No response recorded");
                if response_text {
                    if node_type == "TaskHandling" {
                        st.success(response_text);
                    } elif node_type == "EmailHandling" {
                        st.success(response_text);
                    } else {
                        st.info(response_text);
                    }
                } else {
                    st.warning("No response available");
                }
                # Copy response button
                if st.button(f"📋 Copy Response {i + 1}") {
                    st.write(
                        "📋 Response copied to clipboard! (Use Ctrl+C to copy manually)"
                    );
                }
            }
            i += 1;
        }
        # Clear history button
        if st.button("🗑️ Clear History") {
            st.session_state.task_results = [];
            st.session_state.user_input = "";
            st.rerun();
        }
    }

    # Footer
    st.markdown("---");
    st.markdown("**🤖 Powered by Task Manager Lite AI Assistant**");
    st.markdown(
        "✨ Features: 📋 Task management • 📧 Email writing • 💬 Smart chat • 🔀 Intelligent routing"
    );
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

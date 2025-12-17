import streamlit as st;
import requests;

def bootstrap_frontend(token: str) {
    st.set_page_config(
        page_title="Friendzone Lite - Memory Assistant", page_icon="🧠", layout="wide"
    );

    st.title("🧠 Friendzone Lite - Memory Assistant");
    st.markdown("✨ Capture and organize your memories from images");

    # Initialize session state
    if "memory_results" not in st.session_state {
        st.session_state.memory_results = None;
    }
    if "conversation_active" not in st.session_state {
        st.session_state.conversation_active = False;
    }
    if "image_url" not in st.session_state {
        st.session_state.image_url = "";
    }
    if "conversation_history" not in st.session_state {
        st.session_state.conversation_history = [];
    }
    if "loading" not in st.session_state {
        st.session_state.loading = False;
    }
    if "view_memories" not in st.session_state {
        st.session_state.view_memories = False;
    }
    if "captured_memories" not in st.session_state {
        st.session_state.captured_memories = [];
    }

    # Main interface
    st.markdown("### 📷 Start Your Memory Journey");

    # Add button to view captured memories
    columns = st.columns([3, 1]);
    with columns[1] {
        if st.button("📚 View Captured Memories") {
            st.session_state.view_memories = not st.session_state.view_memories;
            if st.session_state.view_memories {
                # Fetch memories from backend
                try {
                    response = requests.post(
                        "http://localhost:8000/walker/get_memories",
                        json={},
                        headers={"Authorization": f"Bearer {token}"}
                    );
                    if response.status_code == 200 {
                        result = response.json();
                        st.session_state.captured_memories = result.get(
                            "reports", [{}]
                        )[0].get(
                            "memories", []
                        );
                    }
                } except Exception as e {
                    st.error(f"❌ Error loading memories: {str(e)}");
                }
            }
            st.rerun();
        }
    }

    # Display captured memories if view_memories is True
    if st.session_state.view_memories {
        st.markdown("---");
        st.markdown("### 📚 Captured Memories");
        if st.session_state.captured_memories {
            mem_idx = 0;
            for memory in st.session_state.captured_memories {
                mem_idx = mem_idx + 1;
                with st.expander(
                    f"Memory {mem_idx}: {memory.get('summary', 'Untitled')[:50]}...",
                    expanded=False
                ) {
                    mem_columns = st.columns([1, 2]);
                    with mem_columns[0] {
                        if memory.get("image_url") {
                            try {
                                st.image(
                                    memory["image_url"],
                                    caption="Memory Image",
                                    use_column_width=True
                                );
                            } except Exception {
                                st.write("🖼️ Image not available");
                            }
                        }
                    }
                    with mem_columns[1] {
                        st.markdown(f"**📋 Summary:**");
                        st.write(memory.get("summary", "N/A"));
                        st.markdown(
                            f"**📅 When:** {memory.get('when', 'Not specified')}"
                        );
                        who_list = memory.get("who", []);
                        st.markdown(
                            f"**👥 Who:** {', '.join(who_list)
                            if who_list
                            else 'Not specified'}"
                        );
                        where_list = memory.get("where", []);
                        st.markdown(
                            f"**📍 Where:** {', '.join(where_list)
                            if where_list
                            else 'Not specified'}"
                        );
                        st.markdown(
                            f"**🎯 What:** {memory.get('what', 'Not specified')}"
                        );
                    }
                }
            }
        } else {
            st.info(
                "📭 No captured memories yet. Start a memory session to create your first memory!"
            );
        }
        st.markdown("---");
    }

    # Image URL input section
    if not st.session_state.conversation_active {
        st.markdown("#### 🌐 Enter Image URL");
        image_url = st.text_input(
            "🔗 Image URL:",
            placeholder="https://example.com/your-image.jpg",
            help="Enter the URL of an image containing a memory you'd like to capture"
        );
        if st.button("🚀 Start Memory Session") {
            if image_url.strip() {
                st.session_state.image_url = image_url;
                st.session_state.conversation_active = True;
                st.session_state.loading = True;
                st.rerun();
            } else {
                st.warning("⚠️ Please enter a valid image URL!");
            }
        }
    }

    # Active conversation section
    if st.session_state.conversation_active {
        # Display current image
        st.markdown("#### 📷 Current Image");
        try {
            st.image(
                st.session_state.image_url,
                caption="Memory Image",
                use_column_width=True
            );
        } except Exception {
            st.warning("⚠️ Could not display image. Proceeding with URL...");
        }
        # Initialize session if loading
        if st.session_state.loading and not st.session_state.memory_results {
            with st.spinner("🧠 AI is analyzing your image...") {
                try {
                    response = requests.post(
                        "http://localhost:8000/walker/update_session",
                        json={"image_url": st.session_state.image_url, "utterance": ""},
                        headers={"Authorization": f"Bearer {token}"}
                    );

                    if response.status_code == 200 {
                        result = response.json();
                        st.session_state.memory_results = result.get("reports", [{}])[
                            0
                        ];
                        st.session_state.loading = False;
                        st.success("✅ Memory session started!");
                        st.rerun();
                    } else {
                        st.error(f"❌ Failed to start session: {response.text}");
                        st.session_state.loading = False;
                    }
                } except Exception as e {
                    st.error(f"❌ Error: {str(e)}");
                    st.session_state.loading = False;
                }
            }
        }
        # Display memory progress
        if st.session_state.memory_results {
            results = st.session_state.memory_results;
            # Memory summary section
            st.markdown("#### 📝 Memory Details");
            st.markdown("**📅 When:**");
            when_val = results.get("when", "Not specified");
            if when_val {
                st.info(when_val);
            } else {
                st.info("Not specified");
            }
            st.markdown("**👥 Who:**");
            who_val = results.get("who", []);
            if who_val {
                st.info(", ".join(who_val));
            } else {
                st.info("Not specified");
            }
            st.markdown("**📍 Where:**");
            where_val = results.get("where", []);
            if where_val {
                st.info(", ".join(where_val));
            } else {
                st.info("Not specified");
            }
            st.markdown("**🎯 What:**");
            what_val = results.get("what", "");
            if what_val {
                st.info(what_val);
            } else {
                st.info("Not specified");
            }
            # Summary
            if results.get("summary") {
                st.markdown("**📋 Memory Summary:**");
                if results.get("show_summary", False) {
                    if results.get("terminate_conversation", False) {
                        st.success(f"✅ Final Memory Summary: {results['summary']}");
                    } else {
                        st.info(
                            f"📝 Memory Summary (in progress): {results['summary']}"
                        );
                    }
                } else {
                    st.write("📝 Building memory summary...");
                }
            }
            # Conversation section
            st.markdown("#### 💬 Conversation");
            # Display conversation history
            if st.session_state.conversation_history {
                for msg in st.session_state.conversation_history {
                    if msg["role"] == "user" {
                        st.chat_message("user").write(f"👤 {msg['content']}");
                    } else {
                        st.chat_message("assistant").write(f"🤖 {msg['content']}");
                    }
                }
            }
            # Check if conversation is complete
            if results.get("show_summary", False)
            and results.get("terminate_conversation", False) {
                st.success("🎉 Memory capture complete!");
                if st.button("🔄 Start New Memory Session") {
                    st.session_state.conversation_active = False;
                    st.session_state.memory_results = None;
                    st.session_state.image_url = "";
                    st.session_state.conversation_history = [];
                    st.session_state.loading = False;
                    st.rerun();
                }
            } else {
                # User input for continuing conversation
                user_input = st.chat_input("Continue the conversation...");
                if user_input {
                    # Add user message to history
                    st.session_state.conversation_history.append(
                        {"role": "user", "content": user_input}
                    );
                    # Send to backend
                    with st.spinner("🤖 AI is processing your response...") {
                        try {
                            response = requests.post(
                                "http://localhost:8000/walker/update_session",
                                json={
                                    "image_url": st.session_state.image_url,
                                    "utterance": user_input
                                },
                                headers={"Authorization": f"Bearer {token}"}
                            );

                            if response.status_code == 200 {
                                result = response.json();
                                st.session_state.memory_results = result.get(
                                    "reports", [{}]
                                )[0];
                                # Add assistant response to history
                                if "follow_up_questions" in st.session_state.memory_results {
                                    st.session_state.conversation_history.append(
                                        {
                                            "role": "assistant",
                                            "content": st.session_state.memory_results[
                                                "follow_up_questions"
                                            ]
                                        }
                                    );
                                }
                                st.rerun();
                            } else {
                                st.error(
                                    f"❌ Failed to process response: {response.text}"
                                );
                            }
                        } except Exception as e {
                            st.error(f"❌ Error: {str(e)}");
                        }
                    }
                }
            }
        }
        # Reset session button
        if st.button("🔄 Reset Session") {
            st.session_state.conversation_active = False;
            st.session_state.memory_results = None;
            st.session_state.image_url = "";
            st.session_state.conversation_history = [];
            st.session_state.loading = False;
            st.rerun();
        }
    }

    # Footer
    st.markdown("---");
    st.markdown("**🧠 Powered by Friendzone Lite AI Assistant**");
    st.markdown(
        "✨ Features: 📷 Image analysis • 💭 Memory extraction • 📝 Structured capture"
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

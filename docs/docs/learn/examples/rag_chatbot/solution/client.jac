import streamlit as st;
import requests;
import base64;


def bootstrap_frontend(token: str) {
    st.set_page_config(layout="wide");
    st.title("Welcome to your Jac MCP Chatbot!");

    # Initialize session state
    if "messages" not in st.session_state {
        st.session_state.messages = [];
    }
    if "session_id" not in st.session_state {
        st.session_state.session_id = "user_session_123";
    }
    uploaded_file = st.file_uploader('Upload File (PDF, TXT, Image, or Video)');
    if uploaded_file {
        file_b64 = base64.b64encode(uploaded_file.read()).decode('utf-8');
        file_extension = uploaded_file.name.lower().split('.')[-1];
        file_type = uploaded_file.type or '';
        supported_types = ['pdf', 'txt', 'png', 'jpg', 'jpeg', 'webp', 'mp4', 'avi', 'mov'];
        if file_extension not in supported_types and not (file_type.startswith('image') or file_type.startswith('video')) {
            st.error(f"Unsupported file type: {file_type or 'unknown'}. Please upload PDF, TXT, Image, or Video files.");
            return;
        }
        # Use upload_pdf walker endpoint for all uploads, saving in uploads/{session_id}
        payload = {
            "file_name": uploaded_file.name,
            "file_data": file_b64,
            "session_id": st.session_state.session_id
        };
        response = requests.post(
            "http://localhost:8000/walker/upload_file",
            json=payload,
            headers={"Authorization": f"Bearer {token}"}
        );
        if response.status_code == 200 {
            st.success(f"File '{uploaded_file.name}' uploaded and saved to uploads/{st.session_state.session_id}.");
            # Track last uploaded file path in session state
            st.session_state.last_uploaded_file_path = f"uploads/{st.session_state.session_id}/{uploaded_file.name}";
        } else {
            st.error(f"Failed to process {uploaded_file.name}: {response.text}");
        }
    }

    # Display chat messages from history on app rerun
    for message in st.session_state.messages {
        with st.chat_message(message["role"]) {
            st.markdown(message["content"]);
        }
    }

    if prompt := st.chat_input("What is up?") {
        # Add user message to chat history
        st.session_state.messages.append({"role": "user", "content": prompt});

        # Display user message in chat message container
        with st.chat_message("user") {
            st.markdown(prompt);
        }
        # Display assistant response in chat message container
        with st.chat_message("assistant") {
            with st.spinner("Thinking...") {
                # Call walker API
                payload = {
                    "message": prompt,
                    "session_id": st.session_state.session_id
                };
                # If a file was uploaded, include its path
                if "last_uploaded_file_path" in st.session_state {
                    payload["file_path"] = st.session_state.last_uploaded_file_path;
                }
                response = requests.post(
                    "http://localhost:8000/walker/interact",
                    json=payload,
                    headers={"Authorization": f"Bearer {token}"}
                );

                if response.status_code == 200 {
                    response = response.json();
                    print("response is",response);
                    st.write(response["reports"][0]["response"]);

                    # Add assistant response to chat history
                    st.session_state.messages.append({"role": "assistant", "content": response["reports"][0]["response"]});
                }
            }
        }
    }
}

with entry {

    INSTANCE_URL = "http://localhost:8000";
    TEST_USER_EMAIL = "test@mail.com";
    TEST_USER_PASSWORD = "password";

    response = requests.post(
        f"{INSTANCE_URL}/user/login",
        json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
    );

    if response.status_code != 200 {
        # Try registering the user if login fails
        response = requests.post(
            f"{INSTANCE_URL}/user/register",
            json={
                "email": TEST_USER_EMAIL,
                "password": TEST_USER_PASSWORD
            }
        );
        assert response.status_code == 201;

        response = requests.post(
            f"{INSTANCE_URL}/user/login",
            json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
        );
        assert response.status_code == 200;
    }

    token = response.json()["token"];

    print("Token:", token);

    bootstrap_frontend(token);
}

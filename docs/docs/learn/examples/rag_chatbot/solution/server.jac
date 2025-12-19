import from byllm.llm { Model }
import from byllm.types { Image, Video, Text }
import from tools { RagEngine }
import os;
import base64;
import mcp_client;

glob
    rag_engine: RagEngine = RagEngine(),
    llm = Model(model_name='gpt-4o-mini', verbose=True),
    MCP_SERVER_URL: str = os.getenv('MCP_SERVER_URL', 'http://localhost:8899/mcp');

enum ChatType { RAG, QA, IMAGE, VIDEO }

node Router {
    def classify(message: str) -> ChatType by llm(method="Reason", temperature=0.8);
}

node Chat {
    has chat_type: ChatType;
}

walker infer {
    has message: str,
        chat_history: list[dict],
        response: str = "",
        file_path: str = "";

    can init_router with `root entry {
        visit [-->](`?Router) else {
            router_node = here ++> Router();
            router_node ++> RagChat();
            router_node ++> QAChat();
            router_node ++> ImageChat();
            router_node ++> VideoChat();
            visit router_node;
        }
    }

    can route with Router entry {
        classification = here.classify(message=self.message);
        print("Routing message:", self.message, "to chat type:", classification);
        visit [-->](`?Chat)(?chat_type==classification);
    }
}

node ImageChat(Chat) {
    has chat_type: ChatType = ChatType.IMAGE;

    def respond_with_image(img: Image, text: Text, chat_history: list[dict]) -> str by llm(
        tools=([use_mcp_tool, list_mcp_tools])
    );

    can chat with infer entry;
}

node VideoChat(Chat) {
    has chat_type: ChatType = ChatType.VIDEO;

    def respond_with_video(video: Video, text: Text, chat_history: list[dict]) -> str by llm(
        method="Chain-of-Thoughts"
    );

    can chat with infer entry;
}

node RagChat(Chat) {
    has chat_type: ChatType = ChatType.RAG;

    def respond(message: str, chat_history: list[dict]) -> str by llm(
        method="ReAct",
        tools=([list_mcp_tools, use_mcp_tool]),
        messages=chat_history,
        max_react_iterations=6
    );

    can chat with infer entry;
}

node QAChat(Chat) {
    has chat_type: ChatType = ChatType.QA;

    def respond(message: str, chat_history: list[dict]) -> str by llm(
        messages=chat_history, max_react_iterations=6
    );

    can chat with infer entry;
}

walker interact {
    has message: str,
        session_id: str,
        chat_history: list[dict] = [],
        file_path: str = "";

    can init_session with `root entry {
        visit [-->](`?Session)(?id==self.session_id) else {
            session_node = here ++> Session(
                id=self.session_id, chat_history=[], file_path=self.file_path, status=1
            );
            visit session_node;
        }
    }
}

node Session {
    has id: str,
        chat_history: list[dict],
        status: int = 1,
        file_path: str = "";

    can chat with interact entry {
        visitor.chat_history = self.chat_history;
        visitor.chat_history.append({"role": "user", "content": visitor.message});
        response = infer(
            message=visitor.message,
            chat_history=self.chat_history,
            file_path=visitor.file_path
        ) spawn root;
        visitor.chat_history.append(
            {"role": "assistant", "content": response.response}
        );
        self.chat_history = visitor.chat_history;
        report {"response": response.response} ;
    }
}

walker upload_file {
    has file_name: str,
        file_data: str,
        session_id: str;

    can save_doc with `root entry;
}

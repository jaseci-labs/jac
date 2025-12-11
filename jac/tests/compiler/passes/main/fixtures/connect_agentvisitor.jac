node MyNode {
    has foo: str = "";
}

node Session {
    can generate_result with AgentVisitor entry {
        conn = self ++> MyNode();
        other = conn ++> MyNode();
        other ++> MyNode();
    }
}

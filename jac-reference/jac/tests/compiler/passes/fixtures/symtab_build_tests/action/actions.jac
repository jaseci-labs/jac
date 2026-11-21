node LLM {
    can infer with AgentNode entry {
        return "LLM's response";
    }

    def testing_infer {
        return "LLM's response";
    }
}

walker Agent {
    has describ: str = "AgentNode";

    can connect with LLM entry {
        return "AgentNode's response";
    }
}

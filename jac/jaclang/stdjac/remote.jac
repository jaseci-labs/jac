obj RemoteError(Exception) {
    has space: str = "",
        endpoint: str = "",
        detail: str = "";

    def postinit;
    def __str__ -> str;
}

obj RemoteUnavailable(RemoteError) {}

obj RemoteTimeout(RemoteError) {}

obj RemoteRejected(RemoteError) {}

obj RemoteDecodeError(RemoteError) {}

obj RemoteFailed(RemoteError) {}

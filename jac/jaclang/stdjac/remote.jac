"""The exceptions a failed crossing raises, as neojac's stdjac.remote defines them.

Each carries the space called, the endpoint (`module.name`) and a detail, and prints
as its detail. `RemoteError` is never raised itself: it is the base of the others.
"""

obj RemoteError(Exception) {
    has space: str = "",
        endpoint: str = "",
        detail: str = "";

    def postinit -> None {
        Exception.__init__(self, self.detail);
    }

    def __str__ -> str {
        return self.detail;
    }
}

obj RemoteUnavailable(RemoteError) {}

obj RemoteTimeout(RemoteError) {}

obj RemoteRejected(RemoteError) {}

obj RemoteDecodeError(RemoteError) {}

obj RemoteFailed(RemoteError) {}

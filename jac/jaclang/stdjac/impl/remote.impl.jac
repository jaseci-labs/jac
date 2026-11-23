impl RemoteError.postinit {
    Exception.__init__(self, self.detail);
}

impl RemoteError.__str__ -> str {
    return self.detail;
}

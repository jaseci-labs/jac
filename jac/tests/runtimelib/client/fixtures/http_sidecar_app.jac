"""sv backend fixture for the opt-in [desktop.http] sidecar tests.

- save_upload : a walker that receives a multipart file (bytes) plus a scalar
                form field and reports the byte length back -- the canonical
                first-class multipart upload path.
- greet       : a plain walker (proves the sidecar can drive ordinary walkers
                over multipart too, and gives the webhook route a target).
"""

walker:pub save_upload {
    has file: bytes = b"",
        label: str = "";

    can run with Root entry {
        report {"label": self.label, "size": len(self.file)};
    }
}


walker:pub greet {
    has name: str = "world";

    can run with Root entry {
        report {"greeting": f"hello {self.name}"};
    }
}

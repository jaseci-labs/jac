import os;
import from jaclang.server.identity.rate_limit { consume_limit }

obj PostingDenied {
    has message: str,
        retry_after_seconds: int;
}

def:protect posting_limit(actor: str) -> PostingDenied | None;

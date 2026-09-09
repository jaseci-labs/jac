import os;
import from jaclang.server.identity.rate_limit { consume_limit }

obj PostingDenied {
    has message: str,
        retry_after_seconds: int;
}

def posting_limit(actor: str) -> PostingDenied | None {
    for (scope, cap, seconds) in [
        (
            "jacyac-post-burst",
            int(os.environ.get("JACYAC_POSTS_PER_WINDOW", "1")),
            int(os.environ.get("JACYAC_POST_WINDOW_SECONDS", "10"))
        ),
        ("jacyac-post-day", int(os.environ.get("JACYAC_POSTS_PER_DAY", "50")), 86400)
    ] {
        retry = consume_limit(scope, actor, cap, seconds);
        if retry < 0 {
            return PostingDenied(
                "Posting is temporarily unavailable. Please try again.", 0
            );
        }
        if retry > 0 {
            return PostingDenied(
                f"Posting limit reached. Try again in {retry} seconds.", retry
            );
        }
    }
    return None;
}

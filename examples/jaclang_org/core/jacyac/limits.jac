import os;
import from stdjac.server { consume_limit }

def:protect posting_limit(actor: str) -> PostingDenied | None;

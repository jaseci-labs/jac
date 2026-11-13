import hashlib;
import secrets;
import hmac;

glob CHALLENGE_TTL: int = 300,
     CHALLENGE_MAX: int = 100000,
     CHALLENGE_PURPOSE: str = 'registration-pow';

def issue_challenge -> dict[str, any];

def consume_challenge(proof: dict[str, any] | None) -> bool;

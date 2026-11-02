import hashlib;
import math;
import logging;

obj AttemptsExhausted(Exception) {
    has retry_after: int = 1;
}

def limit_key(scope: str, actor: str) -> str;

def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int;

def refund_limit(scope: str, actor: str) -> None;

import time;
import from contextvars { ContextVar }

glob AAL1: str = 'aal1',
     AAL2: str = 'aal2',
     METHOD_PASSWORD: str = 'pwd',
     METHOD_FEDERATED: str = 'sso',
     METHOD_TOTP: str = 'otp',
     METHOD_RECOVERY: str = 'recovery',
     _caller_assurance: ContextVar[dict[str, any] | None] = ContextVar(
         '_jaclang_caller_assurance', `default=None
     );


def second_factor_claims(methods: list[str]) -> dict[str, any];


def carried_claims(claims: (dict[str, any] | None)) -> dict[str, any];


def token_assurance(token: (str | None)) -> dict[str, any];


def bind_caller_assurance(claims: (dict[str, any] | None)) -> any;


def release_caller_assurance(binding: any);


def caller_assurance_level -> str;


def caller_authentication_methods -> list[str];

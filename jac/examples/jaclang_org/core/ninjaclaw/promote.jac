import base64;
import json;
import os;
import urllib.error;
import urllib.request;
import from datetime { datetime, UTC, timedelta }

obj PromoteConfig {
    has upstream: str = "",
        fork: str = "",
        token: str = "",
        base: str = "main",
        dry_run: bool = False,
        min_askers: int = 3,
        min_age_days: int = 7;
}

obj PromoteCandidate {
    has slug: str = "",
        title: str = "",
        summary: str = "",
        body: str = "",
        askers: int = 0,
        created_at: str = "",
        verified_version: str = "",
        status: str = "",
        pr_state: str = "";
}

obj PrResult {
    has state: str = "",
        url: str = "",
        number: int = 0,
        note: str = "";
}

glob DOCS_ROOT: str = "jac/jaclang/cli/docs",
     SECTION_TITLE: str = "Tutorials from JacYac",
     API: str = "https://api.github.com";

def promote_config -> PromoteConfig;

def eligible(
    candidates: list[PromoteCandidate],
    version: str,
    config: PromoteConfig,
    now: datetime
) -> PromoteCandidate | None;

def docs_page(c: PromoteCandidate) -> str;

def nav_with_page(nav: dict[str, any], page: str, title: str) -> dict[str, any];

def github(
    method: str, path: str, token: str, payload: dict[str, any] | None = None
) -> any;

def open_docs_pr(
    c: PromoteCandidate, config: PromoteConfig, http: Callable
) -> PrResult;

def pr_state(number: int, config: PromoteConfig, http: Callable) -> str;

def promote_ready(config: PromoteConfig) -> bool;

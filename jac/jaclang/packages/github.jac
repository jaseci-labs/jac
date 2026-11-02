import base64;
import json;
import os;
import subprocess;
import time;
import urllib.error;
import urllib.request;
import from urllib.parse { quote }

glob API_URL: str = "https://api.github.com",
     UPLOADS_URL: str = "https://uploads.github.com",
     TOKEN_ENVS: tuple[str, ...] = ("JAC_GITHUB_TOKEN", "GITHUB_TOKEN", "GH_TOKEN");

obj GitHubError(Exception) {}

def find_token -> str;

obj GitHub {
    has token: str,
        api: str = API_URL,
        uploads: str = UPLOADS_URL;

    static def from_env -> GitHub;
    def call(
        method: str,
        url: str,
        body: dict[str, any] | None = None,
        data: bytes | None = None,
        content_type: str = "application/json",
        allow_missing: bool = False
    ) -> any;

    def login -> str;
    def ensure_fork(repo: str, login: str) -> str;
    def branch_sha(repo: str, branch: str) -> str;
    def create_branch(repo: str, branch: str, sha: str);
    def read_file(repo: str, path: str, ref: str) -> tuple[str | None, str | None];
    def write_file(
        repo: str, path: str, branch: str, text: str, message: str, sha: str | None
    );

    def release(repo: str, tag: str) -> dict[str, any] | None;
    def release_for(repo: str, tag: str, target: str) -> dict[str, any];
    def upload_asset(release: dict[str, any], name: str, data: bytes) -> str;
    def open_pull(repo: str, head: str, base: str, title: str, body: str) -> str;
}

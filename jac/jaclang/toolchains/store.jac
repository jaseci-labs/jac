import hashlib;
import json;
import os;
import re;
import shutil;
import tarfile;
import tempfile;
import time;
import zipfile;
import from pathlib { Path }
import from http.client { HTTPResponse }
import from urllib.request { Request, urlopen }
import from urllib.parse { urlsplit }

obj Artifact {
    has name: str,
        version: str,
        platform: str,
        url: str,
        digest: str,
        algorithm: str = "sha256",
        headers: dict[str, str] = {};

    def key -> str;
}

def offline -> bool;

def file_digest(path: Path, algorithm: str = "sha256") -> str;

def fetch(
    artifact: Artifact,
    destination: Path | None = None,
    bucket_name: str = "toolchains-downloads"
) -> Path;

def extract(archive: Path, destination: Path);

def installed(artifact: Artifact, required: str) -> (Path | None);

def install(artifact: Artifact, required: str) -> Path;

def _marker(bucket_name: str) -> str;

def build_slot(name: str, host: str, digest: str) -> Path;

def slot_ready(slot: Path) -> bool;

def publish_build_slot(staged: Path, slot: Path);

def install_slot(name: str, version: str, platform: str) -> Path;

def slot_installed(slot: Path) -> bool;

def publish_install_slot(slot: Path, meta: dict[str, str]);


def format_size(size: int) -> str;


def allowed_url(url: str) -> bool;

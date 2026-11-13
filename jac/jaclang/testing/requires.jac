import os;
import shutil;
import socket;
import unittest;
import from importlib.util { find_spec }


def _unmet(kind: str, name: str, hint: str);


def require_module(*names: str);


def require_tool(*names: str);


def require_flag(env_name: str, reason: str = "");


def require_network(host: str = "pypi.org", port: int = 443);

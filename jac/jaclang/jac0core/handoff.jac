import json;
import os;
import sys;

glob HANDOFF_ENV: str = "JAC_HANDOFF";

def handoff -> dict[str, object];

def update_handoff(**fields: object);

def process_executable -> str;

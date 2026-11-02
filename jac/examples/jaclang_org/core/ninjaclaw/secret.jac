import hmac;
import os;
import secrets;

glob SECRET_ENV: str = "NINJACLAW_SERVICE_SECRET",
     SECRET_FILE: str = "service.secret";

def service_secret -> str;

def secret_ok(given: str) -> bool;

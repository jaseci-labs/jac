import os;

glob MOBILE_SETUP_PLATFORM_ENV: str = "JAC_MOBILE_SETUP_PLATFORM";

def mobile_setup_platform_env_swap(value: str) -> str | None {
    prev = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, None);
    os.environ[MOBILE_SETUP_PLATFORM_ENV] = value;
    return prev;
}

def mobile_setup_platform_env_restore(prev: str | None) {
    if prev is None {
        os.environ.pop(MOBILE_SETUP_PLATFORM_ENV, None);
    } else {
        os.environ[MOBILE_SETUP_PLATFORM_ENV] = prev;
    }
}

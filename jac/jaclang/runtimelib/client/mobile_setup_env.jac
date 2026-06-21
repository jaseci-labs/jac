"""Helpers for scoping JAC_MOBILE_SETUP_PLATFORM during mobile setup/build/dev."""
import os;

glob MOBILE_SETUP_PLATFORM_ENV: str = "JAC_MOBILE_SETUP_PLATFORM";

"""Set the env to value and return the previous value (or None if unset)."""
def mobile_setup_platform_env_swap(value: str) -> str | None {
    prev = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, None);
    os.environ[MOBILE_SETUP_PLATFORM_ENV] = value;
    return prev;
}

"""Restore the env to prev as returned from mobile_setup_platform_env_swap."""
def mobile_setup_platform_env_restore(prev: str | None) {
    if prev is None {
        os.environ.pop(MOBILE_SETUP_PLATFORM_ENV, None);
    } else {
        os.environ[MOBILE_SETUP_PLATFORM_ENV] = prev;
    }
}

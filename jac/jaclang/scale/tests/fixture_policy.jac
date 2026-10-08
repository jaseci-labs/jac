"""The auth policy the scale suite's throwaway fixtures run under.

The fixtures register short, repetitive passwords ("pass123", "p1") and log in
as the bootstrap admin, so the suite lowers the password floor and names the
admin password here, once, for both the in-process client and the servers it
spawns. Tests of the policy itself set their own environment.

Not a test module: the runner collects `test_*.jac` only.
"""

import os;

glob ADMIN_BOOTSTRAP_PASSWORD: str = "Bootstrap-Admin-1!",
     FIXTURE_AUTH_ENV: dict[str, str] = {
         # Minimum scrypt cost, so hashing does not dominate test time.
         "JAC_SERVE_AUTH_PASSWORD_HASH_COST": "10",
         "JAC_SERVE_AUTH_PASSWORD_MIN_LENGTH": "1",
         "JAC_SERVE_AUTH_PASSWORD_REJECT_COMMON": "false",
         "JAC_SERVE_AUTH_PASSWORD_REJECT_IDENTIFIERS": "false",
         "JAC_SCALE_ADMIN_PASSWORD": ADMIN_BOOTSTRAP_PASSWORD
     };

"""Apply the fixture policy to `env` (this process by default) without
overriding a value a test has already set."""
def apply_fixture_policy(env: (dict[str, str] | None) = None) {
    target: any = os.environ if env is None else env;
    for (name, value) in FIXTURE_AUTH_ENV.items() {
        target.setdefault(name, value);
    }
}

"""Minimal jac-scale example showing the built-in SMTP emailer.

`jac start app.jac` and the framework's identity/password-reset endpoints
(/user/add-identity, /user/forgot-password, /user/reset-password, etc.)
will send mail through the SMTP relay configured in jac.toml. No custom
emailer code required.

Set the SMTP password via env before starting:
  export EMAILER_SMTP_PASSWORD=<app-password>
  jac start app.jac
"""

walker ping {
    can pong with `root entry {
        report {"status": "ok"};
    }
}

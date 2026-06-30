"""Minimal jac-scale example with a custom SendGrid emailer.

The SendGridEmailer subclass lives in emailer.jac. jac.toml points
`provider` at it; the factory imports it at startup, and the built-in
/user/forgot-password + /user/reset-password endpoints use it
automatically. No further wiring needed.

  export SENDGRID_API_KEY=SG.xxxxx
  jac start app.jac
"""

walker ping {
    can pong with `root entry {
        report {"status": "ok"};
    }
}

**JWT validation: remove redundant user_exists() DB call**

`validate_jwt_token()` previously called `user_exists()` (a MongoDB round-trip) on every
authenticated request after already verifying the JWT signature and expiry with
`jwt.decode()`. A valid, unexpired JWT signed with the server secret is sufficient
proof of a known user — the extra DB call is unnecessary overhead.

Removed the `user_exists()` call; token validation now returns the `user_id` from the
verified JWT payload directly.

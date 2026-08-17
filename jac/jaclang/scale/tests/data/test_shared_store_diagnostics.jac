"""The reason a shared store failed must survive the boundary (issue #8166).

`shared_store` used to wrap everything in `except Exception -> return None`, so a
database that was resolved, reachable and merely failed during schema DDL became
indistinguishable from no database being configured at all. Downstream, the user
manager reconstructed a cause it never verified and told the operator that no
`[scale.database]` url / `JAC_DB_URL` had resolved, for a URL that was set and
valid. These tests pin the failure reason to the failure.
"""

import os;
import unittest.mock;
import pytest;
import jaclang.scale.persistence.pg as pgmod;
import from jaclang.runtimelib.store { PgStore }
import from jaclang.scale.identity.user_manager { JacScaleUserManager }

glob _URL = "postgresql://jac:sekret@db.internal:5432/jacapp";


"""Run *body* with a resolvable JAC_DB_URL and a scrubbed store cache."""
def _with_db_url(body: any) -> any {
    saved = dict(pgmod._holder);
    try {
        with unittest.mock.patch.dict(os.environ, {"JAC_DB_URL": _URL}) {
            pgmod._holder.clear();
            return body();
        }
    } finally {
        pgmod._holder.clear();
        pgmod._holder.update(saved);
    }
}


test "a store that fails to prepare records why, instead of just None" {
    boom = RuntimeError("schema ddl exploded");

    def body {
        with unittest.mock.patch.object(
            PgStore, "ensure_schema_once", side_effect=boom
        ) {
            store = pgmod.shared_store();
        }
        assert store is None , "the store came back despite failing to prepare";
        assert pgmod.shared_store_error() is boom , (
            "shared_store destroyed the reason it failed; the caller can only "
            "guess, and it guesses 'no url configured'"
        );
    }
    _with_db_url(body);
}


test "the reported target never carries the password" {
    def body {
        masked = pgmod.masked_db_url();
        assert "sekret" not in masked , f"the password leaked into {masked}";
        assert "db.internal:5432/jacapp" in masked , (
            f"the operator cannot tell which database failed: {masked}"
        );
    }
    _with_db_url(body);
}


test "a password carried in the query string is masked too" {
    # libpq accepts the password as a URI parameter, which has no '@' for a
    # userinfo-only mask to key on.
    for url in [
        "postgresql://jac@db.internal:5432/jacapp?password=sekret",
        "postgresql://jac@db.internal:5432/jacapp?sslmode=require&password=sekret",
        "postgresql://db.internal/jacapp?PassWord=sekret",
        "postgresql:///jacapp?sslpassword=sekret&sslmode=verify-full",
        "postgres://u:sekret@h1:5432,h2:5432/app?password=sekret"
    ] {
        masked = pgmod.mask_db_url(url);
        assert "sekret" not in masked , f"{url!r} leaked its secret as {masked!r}";
        assert "***" in masked , f"{url!r} was not masked at all: {masked!r}";
        assert "jacapp" in masked or "app" in masked , (
            f"masking destroyed the database name: {masked!r}"
        );
    }
}


test "a keyword/value dsn is masked, quoted values included" {
    for dsn in [
        "host=db.internal user=jac password=sekret dbname=jacapp",
        "host=db.internal PASSWORD=sekret dbname=jacapp",
        "host=db.internal password='se cret' dbname=jacapp",
        "host=db.internal sslpassword=sekret dbname=jacapp"
    ] {
        masked = pgmod.mask_db_url(dsn);
        assert "sekret" not in masked , f"{dsn!r} leaked its secret as {masked!r}";
        assert "se cret" not in masked , f"{dsn!r} leaked its secret as {masked!r}";
        assert "host=db.internal" in masked , (
            f"masking destroyed the host: {masked!r}"
        );
    }
}


test "masking leaves a credential-free url readable" {
    plain = "postgresql://db.internal:5432/jacapp?sslmode=require";
    assert pgmod.mask_db_url(plain) == plain , (
        f"a url with no credentials must survive masking: "
        f"{pgmod.mask_db_url(plain)!r}"
    );
    assert pgmod.mask_db_url("") == "";
}


test "a resolved database that failed is not reported as a missing url" {
    boom = RuntimeError("connection refused at db.internal:5432");
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with unittest.mock.patch(
            "jaclang.scale.persistence.pg.shared_store_error", return_value=boom
        ) {
            with unittest.mock.patch(
                "jaclang.scale.persistence.pg.masked_db_url",
                return_value="postgresql://***@db.internal:5432/jacapp"
            ) {
                with pytest.raises(RuntimeError) as exc {
                    JacScaleUserManager(base_path=".");
                }
            }
        }
    }
    msg = str(exc.value);
    assert "connection refused at db.internal:5432" in msg , (
        f"the real failure never reached the operator: {msg}"
    );
    assert "db.internal:5432/jacapp" in msg , (
        f"the message does not name the database that failed: {msg}"
    );
    assert "no [scale.database] url" not in msg , (
        f"a resolved database is still reported as an unset url: {msg}"
    );
    assert exc.value.__cause__ is boom , "the underlying error is not chained";
    assert "Postgres" in msg;
    assert "credential store" in msg;
}


test "a genuinely missing url is still reported as a missing url" {
    with unittest.mock.patch(
        "jaclang.scale.persistence.pg.shared_store", return_value=None
    ) {
        with unittest.mock.patch(
            "jaclang.scale.persistence.pg.shared_store_error", return_value=None
        ) {
            with unittest.mock.patch(
                "jaclang.scale.persistence.pg.masked_db_url", return_value=""
            ) {
                with pytest.raises(RuntimeError) as exc {
                    JacScaleUserManager(base_path=".");
                }
            }
        }
    }
    msg = str(exc.value);
    assert "no [scale.database] url" in msg , msg;
    assert "Postgres" in msg;
    assert "credential store" in msg;
}

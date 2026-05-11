"""Tests JacScaleUserManager honors JAC_DATA_PATH for the SQLite identity store.

Frozen desktop sidecars install at read-only system paths (e.g. /usr/lib/<app>/
for a .deb), and the sidecar entry point sets JAC_DATA_PATH to a user-writable
location. UserManager must follow that convention so the SQLite store lands in
the writable dir instead of crashing with PermissionError, matching what the
rest of jaclang already does for project databases via get_db_path().
"""

import os;
import tempfile;
import from pathlib { Path }
import from jac_scale.user_manager { JacScaleUserManager }
import from jac_scale.config_loader { reset_scale_config }


"""When JAC_DATA_PATH is set, users.db must land under that dir, not base_path."""
test "JAC_DATA_PATH redirects SQLite identity store away from base_path" {
    with tempfile.TemporaryDirectory() as base_dir {
        with tempfile.TemporaryDirectory() as data_dir {
            toml_content = """
[project]
name = "test-user-manager-data-path"
version = "1.0.0"

[plugins.scale.jwt]
secret = "test_secret"
algorithm = "HS256"
exp_delta_days = 1

[plugins.scale.admin]
username = "admin"
default_password = "admin123"
require_password_reset = true
""";
            with open(os.path.join(base_dir, "jac.toml"), "w") as f {
                f.write(toml_content);
            }

            prev_data_path = os.environ.get('JAC_DATA_PATH');
            prev_mongodb_uri = os.environ.pop('MONGODB_URI', None);
            os.environ['JAC_DATA_PATH'] = data_dir;
            try {
                reset_scale_config();
                JacScaleUserManager(base_path=base_dir);

                data_db = Path(data_dir) / ".jac" / "data" / "users.db";
                base_db = Path(base_dir) / ".jac" / "data" / "users.db";

                assert data_db.exists(), (
                    f"SQLite store should be created under JAC_DATA_PATH ({data_db})"
                );
                assert not base_db.exists(), (
                    f"SQLite store must NOT leak into base_path ({base_db})"
                );
            } finally {
                if prev_data_path is None {
                    os.environ.pop('JAC_DATA_PATH', None);
                } else {
                    os.environ['JAC_DATA_PATH'] = prev_data_path;
                }
                if prev_mongodb_uri is not None {
                    os.environ['MONGODB_URI'] = prev_mongodb_uri;
                }
                reset_scale_config();
            }
        }
    }
}


"""Dev/source-tree runs don't set JAC_DATA_PATH; behavior falls back to base_path."""
test "Without JAC_DATA_PATH the SQLite store falls back to base_path" {
    with tempfile.TemporaryDirectory() as base_dir {
        toml_content = """
[project]
name = "test-user-manager-data-path"
version = "1.0.0"

[plugins.scale.jwt]
secret = "test_secret"
algorithm = "HS256"
exp_delta_days = 1

[plugins.scale.admin]
username = "admin"
default_password = "admin123"
require_password_reset = true
""";
        with open(os.path.join(base_dir, "jac.toml"), "w") as f {
            f.write(toml_content);
        }

        prev_data_path = os.environ.pop('JAC_DATA_PATH', None);
        prev_mongodb_uri = os.environ.pop('MONGODB_URI', None);
        try {
            reset_scale_config();
            JacScaleUserManager(base_path=base_dir);

            base_db = Path(base_dir) / ".jac" / "data" / "users.db";
            assert base_db.exists(), (
                f"SQLite store should fall back to base_path ({base_db})"
            );
        } finally {
            if prev_data_path is not None {
                os.environ['JAC_DATA_PATH'] = prev_data_path;
            }
            if prev_mongodb_uri is not None {
                os.environ['MONGODB_URI'] = prev_mongodb_uri;
            }
            reset_scale_config();
        }
    }
}

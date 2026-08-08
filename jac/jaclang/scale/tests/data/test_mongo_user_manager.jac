import os;
import from jaclang.scale.identity.user_manager { JacScaleUserManager }
import from jaclang.scale.config.config_loader { reset_scale_config }

test "JAC_DATA_PATH redirects SQLite identity store away from base_path" {
    import tempfile;
    import from pathlib { Path }

    with tempfile.TemporaryDirectory() as base_dir {
        with tempfile.TemporaryDirectory() as data_dir {
            with open(os.path.join(base_dir, "jac.toml"), "w") as f {
                f.write('[project]\nname = "t"\nversion = "1.0.0"\n');
            }
            prev = os.environ.get('JAC_DATA_PATH');
            os.environ.pop('MONGODB_URI', None);
            os.environ['JAC_DATA_PATH'] = data_dir;
            try {
                reset_scale_config();
                import from unittest.mock { patch }
                with patch(
                    "jaclang.scale.persistence.pg.shared_store", return_value=None
                ) {
                    JacScaleUserManager(base_path=base_dir);
                }
                assert (Path(data_dir) / ".jac" / "data" / "users.db").exists();
                assert not (Path(base_dir) / ".jac" / "data" / "users.db").exists();
            } finally {
                if prev is None {
                    os.environ.pop('JAC_DATA_PATH', None);
                } else {
                    os.environ['JAC_DATA_PATH'] = prev;
                }
                reset_scale_config();
            }
        }
    }
}

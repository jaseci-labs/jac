"""Test to ensure static assets in dev mode are properly proxied."""

import gc;
import os;
import tempfile;
import time;
import pytest;
import from subprocess { Popen, run }
import from urllib.request { urlopen }
import from urllib.error { HTTPError }

import from test_helpers {
    get_env_with_npm,
    get_free_port,
    get_jac_command,
    wait_for_port
}

"""Start the all-in-one jac server with a custom assets directory."""
def _start_dev_server_with_assets -> tuple {
    app_name = "dev-proxy-test-app";
    jac_cmd = get_jac_command();
    env = get_env_with_npm();

    temp_dir = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(temp_dir);

    # Create project using default template
    create_result = run(
        [*jac_cmd, "create", app_name], capture_output=True, text=True, env=env,
    );
    if create_result.returncode != 0 {
        pytest.fail(f"jac create failed: {create_result.stderr}");
    }

    project_path = os.path.join(temp_dir, app_name);

    # Create an assets directory and a dummy asset
    assets_dir = os.path.join(project_path, "assets");
    os.makedirs(assets_dir, exist_ok=True);
    dummy_asset_path = os.path.join(assets_dir, "dummy_test_asset.css");
    with open(dummy_asset_path, "w") as f {
        f.write('/* asset proxy works */');
    }

    dev_port = get_free_port();
    api_port = get_free_port();

    # Start dev server using Popen wrapper to match test_e2e approach
    server = Popen(
        [*jac_cmd, "start", "--dev", "-p", str(dev_port), "-a", str(api_port)],
        cwd=project_path,
        env=env,
    );

    wait_for_port("localhost", dev_port, timeout=120.0);
    wait_for_port("localhost", api_port, timeout=120.0);
    time.sleep(5);

    return (server, dev_port, api_port, temp_dir, original_cwd);
}

def _stop_running_server(server: Popen, temp_dir: str, original_cwd: str) {
    server.terminate();
    try {
        server.wait(timeout=15);
    } except Exception {
        server.kill();
        server.wait(timeout=5);
    }
    time.sleep(1);
    gc.collect();
    os.chdir(original_cwd);
    gc.collect();
}

test "dev mode properly proxies static assets" {
    (server, dev_port, api_port, temp_dir, original_cwd) = _start_dev_server_with_assets();
    try {
        dev_url = f"http://localhost:{dev_port}/assets/dummy_test_asset.css";

        # Test if Vite dev server correctly proxies the request to the backend
        # Using native urllib.request.urlopen to fetch the file
        response = urlopen(dev_url, timeout=10);
        assert response.getcode() == 200;

        content = response.read().decode("utf-8");
        assert 'asset proxy works' in content;
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

test "dev mode proxy returns 404 for missing assets" {
    (server, dev_port, api_port, temp_dir, original_cwd) = _start_dev_server_with_assets();
    try {
        dev_url = f"http://localhost:{dev_port}/assets/does_not_exist.css";

        try {
            urlopen(dev_url, timeout=10);
            pytest.fail("Expected 404 error but got 200 OK");
        } except HTTPError as e {
            assert e.code == 404;
        }
    } finally {
        _stop_running_server(server, temp_dir, original_cwd);
    }
}

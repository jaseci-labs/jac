"""Tests for Android adb device auto-start helpers."""

import unittest.mock;

import from jaclang.runtimelib.client.mobile_dev_host { ensure_adb_device }
import from jaclang.runtimelib.client.mobile_dev_host { list_adb_devices }


test "list_adb_devices parses connected device lines" {
    class _Res {
        has returncode: int = 0,
            stdout: str = (
                "List of devices attached\n"
                "emulator-5554\tdevice product:sdk\n"
                "offline-1\toffline\n"
            ),
            stderr: str = "";
    }

    with unittest.mock.patch("subprocess.run", return_value=_Res()) as _ {
        devices = list_adb_devices("/fake/adb");
    }
    assert devices == ["emulator-5554"];
}

test "ensure_adb_device returns adb when a device is already connected" {
    calls: list[list] = [];

    def _fake_run(cmd: list, **kwargs: object) -> object {
        calls.append(cmd);
        class _Res {
            has returncode: int = 0,
                stdout: str = "",
                stderr: str = "";
        }
        return _Res();
    }

    with unittest.mock.patch("shutil.which", return_value="/bin/adb") as _, unittest.mock.patch(
        "jaclang.runtimelib.client.mobile_dev_host.list_adb_devices",
        return_value=["emulator-5554"]
    ) as _, unittest.mock.patch("subprocess.run", side_effect=_fake_run) as _ {
        adb = ensure_adb_device("Small_Phone");
    }
    assert adb == "/bin/adb";
    assert calls == [] , "must not spawn emulator when a device is already connected";
}

test "ensure_adb_device starts the requested avd when none is connected" {
    popen_cmds: list[list] = [];
    run_cmds: list[list] = [];

    def _fake_popen(cmd: list, **kwargs: object) -> object {
        popen_cmds.append(cmd);
        return object();
    }

    def _fake_run(cmd: list, **kwargs: object) -> object {
        run_cmds.append(cmd);
        class _Res {
            has returncode: int = 0,
                stdout: str = "1" if cmd[-1] == "sys.boot_completed" else "",
                stderr: str = "";
        }
        return _Res();
    }

    with unittest.mock.patch("shutil.which", return_value="/bin/adb") as _, unittest.mock.patch(
        "jaclang.runtimelib.client.mobile_dev_host.list_adb_devices",
        side_effect=[[], ["emulator-5554"]]
    ) as _, unittest.mock.patch(
        "jaclang.runtimelib.client.mobile_dev_host.locate_android_emulator",
        return_value="/sdk/emulator/emulator"
    ) as _, unittest.mock.patch(
        "jaclang.runtimelib.client.mobile_dev_host.list_android_avds",
        return_value=["Small_Phone", "Pixel_8"]
    ) as _, unittest.mock.patch("subprocess.Popen", side_effect=_fake_popen) as _, unittest.mock.patch(
        "subprocess.run", side_effect=_fake_run
    ) as _, unittest.mock.patch("time.sleep") as _ {
        adb = ensure_adb_device("Small_Phone");
    }
    assert adb == "/bin/adb";
    assert popen_cmds
        == [["/sdk/emulator/emulator", "-avd", "Small_Phone", "-no-snapshot-load"]];
    assert ["/bin/adb", "wait-for-device"] in run_cmds;
    assert ["/bin/adb", "shell", "getprop", "sys.boot_completed"] in run_cmds;
}

test "ensure_adb_device raises when adb and emulator are unavailable" {
    with unittest.mock.patch("shutil.which", return_value=None) as _ {
        try {
            ensure_adb_device();
            assert False , "expected RuntimeError";
        } except RuntimeError as e {
            assert "adb not found" in str(e).lower();
        }
    }
}

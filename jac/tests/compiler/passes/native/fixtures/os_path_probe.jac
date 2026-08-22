import os;

with entry {
    with open("/tmp/jac_ospath_probe.txt", "w") as f {
        f.write("hello");
    }
    _ = os.system("mkdir -p /tmp/jac_ospath_probe_dir");
    print(os.path.isfile("/tmp/jac_ospath_probe.txt"));
    print(os.path.isfile("/tmp/jac_ospath_probe_dir"));
    print(os.path.isdir("/tmp/jac_ospath_probe_dir"));
    print(os.path.isdir("/tmp/jac_ospath_probe.txt"));
    print(os.path.exists("/tmp/jac_ospath_probe.txt"));
    print(os.path.isfile("/tmp/jac_ospath_missing_zz"));
    print(os.path.getsize("/tmp/jac_ospath_probe.txt"));
    print(os.path.getsize("/tmp/jac_ospath_missing_zz"));
}

import os;
import from typing { Any }
import from jac_scale.factories.sandbox_factory { SandboxFactory }
import from jac_scale.factories.ingress_factory { IngressFactory }
import from jac_scale.abstractions.sandbox_environment { SandboxEnvironment }
import from jac_scale.abstractions.ingress_provider { IngressProvider }
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.models.sandbox_result { SandboxResult }
import from jac_scale.abstractions.models.sandbox_status {
    SandboxState,
    SandboxStatus,
    SandboxInfo
}
import from jac_scale.providers.sandbox.local_sandbox { LocalSandbox }
import from jac_scale.providers.sandbox.kubernetes_sandbox { KubernetesSandbox }

# ---- SandboxConfig tests ----
test "sandbox config has correct defaults" {
    config = SandboxConfig();
    assert config.sandbox_type == "docker";
    assert config.namespace == "jac-sandboxes";
    assert config.max_per_user == 3;
    assert config.ttl_seconds == 3600;
    assert config.cpu_limit == "500m";
    assert config.memory_limit == "512Mi";
    assert config.security_context_enabled == True;
    assert config.network_isolation == True;
    assert config.app_storage_limit == "1Gi";
}

test "sandbox config from_dict" {
    cfg = SandboxConfig.from_dict(
        {
            "type": "kubernetes",
            "namespace": "test-ns",
            "max_per_user": 5,
            "ttl_seconds": 7200,
            "cpu_limit": "1",
            "memory_limit": "1Gi",
            "app_storage_limit": "2Gi"
        }
    );
    assert cfg.sandbox_type == "kubernetes";
    assert cfg.namespace == "test-ns";
    assert cfg.max_per_user == 5;
    assert cfg.ttl_seconds == 7200;
    assert cfg.cpu_limit == "1";
    assert cfg.memory_limit == "1Gi";
    assert cfg.app_storage_limit == "2Gi";
}

test "sandbox config from_dict with defaults" {
    cfg = SandboxConfig.from_dict({});
    assert cfg.sandbox_type == "docker";
    assert cfg.namespace == "jac-sandboxes";
    assert cfg.app_storage_limit == "1Gi";
}

# ---- SandboxResult tests ----
test "sandbox result successful" {
    result = SandboxResult(
        success=True, sandbox_id="test-123", url="http://localhost:5180", port=5180
    );
    assert result.is_successful();
    assert result.sandbox_id == "test-123";
    assert result.url == "http://localhost:5180";
    assert result.port == 5180;
}

test "sandbox result failed" {
    result = SandboxResult(success=False, message="No ports available");
    assert not result.is_successful();
    assert result.message == "No ports available";
}

# ---- SandboxStatus tests ----
test "sandbox status running" {
    status = SandboxStatus(
        state=SandboxState.RUNNING,
        sandbox_id="test-123",
        uptime_seconds=60.0,
        url="http://localhost:5180",
        port=5180
    );
    assert status.is_running();
    assert status.sandbox_id == "test-123";
    assert status.uptime_seconds == 60.0;
}

test "sandbox status stopped" {
    status = SandboxStatus(state=SandboxState.STOPPED, sandbox_id="test-123");
    assert not status.is_running();
}

# ---- SandboxInfo tests ----
test "sandbox info creation" {
    info = SandboxInfo(
        sandbox_id="test-123",
        user_id="user1",
        project_id="proj1",
        state=SandboxState.RUNNING,
        url="http://localhost:5180",
        created_at=1000.0
    );
    assert info.sandbox_id == "test-123";
    assert info.user_id == "user1";
    assert info.project_id == "proj1";
    assert info.state == SandboxState.RUNNING;
}

# ---- SandboxFactory tests ----
test "sandbox factory creates local sandbox" {
    sandbox = SandboxFactory.create("local", {});
    assert sandbox is not None;
    assert isinstance(sandbox, SandboxEnvironment);
    assert isinstance(sandbox, LocalSandbox);
    assert hasattr(sandbox, "create");
    assert hasattr(sandbox, "stop");
    assert hasattr(sandbox, "status");
    assert hasattr(sandbox, "destroy");
    assert hasattr(sandbox, "logs");
    assert hasattr(sandbox, "write_file");
    assert hasattr(sandbox, "read_file");
}

test "sandbox factory creates docker sandbox" {
    sandbox = SandboxFactory.create("docker", {});
    assert sandbox is not None;
    assert isinstance(sandbox, SandboxEnvironment);
    assert hasattr(sandbox, "create");
    assert hasattr(sandbox, "stop");
}

test "sandbox factory creates kubernetes sandbox" {
    sandbox = SandboxFactory.create("kubernetes", {});
    assert sandbox is not None;
    assert isinstance(sandbox, SandboxEnvironment);
    assert hasattr(sandbox, "create");
    assert hasattr(sandbox, "stop");
}

test "sandbox factory raises for unsupported type" {
    raised = False;
    try {
        SandboxFactory.create("unsupported", {});
    } except ValueError as e {
        raised = True;
        assert "Unsupported sandbox type" in str(e);
    }
    assert raised , "Expected ValueError for unsupported sandbox type";
}

test "sandbox factory get_default returns local when no config" {
    # Clear env vars that might affect the test
    old_type = os.environ.pop("JAC_SANDBOX_TYPE", None);
    try {
        sandbox = SandboxFactory.get_default();
        assert sandbox is not None;
        assert isinstance(sandbox, SandboxEnvironment);
    } finally {
        if old_type {
            os.environ["JAC_SANDBOX_TYPE"] = old_type;
        }
    }
}

test "sandbox factory respects env var override" {
    old_type = os.environ.get("JAC_SANDBOX_TYPE");
    os.environ["JAC_SANDBOX_TYPE"] = "docker";
    try {
        sandbox = SandboxFactory.get_default();
        assert sandbox is not None;
    } finally {
        if old_type {
            os.environ["JAC_SANDBOX_TYPE"] = old_type;
        } else {
            os.environ.pop("JAC_SANDBOX_TYPE", None);
        }
    }
}

# ---- IngressFactory tests ----
test "ingress factory creates local ingress" {
    ingress = IngressFactory.create("local", {});
    assert ingress is not None;
    assert isinstance(ingress, IngressProvider);
    assert hasattr(ingress, "create_route");
    assert hasattr(ingress, "delete_route");
    assert hasattr(ingress, "get_url");
}

test "ingress factory creates kubernetes ingress" {
    ingress = IngressFactory.create("kubernetes", {});
    assert ingress is not None;
    assert isinstance(ingress, IngressProvider);
}

test "ingress factory raises for unsupported type" {
    raised = False;
    try {
        IngressFactory.create("unsupported", {});
    } except ValueError as e {
        raised = True;
        assert "Unsupported ingress type" in str(e);
    }
    assert raised , "Expected ValueError for unsupported ingress type";
}

# ---- LocalIngress behavior tests ----
test "local ingress creates and retrieves routes" {
    ingress = IngressFactory.create("local", {});
    url = ingress.create_route("test-sandbox", "svc", 8000, "default", {});
    assert url == "http://localhost:8000";
    assert ingress.get_url("test-sandbox") == "http://localhost:8000";

    ingress.delete_route("test-sandbox", "default");
    assert ingress.get_url("test-sandbox") is None;
}

# ---- LocalSandbox lifecycle tests ----
test "local sandbox lifecycle create status stop destroy" {
    import shutil;
    import tempfile;

    sandbox = LocalSandbox(config=SandboxConfig());

    # Create a temp directory with a main.jac
    temp_dir = tempfile.mkdtemp();
    with open(os.path.join(temp_dir, "main.jac"), "w") as f {
        f.write("with entry { print('hello'); }");
    }

    # Create sandbox — will fail to start (no jac binary in test env typically)
    # but we can test the registration and status flow
    result = sandbox.create("test-user", "test-proj", temp_dir);

    # Even if jac isn't installed, the sandbox should be registered
    assert result.sandbox_id != "";

    # Check status
    status = sandbox.status(result.sandbox_id);
    assert status.sandbox_id == result.sandbox_id;
    assert status.state in [
        SandboxState.STARTING,
        SandboxState.RUNNING,
        SandboxState.ERROR,
        SandboxState.STOPPED
    ];

    # List sandboxes
    sandboxes = sandbox.list_sandboxes("test-user");
    assert len(sandboxes) >= 1;
    found = False;
    for s in sandboxes {
        if s.sandbox_id == result.sandbox_id {
            found = True;
        }
    }
    assert found , "Created sandbox should appear in list";

    # Stop
    sandbox.stop(result.sandbox_id);
    status_after = sandbox.status(result.sandbox_id);
    assert status_after.state == SandboxState.STOPPED;

    # Destroy
    sandbox.destroy(result.sandbox_id);
    sandboxes_after = sandbox.list_sandboxes("test-user");
    for s in sandboxes_after {
        assert s.sandbox_id != result.sandbox_id , "Destroyed sandbox should not appear in list";
    }

    # Cleanup
    shutil.rmtree(temp_dir, ignore_errors=True);
}

test "local sandbox file operations" {
    import shutil;
    import tempfile;

    sandbox = LocalSandbox(config=SandboxConfig());
    temp_dir = tempfile.mkdtemp();
    with open(os.path.join(temp_dir, "main.jac"), "w") as f {
        f.write("with entry { print('hello'); }");
    }

    result = sandbox.create("test-user2", "test-proj2", temp_dir);
    sid = result.sandbox_id;

    # Write file
    write_result = sandbox.write_file(sid, "test.txt", "hello world");
    assert write_result.get("success") == True;

    # Read file
    read_result = sandbox.read_file(sid, "test.txt");
    assert read_result.get("success") == True;
    assert read_result.get("content") == "hello world";

    # List files
    list_result = sandbox.list_files(sid);
    assert list_result.get("success") == True;
    files = list_result.get("files", []);
    assert "test.txt" in files;

    # Delete file
    delete_result = sandbox.delete_file(sid, "test.txt");
    assert delete_result.get("success") == True;

    # Verify deleted
    read_after = sandbox.read_file(sid, "test.txt");
    assert not read_after.get("success");

    # Cleanup
    sandbox.destroy(sid);
    shutil.rmtree(temp_dir, ignore_errors=True);
}

test "local sandbox enforces path sandboxing" {
    import shutil;
    import tempfile;

    sandbox = LocalSandbox(config=SandboxConfig());
    temp_dir = tempfile.mkdtemp();
    with open(os.path.join(temp_dir, "main.jac"), "w") as f {
        f.write("with entry { print('hello'); }");
    }

    result = sandbox.create("test-user3", "test-proj3", temp_dir);
    sid = result.sandbox_id;

    # Attempt path traversal — should fail
    read_result = sandbox.read_file(sid, "../../etc/passwd");
    assert not read_result.get("success")
    or "outside" in read_result.get("error", "").lower()
    or read_result.get("error") == "File not found";

    sandbox.destroy(sid);
    shutil.rmtree(temp_dir, ignore_errors=True);
}

test "local sandbox get_sandbox_id convenience" {
    import shutil;
    import tempfile;

    sandbox = LocalSandbox(config=SandboxConfig());
    temp_dir = tempfile.mkdtemp();
    with open(os.path.join(temp_dir, "main.jac"), "w") as f {
        f.write("with entry { print('hello'); }");
    }

    result = sandbox.create("user4", "proj4", temp_dir);
    assert result.sandbox_id != "";

    # get_sandbox_id should return the same ID
    found_id = sandbox.get_sandbox_id("user4", "proj4");
    assert found_id == result.sandbox_id;

    # Non-existent user
    assert sandbox.get_sandbox_id("nonexistent", "proj") is None;

    sandbox.destroy(result.sandbox_id);
    shutil.rmtree(temp_dir, ignore_errors=True);
}

# ---- Sandbox pod security hardening tests ----
test "build_pod_spec security hardening when enabled" {
    config = SandboxConfig(security_context_enabled=True, app_storage_limit="2Gi");
    sandbox = KubernetesSandbox(config=config);
    pod: Any = sandbox._build_pod_spec("sbx-1", "cm-1", "user1", "proj1");

    # Security context on main container
    sc: Any = pod.spec.containers[0].security_context;
    assert sc is not None;
    assert sc.run_as_non_root;
    assert sc.run_as_user == 1000;
    assert not sc.allow_privilege_escalation;
    assert "ALL" in sc.capabilities.drop;
    assert sc.seccomp_profile.type == "RuntimeDefault";

    # SA token disabled at pod level
    assert not pod.spec.automount_service_account_token;

    # app-data volume has size limit
    app_vol: Any = None;
    for v in pod.spec.volumes {
        if v.name == "app-data" {
            app_vol = v;
        }
    }
    assert app_vol is not None;
    assert app_vol.empty_dir.size_limit == "2Gi";

    # Init container runs chown
    init: Any = pod.spec.init_containers[0];
    cmd_str: str = str(" ".join(init.command));
    assert "chown -R 1000:1000 /app" in cmd_str;
}

test "build_pod_spec no security context when disabled but SA token still off" {
    config = SandboxConfig(security_context_enabled=False);
    sandbox = KubernetesSandbox(config=config);
    pod: Any = sandbox._build_pod_spec("sbx-2", "cm-2", "user1", "proj1");

    sc: Any = pod.spec.containers[0].security_context;
    assert sc is None;
    assert not pod.spec.automount_service_account_token;
}

test "warm pod spec security hardening matches regular pod" {
    config = SandboxConfig(security_context_enabled=True, app_storage_limit="3Gi");
    sandbox = KubernetesSandbox(config=config);
    warm: Any = sandbox._build_warm_pod_spec("warm-1");

    sc: Any = warm.spec.containers[0].security_context;
    assert sc is not None;
    assert "ALL" in sc.capabilities.drop;
    assert sc.seccomp_profile.type == "RuntimeDefault";
    assert sc.run_as_non_root;
    assert sc.run_as_user == 1000;
    assert not sc.allow_privilege_escalation;
    assert not warm.spec.automount_service_account_token;

    # Storage limit
    app_vol: Any = None;
    for v in warm.spec.volumes {
        if v.name == "app-data" {
            app_vol = v;
        }
    }
    assert app_vol is not None;
    assert app_vol.empty_dir.size_limit == "3Gi";
}

test "warm pod spec no security context when disabled" {
    config = SandboxConfig(security_context_enabled=False);
    sandbox = KubernetesSandbox(config=config);
    warm: Any = sandbox._build_warm_pod_spec("warm-2");

    sc: Any = warm.spec.containers[0].security_context;
    assert sc is None;
    assert not warm.spec.automount_service_account_token;
}

# ---- Warm pool TTL tests ----
test "sandbox config warm_pool_ttl defaults to zero" {
    config = SandboxConfig();
    assert config.warm_pool_ttl == 0;
}

test "sandbox config warm_pool_ttl from_dict" {
    cfg = SandboxConfig.from_dict({"warm_pool_ttl": 7200});
    assert cfg.warm_pool_ttl == 7200;
}

test "sandbox config warm_pool_ttl from_dict defaults to zero" {
    cfg = SandboxConfig.from_dict({});
    assert cfg.warm_pool_ttl == 0;
}

test "warm pod spec no activeDeadlineSeconds when warm_pool_ttl is zero" {
    config = SandboxConfig(warm_pool_size=3, warm_pool_ttl=0);
    sandbox = KubernetesSandbox(config=config);
    warm: Any = sandbox._build_warm_pod_spec("warm-ttl-0");

    assert warm.spec.active_deadline_seconds is None;
}

test "warm pod spec uses warm_pool_ttl when set" {
    config = SandboxConfig(warm_pool_size=3, warm_pool_ttl=7200);
    sandbox = KubernetesSandbox(config=config);
    warm: Any = sandbox._build_warm_pod_spec("warm-ttl-7200");

    assert warm.spec.active_deadline_seconds == 7200;
}

test "warm pod spec ttl independent from sandbox ttl" {
    config = SandboxConfig(ttl_seconds=1800, warm_pool_size=3, warm_pool_ttl=0);
    sandbox = KubernetesSandbox(config=config);
    warm: Any = sandbox._build_warm_pod_spec("warm-independent");

    # Warm pod should NOT inherit sandbox ttl_seconds
    assert warm.spec.active_deadline_seconds is None;
}

test "regular pod spec still uses sandbox ttl_seconds" {
    config = SandboxConfig(ttl_seconds=1800, warm_pool_size=3, warm_pool_ttl=0);
    sandbox = KubernetesSandbox(config=config);
    pod: Any = sandbox._build_pod_spec("sbx-ttl", "cm-ttl", "user1", "proj1");

    # Regular pod should use ttl_seconds
    assert pod.spec.active_deadline_seconds == 1800;
}

# ---- Sandbox status returns STOPPED for missing pods ----
test "k8s sandbox status returns STOPPED when pod query fails" {
    config = SandboxConfig();
    sandbox = KubernetesSandbox(config=config);

    # Manually inject a fake registry entry with RUNNING state
    sandbox._registry["dead-sandbox-123"] = {
        "sandbox_id": "dead-sandbox-123",
        "user_id": "user1",
        "project_id": "proj1",
        "pod_name": "dead-sandbox-123",
        "namespace": "jac-sandboxes",
        "status": SandboxState.RUNNING,
        "url": "http://dead-sandbox.example.com",
        "port": 8000,
        "created_at": 1000.0
    };

    # status() will try to query K8s which will fail (no cluster),
    # and should return STOPPED instead of cached RUNNING
    status = sandbox.status("dead-sandbox-123");
    assert status.state == SandboxState.STOPPED;
    assert status.sandbox_id == "dead-sandbox-123";
    assert status.uptime_seconds == 0.0;
}

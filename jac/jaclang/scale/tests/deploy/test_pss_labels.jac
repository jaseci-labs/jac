"""jac-scale must be able to upgrade a namespace it labeled itself.

The deploy stamps enforce=baseline on any namespace lacking an enforce label,
then the observability step refused to touch a namespace that already carried
one, so the privileged upgrade the hostPath DaemonSets need could never fire on
a namespace jac-scale created. An operator's own label must still be respected.
"""

test "the default labels record that jac-scale set the enforce level" {
    labels = default_pss_labels();
    assert labels[PSS_ENFORCE_LABEL] == "baseline";
    assert labels[PSS_WARN_LABEL] == "restricted";
    assert labels[PSS_SOURCE_LABEL] == "baseline";
}


test "an unlabeled namespace is upgraded to privileged" {
    patch = privileged_pss_labels({});
    assert patch == {PSS_ENFORCE_LABEL: "privileged", PSS_SOURCE_LABEL: "privileged"};
}


test "the baseline jac-scale set on this namespace is upgraded, not refused" {
    patch = privileged_pss_labels(default_pss_labels());
    assert patch is not None , "jac-scale must be able to overwrite its own default";
    assert patch[PSS_ENFORCE_LABEL] == "privileged";
    assert patch[PSS_SOURCE_LABEL] == "privileged" , "the marker follows the value";
}


test "an operator's own enforce label is left alone" {
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "baseline"}) is None;
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "restricted"}) is None;
}


test "a namespace whose baseline came from somewhere else is left alone" {
    existing = {PSS_ENFORCE_LABEL: "restricted", PSS_SOURCE_LABEL: "baseline"};
    assert privileged_pss_labels(existing) is None;
}


test "a namespace already privileged needs no patch and no warning" {
    assert privileged_pss_labels({PSS_ENFORCE_LABEL: "privileged"}) == {};
}


test "a second deploy of the same namespace is a no-op" {
    first = privileged_pss_labels(default_pss_labels());
    settled = {** default_pss_labels(), ** first};
    assert privileged_pss_labels(settled) == {} , "upgrading twice must not re-patch";
}


test "only a privileged level jac-scale set is released, and default goes back to unlabeled" {
    jac_privileged = {PSS_ENFORCE_LABEL: "privileged", PSS_SOURCE_LABEL: "privileged"};
    cases: list[tuple[str, dict[str, str], dict[str, any]]] = [
        (
            "app-ns",
            jac_privileged,
            {PSS_ENFORCE_LABEL: "baseline", PSS_SOURCE_LABEL: "baseline"}
        ),
        ("default", jac_privileged, {PSS_ENFORCE_LABEL: None, PSS_SOURCE_LABEL: None}),
        ("app-ns", {PSS_ENFORCE_LABEL: "privileged"}, {}),
        ("app-ns", default_pss_labels(), {}),
        ("app-ns", {}, {}),

    ];
    for (namespace, existing, expected) in cases {
        assert released_pss_labels(namespace, existing) == expected , (
            namespace,
            existing
        );
    }
}


test "a workload holds the namespace exactly while it can ask the node for something" {
    import from kubernetes.client {
        V1AppArmorProfile,
        V1Capabilities,
        V1PodSecurityContext,
        V1SELinuxOptions,
        V1SeccompProfile,
        V1Sysctl,
        V1WindowsSecurityContextOptions,
        V1Job,
        V1JobCondition,
        V1JobStatus,
        V1Container,
        V1ContainerPort,
        V1HostPathVolumeSource,
        V1HTTPGetAction,
        V1Lifecycle,
        V1LifecycleHandler,
        V1PodSpec,
        V1Probe,
        V1TCPSocketAction,
        V1SecurityContext,
        V1Volume
    }
    plain = V1Container(name="app", image="app");
    cases: list[tuple[str, any, bool]] = [
        ("plain", V1PodSpec(containers=[plain]), False),
        ("no spec", None, False),
        (
            "hostPath volume",
            V1PodSpec(
                containers=[plain],
                volumes=[
                    V1Volume(
                        name="logs",
                        host_path=V1HostPathVolumeSource(path="/var/log/pods")
                    )
                ]
            ),
            True
        ),
        ("host network", V1PodSpec(containers=[plain], host_network=True), True),
        (
            "privileged container",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x", security_context=V1SecurityContext(privileged=True)
                    )
                ]
            ),
            True
        ),
        (
            "added capability",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(
                            capabilities=V1Capabilities(add=["NET_ADMIN"])
                        )
                    )
                ]
            ),
            True
        ),
        (
            "jac-bootstrap's baseline-allowed capabilities",
            V1PodSpec(
                containers=[plain],
                init_containers=[
                    V1Container(
                        name="jac-bootstrap",
                        security_context=V1SecurityContext(
                            capabilities=V1Capabilities(
                                drop=["ALL"],
                                add=[
                                    "CHOWN",
                                    "DAC_OVERRIDE",
                                    "FOWNER",
                                    "FSETID",
                                    "SETUID",
                                    "SETGID"
                                ]
                            )
                        )
                    )
                ]
            ),
            False
        ),
        (
            "one capability beyond baseline among allowed ones",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(
                            capabilities=V1Capabilities(add=["CHOWN", "SYS_ADMIN"])
                        )
                    )
                ]
            ),
            True
        ),
        (
            "pod seccomp Unconfined",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    seccomp_profile=V1SeccompProfile(type="Unconfined")
                )
            ),
            True
        ),
        (
            "pod seccomp RuntimeDefault",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    seccomp_profile=V1SeccompProfile(type="RuntimeDefault")
                )
            ),
            False
        ),
        (
            "container AppArmor Unconfined",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(
                            app_armor_profile=V1AppArmorProfile(type="Unconfined")
                        )
                    )
                ]
            ),
            True
        ),
        (
            "unsafe sysctl",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    sysctls=[V1Sysctl(name="kernel.msgmax", value="65536")]
                )
            ),
            True
        ),
        (
            "safe sysctl",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    sysctls=[V1Sysctl(name="net.ipv4.tcp_syncookies", value="1")]
                )
            ),
            False
        ),
        (
            "unmasked /proc",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(proc_mount="Unmasked")
                    )
                ]
            ),
            True
        ),
        (
            "custom SELinux type",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    se_linux_options=V1SELinuxOptions(type="spc_t")
                )
            ),
            True
        ),
        (
            "container SELinux type",
            V1PodSpec(
                containers=[plain],
                security_context=V1PodSecurityContext(
                    se_linux_options=V1SELinuxOptions(type="container_t", level="s0")
                )
            ),
            False
        ),
        (
            "Windows hostProcess",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(
                            windows_options=V1WindowsSecurityContextOptions(
                                host_process=True
                            )
                        )
                    )
                ]
            ),
            True
        ),
        (
            "dropped capabilities only",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        security_context=V1SecurityContext(
                            capabilities=V1Capabilities(drop=["ALL"])
                        )
                    )
                ]
            ),
            False
        ),
        (
            "host port",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        ports=[V1ContainerPort(container_port=80, host_port=80)]
                    )
                ]
            ),
            True
        ),
        (
            "readiness probe on the pod's own address",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        readiness_probe=V1Probe(
                            http_get=V1HTTPGetAction(path="/healthz", port=80)
                        )
                    )
                ]
            ),
            False
        ),
        (
            "liveness probe sent to another host",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        liveness_probe=V1Probe(
                            http_get=V1HTTPGetAction(
                                path="/healthz", port=80, host="10.0.0.1"
                            )
                        )
                    )
                ]
            ),
            True
        ),
        (
            "preStop hook sent to another host",
            V1PodSpec(
                containers=[
                    V1Container(
                        name="x",
                        lifecycle=V1Lifecycle(
                            pre_stop=V1LifecycleHandler(
                                tcp_socket=V1TCPSocketAction(port=80, host="10.0.0.1")
                            )
                        )
                    )
                ]
            ),
            True
        ),

    ];
    for (label, spec, expected) in cases {
        assert pod_spec_escapes_baseline(spec) == expected , label;
    }

    def _job(*conditions: tuple[str, str]) -> any {
        return V1Job(
            status=V1JobStatus(
                conditions=[V1JobCondition(type=t, status=st) for (t, st) in conditions]
            )
        );
    }
    jobs: list[tuple[str, any, bool]] = [
        ("running", _job(), False),
        ("no status", V1Job(), False),
        ("complete", _job(("Complete", "True")), True),
        ("failed", _job(("Failed", "True")), True),
        ("suspended, not finished", _job(("Suspended", "True")), False),
        ("complete condition not yet true", _job(("Complete", "False")), False),

    ];
    for (label, job, finished) in jobs {
        assert job_finished(job) == finished , label;
    }
}

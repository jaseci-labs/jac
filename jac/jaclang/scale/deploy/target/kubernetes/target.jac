import logging;
import secrets;
import time;

glob MINTED_SECRET_NOTES: dict[str, str] = {
         SIGNING_SECRET_ENV: "Minted a JWT signing secret, kept across redeploys. Set "
         "[scale.secrets] JAC_SERVE_AUTH_SECRET to control it yourself.",
         ADMIN_PASSWORD_ENV: "Minted the bootstrap admin password into the app Secret "
         "as JAC_SCALE_ADMIN_PASSWORD, kept across redeploys. Set [scale.admin] "
         "default_password to control it yourself."
     },
     logger = logging.getLogger(__name__),
     REVISION_ANNOTATION: str = "deployment.kubernetes.io/revision",
     FLEET_SELECTOR: str = "managed=jac-scale,jac-scale.role in (microservice,gateway)";


def _revision_sort_key(item: dict[str, any]) -> int;


def fleet_revert_order(names: list[str]) -> list[str];


def app_bundle_digest(bundle_keys: list[str]) -> str;


def releases_from_revisions(entries: list[dict[str, any]]) -> list[dict[str, any]];


def fleet_targets_for_release(
    releases: list[dict[str, any]], revision: int, expected: list[str]
) -> dict[str, any];


def replacing_init_containers(body: dict[str, any]) -> dict[str, any];


def restorable_pod_template(template: dict[str, any]) -> dict[str, any];

def apply_http_activations_for_bundle(
    bundle: dict[str, any], namespace: str, keda: KEDAAutoscaler
);


def reap_stale_scaling_resources_for_bundle(
    bundle: dict[str, any], namespace: str, autoscaler: any, keda: KEDAAutoscaler
);


obj KubernetesTarget(KubernetesTargetBase) {
    has _deploy_context: DeployContext = DeployContext(),
        fleet: (FleetSpec | None) = None,
        gateway_config: (dict[str, any] | None) = None,
        app_overrides: dict[str, dict[str, any]] = {};

    def _gateway_cfg -> dict[str, any];
    def deploy(app_config: AppConfig) -> DeploymentResult;
    def _scan_for_crash_loop(
        core_v1: any,
        ns: str,
        current_hashes: set,
        fleet_app_names: set,
        companion_app_names: set | None = None
    ) -> dict[str, any];

    def _pod_mount_wedged(core_v1: any, ns: str, pod_name: str) -> bool;
    def _try_self_heal(
        core_v1: any, ns: str, pod: any, why: str, healed_apps: dict[str, int]
    ) -> bool;

    def _wait_for_fleet_rollout(
        bundle: dict[str, any], timeout: int = 1200, require_full: bool = False
    ) -> None;

    def _pod_failure_detail(
        core_v1: any, namespace: str, pod_name: str, pod: any = None
    ) -> str;

    def _observability_requested -> bool;
    def _deploy_observability(app_name: str) -> None;
    def ensure_alb_readiness_gates(core_v1: any, namespace: str) -> None;
    def _ensure_privileged_namespace(core_v1: any, namespace: str) -> None;
    def _build_observability_config -> KubernetesConfig;
    def _read_gateway_logs_config -> dict[str, any];
    def _read_gateway_tracing_config -> dict[str, any];
    def generate_manifests(app_config: AppConfig) -> dict[str, any];
    def _manifest_builder(app_config: AppConfig) -> ManifestBuilder;
    def _context_with_env -> DeployContext;
    def _resolve_service_triggers(svc_name: str, cfg: dict[str, any]) -> list[Trigger];
    def _autoscaler_spec(
        svc_name: str, plan: dict[str, any], autoscaler: any, namespace: str
    ) -> AutoscalerSpec;

    def render_autoscaler_manifests(bundle: dict[str, any]) -> list[dict[str, any]];
    def apply_manifests(bundle: dict[str, any]);
    def _apply_ops_rbac(namespace: str, ops_rbac: dict[str, any]);
    def reap_superseded_deployments(
        apps_v1: any, namespace: str, bundle: dict[str, any]
    );

    def _fleet_deployment_names(apps_v1: any, namespace: str) -> list[str];
    def _owned_replica_sets(
        apps_v1: any, namespace: str, strict: bool = False
    ) -> list[any];

    def _revision_entries(strict: bool = False) -> list[dict[str, any]];
    def _assert_own_app(app_name: str);
    def list_revisions(app_name: str) -> list[dict[str, any]];
    def referenced_bundle_keys(app_name: str) -> set[str];
    def _restore_templates(
        apps_v1: any, namespace: str, names: list[str], undo: dict[str, any]
    ) -> list[str];

    def rollback_to(app_name: str, revision: int) -> DeploymentResult;
    def _deployment_patch_body(
        manifest: dict[str, any], plan: dict[str, any]
    ) -> (dict[str, any] | None);

    def _apply_or_replace(
        api: any,
        read: str,
        update: str,
        create: str,
        namespace: str,
        manifest: dict[str, any],
        patch_body: (dict[str, any] | None) = None
    );

    def _apply_or_replace_pvc(core_v1: any, namespace: str, manifest: dict[str, any]);
    def _destroy_fleet_workloads(
        namespace: str, apps_v1: any, core_v1: any, policy_v1: any, networking_v1: any
    );

    def _destroy_monitoring(
        app_name: str, namespace: str, apps_v1: any, core_v1: any, strict: bool = False
    ) -> bool;

    def _postgres_pvc_name(app_name: str) -> str;
    def _app_pvc_names(app_name: str) -> list[str];
    def _destroy_pvcs(pvc_names: list[str], namespace: str, core_v1: any);
    def _destroy_app_pvcs(app_name: str, namespace: str, core_v1: any);
    def _report_unowned_shared_volumes(namespace: str, core_v1: any);
    def _destroy_shared_volume_pvcs(
        app_name: str, namespace: str, core_v1: any, sole_tenant: bool
    );

    def _list_managed(lister: any, namespace: str, selector: str) -> list[any];
    def _foreign_app_resources(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) -> list[str];

    def _co_tenants_best_effort(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    ) -> list[str];

    def _warn_co_tenant_workloads_removed(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _destroy_ops_rbac(app_name: str, namespace: str);
    def _wait_for_namespace_deletion(
        namespace: str, core_v1: any, timeout: int = 300
    ) -> bool;

    def _reclaim_namespace(namespace: str, core_v1: any) -> bool;
    def _destroy_app_database(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _destroy_in_shared_namespace(
        app_name: str, namespace: str, apps_v1: any, core_v1: any, sole_tenant: bool
    );

    def destroy(app_name: str, component: str = "");
    def _destroy_named_component(
        app_name: str,
        namespace: str,
        component: str,
        apps_v1: any,
        core_v1: any,
        policy_v1: any,
        networking_v1: any
    );
}

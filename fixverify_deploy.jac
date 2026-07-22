"""#7668 verification driver: deploy a type-error fullstack app through the
programmatic jac-scale API (the PR's manifest builder, via the editable dev
loop) and prove the gateway still ships the client."""
import os;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config { KubernetesConfig }
import from jaclang.scale.deploy.target.kubernetes.microservice.target { KubernetesMicroserviceTarget }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.observability.factory { UtilityFactory }

with entry {
    app_dir = os.environ["FIXVERIFY_APP"];
    cfg = KubernetesConfig(app_name="fixverify", namespace="jac-fixverify-7668");
    target = KubernetesMicroserviceTarget(
        config=cfg,
        logger=UtilityFactory.create_logger('standard'),
        no_image=True,
        microservices_config={}
    );
    app_cfg = AppConfig(code_folder=app_dir, file_name="main.jac", app_name="fixverify", no_image=True);
    result = target.deploy(app_cfg);
    print("DEPLOY_RESULT success=", result.success, " msg=", result.message);
}

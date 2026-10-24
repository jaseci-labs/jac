import base64;
import os;
import secrets as _pysecrets;

glob PG_PORT = 5432,
     PG_IMAGE = 'postgres:18',
     POD_NAMESPACE_FILE = '/var/run/secrets/kubernetes.io/serviceaccount/namespace',
     CLUSTER_DNS_SUFFIX = 'svc.cluster.local';


obj KubernetesPostgresProvider {
    has target: (DeploymentTarget | None) = None,
        config: dict[str, any] = {},
        app_name: str postinit,
        connection_string: str = '';

    def postinit;
    def _db_cfg -> dict[str, any];
    def _requested_mode -> str;
    def _configured_url -> str;
    def _source_namespace -> str;
    def _qualify_external_url(url: str) -> str;
    def _intent -> dict[str, str];
    def _mode -> str;
    def _names -> dict[str, str];
    def get_connection_string -> str;
    def is_available -> bool;
    def deploy(config: dict[str, any] = {}) -> dict[str, any];
    def cleanup;
    def get_init_container(
        app_name: str, wait_image: str
    ) -> (dict[(str, any)] | None);
}

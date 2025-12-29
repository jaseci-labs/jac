import tempfile;
import urllib.request;
import from kubernetes { client, config, utils }
import from kubernetes.client.exceptions { ApiException }
def install_and_patch_metrics_server -> None;

def install_metrics_server_yaml -> None;

with entry {
    if (__name__ == '__main__') {
        install_and_patch_metrics_server();
    }
}

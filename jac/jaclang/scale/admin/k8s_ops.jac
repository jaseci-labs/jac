import os;
import logging;

glob logger = logging.getLogger(__name__);

glob _config_loaded: bool = False,
     _config_ok: bool = False;


def k8s_available -> bool;


def _ensure_config -> bool;


def ops_namespace -> str;


def core_api -> any;


def apps_api -> any;


def networking_api -> any;


def autoscaling_api -> any;


def custom_objects_api -> any;


def api_error_detail(e: any) -> str;


def unavailable_detail -> str;

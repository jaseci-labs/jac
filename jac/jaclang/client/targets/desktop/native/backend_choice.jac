import json;
import os;
import threading;

glob ASK: str = "ask",
     EMBEDDED_BACKEND: str = "embedded",
     TOKEN_SWAP_JS: str = (
         "(function(a){try{var s=window.localStorage,p=s.getItem('jac_backend');"
         + "if(p===a)return;var t=s.getItem('jac_token');"
         + "if(p){if(t)s.setItem('jac_token@'+p,t);else s.removeItem('jac_token@'+p);}"
         + "var n=s.getItem('jac_token@'+a);"
         + "if(n)s.setItem('jac_token',n);else s.removeItem('jac_token');"
         + "s.setItem('jac_backend',a);}catch(e){}})"
     );


obj BackendChoice {
    has backends: dict[str, str],
        active: str = "",
        default_name: str = ASK,
        path: str = "",
        relaunch: bool = False,
        _lock: threading.Lock = threading.Lock();

    static def load(
        backends: dict[str, str], default_name: str, path: str
    ) -> BackendChoice;

    def backend -> str;
    def api_base -> str;
    def describe -> dict[str, any];
    def script -> str;
    def choose(name: str) -> bool;
}

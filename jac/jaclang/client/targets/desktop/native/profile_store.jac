import sys;
import importlib;
import json;
import os;
import secrets;
import threading;
import time;

glob PROFILE_SESSION_JS: str = (
         "(function(){try{var s=window.localStorage,x=new XMLHttpRequest();"
         + "x.open('POST','/__jac/profiles/session',false);x.send();"
         + "var t=x.status===200?JSON.parse(x.responseText).token:'';"
         + "if(t)s.setItem('jac_token',t);else s.removeItem('jac_token');}catch(e){}})();"
     ),
     MAX_PROFILE_NAME: int = 64;


obj LocalProfile {
    has id: str,
        name: str,
        user_id: str,
        created: float = 0.0;

    def public -> dict[str, any];
}


obj ProfileStore {
    has path: str,
        active: str = "",
        profiles: list[LocalProfile] = [],
        _lock: threading.Lock = threading.Lock();

    static def load(path: str) -> ProfileStore;
    def save;
    def _lock_file -> any;
    def _unlock_file(handle: any);
    def _reload;
    def find(profile_id: str) -> (LocalProfile | None);
    def describe -> dict[str, any];
    def add(name: str, user_id: str, profile_id: str) -> LocalProfile;
    def select(profile_id: str);
    def script -> str;
}

def new_profile_id -> str;

def clean_profile_name(name: str) -> str;

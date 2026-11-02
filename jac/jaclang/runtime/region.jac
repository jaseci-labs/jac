import threading;
import weakref;

glob _region_tls: any = threading.local();

def _stack -> list[JacRegion];

obj JacRegion {
    has _drops: list[any] = [],
        _parent: any = None;

    def partition(n: int = 0) -> any;
    def _jac_open;
    def _jac_close;
    def _jac_register(item: any);
    def _jac_drop;
    def __del__;
}

def escape_regions -> list[JacRegion];

def restore_regions(saved: list[JacRegion]);

def open_region(r: any);

def close_region(r: any);

def register_drop(item: any);

def region_of(item: any) -> any;

def instrument_drops(cls: any);

def is_drop_hook(member: any) -> bool;

def run_drop(item: any);

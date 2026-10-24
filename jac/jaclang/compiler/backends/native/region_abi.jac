import os;

glob REGION_KERNEL_ABI: dict[str, tuple[bool, int]] = {
         "__jac_region_new": (True, 0),
         "__jac_region_alloc": (True, 2),
         "__jac_region_log_dtor": (False, 3),
         "__jac_region_drop": (False, 1),
         "__jac_region_partition": (True, 1),
         "__jac_region_enter": (False, 1),
         "__jac_region_leave": (False, 0),
         "__jac_region_unwind": (False, 1),
         "__jac_region_current": (True, 0),
         "__jac_region_depth": (True, 0),
         "__jac_region_escape": (True, 0),
         "__jac_region_restore": (False, 1),
         "__jac_region_of": (True, 1),
         "__jac_region_owns": (True, 1)
     };

def _region_layout_facts -> dict[str, int];

def _declared_int(source: str, name: str) -> (str | None);

def verify_region_layout(source: str);

def verify_region_unit(path: str);

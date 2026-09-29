"""Imports a module with a private `double` and another exporting `double`."""
import from priv_shadow_lib { quadruple }
import from priv_shadow_other { double }

def via_private_helper -> int {
    return quadruple(3);
}

def via_public_import -> int {
    return double(3);
}

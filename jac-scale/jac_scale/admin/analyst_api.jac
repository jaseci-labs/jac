"""A-07 Performance Analyst - admin endpoint mixin declaration.

Kept separate from the `analyst` contracts module on purpose: this mixin's
impl pulls in the collect/assemble chain (analyst_assemble -> analyst_collect
-> analyst), so housing it in `analyst.jac` itself would make the contracts
module import its own dependents (circular import). Contracts stay dependency-
free in `analyst.jac`; the endpoints live here.

Composed into JacAPIServer (monolith) and MicroserviceGateway. Impl (the
/admin/analyst/* handlers) in impl/analyst_api.impl.jac.
"""


"""Admin mixin providing the in-admin Performance Analyst endpoints (A-07)."""
obj JacAPIServerAnalyst {
    def register_analyst_endpoints -> None;
}

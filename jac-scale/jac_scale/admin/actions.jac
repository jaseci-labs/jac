"""Controlled mutations for the Ops Console (V-10, Tier 2).

A small set of POST endpoints with real blast radius, so every one is
admin-gated, audit-logged (actor + action + target), and needs the
mutation RBAC the microservice target only grants when
`[plugins.scale.kubernetes].ops_console_mutations` is set (without it the
K8s API returns 403 and the action reports it):

  POST /admin/ops/actions/rollout-restart  {deployment}
  POST /admin/ops/actions/scale            {deployment, replicas}
  POST /admin/ops/actions/delete-pod       {pod}
  POST /admin/ops/actions/unstick-pvc      {pvc}

Redeploy and ingress-backend flips are intentionally NOT here: redeploy
goes through the normal build/apply pipeline (the Role has no create
verbs), and a safe ingress rule-targeting UX is a follow-up. The UI
requires a typed confirmation before calling any of these.
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin controlled-mutation endpoints (V-10)."""
obj JacAPIServerActions {
    def register_actions_endpoints -> None;
}

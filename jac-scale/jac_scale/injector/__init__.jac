"""Code-injection port for jac-scale k8s deploys.

An Injector decides how a service's source reaches its pod. The default
`PvcInjector` packs the project, places it on a shared ReadWriteMany PVC, and has
an init container unpack it before the app starts. This needs no Docker daemon, no
external registry, and no object-store server, and is not bounded by the 1 MiB
etcd ConfigMap limit. An `ImageInjector` (built in a later, deferred PR) slots in
behind the same port for image-based deploys.
"""

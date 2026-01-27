# Jac-Cloud Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Cloud**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-cloud 0.2.11 (Unreleased)

## jac-cloud 0.2.10 (Latest Release)

- **Jac Serve Faux Mode**: Added `--faux` flag to `jac serve` command that prints documentation for API endpoints instead of starting the server, useful for quickly inspecting available endpoints and their specifications.

## jac-cloud 0.2.8

- **Consistent Jac Code Execution**: Fixed an issue allowing Jac code to be executed both as a standalone program and as an application. Running `jac run` now executes the `main()` function, while `jac serve` launches the application without invoking `main()`.

## jac-cloud 0.2.5

- **Jac Cloud Hot Reload**: Introduced the ability to enable development mode like uvicorn by adding `--reload` in `jac serve`. This supports targetting specific directories by using `--dev path/to/dir1,path/to/dir2` (comma separated).
- **Dynamic Runtime Walker Endpoint**: Fixes auto-generated endpoints for walkers created at runtime.
- **Jac Clouds Traverse API**: Introduced the ability to traverse graph. This API support control of the following:
  - source - Starting node/edge. Defaults to root
  - detailed - If response includes archetype context. Defaults to False
  - depth - how deep the traversal from source. Count includes edges. Defaults to 1
  - node_types - Node filter by name. Defaults to no filter
  - edge_types - Edge filter by name. Defaults to no filter
- **Dedicated Memory commit interface.**: Introduced the interface to commit memory to db at runtime. Previously, we only have it on jac-cloud but we generalized it and support it for both jac and jac-cloud.

## jac-cloud 0.2.4

- **Support Spawning a Walker with List of Nodes and Edges**: Introduced the ability to spawn a walker on a list of nodes and edges. This feature enables initiating traversal across multiple graph elements simultaneously, providing greater flexibility and efficiency in handling complex graph structures.
- **save(...) should not override root in runtime**: The previous version bypassed access validation because the target archetype root was overridden by the current root, simulating ownership of the archetype.
- **Support Custom Access Validation**: Introduced the ability to override access validation. `Node`/`Edge` can override `__jac_access__` reserved function (`builtin`) to have a different way of validating access. Either you cross-check it by current attribute, check from db or global vars or by just returning specific access level. [PR#1524](https://github.com/jaseci-labs/jaseci/pull/1524)
- **Get all Root Builtin Method**: Introduced `allroots` builtin method to get all the roots available in the memory. Developers can get all the roots in the memory/ database by calling `allroots()` method.
- **Permission Update Builtin Methods**: Introduced `grant`, `revoke` builtin methods, `NoPerm`, `ReadPerm`, `ConnectPerm`, `WritePerm` builtin enums, to give the permission to a node or revoke the permission. Developers can use them by calling `grant(node_1, ConnectPerm)` or `revoke(node_1)` method.
- **`jac create_system_admin` cli now support local db**: `DATABASE_HOST` are now not required when creating system admin.

## jac-cloud 0.2.3

- **Async Walker Support**: Introduced comprehensive async walker functionality that brings Python's async/await paradigm to object-spatial programming. Async walkers enable non-blocking spawns during graph traversal, allowing for concurrent execution of multiple walkers and efficient handling of I/O-bound operations.

## Version 0.8.0

- **Permission API Renaming**: The `Jac.restrict` and `Jac.unrestrict` interfaces have been renamed to `Jac.perm_revoke` and `Jac.perm_grant` respectively, for better clarity on their actions.
- **Permission API Renaming**: The `Jac.restrict` and `Jac.unrestrict` interfaces have been renamed to `Jac.perm_revoke` and `Jac.perm_grant` respectively, for better clarity on their actions.

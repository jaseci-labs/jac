"""Jac Cloud Utils APIs."""

from collections.abc import Generator
from dataclasses import is_dataclass
from typing import Annotated, Any

from bson import ObjectId

from fastapi import APIRouter, Depends, Query
from fastapi.responses import ORJSONResponse, StreamingResponse

from jac_cloud.core.archetype import BaseAnchor, EdgeAnchor, NodeAnchor

from orjson import dumps

from ..security import BEARER, User, authenticate

router = APIRouter(prefix="/util", tags=["Utility APIs"])


@router.get("/traverse", dependencies=BEARER)
def traverse(
    user_root: Annotated[tuple[User, NodeAnchor], Depends(authenticate)],  # type: ignore
    source: str | None = None,
    detailed: bool = False,
    depth: int = 1,
    node_types: Annotated[set[str] | None, Query()] = None,
    edge_types: Annotated[set[str] | None, Query()] = None,
) -> ORJSONResponse:
    """Healthz API."""
    nodes: list[dict] = []
    edges: list[dict] = []
    node_ids = set[ObjectId]()
    edge_ids = set[ObjectId]()
    entries: list[ObjectId] = []

    if source:
        anchor = BaseAnchor.ref(source)
        if not (entry := anchor.Collection.find_by_id(anchor.id)):  # type: ignore[attr-defined]
            raise ValueError("Invalid source!")
    else:
        entry = user_root[1]

    if isinstance(entry, NodeAnchor):
        nodes.append(
            build_data(
                {
                    "id": entry.ref_id,
                    "edges": [
                        append_entry(edge_types, edge_ids, entries, ed)
                        for ed in entry.edges
                    ],
                },
                entry,
                detailed,
            )
        )
        node_ids.add(entry.id)
        get_edges = True
    elif isinstance(entry, EdgeAnchor):
        edges.append(
            build_data(
                {
                    "id": entry.ref_id,
                    "source": append_entry(node_types, node_ids, entries, entry.source),
                    "target": append_entry(node_types, node_ids, entries, entry.target),
                },
                entry,
                detailed,
            )
        )
        edge_ids.add(entry.id)
        get_edges = False
    else:
        raise ValueError("Invalid source!")

    while entries and (depth > 0 or depth < 0):
        if get_edges:
            get_edges = False
            _entries: list[ObjectId] = []
            edges.extend(
                build_data(
                    {
                        "id": edge.ref_id,
                        "source": append_entry(
                            node_types, node_ids, _entries, edge.source
                        ),
                        "target": append_entry(
                            node_types, node_ids, _entries, edge.target
                        ),
                    },
                    edge,
                    detailed,
                )
                for edge in EdgeAnchor.Collection.find({"_id": {"$in": entries}})
            )
        else:
            get_edges = True
            _entries = []
            nodes.extend(
                build_data(
                    {
                        "id": node.ref_id,
                        "edges": [
                            append_entry(edge_types, edge_ids, _entries, ed)
                            for ed in node.edges
                        ],
                    },
                    node,
                    detailed,
                )
                for node in NodeAnchor.Collection.find({"_id": {"$in": entries}})
            )
        entries = _entries
        depth -= 1

    return ORJSONResponse({"edges": edges, "nodes": nodes})


@router.get("/traverse-stream", dependencies=BEARER)
def traverse_stream(
    user_root: Annotated[tuple[User, NodeAnchor], Depends(authenticate)],  # type: ignore
    source: str | None = None,
    detailed: bool = False,
    depth: int = 1,
    node_types: Annotated[set[str] | None, Query()] = None,
    edge_types: Annotated[set[str] | None, Query()] = None,
) -> StreamingResponse:
    """Traverse Graph stream."""
    return StreamingResponse(
        traverse_process(user_root[1], source, detailed, depth, node_types, edge_types),
        media_type="application/json",
    )


def append_entry(
    filter: set[str] | None,
    cache: set[ObjectId],
    entries: list[ObjectId],
    anchor: BaseAnchor,
) -> str:
    """Append entry."""
    if (not filter or anchor.name in filter) and anchor.id not in cache:
        cache.add(anchor.id)
        entries.append(anchor.id)
    return anchor.ref_id


def build_data(
    data: dict[str, Any], anchor: BaseAnchor, detailed: bool
) -> dict[str, Any]:
    """Build data."""
    if detailed:
        data["archetype"] = (
            anchor.archetype.__serialize__()  # type: ignore[assignment]
            if is_dataclass(anchor.archetype) and not isinstance(anchor.archetype, type)
            else {}
        )
    return data


def traverse_process(
    root: NodeAnchor,
    source: str | None = None,
    detailed: bool = False,
    depth: int = 1,
    node_types: Annotated[set[str] | None, Query()] = None,
    edge_types: Annotated[set[str] | None, Query()] = None,
) -> Generator[bytes, None, None]:
    """Healthz API."""
    node_ids = set[ObjectId]()
    edge_ids = set[ObjectId]()
    entries: list[ObjectId] = []

    if source:
        anchor = BaseAnchor.ref(source)
        if not (entry := anchor.Collection.find_by_id(anchor.id)):  # type: ignore[attr-defined]
            raise ValueError("Invalid source!")
    else:
        entry = root

    if isinstance(entry, NodeAnchor):
        node_ids.add(entry.id)
        get_edges = True
        yield dumps(
            {
                "nodes": [
                    build_data(
                        {
                            "id": entry.ref_id,
                            "edges": [
                                append_entry(edge_types, edge_ids, entries, ed)
                                for ed in entry.edges
                            ],
                        },
                        entry,
                        detailed,
                    )
                ]
            }
        ) + b"\n"
    elif isinstance(entry, EdgeAnchor):
        edge_ids.add(entry.id)
        get_edges = False
        yield dumps(
            {
                "edges": [
                    build_data(
                        {
                            "id": entry.ref_id,
                            "source": append_entry(
                                node_types, node_ids, entries, entry.source
                            ),
                            "target": append_entry(
                                node_types, node_ids, entries, entry.target
                            ),
                        },
                        entry,
                        detailed,
                    )
                ]
            }
        ) + b"\n"
    else:
        raise ValueError("Invalid source!")

    while entries and (depth > 0 or depth < 0):
        from time import sleep

        sleep(2)
        if get_edges:
            get_edges = False
            _entries: list[ObjectId] = []
            yield dumps(
                {
                    "edges": [
                        build_data(
                            {
                                "id": edge.ref_id,
                                "source": append_entry(
                                    node_types, node_ids, _entries, edge.source
                                ),
                                "target": append_entry(
                                    node_types, node_ids, _entries, edge.target
                                ),
                            },
                            edge,
                            detailed,
                        )
                        for edge in EdgeAnchor.Collection.find(
                            {"_id": {"$in": entries}}
                        )
                    ]
                }
            ) + b"\n"
        else:
            get_edges = True
            _entries = []
            yield dumps(
                {
                    "nodes": [
                        build_data(
                            {
                                "id": node.ref_id,
                                "edges": [
                                    append_entry(edge_types, edge_ids, _entries, ed)
                                    for ed in node.edges
                                ],
                            },
                            node,
                            detailed,
                        )
                        for node in NodeAnchor.Collection.find(
                            {"_id": {"$in": entries}}
                        )
                    ]
                }
            ) + b"\n"
        entries = _entries
        depth -= 1

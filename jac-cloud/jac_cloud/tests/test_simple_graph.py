"""JacLang Jaseci Unit Test."""

from concurrent.futures import ThreadPoolExecutor
from os import getenv
from pathlib import Path
from time import sleep
from typing import cast

from bson import ObjectId

from httpx import get, post, stream

from pymongo.collection import Collection as PCollection
from pymongo.mongo_client import MongoClient

from yaml import safe_load

from .test_utils import JacCloudTest
from ..jaseci.datasources import Collection


class SimpleGraphTest(JacCloudTest):
    """JacLang Jaseci Feature Tests."""

    directory: Path
    client: MongoClient
    q_node: PCollection
    q_edge: PCollection
    q_walker: PCollection

    @classmethod
    def setUpClass(cls) -> None:
        """Set up once before all tests."""
        cls.directory = Path(__file__).parent
        cls.run_server(f"{cls.directory}/simple_graph.jac")

        Collection.__client__ = None
        Collection.__database__ = None
        cls.client = Collection.get_client()
        cls.q_node = Collection.get_collection("node")
        cls.q_edge = Collection.get_collection("edge")
        cls.q_walker = Collection.get_collection("walker")

    @classmethod
    def tearDownClass(cls) -> None:
        """Tear down after the last test."""
        cls.client.drop_database(cls.database)
        cls.stop_server()

    def trigger_openapi_specs_test(self) -> None:
        """Test OpenAPI Specs."""
        res = get(f"{self.host}/openapi.yaml", timeout=1)
        res.raise_for_status()

        with open(f"{self.directory}/openapi_specs.yaml") as file:
            self.assertEqual(safe_load(file), safe_load(res.text))

    def trigger_create_user_test(self, suffix: str = "") -> None:
        """Test User Creation."""
        email = f"user{suffix}@example.com"

        res = post(
            f"{self.host}/user/register",
            json={
                "password": "string",
                "email": email,
                "name": "string",
            },
        )
        res.raise_for_status()
        self.assertEqual({"message": "Successfully Registered!"}, res.json())

        res = post(
            f"{self.host}/user/login",
            json={"email": email, "password": "string"},
        )
        res.raise_for_status()
        body: dict = res.json()

        token = body.get("token")
        self.assertIsNotNone(token)

        user: dict = body.get("user", {})
        self.assertEqual(email, user["email"])
        self.assertEqual("string", user["name"])

        self.users.append(
            {"user": user, "headers": {"Authorization": f"Bearer {token}"}}
        )

    def trigger_create_graph_test(self, user: int = 0) -> None:
        """Test Graph Creation."""
        res = self.post_api("create_graph", user=user)

        self.assertEqual(200, res["status"])

        root_node = res["reports"].pop(0)
        self.assertTrue(root_node["id"].startswith("n::"))
        self.assertEqual({}, root_node["context"])

        for idx, report in enumerate(res["reports"]):
            self.assertEqual({"val": idx}, report["context"])

    def trigger_traverse_graph_test(self) -> None:
        """Test Graph Traversion."""
        res = self.post_api("traverse_graph")

        self.assertEqual(200, res["status"])

        root_node = res["reports"].pop(0)
        self.assertTrue(root_node["id"].startswith("n::"))
        self.assertEqual({}, root_node["context"])

        for idx, report in enumerate(res["reports"]):
            self.assertEqual({"val": idx}, report["context"])

            res = self.post_api(f"traverse_graph/{report["id"]}")
            self.assertEqual(200, res["status"])
            for _idx, report in enumerate(res["reports"]):
                self.assertEqual({"val": idx + _idx}, report["context"])

    def trigger_detach_node_test(self) -> None:
        """Test detach node."""
        res = self.post_api("detach_node")

        self.assertEqual(200, res["status"])
        self.assertEqual([True], res["reports"])

        res = self.post_api("traverse_graph")
        self.assertEqual(200, res["status"])

        root_node = res["reports"].pop(0)
        self.assertTrue(root_node["id"].startswith("n::"))
        self.assertEqual({}, root_node["context"])

        for idx, report in enumerate(res["reports"]):
            self.assertEqual({"val": idx}, report["context"])

            res = self.post_api(f"traverse_graph/{report["id"]}")
            self.assertEqual(200, res["status"])
            for _idx, report in enumerate(res["reports"]):
                self.assertEqual({"val": idx + _idx}, report["context"])

    def trigger_update_graph_test(self) -> None:
        """Test update graph."""
        res = self.post_api("update_graph")

        self.assertEqual(200, res["status"])

        root_node = res["reports"].pop(0)
        self.assertTrue(root_node["id"].startswith("n::"))
        self.assertEqual({}, root_node["context"])

        for idx, report in enumerate(res["reports"]):
            self.assertEqual({"val": idx + 1}, report["context"])

        res = self.post_api("traverse_graph")

        self.assertEqual(200, res["status"])

        root_node = res["reports"].pop(0)
        self.assertTrue(root_node["id"].startswith("n::"))
        self.assertEqual({}, root_node["context"])

        for idx, report in enumerate(res["reports"]):
            self.assertEqual({"val": idx + 1}, report["context"])

            res = self.post_api(f"traverse_graph/{report["id"]}")
            self.assertEqual(200, res["status"])
            for _idx, report in enumerate(res["reports"]):
                self.assertEqual({"val": idx + _idx + 1}, report["context"])

    def trigger_create_nested_node_test(self, manual: bool = False) -> None:
        """Test create nested node."""
        res = self.post_api(f"{'manual_' if manual else ""}create_nested_node", user=1)

        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": None,
            },
            res["reports"][0]["context"],
        )

    def trigger_update_nested_node_test(
        self, manual: bool = False, user: int = 1
    ) -> None:
        """Test update nested node."""
        for walker in [
            f"{'manual_' if manual else ""}update_nested_node",
            "visit_nested_node",
        ]:
            res = self.post_api(walker, user=user)
            self.assertEqual(200, res["status"])
            self.assertEqual(
                {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "parent": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "child": {
                            "val": 3,
                            "arr": [1, 2, 3],
                            "data": {"a": 1, "b": 2, "c": 3},
                            "enum_field": "A",
                        },
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                    "access": None,
                },
                res["reports"][0]["context"],
            )

    def trigger_detach_nested_node_test(self, manual: bool = False) -> None:
        """Test detach nested node."""
        res = self.post_api(f"{'manual_' if manual else ""}detach_nested_node", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([True], res["reports"])

        res = self.post_api("visit_nested_node", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([[]], res["reports"])

    def trigger_delete_nested_node_test(self, manual: bool = False) -> None:
        """Test create nested node."""
        res = self.post_api(f"{'manual_' if manual else ""}delete_nested_node", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([[]], res["reports"])

        res = self.post_api("visit_nested_node", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([[]], res["reports"])

    def trigger_delete_nested_edge_test(self, manual: bool = False) -> None:
        """Test create nested node."""
        res = self.post_api(f"{'manual_' if manual else ""}delete_nested_edge", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([[]], res["reports"])

        res = self.post_api("visit_nested_node", user=1)
        self.assertEqual(200, res["status"])
        self.assertEqual([[]], res["reports"])

    def trigger_access_validation_test(
        self, give_access_to_full_graph: bool, via_all: bool = False
    ) -> None:
        """Test giving access to node or full graph."""
        res = self.post_api("create_nested_node", user=1)

        nested_node = res["reports"][0]

        allow_walker_suffix = (
            "" if give_access_to_full_graph else f'/{nested_node["id"]}'
        )

        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": None,
            },
            nested_node["context"],
        )

        ###################################################
        #                    NO ACCESS                    #
        ###################################################

        self.assertEqual(
            403,
            self.post_api(f"visit_nested_node/{nested_node['id']}", expect_error=True),
        )

        ###################################################
        #          WITH ALLOWED ROOT READ ACCESS          #
        ###################################################

        res = self.post_api(
            f"allow_other_root_access{allow_walker_suffix}",
            json={
                "root_id": f'n::{self.users[0]["user"]["root_id"]}',
                "via_all": via_all,
            },
            user=1,
        )
        self.assertEqual(200, res["status"])

        res = self.post_api(f"update_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": None,
            },
            res["reports"][0]["context"],
        )

        res = self.post_api(f"update_nested_node_trigger_save/{nested_node['id']}")
        self.assertEqual(200, res["status"])

        # ----------- NO UPDATE SHOULD HAPPEN ----------- #

        res = self.post_api(f"visit_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": None,
            },
            res["reports"][0]["context"],
        )

        ###################################################
        #          WITH ALLOWED ROOT WRITE ACCESS         #
        ###################################################

        res = self.post_api(
            f"allow_other_root_access{allow_walker_suffix}",
            json={
                "root_id": f'n::{self.users[0]["user"]["root_id"]}',
                "level": "WRITE",
                "via_all": via_all,
            },
            user=1,
        )
        self.assertEqual(200, res["status"])

        res = self.post_api(f"update_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": None,
            },
            res["reports"][0]["context"],
        )

        # ------------ UPDATE SHOULD REFLECT ------------ #

        res = self.post_api(f"visit_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": None,
            },
            res["reports"][0]["context"],
        )

        ###################################################
        #                REMOVE ROOT ACCESS               #
        ###################################################

        res = self.post_api(
            f"disallow_other_root_access{allow_walker_suffix}",
            json={
                "root_id": f'n::{self.users[0]["user"]["root_id"]}',
                "via_all": via_all,
            },
            user=1,
        )
        self.assertEqual(200, res["status"])

        self.assertEqual(
            403,
            self.post_api(f"visit_nested_node/{nested_node['id']}", expect_error=True),
        )

    def nested_count_should_be(self, node: int, edge: int) -> None:
        """Test nested node count."""
        self.assertEqual(node, self.q_node.count_documents({"name": "Nested"}))
        self.assertEqual(
            edge,
            self.q_edge.count_documents(
                {
                    "$or": [
                        {"source": {"$regex": "^n:Nested:"}},
                        {"target": {"$regex": "^n:Nested:"}},
                    ]
                }
            ),
        )

    def trigger_custom_status_code(self) -> None:
        """Test custom status code."""
        for acceptable_code in [200, 201, 202, 203, 205, 206, 207, 208, 226]:
            res = self.post_api("custom_status_code", {"status": acceptable_code})
            self.assertEqual(acceptable_code, res["status"])

        for error_code in [
            400,
            401,
            402,
            403,
            404,
            405,
            406,
            407,
            408,
            409,
            410,
            411,
            412,
            413,
            414,
            415,
            416,
            417,
            418,
            421,
            422,
            423,
            424,
            425,
            426,
            428,
            429,
            431,
            451,
            500,
            501,
            502,
            503,
            504,
            505,
            506,
            507,
            508,
            510,
            511,
        ]:
            self.assertEqual(
                error_code,
                self.post_api(
                    "custom_status_code", {"status": error_code}, expect_error=True
                ),
            )

        for invalid_code in [
            100,
            101,
            102,
            103,
            204,
            300,
            301,
            302,
            303,
            304,
            305,
            306,
            307,
            308,
        ]:
            self.assertRaises(
                Exception, self.post_api, "custom_status_code", {"status": invalid_code}
            )

    def trigger_custom_report(self) -> None:
        """Test custom status code."""
        res = self.post_api("custom_report")
        self.assertEqual({"value": 1}, res)

    def trigger_upload_file(self) -> None:
        """Test upload file."""
        with open(f"{self.directory}/simple.json", mode="br") as s:
            files = [
                ("single", ("simple.json", s)),
                ("multiple", ("simple.json", s)),
                ("multiple", ("simple.json", s)),
            ]
            res = post(
                f"{self.host}/walker/post_with_file",
                files=files,
                headers=self.users[0]["headers"],
            )
            res.raise_for_status()
            data: dict = res.json()

            self.assertEqual(200, data["status"])
            self.assertEqual(
                [
                    {
                        "single": {
                            "single": {
                                "name": "simple.json",
                                "content_type": "application/json",
                                "size": 25,
                            }
                        },
                        "multiple": [
                            {
                                "name": "simple.json",
                                "content_type": "application/json",
                                "size": 25,
                            },
                            {
                                "name": "simple.json",
                                "content_type": "application/json",
                                "size": 25,
                            },
                        ],
                        "singleOptional": None,
                    }
                ],
                data["reports"],
            )

    def trigger_reset_graph(self) -> None:
        """Test custom status code."""
        res = self.post_api("populate_graph", user=2)
        self.assertEqual(200, res["status"])

        res = self.post_api("traverse_populated_graph", user=2)
        self.assertEqual(200, res["status"])
        reports = res["reports"]

        root = reports.pop(0)
        self.assertTrue(root["id"].startswith("n::"))
        self.assertEqual({}, root["context"])

        cur = 0
        max = 2
        for node in ["D", "E", "F", "G", "H"]:
            for idx in range(cur, cur + max):
                self.assertTrue(reports[idx]["id"].startswith(f"n:{node}:"))
                self.assertEqual({"id": idx % 2}, reports[idx]["context"])
                cur += 1
            max = max * 2

        res = self.post_api("check_populated_graph", user=2)
        self.assertEqual(200, res["status"])
        self.assertEqual([125], res["reports"])

        res = self.post_api("purge_populated_graph", user=2)
        self.assertEqual(200, res["status"])
        self.assertEqual([124], res["reports"])

        res = self.post_api("check_populated_graph", user=2)
        self.assertEqual(200, res["status"])
        self.assertEqual([1], res["reports"])

    def trigger_memory_sync(self) -> None:
        """Test memory sync."""
        res = self.post_api("traverse_graph")

        self.assertEqual(200, res["status"])

        a_node = res["reports"].pop(1)
        self.assertTrue(a_node["id"].startswith("n:A:"))
        self.assertEqual({"val": 1}, a_node["context"])

        res = self.post_api(
            "check_memory_sync", json={"other_node_id": a_node["id"]}, user=1
        )
        self.assertEqual(200, res["status"])

    def trigger_create_custom_object_test(self) -> str:
        """Test create custom object."""
        res = self.post_api("create_custom_object", user=1)
        obj = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertTrue(obj["id"].startswith("o:SavableObject:"))
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
            },
            obj["context"],
        )

        res = self.post_api("get_custom_object", json={"object_id": obj["id"]}, user=1)
        obj = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertTrue(obj["id"].startswith("o:SavableObject:"))
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
            },
            obj["context"],
        )

        return obj["id"]

    def trigger_update_custom_object_test(self, obj_id: str) -> None:
        """Test update custom object."""
        res = self.post_api("update_custom_object", json={"object_id": obj_id}, user=1)
        obj = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertTrue(obj["id"].startswith("o:SavableObject:"))
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
            },
            obj["context"],
        )

        res = self.post_api("get_custom_object", json={"object_id": obj_id}, user=1)
        obj = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertTrue(obj["id"].startswith("o:SavableObject:"))
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
            },
            obj["context"],
        )

    def trigger_delete_custom_object_test(self, obj_id: str) -> None:
        """Test delete custom object."""
        res = self.post_api("delete_custom_object", json={"object_id": obj_id}, user=1)
        self.assertEqual(200, res["status"])

        res = self.post_api("get_custom_object", json={"object_id": obj_id}, user=1)
        obj = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertIsNone(obj)

    def trigger_visit_sequence(self) -> None:
        """Test visit sequence."""
        res = self.post_api("visit_sequence")

        self.assertEqual(200, res["status"])
        self.assertEqual(
            [
                "walker entry",
                "walker enter to root",
                "a-1",
                "a-2",
                "a-3",
                "a-4",
                "a-5",
                "a-6",
                "b-1",
                "b-2",
                "b-3",
                "b-4",
                "b-5",
                "b-6",
                "c-1",
                "c-2",
                "c-3",
                "c-4",
                "c-5",
                "c-6",
                "walker exit",
            ],
            res["reports"],
        )

    def trigger_webhook_test(self) -> None:
        """Test webhook."""
        res = post(
            f"{self.host}/webhook/generate-key",
            json={
                "name": "test",
                "walkers": [],
                "nodes": [],
                "expiration": {"count": 60, "interval": "days"},
            },
            headers=self.users[0]["headers"],
        )

        res.raise_for_status()
        key = res.json()["key"]

        self.assertEqual(
            {"status": 200, "reports": [True]},
            self.post_webhook("webhook_by_header", headers={"test_key": key}),
        )

        self.assertEqual(
            {"status": 200, "reports": [True]},
            self.post_webhook(f"webhook_by_query?test_key={key}"),
        )

        self.assertEqual(
            {"status": 200, "reports": [True]},
            self.post_webhook(f"webhook_by_path/{key}"),
        )

        self.assertEqual(
            {"status": 200, "reports": [True]},
            self.post_webhook("webhook_by_body", {"test_key": key}),
        )

    def trigger_nested_request_payload_test(self) -> None:
        """Test nested request payload."""
        res = self.post_api(
            "nested_request_payload",
            json={
                "adult": {
                    "enum_field": "a",
                    "kid": {"enum_field": "a"},
                    "arr": [{"enum_field": "a"}],
                    "data": {"kid1": {"enum_field": "a"}},
                },
                "arr": [
                    {
                        "enum_field": "a",
                        "kid": {"enum_field": "a"},
                        "arr": [{"enum_field": "a"}],
                        "data": {"kid1": {"enum_field": "a"}},
                    }
                ],
                "data": {
                    "kid1": {
                        "enum_field": "a",
                        "kid": {"enum_field": "a"},
                        "arr": [{"enum_field": "a"}],
                        "data": {"kid1": {"enum_field": "a"}},
                    }
                },
                "enum_field": "a",
            },
        )
        self.assertEqual(
            {
                "status": 200,
                "reports": [
                    "Adult",
                    "Kid",
                    "Kid",
                    "Kid",
                    "Enum",
                    "Adult",
                    "Kid",
                    "Kid",
                    "Kid",
                    "Enum",
                    "Adult",
                    "Kid",
                    "Kid",
                    "Kid",
                    "Enum",
                    "Enum",
                ],
            },
            res,
        )

    def trigger_task_creation_and_scheduled_walker(self) -> None:
        """Test task creation."""
        res = self.post_api("get_or_create_counter")

        self.assertEqual(200, res["status"])
        self.assertEqual(1, len(res["reports"]))

        report = res["reports"][0]

        self.assertEqual({"val": 0}, report["context"])

        task_counter = report["id"]

        if getenv("TASK_CONSUMER_CRON_SECOND"):
            for i in range(1, 4):
                res = self.post_api("trigger_counter_task", json={"id": i})

                wlk = self.q_walker.find_one(
                    {"name": "trigger_counter_task", "archetype.id": i}
                )

                assert wlk is not None
                self.assertEqual(i, wlk["archetype"]["id"])

                self.assertEqual(200, res["status"])
                self.assertEqual(1, len(res["reports"]))
                self.assertTrue(res["reports"][0].startswith("w:increment_counter:"))

                sleep(1)

                res = self.post_api(f"get_or_create_counter/{task_counter}")

                self.assertEqual(200, res["status"])
                self.assertEqual(1, len(res["reports"]))

                report = res["reports"][0]

                self.assertEqual({"val": i}, report["context"])

                sleep(1)

                walker = self.q_walker.find_one(
                    {"name": "walker_cron"}, sort=[("_id", -1)]
                )

                self.assertIsNotNone(walker)

                cast(dict, walker).pop("_id")

                self.assertEqual(
                    {
                        "name": "walker_cron",
                        "root": ObjectId("000000000000000000000000"),
                        "access": {"all": "NO_ACCESS", "roots": {"anchors": {}}},
                        "archetype": {
                            "arg1": 1,
                            "arg2": "2",
                            "kwarg1": 30,
                            "kwarg2": "40",
                        },
                        "schedule": {
                            "status": "COMPLETED",
                            "root_id": None,
                            "node_id": None,
                            "execute_date": None,
                            "executed_date": None,
                            "http_status": 200,
                            "reports": [i],
                            "custom": None,
                            "error": None,
                        },
                    },
                    walker,
                )

        else:
            walker = self.q_walker.find_one({"name": "walker_cron"}, sort=[("_id", -1)])

            self.assertIsNotNone(walker)

            cast(dict, walker).pop("_id")

            self.assertEqual(
                {
                    "name": "walker_cron",
                    "root": ObjectId("000000000000000000000000"),
                    "access": {"all": "NO_ACCESS", "roots": {"anchors": {}}},
                    "archetype": {"arg1": 1, "arg2": "2", "kwarg1": 30, "kwarg2": "40"},
                    "schedule": {
                        "status": "COMPLETED",
                        "root_id": None,
                        "node_id": None,
                        "execute_date": None,
                        "executed_date": None,
                        "http_status": 200,
                        "reports": [None],
                        "custom": None,
                        "error": None,
                    },
                },
                walker,
            )

    def trigger_async_walker_test(self) -> None:
        """Test async walker api call."""
        res = self.post_api(
            "async_walker",
            json={
                "arg1": 0,
                "arg2": "string",
                "kwarg1": 3,
                "kwarg2": "4",
                "done": False,
            },
        )

        self.assertTrue(res["walker_id"].startswith("w:async_walker:"))
        walker_id = res["walker_id"].removeprefix("w:async_walker:")

        for _i in range(3):
            sleep(0.5)
            walker = self.q_walker.find_one(
                {"name": "async_walker"}, sort=[("_id", -1)]
            )
            if walker:
                break
        self.assertIsNotNone(walker)
        self.assertEqual(
            walker,
            {
                "_id": ObjectId(walker_id),
                "name": "async_walker",
                "root": ObjectId(self.users[0]["user"]["root_id"]),
                "access": {"all": "NO_ACCESS", "roots": {"anchors": {}}},
                "archetype": {
                    "arg1": 0,
                    "arg2": "string",
                    "kwarg1": 3,
                    "kwarg2": "4",
                    "done": True,
                },
                "schedule": {
                    "status": "COMPLETED",
                    "node_id": None,
                    "root_id": None,
                    "execute_date": None,
                    "executed_date": None,
                    "http_status": 200,
                    "reports": [],
                    "custom": None,
                    "error": None,
                },
            },
        )

    def trigger_custom_access_validation_test(self) -> None:
        """Test custom access validation."""
        res = self.post_api("create_nested_node", user=1)

        nested_node = res["reports"][0]

        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": None,
            },
            nested_node["context"],
        )

        ##########################################################
        #                        NO ACCESS                       #
        ##########################################################

        self.assertEqual(
            403,
            self.post_api(f"visit_nested_node/{nested_node['id']}", expect_error=True),
        )

        ##########################################################
        #           UPDATE NODE (WILL ALLOW READ ACESS)          #
        ##########################################################

        # BY OWNER
        res = self.post_api(
            f"update_nested_node_access/{nested_node['id']}",
            json={"access": "READ"},
            user=1,
        )
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": "READ",
            },
            res["reports"][0]["context"],
        )

        # BY OTHER
        res = self.post_api(f"update_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": "READ",
            },
            res["reports"][0]["context"],
        )

        # ---- NO UPDATE SHOULD HAPPEN BUT STILL ACCESSIBLE ---- #

        res = self.post_api(f"visit_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": "READ",
            },
            res["reports"][0]["context"],
        )

        ##########################################################
        #          UPDATE NODE (WILL ALLOW WRITE ACESS)          #
        ##########################################################

        # BY OWNER
        res = self.post_api(
            f"update_nested_node_access/{nested_node['id']}",
            json={"access": "WRITE"},
            user=1,
        )
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 0,
                "arr": [],
                "data": {},
                "parent": {
                    "val": 1,
                    "arr": [1],
                    "data": {"a": 1},
                    "child": {
                        "val": 2,
                        "arr": [1, 2],
                        "data": {"a": 1, "b": 2},
                        "enum_field": "C",
                    },
                    "enum_field": "B",
                },
                "enum_field": "A",
                "access": "WRITE",
            },
            res["reports"][0]["context"],
        )

        # BY OTHER
        res = self.post_api(f"update_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": "WRITE",
            },
            res["reports"][0]["context"],
        )

        # ---------------- UPDATE SHOULD HAPPEN ---------------- #

        res = self.post_api(f"visit_nested_node/{nested_node['id']}")
        self.assertEqual(200, res["status"])
        self.assertEqual(
            {
                "val": 1,
                "arr": [1],
                "data": {"a": 1},
                "parent": {
                    "val": 2,
                    "arr": [1, 2],
                    "data": {"a": 1, "b": 2},
                    "child": {
                        "val": 3,
                        "arr": [1, 2, 3],
                        "data": {"a": 1, "b": 2, "c": 3},
                        "enum_field": "A",
                    },
                    "enum_field": "C",
                },
                "enum_field": "B",
                "access": "WRITE",
            },
            res["reports"][0]["context"],
        )

        ###################################################
        #                REMOVE ROOT ACCESS               #
        ###################################################

        # UPDATE BY OWNER
        res = self.post_api(
            f"update_nested_node_access/{nested_node['id']}",
            json={"access": None},
            user=1,
        )
        self.assertEqual(200, res["status"])

        # VISIT BY OTHER
        self.assertEqual(
            403,
            self.post_api(f"visit_nested_node/{nested_node['id']}", expect_error=True),
        )

    def trigger_flood_request(self) -> None:
        """Test multiple simultaneous request."""
        with ThreadPoolExecutor(max_workers=20) as exc:
            futures = [exc.submit(self.post_api, "traverse_graph") for i in range(20)]

        for future in futures:
            res = future.result()

            self.assertEqual(200, res["status"])

            root_node = res["reports"].pop(0)
            self.assertTrue(root_node["id"].startswith("n::"))
            self.assertEqual({}, root_node["context"])

            for idx, report in enumerate(res["reports"]):
                self.assertEqual({"val": idx + 1}, report["context"])

                res = self.post_api(f"traverse_graph/{report["id"]}")
                self.assertEqual(200, res["status"])
                for _idx, report in enumerate(res["reports"]):
                    self.assertEqual({"val": idx + _idx + 1}, report["context"])

    def trigger_traverse_graph_util(self) -> None:
        """Test traverse graph util."""
        names = ["", "A", "B", "C"]

        # full graph

        res = get(
            f"{self.host}/util/traverse?depth=-1",
            headers=self.users[3]["headers"],
        )
        res.raise_for_status()

        data = res.json()
        edges = data["edges"]
        nodes = data["nodes"]

        self.assertEqual(3, len(edges))
        self.assertEqual(4, len(nodes))

        for i, edge in enumerate(edges):
            self.assertTrue(edge["id"].startswith("e::"))
            self.assertTrue(edge["source"].startswith(f"n:{names[i]}:"))
            self.assertTrue(edge["target"].startswith(f"n:{names[i + 1]}:"))

        for i, node in enumerate(nodes):
            self.assertTrue(node["id"].startswith(f"n:{names[i]}:"))
            self.assertTrue(node["edges"])

        # controlled depth

        for i in range(0, 7):
            res = get(
                f"{self.host}/util/traverse?depth={i}",
                headers=self.users[3]["headers"],
            )
            res.raise_for_status()

            data = res.json()
            edges = data["edges"]
            nodes = data["nodes"]

            self.assertEqual(int((i + 1) / 2), len(edges))
            self.assertEqual(int(i / 2) + 1, len(nodes))

            for i, edge in enumerate(edges):
                self.assertTrue(edge["id"].startswith("e::"))
                self.assertTrue(edge["source"].startswith(f"n:{names[i]}:"))
                self.assertTrue(edge["target"].startswith(f"n:{names[i + 1]}:"))

            for i, node in enumerate(nodes):
                self.assertTrue(node["id"].startswith(f"n:{names[i]}:"))
                self.assertTrue(node["edges"])

        # detailed true

        res = get(
            f"{self.host}/util/traverse?depth=1&detailed=true",
            headers=self.users[3]["headers"],
        )
        res.raise_for_status()

        data = res.json()
        edges = data["edges"]
        nodes = data["nodes"]

        self.assertEqual(1, len(edges))
        self.assertEqual(1, len(nodes))
        self.assertTrue(edges[0]["id"].startswith("e::"))
        self.assertTrue(edges[0]["source"].startswith("n::"))
        self.assertTrue(edges[0]["target"].startswith("n:A:"))
        self.assertEqual({}, edges[0]["archetype"])
        self.assertTrue(nodes[0]["id"].startswith("n::"))
        self.assertTrue(nodes[0]["edges"])
        self.assertEqual({}, nodes[0]["archetype"])

        # filter by node types

        res = get(
            f"{self.host}/util/traverse?depth=-1&detailed=true&node_types=A&node_types=B",
            headers=self.users[3]["headers"],
        )
        res.raise_for_status()

        data = res.json()
        edges = data["edges"]
        nodes = data["nodes"]

        self.assertEqual(3, len(edges))
        self.assertEqual(3, len(nodes))

        for i, edge in enumerate(edges):
            self.assertTrue(edge["id"].startswith("e::"))
            self.assertTrue(edge["source"].startswith(f"n:{names[i]}:"))
            self.assertTrue(edge["target"].startswith(f"n:{names[i + 1]}:"))
            self.assertEqual({}, edge["archetype"])

        for i, node in enumerate(nodes):
            self.assertTrue(node["id"].startswith(f"n:{names[i]}:"))
            self.assertTrue(node["edges"])
            self.assertTrue("archetype" in node)

    def trigger_generate_walker(self) -> None:
        """Test dynamic generation of walker endpoint."""
        res = get(f"{self.host}/walker/generated_walker")
        self.assertEqual(404, res.status_code)

        res = get(f"{self.host}/walker/generate_walker")
        res.raise_for_status()
        self.assertEqual({"status": 200, "reports": ["generate_walker"]}, res.json())

        res = get(f"{self.host}/walker/generated_walker")
        res.raise_for_status()
        self.assertEqual({"status": 200, "reports": ["generated_walker"]}, res.json())

    def trigger_custom_walkers(self) -> None:
        """Test custom specification walkers."""
        resp = self.post_api("exclude_in_specs")
        self.assertEqual({"status": 200, "reports": []}, resp)

        res = get(f"{self.host}/walker/html_response")
        res.raise_for_status()
        self.assertEqual(
            '<!DOCTYPE html><html lang="en"><body>HELLO WORLD</body></html>', res.text
        )
        self.assertEqual("text/html; charset=utf-8", res.headers["content-type"])

        with stream("GET", f"{self.host}/walker/stream_response") as streamer:
            streamer.raise_for_status()
            self.assertEqual(
                "text/event-stream; charset=utf-8", streamer.headers["content-type"]
            )
            for i, chunk in enumerate(streamer.iter_text()):
                self.assertEqual(str(i), chunk)

    # Individual test methods for each feature

    def test_01_openapi_specs(self) -> None:
        """Test OpenAPI Specs."""
        self.trigger_openapi_specs_test()

    def test_02_create_users(self) -> None:
        """Test User Creation."""
        self.trigger_create_user_test()
        self.trigger_create_user_test(suffix="2")
        self.trigger_create_user_test(suffix="3")
        self.trigger_create_user_test(suffix="4")

    def test_03_basic_graph_operations(self) -> None:
        """Test basic graph operations."""
        self.trigger_create_graph_test()
        self.trigger_traverse_graph_test()
        self.trigger_detach_node_test()
        self.trigger_update_graph_test()

    def test_04_nested_node_via_detach(self) -> None:
        """Test nested node operations via detach."""
        # VIA DETACH
        self.nested_count_should_be(node=0, edge=0)

        self.trigger_create_nested_node_test()
        self.nested_count_should_be(node=1, edge=1)

        self.trigger_update_nested_node_test()
        self.trigger_detach_nested_node_test()
        self.nested_count_should_be(node=0, edge=0)

        self.trigger_create_nested_node_test(manual=True)
        self.nested_count_should_be(node=1, edge=1)

        self.trigger_update_nested_node_test(manual=True)
        self.trigger_detach_nested_node_test(manual=True)
        self.nested_count_should_be(node=0, edge=0)

    def test_05_nested_node_via_destroy(self) -> None:
        """Test nested node operations via destroy."""
        # VIA DESTROY
        self.trigger_create_nested_node_test()
        self.nested_count_should_be(node=1, edge=1)

        self.trigger_delete_nested_node_test()
        self.nested_count_should_be(node=0, edge=0)

        self.trigger_create_nested_node_test(manual=True)
        self.nested_count_should_be(node=1, edge=1)

        self.trigger_delete_nested_node_test(manual=True)
        self.nested_count_should_be(node=0, edge=0)

    def test_06_nested_edge_operations(self) -> None:
        """Test nested edge operations."""
        self.trigger_create_nested_node_test()
        self.nested_count_should_be(node=1, edge=1)

        self.trigger_delete_nested_edge_test()
        self.nested_count_should_be(node=0, edge=0)

        self.trigger_create_nested_node_test(manual=True)
        self.nested_count_should_be(node=1, edge=1)

        # only automatic cleanup remove nodes that doesn't have edges
        # manual save still needs to trigger the destroy for that node
        self.trigger_delete_nested_edge_test(manual=True)
        self.nested_count_should_be(node=1, edge=0)

    def test_07_access_validation(self) -> None:
        """Test access validation."""
        self.trigger_access_validation_test(give_access_to_full_graph=False)
        self.trigger_access_validation_test(give_access_to_full_graph=True)

        self.trigger_access_validation_test(
            give_access_to_full_graph=False, via_all=True
        )
        self.trigger_access_validation_test(
            give_access_to_full_graph=True, via_all=True
        )

    def test_08_custom_status_code(self) -> None:
        """Test custom status code."""
        self.trigger_custom_status_code()

    def test_09_custom_report(self) -> None:
        """Test custom report."""
        self.trigger_custom_report()

    def test_10_file_upload(self) -> None:
        """Test file upload."""
        self.trigger_upload_file()

    def test_11_reset_graph(self) -> None:
        """Test graph reset."""
        self.trigger_reset_graph()

    def test_12_memory_sync(self) -> None:
        """Test memory sync."""
        self.trigger_memory_sync()

    def test_13_savable_object(self) -> None:
        """Test savable object operations."""
        obj_id = self.trigger_create_custom_object_test()
        self.trigger_update_custom_object_test(obj_id)
        self.trigger_delete_custom_object_test(obj_id)

    def test_14_visit_sequence(self) -> None:
        """Test visit sequence."""
        self.trigger_visit_sequence()

    def test_15_webhook(self) -> None:
        """Test webhook."""
        self.trigger_webhook_test()

    def test_16_nested_request_payload(self) -> None:
        """Test nested request payload."""
        self.trigger_nested_request_payload_test()

    ##################################################
    #              TASK CREATION TESTS               #
    ##################################################

    def test_17_task_creation_and_scheduled_walker(self) -> None:
        """Test task creation and scheduled walker."""
        self.trigger_task_creation_and_scheduled_walker()

    def test_18_async_walker(self) -> None:
        """Test async walker api call."""
        self.trigger_async_walker_test()

    ###################################################
    #             CUSTOM ACCESS VALIDATION            #
    ###################################################

    def test_19_custom_access_validation(self) -> None:
        """Test custom access validation."""
        self.trigger_custom_access_validation_test()

    def test_20_flood_request(self) -> None:
        """Test multiple simultaneous request."""
        self.trigger_flood_request()

    def test_21_traverse_graph_util(self) -> None:
        """Test traverse graph util."""
        self.trigger_create_graph_test(3)
        self.trigger_traverse_graph_util()

    def test_22_generate_dynamic_walker(self) -> None:
        """Test multiple simultaneous request."""
        self.trigger_generate_walker()

    def test_23_trigger_custom_walkers(self) -> None:
        """Test custom specification walkers."""
        self.trigger_custom_walkers()

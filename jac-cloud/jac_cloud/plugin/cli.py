"""Module for registering CLI plugins for jaseci."""

from getpass import getpass
from os import environ
from os.path import split
from pickle import load
from typing import Any

from jaclang import JacMachine as Jac
from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

from pymongo.errors import ConnectionFailure, OperationFailure

from ..core.archetype import BulkWrite, NodeAnchor
from ..core.context import JaseciContext, PUBLIC_ROOT_ID, SUPER_ROOT_ID
from ..jaseci.datasources import Collection
from ..jaseci.main import FastAPI
from ..jaseci.models import User as BaseUser
from ..jaseci.utils import logger


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def serve(filename: str, host: str = "0.0.0.0", port: int = 8000) -> None:
            """Serve the jac application."""
            base, mod = split(filename)
            base = base if base else "./"
            mod = mod[:-4]

            FastAPI.enable()

            ctx = JaseciContext.create(None)

            if filename.endswith(".jac"):
                Jac.jac_import(target=mod, base_path=base, override_name="__main__")
            elif filename.endswith(".jir"):
                with open(filename, "rb") as f:
                    Jac.attach_program(load(f))
                    Jac.jac_import(target=mod, base_path=base, override_name="__main__")
            else:
                raise ValueError("Not a valid file!\nOnly supports `.jac` and `.jir`")
            ctx.close()
            FastAPI.start(host=host, port=port)

        @cmd_registry.register
        def create_system_admin(
            filename: str, email: str = "", password: str = ""
        ) -> str:
            base, mod = split(filename)
            base = base if base else "./"
            mod = mod[:-4]

            if filename.endswith(".jac"):
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    override_name="__main__",
                )
            elif filename.endswith(".jir"):
                with open(filename, "rb") as f:
                    Jac.attach_program(load(f))
                    Jac.jac_import(
                        target=mod,
                        base_path=base,
                        override_name="__main__",
                    )

            if not email:
                trial = 0
                while (email := input("Email: ")) != input("Confirm Email: "):
                    if trial > 2:
                        raise ValueError("Email don't match! Aborting...")
                    print("Email don't match! Please try again.")
                    trial += 1

            if not password:
                trial = 0
                while (password := getpass()) != getpass(prompt="Confirm Password: "):
                    if trial > 2:
                        raise ValueError("Password don't match! Aborting...")
                    print("Password don't match! Please try again.")
                    trial += 1

            user_model = BaseUser.model()
            user_request = user_model.register_type()(
                email=email,
                password=password,
                **user_model.system_admin_default(),
            )

            Collection.apply_indexes()
            with user_model.Collection.get_session() as session, session.start_transaction():
                req_obf: dict = user_request.obfuscate()
                req_obf.update(
                    {
                        "root_id": SUPER_ROOT_ID,
                        "is_activated": True,
                        "is_admin": True,
                    }
                )

                retry = 0
                while True:
                    try:
                        default_data: dict[str, Any] = {
                            "name": None,
                            "root": None,
                            "access": {
                                "all": "NO_ACCESS",
                                "roots": {"anchors": {}},
                            },
                            "archetype": {},
                            "edges": [],
                        }

                        if not NodeAnchor.Collection.find_by_id(
                            PUBLIC_ROOT_ID, session=session
                        ):
                            NodeAnchor.Collection.insert_one(
                                {"_id": PUBLIC_ROOT_ID, **default_data},
                                session=session,
                            )
                        if not NodeAnchor.Collection.find_by_id(
                            SUPER_ROOT_ID, session=session
                        ):
                            NodeAnchor.Collection.insert_one(
                                {"_id": SUPER_ROOT_ID, **default_data},
                                session=session,
                            )
                        if id := (
                            user_model.Collection.insert_one(req_obf, session=session)
                        ).inserted_id:
                            BulkWrite.commit(session)
                            return f"System Admin created with id: {id}"
                        raise SystemError("Can't create System Admin!")
                    except (ConnectionFailure, OperationFailure) as ex:
                        if (
                            ex.has_error_label("TransientTransactionError")
                            and retry <= BulkWrite.SESSION_MAX_TRANSACTION_RETRY
                        ):
                            retry += 1
                            logger.error(
                                "Error executing bulk write! "
                                f"Retrying [{retry}/{BulkWrite.SESSION_MAX_TRANSACTION_RETRY}] ..."
                            )
                            continue
                        logger.exception(
                            f"Error executing bulk write after max retry [{BulkWrite.SESSION_MAX_TRANSACTION_RETRY}] !"
                        )
                        raise
                    except Exception:
                        logger.exception("Error executing bulk write!")
                        raise

            raise Exception("Can't process registration. Please try again!")

        @cmd_registry.register
        def cloud_test(
            filepath: str,
            test_name: str = "",
            filter: str = "",
            xit: bool = False,
            maxfail: int = None,  # type:ignore
            directory: str = "",
            verbose: bool = False,
            use_db: bool = False,
        ) -> None:
            """Run the test suite in the specified .jac file or directory.

            Executes test functions in Jac files to verify code correctness. Tests are
            identified by functions with names starting with 'test_'. Provides various
            options to control test execution and reporting.

            Args:
                filepath: Path to the .jac file or directory containing tests
                test_name: Run a specific test (without the 'test_' prefix)
                filter: Filter test files using Unix shell style patterns
                xit: Stop running tests as soon as an error is found
                maxfail: Stop running tests after specified number of failures
                directory: Run tests from the specified directory
                verbose: Show detailed test information and results

            Examples:
                jac test                     # Run all tests in current directory
                jac test mytest.jac          # Run all tests in mytest.jac
                jac test --test_name my_test # Run only test_my_test
                jac test --directory tests/  # Run all tests in tests/ directory
                jac test --filter "*_unit_*" # Run tests matching the pattern
                jac test --xit               # Stop on first failure
                jac test --verbose           # Show detailed output
            """
            FastAPI.enable()
            JaseciContext.create(None)

            if not use_db:
                del environ["DATABASE_HOST"]
                environ["DATABASE_NAME"] = "test"
                del environ["SOCKET_REDIS_HOST"]
                del environ["REDIS_HOST"]

            failcount = Jac.run_test(
                filepath=filepath,
                func_name=("test_" + test_name) if test_name else None,
                filter=filter,
                xit=xit,
                maxfail=maxfail,
                directory=directory,
                verbose=verbose,
            )

            if failcount:
                raise SystemExit(f"Tests failed: {failcount}")

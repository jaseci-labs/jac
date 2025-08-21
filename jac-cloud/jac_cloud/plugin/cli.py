"""Module for registering CLI plugins for jaseci."""

from getpass import getpass
from logging import WARNING, getLogger
from os.path import split
from pickle import load
from typing import Any

from jaclang import JacMachine as Jac
from jaclang.cli.cmdreg import cmd_registry
from jaclang.runtimelib.machine import hookimpl

from pymongo.errors import ConnectionFailure, OperationFailure

from watchfiles import Change, run_process

from ..core.archetype import BulkWrite, NodeAnchor
from ..core.context import JaseciContext, PUBLIC_ROOT_ID, SUPER_ROOT_ID
from ..jaseci.datasources import Collection
from ..jaseci.main import FastAPI
from ..jaseci.models import User as BaseUser
from ..jaseci.utils import logger

# hide watchfiles INFO logs
getLogger("watchfiles.main").setLevel(WARNING)


def log_changes(changes: set[tuple[Change, str]]) -> None:
    """Log changes."""
    num_of_changes = len(changes)
    logger.warning(
        f'Detected {num_of_changes} change{"s" if num_of_changes > 1 else ""}'
    )
    for change in changes:
        logger.warning(f"{change[1]} ({change[0].name})")
    logger.warning("Reloading ...")


def run_cloud(
    base: str, mod: str, filename: str, host: str = "0.0.0.0", port: int = 8000
) -> None:
    """Run Jac Cloud service."""
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


class JacCmd:
    """Jac CLI."""

    @staticmethod
    @hookimpl
    def create_cmd() -> None:
        """Create Jac CLI cmds."""

        @cmd_registry.register
        def serve(
            filename: str,
            host: str = "0.0.0.0",
            port: int = 8000,
            reload: bool = False,
            watch: str = "",
        ) -> None:
            """Serve the jac application."""
            base, mod = split(filename)

            if reload:
                run_process(
                    *(watch.split(",") if watch else [base]),
                    target=run_cloud,
                    args=(base, mod, filename, host, port),
                    callback=log_changes,
                )
                return
            elif watch:
                print(f"Ignoring --watch {watch} as --reload is not set.")
            run_cloud(base, mod, filename, host, port)

        @cmd_registry.register
        def create_system_admin(
            filename: str, email: str = "", password: str = ""
        ) -> str:
            from jaclang import JacMachineInterface as Jac

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

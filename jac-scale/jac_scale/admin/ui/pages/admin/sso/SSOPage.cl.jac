"""SSO providers page."""

cl {
    import from react { useEffect }
    import from ....components.common.Card { Card, CardHeader }
    import from ....components.tables.DataTable { DataTable, TableRow, TableCell }
    import from ....context.AuthContext { useAuth }
    import from ....services.userService { getSSOProviders }
    def:pub SSOPage -> JsxElement {
        has ssoProviders: list = [];

        auth = useAuth();

        async def loadSSO -> None {
            result = await getSSOProviders(auth["authToken"]);
            if result["ok"] and result["data"] {
                ssoProviders = result["data"]["providers"];
            }
        }

        useEffect(lambda -> None { loadSSO();}, []);

        columns = [
            {"key": "platform", "label": "Provider"},
            {"key": "status", "label": "Status"},
            {"key": "client_id", "label": "Client ID"},
            {"key": "secret", "label": "Secret"}
        ];

        return
            <Card className="overflow-hidden">
                <CardHeader title="SSO Providers"/>
                <DataTable columns={columns}>
                    {[
                        <TableRow key={p["platform"]}>
                            <TableCell>
                                <span className="text-sm text-white capitalize">
                                    {p["platform"]}
                                </span>
                            </TableCell>
                            <TableCell>
                                {p["configured"]
                                and <span className="text-xs text-emerald-400">
                                    Configured
                                </span>
                                or <span className="text-xs text-slate-500">
                                    Not configured
                                </span>}
                            </TableCell>
                            <TableCell>
                                <span
                                    className={"text-xs " + (
                                        p["client_id_set"]
                                        and "text-emerald-400"
                                        or "text-slate-600"
                                    )}
                                >
                                    {p["client_id_set"] and "Set" or "Not set"}
                                </span>
                            </TableCell>
                            <TableCell>
                                <span
                                    className={"text-xs " + (
                                        p["client_secret_set"]
                                        and "text-emerald-400"
                                        or "text-slate-600"
                                    )}
                                >
                                    {p["client_secret_set"] and "Set" or "Not set"}
                                </span>
                            </TableCell>
                        </TableRow> for p in ssoProviders
                    ]}
                </DataTable>
            </Card>;
    }
}

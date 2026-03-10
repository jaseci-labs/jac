"""Base API service with authentication."""

cl {
    glob:pub baseUrl = window.location.origin;

    async def:pub fetchApi(endpoint: str, options: dict = {}, token: str = "") -> dict {
        headers = options["headers"] or {};
        if token {
            headers["Authorization"] = "Bearer " + token;
        }
        if options["body"] {
            headers["Content-Type"] = "application/json";
        }

        fetchOptions = {** options, "headers": headers};

        try {
            resp = await fetch(baseUrl + endpoint, fetchOptions);
            data = await resp.json();
            return data;
        } except Exception as e {
            console.error("API error:", e);
            return {"ok": False, "error": {"message": str(e)}};
        }
    }

    async def:pub get(endpoint: str, token: str = "") -> dict {
        return await fetchApi(endpoint, {}, token);
    }

    async def:pub post(endpoint: str, body: dict, token: str = "") -> dict {
        return await fetchApi(
            endpoint, {"method": "POST", "body": JSON.stringify(body)}, token
        );
    }

    async def:pub put(endpoint: str, body: dict, token: str = "") -> dict {
        return await fetchApi(
            endpoint, {"method": "PUT", "body": JSON.stringify(body)}, token
        );
    }

    async def:pub del(endpoint: str, token: str = "") -> dict {
        return await fetchApi(endpoint, {"method": "DELETE"}, token);
    }
}

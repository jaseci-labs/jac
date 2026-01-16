import from "@tanstack/react-query" {
    QueryClient,
    QueryClientProvider
}


glob queryClient = Reflect.construct(QueryClient, [
    {
    "defaultOptions": {
        "queries": {
            "staleTime": 1000 * 60,
            "retry": 1
        }
    }
}
]);


def:pub QueryProvider(props: dict) -> any {
    return <QueryClientProvider client={queryClient}>
        {props["children"]}
    </QueryClientProvider>;
}


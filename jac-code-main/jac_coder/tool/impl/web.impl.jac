impl web_fetch(url: str, format: str = "text") -> str {
    tool_status("web_fetch", url);
    if not url {
        return "Error: url is required";
    }

    if url.startswith("http://") {
        url = "https://" + url[7:];
    }
    if not url.startswith("https://") {
        url = "https://" + url;
    }

    try {
        import httpx;
        client = httpx.Client(timeout=30.0, follow_redirects=True);
        response = client.get(
            url, headers={"User-Agent": "JacCoder/0.1 (AI Coding Agent)"}
        );
        response.raise_for_status();
        content = response.text;
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Error fetching URL: {e}";
    }

    if format == "html" {
        (output, _) = truncate_output(content);
        tool_end(f"-> {len(content)} chars");
        return output;
    }

    try {
        import markdownify;
        output = markdownify.markdownify(content, strip=["img", "script", "style"]);
    } except ImportError {
        output = re.sub(r'<[^>]+>', '', content);
        output = re.sub(r'\s+', ' ', output).strip();
    }

    (output, _) = truncate_output(output);
    tool_end(f"-> {len(output)} chars");
    return output;
}


impl web_search(query: str, num_results: int = 5) -> str {
    tool_status("web_search", query);
    if not query {
        return "Error: query is required";
    }

    num_results = min(num_results, 10);

    try {
        import httpx;
        client = httpx.Client(timeout=15.0, follow_redirects=True);
        response = client.get(
            "https://html.duckduckgo.com/html/",
            params={"q": query},
            headers={"User-Agent": "JacCoder/0.1"}
        );
        response.raise_for_status();

        results = [];
        result_pattern = r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>';
        snippet_pattern = r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>';
        urls = re.findall(result_pattern, response.text, re.DOTALL);
        snippets = re.findall(snippet_pattern, response.text, re.DOTALL);

        for i in range(min(len(urls), num_results)) {
            (url, title) = urls[i];
            title = re.sub(r'<[^>]+>', '', title).strip();
            snippet = re.sub(r'<[^>]+>', '', snippets[i]).strip()
                if i < len(snippets)
                else "";
            results.append(f"**{title}**\n{url}\n{snippet}");
        }

        if not results {
            tool_end("-> 0 results");
            return "No results found.";
        }

        tool_end(f"-> {len(results)} results");
        return "\n\n---\n\n".join(results);
    } except Exception as e {
        tool_end("-> error", error=True);
        return f"Search error: {e}";
    }
}

"""Serper API Integration."""

import json
import os

from jaclang import JacMachineInterface as _

from mtllm.types import Tool

import requests

API_HEADERS = {
    "X-API-KEY": os.getenv("SERPER_API_KEY"),
    "Content-Type": "application/json",
}
assert API_HEADERS["X-API-KEY"], "Please set the SERPER_API_KEY environment variable."


@_.sem(
    "A tool that performs a web search using the Serper API.",
    {
        "query": "Query to search for on the web.",
    },
)
def serper_search_tool(query: str) -> str:
    """Search the Serper API."""
    payload = json.dumps(
        {
            "q": query,
        }
    )
    response = requests.request(
        "POST", "https://google.serper.dev/search", headers=API_HEADERS, data=payload
    )
    return response.text


search = Tool(
    serper_search_tool,
)


@_.sem(
    "A tool that scrapes a webpage using the Serper API.",
    {
        "url": "URL of the webpage to scrape.",
    },
)
def serper_scrape_webpage(url: str) -> str:
    """Scrapes the Serper API."""
    payload = json.dumps(
        {
            "url": url,
        }
    )
    response = requests.request(
        "POST", "https://scrape.serper.dev", headers=API_HEADERS, data=payload
    )
    return response.text


scrape = Tool(
    serper_scrape_webpage,
)

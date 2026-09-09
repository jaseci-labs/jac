import asyncio;
import from types { SimpleNamespace }
import from unittest.mock { AsyncMock, patch }

test "posting quota reports the retry message and returns a rejection exit code" {
    result = SimpleNamespace(reports=[PostingDenied("Try again in 10 seconds.", 10)]);
    with patch(
        run_post.__module__ + ".create_tweet", new=AsyncMock(return_value=result)
    ), patch(run_post.__module__ + ".warn") as warning {
        assert asyncio.run(run_post("hello")) == EXIT_REJECTED;
        warning.assert_called_once_with("Try again in 10 seconds.");
    }
}

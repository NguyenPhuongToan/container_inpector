from __future__ import annotations

import json
import sys
from urllib import error, request


def main() -> int:
    url = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/health"

    try:
        with request.urlopen(url, timeout=10) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"unhealthy: {exc}")
        return 1

    if payload.get("status") != "healthy":
        print(f"unhealthy: unexpected payload {payload}")
        return 1

    print("healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

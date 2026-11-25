"""Serve the trial web build with caching turned off, so phones always load the latest export.

Usage: python -I trial/tools/serve.py <port> <bind address> <folder>
"""

import functools
import http.server
import sys


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, must-revalidate")
        self.send_header("Expires", "0")
        super().end_headers()


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8061
    bind = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1"
    folder = sys.argv[3] if len(sys.argv) > 3 else "trial/build/web"
    handler = functools.partial(NoCacheHandler, directory=folder)
    with http.server.ThreadingHTTPServer((bind, port), handler) as server:
        print(f"Serving {folder} on http://{bind}:{port} (no caching)", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()

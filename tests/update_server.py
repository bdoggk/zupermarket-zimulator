"""A stand-in for GitHub's release server, for tests/update_test.gd.

    python3 tests/update_server.py PORT FOLDER

Serves the files in FOLDER at /files/<name>, and /redirect/<name> sends you
on to /files/<name> (GitHub's download links redirect like that).
"""
import http.server
import os
import sys

PORT = int(sys.argv[1])
FOLDER = os.path.abspath(sys.argv[2])


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/redirect/"):
            self.send_response(302)
            self.send_header("Location", "/files/" + self.path[len("/redirect/"):])
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        name = os.path.basename(self.path[len("/files/"):]) if self.path.startswith("/files/") else ""
        path = os.path.join(FOLDER, name)
        if not name or not os.path.isfile(path):
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        with open(path, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "application/json" if name.endswith(".json") else "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()

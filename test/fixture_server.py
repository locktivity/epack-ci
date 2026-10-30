"""A fake GitHub ID token endpoint and Locktivity sign-in for the tests.

The token endpoint returns "id-token-for:<audience>". The sign-in accepts only
the token for its own address. Its answer depends on the pipeline ID in the
path, so each test picks an answer by the ID it signs in with. The port goes
to the file named by the first argument.
"""

import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

SESSION_ENV = {"LOCKTIVITY_ACCESS_TOKEN": "ltk_fixture_session"}

ANSWERS = {
    "current": (200, {"env": SESSION_ENV, "expires_at": "2030-01-01T00:00:00Z", "epack_release_tag": "v0.9.4"}),
    "no-revision": (200, {"env": SESSION_ENV, "expires_at": "2030-01-01T00:00:00Z", "epack_release_tag": None}),
    "odd-tag": (200, {"env": SESSION_ENV, "expires_at": "2030-01-01T00:00:00Z", "epack_release_tag": "v0.9.4; curl evil"}),
    "paused": (403, {"error": "pipeline_paused", "error_description": "This pipeline is paused. Resume it on its page."}),
    "refused": (403, {"error": "Workflow run is not allowed for this pipeline"}),
    "multiline": (403, {"error": "first line\n::warning::second line"}),
    "missing": (404, {"error": "Not found"}),
}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path != "/token" or self.headers.get("Authorization") != "Bearer request-token":
            return self.answer(401, {"message": "bad request token"})
        audience = parse_qs(url.query).get("audience", [""])[0]
        self.answer(200, {"value": f"id-token-for:{audience}"})

    def do_POST(self):
        match = re.fullmatch(r"/oidc/v1/pipelines/([^/]+)/session", self.path)
        own_audience = f"http://127.0.0.1:{self.server.server_port}"
        if not match:
            return self.answer(404, {"error": "Not found"})
        if self.headers.get("Authorization") != f"Bearer id-token-for:{own_audience}":
            return self.answer(401, {"error": "ID token audience mismatch"})
        status, body = ANSWERS.get(match.group(1), (404, {"error": "Not found"}))
        self.answer(status, body)

    def answer(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()

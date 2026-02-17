"""
app/server.py
Minimal Python HTTP server — the application being containerized.
Intentionally simple to keep focus on the DevSecOps pipeline.
"""

import http.server
import json
import platform
import sys
import os


class HealthHandler(http.server.BaseHTTPRequestHandler):
    """Simple health-check server for container liveness probes."""

    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {
                "status": "healthy",
                "python": sys.version.split()[0],
                "platform": platform.system(),
            })
        elif self.path == "/":
            self._respond(200, {"message": "DevSecOps pipeline demo app"})
        else:
            self._respond(404, {"error": "not found"})

    def _respond(self, code: int, body: dict):
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        # Structured log output for container environments
        print(f"[{self.log_date_time_string()}] {self.address_string()} {fmt % args}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"Starting server on port {port}")
    with http.server.HTTPServer(("", port), HealthHandler) as httpd:
        httpd.serve_forever()

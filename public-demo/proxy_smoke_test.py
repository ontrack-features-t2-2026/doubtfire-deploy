#!/usr/bin/env python3
"""Probe the built origin proxy without starting or changing the demo database."""

import http.client
import json
from pathlib import Path
import subprocess
import time
import uuid


name = f"ontrack-public-demo-proxy-check-{uuid.uuid4().hex[:8]}"
config = Path(__file__).with_name("proxy-nginx.conf.template").resolve()
started = False
try:
    subprocess.run([
        "docker", "run", "--detach", "--name", name,
        "--publish", "127.0.0.1::80", "--env", "PUBLIC_HOST=demo.example.invalid",
        "--env", "NGINX_ENVSUBST_FILTER=^PUBLIC_HOST$",
        "--mount", f"type=bind,src={config},dst=/etc/nginx/templates/default.conf.template,readonly",
        "ontrack-public-demo-proxy:local",
    ], check=True, capture_output=True, text=True)
    started = True
    port = int(subprocess.check_output(["docker", "port", name, "80"], text=True).strip().split(":")[-1])
    for attempt in range(30):
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
        try:
            connection.putrequest("POST", "/api/test-upload")
            # The proxy must reject the declared size before reading a large
            # body or contacting Rails. No 96 MB fixture needs to be allocated.
            connection.putheader("Content-Length", str(96 * 1024 * 1024))
            connection.endheaders()
            response = connection.getresponse()
            payload = json.loads(response.read())
            assert response.status == 413, response.status
            assert payload["code"] == "request_too_large", payload
            assert isinstance(payload["error"], str), payload
            assert "'self'" in response.getheader("Content-Security-Policy", "")
            assert response.getheader("Referrer-Policy") == "no-referrer"
            print("Proxy smoke passed: readable JSON413, loopback-compatible CSP, no referrer leakage.")
            break
        except (ConnectionRefusedError, ConnectionResetError, http.client.RemoteDisconnected):
            if attempt == 29:
                raise
            time.sleep(0.1)
        finally:
            connection.close()
finally:
    if started:
        subprocess.run(["docker", "rm", "--force", name], check=True, capture_output=True)

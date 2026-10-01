#!/usr/bin/env python3
"""Check the resolved deployment boundary, not only YAML syntax.

docker compose --env-file .env.example -f compose.yml --profile setup \
  --profile tunnel --profile quick config --format json > compose.resolved.json
python3 compose_contract_test.py compose.resolved.json
The example has no usable secrets and is only suitable for this config check.
"""

import json
from pathlib import Path
import sys


def require(condition, message):
    if not condition:
        raise AssertionError(message)


compose = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
services = compose["services"]
require(compose["name"] == "ontrack-public-demo", "unexpected demo project")
expected = {
    "db", "redis", "mailpit", "bootstrap", "migrate", "apiserver", "webserver",
    "sidekiq", "pdfgen", "texlive-sidekiq", "texlive-pdfgen", "jplag",
    "docker-socket-proxy", "proxy", "cloudflared", "quick-tunnel",
}
require(set(services) == expected, "unexpected services; include all profiles when resolving")

published = [
    (name, port.get("host_ip"), int(port["published"]), int(port["target"]))
    for name, service in services.items() for port in service.get("ports", [])
]
require(sorted(published) == [
    ("mailpit", "127.0.0.1", 8025, 8025),
    ("proxy", "127.0.0.1", 8080, 80),
], "only loopback origin and private mail viewer may be published")
for name in ("data", "docker-api"):
    require(compose["networks"][name]["internal"] is True, f"{name} must be internal")
require(set(services["mailpit"]["networks"]) == {"data", "mail-viewer"},
        "mail viewer needs its own bridge and must not join the public edge")
require([name for name, service in services.items() if "mail-viewer" in service.get("networks", {})] == ["mailpit"],
        "the mail viewer bridge must not have other peers")
require(not any(key.startswith("MP_SMTP_RELAY") or key.startswith("MP_SMTP_FORWARD")
                for key in services["mailpit"]["environment"]), "mail must never be forwarded externally")

for name in ("bootstrap", "migrate", "apiserver", "sidekiq", "pdfgen"):
    service = services[name]
    env = service["environment"]
    require(env["RAILS_ENV"] == "production", f"{name} must not serve development Rails")
    require(env["DF_DEMO_DATA_PROFILE"] == "public-demo", f"{name} lost the guarded profile")
    require(env["DF_PRODUCTION_DB_DATABASE"] == "doubtfire-public-demo", f"{name} wrong database")
    require(env["DF_AUTH_METHOD"] == "database", f"{name} must preserve shared demo login")
    require(env["DF_SMTP_ADDRESS"] == "mailpit" and env["DF_SMTP_PORT"] == "1025",
            f"{name} must capture mail internally")
    require(env["DF_MAIL_DELIVERY_METHOD"] == "smtp", f"{name} must use mail capture")
    require(env["DF_TEAMS_ANNOUNCEMENTS_ENABLED"] == "false", f"{name} must not import real Teams data")
    require(env["OVERSEER_ENABLED"] == "0" and env["TII_ENABLED"] == "false",
            f"{name} enabled an unconfigured external integration")
    require(int(env["DF_PPI_MINIMUM_COHORT_SIZE"]) >= 21, f"{name} lowered peer privacy")
    require("MARIADB_ROOT_PASSWORD" not in env, f"{name} received DB root credentials")
    volumes = {volume["target"]: volume for volume in service["volumes"]}
    require(volumes["/student-work"]["source"] == "student_work", f"{name} lost shared student work")
    require(volumes["/student-work"]["type"] == "volume", f"{name} uses host student data")
    require(not volumes["/student-work"].get("read_only", False), f"{name} cannot save work")
    require(volumes["/student-work/jplag"]["source"] == "jplag_reports", f"{name} lost JPlag reports")

require(services["bootstrap"]["command"] == ["bundle", "exec", "rake", "db:public_demo_prepare"],
        "bootstrap must use the non-destructive guarded seed")
require(services["bootstrap"]["profiles"] == ["setup"], "bootstrap must be explicitly invoked")
require(services["apiserver"]["depends_on"]["migrate"]["condition"] == "service_completed_successfully",
        "API must wait for migrations")
require(services["sidekiq"]["command"] == ["/doubtfire/lib/shell/sidekiq_entry_point.sh"],
        "worker must use all queues from the tested API configuration")
require(services["sidekiq"]["environment"]["DF_SIDEKIQ_CONCURRENCY"] == "5",
        "worker concurrency must stay within its default connection pool")
require(services["pdfgen"]["command"] == ["/doubtfire/lib/shell/pdfgen_entry_point.sh"],
        "scheduled PDF/portfolio work must run")

for name in ("sidekiq", "pdfgen"):
    service = services[name]
    require(service["environment"]["DOCKER_HOST"] == "tcp://docker-socket-proxy:2375",
            f"{name} bypasses the restricted Docker API")
    require(service["environment"]["LATEX_CONTAINER_NAME"] == f"ontrack-public-demo-texlive-{name}",
            f"{name} points at a different helper")
    require(service["depends_on"]["docker-socket-proxy"]["condition"] == "service_healthy",
            f"{name} must wait for Docker API readiness")

socket_mounts = [
    (name, volume) for name, service in services.items()
    for volume in service.get("volumes", []) if volume["target"] == "/var/run/docker.sock"
]
require(len(socket_mounts) == 1 and socket_mounts[0][0] == "docker-socket-proxy",
        "only the restricted proxy may mount the Docker socket")
require(socket_mounts[0][1]["read_only"] is True, "Docker socket mount must remain read-only")
require(services["docker-socket-proxy"]["read_only"] is True, "Docker proxy must be read-only")

for name in ("texlive-sidekiq", "texlive-pdfgen", "jplag"):
    service = services[name]
    require(service["network_mode"] == "none", f"{name} must have no network")
    require(service["cap_drop"] == ["ALL"], f"{name} must drop capabilities")
    require("no-new-privileges:true" in service["security_opt"], f"{name} can gain privileges")
    require(float(service["cpus"]) > 0 and int(service["pids_limit"]) > 0 and service["mem_limit"],
            f"{name} lacks resource ceilings")
    require(all(volume["target"] != "/student-work" for volume in service["volumes"]),
            f"{name} must not receive the whole student-work volume")
require(services["jplag"]["container_name"] == "jplag", "API expects the fixed JPlag name")

require(services["cloudflared"]["profiles"] == ["tunnel"], "permanent tunnel must be opt-in")
require(services["quick-tunnel"]["profiles"] == ["quick"], "temporary tunnel must be opt-in")
require(services["quick-tunnel"]["restart"] == "no", "temporary hostname must not rotate after an automatic restart")
require("http://proxy:80" in services["quick-tunnel"]["command"], "tunnel origin must be the container proxy")
require("--token-file" in services["cloudflared"]["command"], "tunnel credentials must use a secret file")
require("--token" not in services["cloudflared"]["command"], "token must not appear in process arguments")
for name in ("cloudflared", "quick-tunnel"):
    service = services[name]
    require(set(service["networks"]) == {"edge"}, f"{name} may only reach the origin network")
    require(not service.get("environment"), f"{name} must not receive application secrets")

for name, service in services.items():
    if name not in {"bootstrap", "migrate"}:
        require("healthcheck" in service, f"{name} needs a readiness check")
        require(service.get("restart") == ("no" if name == "quick-tunnel" else "unless-stopped"),
                f"{name} restart policy changed")
    require(not service.get("privileged"), f"{name} must not be privileged")
    if not service["image"].startswith("ontrack-public-demo-"):
        require("@sha256:" in service["image"], f"{name} upstream image is not pinned")

for name, dockerfile in {
    "apiserver": "deployApi.Dockerfile", "sidekiq": "deployAppSvr.Dockerfile",
    "webserver": "deploy.Dockerfile", "texlive-sidekiq": "texlive.Dockerfile",
    "jplag": "jplag.Dockerfile", "proxy": "proxy.Dockerfile",
}.items():
    require(services[name]["build"]["dockerfile"] == dockerfile, f"{name} builds the wrong runtime")

print("Public demo deployment contract passed.")

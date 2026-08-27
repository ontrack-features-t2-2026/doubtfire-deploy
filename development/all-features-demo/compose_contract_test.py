#!/usr/bin/env python3

"""Fail closed if the rendered all-features demo loses its isolation contract."""

import json
import sys


def require(condition, message):
    if not condition:
        raise AssertionError(message)


with open(sys.argv[1], encoding="utf-8") as compose_file:
    compose = json.load(compose_file)

require(compose["name"] == "all-features-demo", "unexpected Compose project name")

services = compose["services"]
expected_services = {
    "dev-db",
    "doubtfire-api",
    "doubtfire-sidekiq",
    "doubtfire-web",
    "mailpit",
    "redis-sidekiq",
}
require(set(services) == expected_services, "unexpected all-features demo service set")

expected_containers = {
    service_name: f"all-features-demo-{suffix}"
    for service_name, suffix in {
        "dev-db": "db",
        "doubtfire-api": "api",
        "doubtfire-sidekiq": "sidekiq",
        "doubtfire-web": "web",
        "mailpit": "mailpit",
        "redis-sidekiq": "redis",
    }.items()
}
for service_name, container_name in expected_containers.items():
    require(
        services[service_name]["container_name"] == container_name,
        f"{service_name} is not isolated under the all-features demo name",
    )

expected_environment = {
    "RAILS_ENV": "development",
    "DF_DEMO_DATA_PROFILE": "all-features",
    "DF_DEV_DB_DATABASE": "doubtfire-all-features-demo",
    "DF_TEST_DB_DATABASE": "doubtfire-all-features-demo-test",
    "DF_PRODUCTION_DB_DATABASE": "doubtfire-all-features-demo",
    "DF_PPI_MINIMUM_COHORT_SIZE": "21",
    "DF_PPI_STALE_AFTER_HOURS": "48",
    "DF_INSTITUTION_HOST": "http://localhost:4400",
    "DF_INSTITUTION_EMAIL_SENDER": "noreply@ontrack-demo.invalid",
    "DF_SMTP_ADDRESS": "mailpit",
    "DF_REDIS_SIDEKIQ_URL": "redis://redis-sidekiq:6379/0",
}
for service_name in ("doubtfire-api", "doubtfire-sidekiq"):
    environment = services[service_name]["environment"]
    for key, value in expected_environment.items():
        require(
            environment.get(key) == value,
            f"{service_name} has an unsafe or incomplete {key} value",
        )

require(
    services["doubtfire-api"]["depends_on"]["mailpit"]["condition"]
    == "service_healthy",
    "API must wait for the local mail catcher",
)
require(
    services["doubtfire-web"]["depends_on"]["doubtfire-api"]["condition"]
    == "service_healthy",
    "web must wait for a ready API",
)
for service_name, expected_probe in {
    "dev-db": "healthcheck.sh",
    "mailpit": "readyz",
    "doubtfire-api": "/readiness",
    "doubtfire-web": "127.0.0.1:4200",
}.items():
    probe = " ".join(services[service_name]["healthcheck"]["test"])
    require(expected_probe in probe, f"{service_name} readiness probe is missing")

published_ports = []
for service_name, service in services.items():
    for port in service.get("ports", []):
        published_ports.append(
            (service_name, int(port["target"]), int(port["published"]))
        )
require(
    sorted(published_ports)
    == [
        ("doubtfire-api", 3000, 3200),
        ("doubtfire-web", 4200, 4400),
        ("mailpit", 1025, 1225),
        ("mailpit", 8025, 8225),
    ],
    "demo published ports changed or a database/Redis port became public",
)

expected_volume_names = {
    "all_features_demo_db_data",
    "all_features_demo_redis_data",
    "all_features_demo_student_work",
    "all_features_demo_tmp",
    "all_features_demo_web_node_modules",
}
require(set(compose["volumes"]) == expected_volume_names, "unexpected demo volumes")
for volume_name in expected_volume_names:
    require(
        compose["volumes"][volume_name]["name"]
        == f"all-features-demo_{volume_name}",
        f"{volume_name} can collide with another Compose project",
    )

database_mounts = services["dev-db"]["volumes"]
require(
    len(database_mounts) == 1
    and database_mounts[0]["type"] == "volume"
    and database_mounts[0]["source"] == "all_features_demo_db_data"
    and database_mounts[0]["target"] == "/var/lib/mysql",
    "demo database must use only its dedicated named volume",
)

for service_name in ("doubtfire-api", "doubtfire-sidekiq"):
    volume_targets = {
        volume["target"]: (volume["type"], volume["source"])
        for volume in services[service_name]["volumes"]
    }
    require(
        volume_targets["/doubtfire/tmp"]
        == ("volume", "all_features_demo_tmp"),
        f"{service_name} does not use the isolated temporary volume",
    )
    require(
        volume_targets["/student-work"]
        == ("volume", "all_features_demo_student_work"),
        f"{service_name} does not use the isolated student-work volume",
    )

require(
    services["doubtfire-api"]["build"]["context"]
    == services["doubtfire-sidekiq"]["build"]["context"],
    "API and Sidekiq must build from the same source revision",
)
require(
    services["doubtfire-api"]["image"] == services["doubtfire-sidekiq"]["image"],
    "API and Sidekiq must run the same image",
)
require(
    services["doubtfire-sidekiq"]["command"]
    == [
        "bundle",
        "exec",
        "sidekiq",
        "-C",
        "config/sidekiq.yml",
        "-q",
        "mailers",
        "-q",
        "notifications",
    ],
    "development Sidekiq must consume both notification channels and not default",
)

print("All-features demo Compose contract checks passed.")

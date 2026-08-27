![Doubtfire Logo](http://puu.sh/lyClF/fde5bfbbe7.png)

# Doubtfire Deploy

Doubtfire is a feedback-driven learning support system.

The Doubtfire Deploy repository is used to manage releases of Doubtfire using containers.

## Table of Contents

- [Doubtfire Deploy](#doubtfire-deploy)
  - [Table of Contents](#table-of-contents)
  - [How to use this project for development](#how-to-use-this-project-for-development)
  - [How to use this project for deployment](#how-to-use-this-project-for-deployment)

## How to use this project for development

Refer to [CONTRIBUTING.md](CONTRIBUTING.md) for details on getting started contributing to Doubtfire.

## How to use this project for deployment

Use the fail-closed production Compose stack and operator runbook in
[DEPLOYING.md](DEPLOYING.md). The deployment requires institution-owned secrets,
TLS, identity-provider and SMTP settings, persistent storage, and immutable
container image digests; none are defaulted in the repository.


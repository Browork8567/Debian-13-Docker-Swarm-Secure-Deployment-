# 🔐 Secrets

DO NOT store secrets in this repository.

Use one of the following:
- Docker secrets
- External secret managers
- Local `/opt/swarm-secure/config.env`

Never commit:
- passwords
- SSH private keys
- SMB credentials

## Example

echo "mypassword" | docker secret create db_password -

## Use in service

docker service create \
  --name app \
  --secret db_password \
  nginx
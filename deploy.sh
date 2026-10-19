#!/bin/bash
# Bouwt en deployt de TodoApp (.NET) met een MariaDB-database als containers.
# Het script is herhaalbaar: je kunt het zo vaak uitvoeren als je wilt.
set -euo pipefail

NETWORK=todo-net
DB=todoappdb
APP=todoapp
HOST_PORT=5080   # 8080 is al in gebruik door Jenkins zelf

# Demo-credentials, overgenomen uit docker-compose.yml van de repo
DB_ROOT_PASSWORD=sekrit
DB_NAME=todo_db
DB_USER=todo_usr
DB_PASSWORD=letmeinplz

# Eigen netwerk, zodat de app de database kan bereiken via de naam "todoappdb"
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

# Eerst de nieuwe image bouwen; de oude versie blijft draaien tot dit klaar is
docker build -t todoapp ./TodoApp

# Database alleen starten als ze nog niet draait.
# De data staat in het named volume 'mariadb-data' en blijft dus bewaard.
if ! docker inspect -f '{{.State.Running}}' "$DB" 2>/dev/null | grep -q true; then
  docker rm -f "$DB"
  docker run -d --name "$DB" --network "$NETWORK" \
    -e MARIADB_ROOT_PASSWORD="$DB_ROOT_PASSWORD" \
    -e MARIADB_DATABASE="$DB_NAME" \
    -e MARIADB_USER="$DB_USER" \
    -e MARIADB_PASSWORD="$DB_PASSWORD" \
    -v mariadb-data:/var/lib/mysql \
    mariadb:11
fi

# Wachten tot de database klaar is (zelfde check als de healthcheck in docker-compose.yml)
for i in $(seq 1 30); do
  if docker exec "$DB" healthcheck.sh --connect --innodb_initialized >/dev/null 2>&1; then
    echo "Database is ready"
    break
  fi
  echo "Waiting for database ($i/30)..."
  sleep 2
done

# Schema laden via 'docker exec' (geen bind mount: een bind mount vanuit de
# Jenkins-container zou verwijzen naar een pad op de host dat niet bestaat)
docker exec -i "$DB" mariadb -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < TodoApp/schema.sql

# Oude app-container vervangen door de nieuwe
docker rm -f "$APP"
docker run -d --name "$APP" --network "$NETWORK" -p "$HOST_PORT":8080 \
  -e "ConnectionStrings__TodoDb=Server=$DB;Port=3306;Database=$DB_NAME;User=$DB_USER;Password=$DB_PASSWORD;" \
  -e ASPNETCORE_ENVIRONMENT=Development \
  todoapp

docker ps

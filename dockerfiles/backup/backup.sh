#!/bin/sh
echo "starting backup"

if [ "$IS_ISTIO" = "true" ]; then
  echo "waiting for istio proxy to start..."
  sleep 30
  trap "curl --max-time 2 -s -f -XPOST http://127.0.0.1:15020/quitquitquit" EXIT
  while ! curl -s -f http://127.0.0.1:15020/healthz/ready; do sleep 1; done
fi

DATE=$(date -u +%Y-%m-%d-%H-%M)

if [ "$MONGODB_ENABLED" = "true" ]; then
  echo "starting mongodb backup"
  mkdir -p /mnt/backup/mongodb
  cd /mnt/backup/mongodb
  for DATABASE in $(echo $MONGODB_DATABASES | sed "s/,/ /g"); do
    DUMP_FILE="mongodb-$DATE-$DATABASE.dump"
    echo "mongodb dump file, $DUMP_FILE"
    MONGGODB_URI="mongodb://$MONGODB_USER:$MONGODB_PASSWORD@$MONGODB_HOST:27017/$DATABASE?authSource=admin"
    mongodump \
      --uri $MONGGODB_URI \
      -o $DUMP_FILE
  done;
fi

if [ "$MYSQL_ENABLED" = "true" ]; then
  echo "starting mysql backup"
  mkdir -p /mnt/backup/mysql
  cd /mnt/backup/mysql
  for DATABASE in $(echo $MYSQL_DATABASES | sed "s/,/ /g"); do
    DUMP_FILE="mysql-$DATE-$DATABASE.sql"
    echo "mysql dump file, $DUMP_FILE"
    mysqldump \
      -h $MYSQL_HOST \
      -u $MYSQL_USER \
      -p$MYSQL_PASSWORD \
      $DATABASE \
      > $DUMP_FILE
  done;
  DUMP_FILE="mysql-$DATE-all.sql"
  echo "mysql dump all file, $DUMP_FILE"
  mysqldump \
    --all-databases \
    -h $MYSQL_HOST \
    -u $MYSQL_USER \
    -p$MYSQL_PASSWORD \
    > $DUMP_FILE
fi

if [ "$PGENABLED" = "true" ]; then
  echo "starting postgresql backup"
  mkdir -p /mnt/backup/postgresql
  cd /mnt/backup/postgresql
  for DATABASE in $(echo $PGDATABASES | sed "s/,/ /g"); do
    PGDUMPFILE="postgresql-$DATE-$DATABASE.sql"
    echo "postgresql dump file, $PGDUMPFILE"
    pg_dump \
      -C \
      -w \
      --format=c \
      --blobs \
      $DATABASE \
      > $PGDUMPFILE
  done;
  PGDUMPFILE="postgresql-$DATE-all.sql"
  echo "postgresql dump all file, $PGDUMPFILE"
  pg_dumpall > $PGDUMPFILE
fi

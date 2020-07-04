# backup

backup container for following databases:
* postgresql
* mysql
* mongodb

| Parameter           | Description              | Default   |
|---------------------|--------------------------|-----------|
| `IS_ISTIO`          | If deployed in istio env | `"false"` |
| `MONGODB_ENABLED`   | Enable MongoDB backup    | `"false"` |
| `MONGODB_HOST`      | MongoDB host             | `""`      |
| `MONGODB_USER`      | MongoDB user             | `""`      |
| `MONGODB_PASSWORD`  | MongoDB password         | `""`      |
| `MONGODB_DATABASES` | MongoDB databases        | `""`      |
| `MYSQL_ENABLED`     | Enable MySQL backup      | `"false"` |
| `MYSQL_HOST`        | MySQL host               | `""`      |
| `MYSQL_USER`        | MySQL user               | `""`      |
| `MYSQL_PASSWORD`    | MySQL password           | `""`      |
| `MYSQL_DATABASES`   | MySQL databases          | `""`      |
| `PGENABLED`         | Enable postgresql backup | `"false"` |
| `PGHOST`            | Postgresql host          | `""`      |
| `PGUSER`            | Postgresql user          | `""`      |
| `PGPASSWORD`        | Postgresql password      | `""`      |
| `PGDATABASES`       | Postgresql databases     | `""`      |

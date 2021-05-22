# How to use Presto (with Hive metastore) and MinIO?

To start using this project you need to clone this repository locally.

```
git clone https://github.com/minio/presto-minio
cd presto-minio
docker-compose up -d
```

Using `docker-compose` you set up Presto, Hive containers for Presto to query data from MinIO. Presto uses the Hive container for the metastore. Once up you can view the Presto WebUI at `http://127.0.0.1:8080/`

Please make relevant changes to `fs.s3a.endpoint` to point to your local MinIO setup, files to be modified are

```
hadoop/core-site.xml
```

and

```
presto/minio.properties
```

Once you have edited these files, proceed to edit the environment value for `mcjob` in `docker-compose.yml` this should point to the same local MinIO setup as configured in previous files.

# Example
First create a table in the Hive metastore. Note that the location `'s3a://customer-data-text/'` points to data that already exists in the Minio container.

Run `docker exec -it hadoop-master /bin/bash`.

```
[root@hadoop-master /]# hive
hive> use default;
hive> create external table customer_text(id string, fname string, lname string) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE location 's3a://customer-data-text/';
hive> select * from customer_text;
```

Next let's query the data from Presto. Run `docker exec -it presto /bin/bash`

```
[presto@presto /]$ presto --server localhost:8080 --catalog hive --schema default
presto> use minio.default;
presto:default> show tables;

presto:default> show tables;
     Table
---------------
 customer_text
(2 rows)

presto:default> select * from customer_text;
 id | fname | lname
----+-------+-------
 5  | Bob   | Jones
 6  | Phil  | Brune
(2 rows)
```

Next, let's create a new table via Presto and copy the CSV data into ORC format. Before you do that, make a new bucket in Minio named `customer-data-orc`.

```
presto:default> create table customer_orc(id varchar,fname varchar,lname varchar) with (format = 'ORC', external_location = 's3a://customer-data-orc/');
CREATE TABLE

presto:default> insert into customer_orc select * from customer_text;
INSERT: 2 rows

presto:default> select * from customer_orc;
 id | fname | lname
----+-------+-------
 5  | Bob   | Jones
 6  | Phil  | Brune
```

# How to use Presto (with Hive metastore) and MinIO?

This is a derivative of the work done by the repository that this was forked from. Thanks to the OP!

The changes between this fork and the upstream repo are as follwos:
1. Adding a MinIO container to the docker-compose to provide out of the box local S3 storage. 
2. Setting the local S3 storage up for use by Hive and Presto.
3. Switch Starburst Presto for the Ahana Presto sandbox.
4. Use a new Hive image (hive3.1-hive:10)


## Prereq

The host must have installed 
- docker 
- docker-compose

In this example we are using the docker-compose script and not the newer docker compose command although both should work.


## Do it

To start using this project you need to clone this repository locally.

```
git clone https://github.com/minio/presto-minio
cd presto-minio
mkdir -p ~/minio/data
docker-compose up -d
```

The MinIO local storage is set up to `~/minio/data`. This path is mounted into the MinIO container and will contain new buckets and any data that is created as part of the container setup. You can change this in the `docker-compose.yml` to a different local path if needed.

Using `docker-compose` you set up MinIO, Hive, and Presto containers for Presto to query data from MinIO. Presto uses the Hive container for the metastore. Once up you can view the Presto WebUI at `http://127.0.0.1:8080/` and the MinIO console at `http://127.0.0.1:9001`.

The main configuration files are

```
hadoop/core-site.xml
```

and

```
presto/minio.properties
```

The main change is to the `fs.s3a.endpoint` to point to the fixed local MinIO setup.

Follow the example to create a table (in memory) to be used in Hive for later use in Presto.

# Example
First create a table in the Hive metastore. Note that the location `'s3a://customer-data-text/'` points to data that already exists in the Minio container.

The raw data file used for the `customer_text` table was copied by the mcjob from the local storage to MinIO. It can be found in `./minio/data/customer-data-text/customer.csv`.

Run `docker exec -it hadoop-master /bin/bash`.

```
[root@hadoop-master /]# hive
hive> use default;
hive> create external table customer_text(id string, fname string, lname string) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE location 's3a://customer-data-text/';
hive> select * from customer_text;
hive> exit;
[root@hadoop-master /]# exit
```

This generates the following output.

```
czentgr@cz-vm-ubuntu-2004:~/presto-minio$ docker exec -it hadoop-master /bin/bash
[root@hadoop-master /]# hive
<... java messages ...>
Hive Session ID = 776bded5-4302-498e-84dd-3316de411db7

Logging initialized using configuration in jar:file:/opt/hive/lib/hive-common-3.1.2.jar!/hive-log4j2.properties Async: true
Hive Session ID = 36bee145-cbc5-4b76-b21e-809743e16af8
Hive-on-MR is deprecated in Hive 2 and may not be available in the future versions. Consider using a different execution engine (i.e. spark, tez) or using Hive 1.X releases.
hive> use default;
OK
Time taken: 0.79 seconds
hive> create external table customer_text(id string, fname string, lname string) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE location 's3a://customer-data-text/';
OK
Time taken: 4.705 seconds
hive> select * from customer_text;
OK
5	Bob	Jones
6	Phil	Brune
Time taken: 2.375 seconds, Fetched: 2 row(s)
hive> exit;
[root@hadoop-master /]# exit
exit
```


Next let's query the data from Presto. Run `docker exec -it presto  presto-cli`


```
$ docker exec -it presto  presto-cli
presto> use minio.default;
USE
presto:default> show tables;
     Table     
---------------
 customer_text 
(1 row)

Query 20230303_233637_00001_ihmqp, FINISHED, 1 node
Splits: 19 total, 19 done (100.00%)
[Latency: client-side: 0:02, server-side: 0:02] [1 rows, 30B] [0 rows/s, 15B/s]

presto:default> select * from customer_text;
 id | fname | lname 
----+-------+-------
 5  | Bob   | Jones 
 6  | Phil  | Brune 
(2 rows)

Query 20230303_233647_00002_ihmqp, FINISHED, 1 node
Splits: 17 total, 17 done (100.00%)
[Latency: client-side: 0:02, server-side: 0:02] [2 rows, 25B] [1 rows/s, 12B/s]

```

Note: the data is persisted to MinIO when following the next step.

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

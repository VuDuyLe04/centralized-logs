-- ==============================
-- CLICKHOUSE INIT SCRIPT
-- ==============================

-- Tạo database chính
CREATE DATABASE IF NOT EXISTS observability;

USE observability;

-- ==========================================
-- 1️⃣ LOGS TABLES
-- ==========================================

-- Bảng tạm đọc trực tiếp từ Kafka topic "logs_raw"
CREATE TABLE IF NOT EXISTS kafka_logs_raw
(
    `timestamp` DateTime,
    `source_type` String,
    `container` String,
    `level` String,
    `event_id` String,
    `message` String
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'logs_raw',
    kafka_group_name = 'clickhouse_logs_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1;

-- Bảng chính để lưu log đã ingest
CREATE TABLE IF NOT EXISTS logs
(
    `timestamp` DateTime,
    `source_type` LowCardinality(String),
    `container` LowCardinality(String),
    `level` LowCardinality(String),
    `event_id` String,
    `message` String
)
ENGINE = MergeTree()
ORDER BY (timestamp, source_type)
PARTITION BY toYYYYMMDD(timestamp);

-- View để tự động ingest từ Kafka → logs
CREATE MATERIALIZED VIEW IF NOT EXISTS logs_mv
TO logs
AS
SELECT
    timestamp,
    source_type,
    container,
    level,
    event_id,
    message
FROM kafka_logs_raw;

-- ==========================================
-- 2️⃣ METRICS TABLES
-- ==========================================

CREATE TABLE IF NOT EXISTS kafka_metrics_raw
(
    `timestamp` DateTime,
    `source_type` String,
    `hostname` String,
    `cpu_usage` Float64 DEFAULT 0,
    `memory_used_percent` Float64 DEFAULT 0,
    `disk_used_percent` Float64 DEFAULT 0,
    `network_in_bytes` Float64 DEFAULT 0,
    `network_out_bytes` Float64 DEFAULT 0
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'metrics_raw',
    kafka_group_name = 'clickhouse_metrics_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1;

CREATE TABLE IF NOT EXISTS metrics
(
    `timestamp` DateTime,
    `source_type` LowCardinality(String),
    `hostname` LowCardinality(String),
    `cpu_usage` Float64,
    `memory_used_percent` Float64,
    `disk_used_percent` Float64,
    `network_in_bytes` Float64,
    `network_out_bytes` Float64
)
ENGINE = MergeTree()
ORDER BY (timestamp, hostname)
PARTITION BY toYYYYMMDD(timestamp);

CREATE MATERIALIZED VIEW IF NOT EXISTS metrics_mv
TO metrics
AS
SELECT
    timestamp,
    source_type,
    hostname,
    cpu_usage,
    memory_used_percent,
    disk_used_percent,
    network_in_bytes,
    network_out_bytes
FROM kafka_metrics_raw;

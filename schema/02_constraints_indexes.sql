-- =====================================================================
-- Smart Bike Rental App | GIU Software Engineering | Milestone 2
-- File    : 02_constraints_indexes.sql
-- Purpose : additional uniqueness rules, performance indexes, and views
-- Run     : AFTER 01_create_tables.sql and BEFORE 03_seed_data.sql
-- Database: PostgreSQL
-- =====================================================================

-- ---------------------------------------------------------------------
-- (a) Partial unique indexes: enforce rules only for matching rows
-- ---------------------------------------------------------------------

-- A bike can have only one ride in progress at a time.
-- A ride is in progress while docked_at is NULL.
CREATE UNIQUE INDEX ux_rentals_one_running_per_bike
    ON rentals (bike_id)
    WHERE docked_at IS NULL;

-- A bike can have only one active reservation at a time.
CREATE UNIQUE INDEX ux_reservations_one_active_per_bike
    ON reservations (bike_id)
    WHERE status = 'active';


-- ---------------------------------------------------------------------
-- (b) Performance indexes
-- Note: primary keys and UNIQUE constraints already create indexes.
-- ---------------------------------------------------------------------

-- Rider ride history, usually shown newest first.
CREATE INDEX ix_rentals_user
    ON rentals (user_id, unlocked_at);

-- Find rides for a particular bike.
CREATE INDEX ix_rentals_bike
    ON rentals (bike_id);

-- Check whether a rider has unpaid rides.
CREATE INDEX ix_rentals_unpaid
    ON rentals (user_id)
    WHERE payment_status = 'unpaid';

-- Show a rider's reservations.
CREATE INDEX ix_reservations_user
    ON reservations (user_id);

-- Show wallet transactions in chronological order.
CREATE INDEX ix_wallet_tx_wallet
    ON wallet_transactions (wallet_id, created_at);

-- Find a rider's latest national-ID verification attempts.
CREATE INDEX ix_id_ver_user
    ON id_verifications (user_id, submitted_at);

-- Find a rider's latest phone verification codes.
CREATE INDEX ix_phone_ver_user
    ON phone_verifications (user_id, sent_at);

-- Find all damage reports for a particular bike.
CREATE INDEX ix_damage_reports_bike
    ON damage_reports (bike_id);

-- Admin review queue: open reports, oldest first.
CREATE INDEX ix_damage_reports_open
    ON damage_reports (created_at)
    WHERE status = 'open';

-- Find users by membership level.
CREATE INDEX ix_users_level
    ON users (membership_level_id);

-- Find promotions assigned to a membership level.
-- promotions and membership_levels are related through promotion_levels.
CREATE INDEX ix_promotion_levels_level
    ON promotion_levels (membership_level_id);

-- No separate docks(station_id) index is needed:
-- UNIQUE (station_id, dock_number) already creates a suitable index.
-- bikes.dock_id is also indexed automatically because it is UNIQUE.


-- ---------------------------------------------------------------------
-- (c) Helper views: calculated results; they do not store extra rows
-- ---------------------------------------------------------------------

-- Station map information:
-- capacity       = number of dock slots at the station
-- available_bikes = docked bikes whose status is 'available'
-- free_docks     = dock slots that currently have no bike
CREATE VIEW station_availability AS
SELECT
    s.station_id,
    s.name,
    s.latitude,
    s.longitude,
    COUNT(DISTINCT d.dock_id) AS capacity,
    COUNT(DISTINCT b.bike_id)
        FILTER (WHERE b.status = 'available') AS available_bikes,
    COUNT(DISTINCT d.dock_id)
        - COUNT(DISTINCT b.dock_id) AS free_docks
FROM stations s
LEFT JOIN docks d
    ON d.station_id = s.station_id
LEFT JOIN bikes b
    ON b.dock_id = d.dock_id
GROUP BY
    s.station_id,
    s.name,
    s.latitude,
    s.longitude;


-- Rider ride history, including duration rounded up to whole minutes.
-- An ongoing ride has NULL docked_at and therefore NULL minutes_billed.
CREATE VIEW rider_ride_history AS
SELECT
    r.rental_id,
    r.user_id,
    u.username,
    r.bike_id,
    r.unlocked_at,
    r.docked_at,
    CEIL(
        EXTRACT(EPOCH FROM (r.docked_at - r.unlocked_at)) / 60
    )::INT AS minutes_billed,
    r.total_cost,
    r.payment_status
FROM rentals r
JOIN users u
    ON u.user_id = r.user_id;


-- Riders with unpaid rides and the total amount they owe.
CREATE VIEW riders_blocked_for_unpaid AS
SELECT
    u.user_id,
    u.username,
    COUNT(*) AS unpaid_rides,
    SUM(r.total_cost) AS amount_due
FROM users u
JOIN rentals r
    ON r.user_id = u.user_id
WHERE r.payment_status = 'unpaid'
GROUP BY
    u.user_id,
    u.username;


-- Membership level a rider qualifies for based on completed rides.
-- This view reports the qualifying level; it does not update users.
CREATE VIEW rider_membership_check AS
WITH ride_counts AS (
    SELECT
        u.user_id,
        u.username,
        COUNT(r.rental_id) AS completed_rides
    FROM users u
    LEFT JOIN rentals r
        ON r.user_id = u.user_id
       AND r.docked_at IS NOT NULL
    WHERE u.role = 'rider'
    GROUP BY
        u.user_id,
        u.username
)
SELECT
    rc.user_id,
    rc.username,
    rc.completed_rides,
    (
        SELECT ml.name
        FROM membership_levels ml
        WHERE ml.min_rides <= rc.completed_rides
        ORDER BY ml.min_rides DESC
        LIMIT 1
    ) AS level_by_rides
FROM ride_counts rc;

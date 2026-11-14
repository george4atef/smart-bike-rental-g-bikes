-- =====================================================================
-- Smart Bike Rental App | GIU Software Engineering | Milestone 2
-- File    : schema/02_constraints_indexes.sql
-- Purpose : (a) rules that cannot be written inside CREATE TABLE,
--           (b) indexes that make common searches fast,
--           (c) helper VIEWS that calculate values we do not store.
-- Run     : AFTER 01_create_tables.sql
-- =====================================================================


-- ---------------------------------------------------------------------
-- (a) Rules that need a "partial unique index"
--     "UNIQUE ... WHERE" means: the rule only applies to some rows.
-- ---------------------------------------------------------------------

-- A bike can only be in ONE running rental at a time
-- (running rental = dock_time is still empty).      -> US-08, US-14
CREATE UNIQUE INDEX ux_rentals_one_running_per_bike
    ON rentals (bike_id)
    WHERE dock_time IS NULL;

-- A bike can only have ONE active reservation at a time. -> US-16
CREATE UNIQUE INDEX ux_reservations_one_active_per_bike
    ON reservations (bike_id)
    WHERE status = 'active';


-- ---------------------------------------------------------------------
-- (b) Indexes on the columns we search by most often
--     (think of an index as the "index page" at the back of a book).
-- ---------------------------------------------------------------------

-- "Show my ride history"                                  -> US-22
CREATE INDEX ix_rentals_user            ON rentals (user_id, unlock_time);
-- "Does this rider have unpaid rides?" (blocks renting)   -> US-13
CREATE INDEX ix_rentals_unpaid          ON rentals (user_id)
    WHERE payment_status = 'unpaid';
-- "Which bikes are at this station?"                      -> US-07, US-15
CREATE INDEX ix_bikes_station           ON bikes (station_id);
-- "Show my wallet transactions"                           -> US-22
CREATE INDEX ix_wallet_tx_wallet        ON wallet_transactions (wallet_id, created_at);
-- "Show my reservations"                                  -> US-16..US-18
CREATE INDEX ix_reservations_user       ON reservations (user_id);
-- "Latest ID-check attempts of a rider"                   -> US-05, US-06
CREATE INDEX ix_identity_ver_user       ON identity_verifications (user_id, submitted_at);
-- "Latest phone code of a rider"                          -> US-02
CREATE INDEX ix_phone_ver_user          ON phone_verifications (user_id, created_at);
-- "All reports of one bike" / "all reports still waiting" -> US-24
CREATE INDEX ix_damage_reports_bike     ON damage_reports (bike_id);
CREATE INDEX ix_damage_reports_open     ON damage_reports (status)
    WHERE status = 'open';
-- "Promotions of my level"                                -> US-20
CREATE INDEX ix_promotions_level        ON promotions (membership_level_id);
-- "Riders of a level"                                     -> US-19
CREATE INDEX ix_users_level             ON users (membership_level_id);


-- ---------------------------------------------------------------------
-- (c) Helper views (they store nothing; they calculate on demand)
-- ---------------------------------------------------------------------

-- Station map data: name, capacity, available bikes, free docks.  -> US-07, US-15
--   available_bikes = bikes docked here that can be rented right now
--   free_docks      = capacity - every bike that occupies a dock here
CREATE VIEW station_availability AS
SELECT s.station_id,
       s.name,
       s.capacity,
       COUNT(b.bike_id) FILTER (WHERE b.status = 'available') AS available_bikes,
       s.capacity - COUNT(b.bike_id)                          AS free_docks
FROM stations s
LEFT JOIN bikes b ON b.station_id = s.station_id
GROUP BY s.station_id, s.name, s.capacity;

-- Ride history: minutes are calculated, rounded UP to whole minutes.  -> US-22
CREATE VIEW rider_ride_history AS
SELECT r.rental_id,
       r.user_id,
       u.username,
       r.bike_id,
       r.unlock_time,
       r.dock_time,
       CEIL(EXTRACT(EPOCH FROM (r.dock_time - r.unlock_time)) / 60)::INT
                                   AS minutes_billed,
       r.cost,
       r.payment_status
FROM rentals r
JOIN users u ON u.user_id = r.user_id;

-- Riders who are blocked from renting/reserving because of unpaid rides. -> US-13
CREATE VIEW riders_blocked_for_unpaid AS
SELECT u.user_id,
       u.username,
       COUNT(*)       AS unpaid_rides,
       SUM(r.cost)    AS amount_due
FROM users u
JOIN rentals r ON r.user_id = u.user_id
WHERE r.payment_status = 'unpaid'
GROUP BY u.user_id, u.username;

-- Which membership level each rider SHOULD have, from the completed rides. -> US-19
CREATE VIEW rider_membership_check AS
WITH ride_counts AS (
    SELECT u.user_id,
           u.username,
           COUNT(r.rental_id) AS completed_rides
    FROM users u
    LEFT JOIN rentals r
           ON r.user_id = u.user_id AND r.dock_time IS NOT NULL
    WHERE u.role = 'rider'
    GROUP BY u.user_id, u.username
)
SELECT rc.user_id,
       rc.username,
       rc.completed_rides,
       (SELECT ml.name
          FROM membership_levels ml
         WHERE ml.min_rides <= rc.completed_rides
         ORDER BY ml.min_rides DESC
         LIMIT 1) AS level_by_rides
FROM ride_counts rc;

-- =====================================================================
-- Smart Bike Rental App - Milestone 2
-- 02_constraints_indexes.sql : extra uniqueness rules and indexes
-- Run after 01_create_tables.sql.
-- =====================================================================

-- A bike can be in only one ride at a time (US-08).
CREATE UNIQUE INDEX uq_rentals_one_active_per_bike
    ON rentals (bike_id) WHERE docked_at IS NULL;

-- A bike can be held by only one active reservation at a time (US-16).
CREATE UNIQUE INDEX uq_reservations_one_active_per_bike
    ON reservations (bike_id) WHERE status = 'active';

-- Indexes on foreign keys used by the most common lookups.
-- PostgreSQL indexes primary keys and UNIQUE columns automatically, but not foreign keys.
CREATE INDEX idx_users_membership_level        ON users (membership_level_id);
CREATE INDEX idx_phone_verifications_user      ON phone_verifications (user_id);
CREATE INDEX idx_id_verifications_user         ON id_verifications (user_id);
CREATE INDEX idx_rentals_user                  ON rentals (user_id);              -- ride history (US-22)
CREATE INDEX idx_rentals_bike                  ON rentals (bike_id);
CREATE INDEX idx_reservations_user             ON reservations (user_id);
CREATE INDEX idx_wallet_transactions_wallet    ON wallet_transactions (wallet_id); -- wallet history (US-22)
CREATE INDEX idx_damage_reports_bike           ON damage_reports (bike_id);

-- Unpaid rides are checked before every rental and reservation (US-13).
CREATE INDEX idx_rentals_unpaid
    ON rentals (user_id) WHERE payment_status = 'unpaid';

-- Open damage reports are what the Admin reviews (US-24).
CREATE INDEX idx_damage_reports_open
    ON damage_reports (created_at) WHERE status = 'open';

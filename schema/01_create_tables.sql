-- =====================================================================
-- Smart Bike Rental App - Milestone 2
-- 01_create_tables.sql : tables, primary keys, foreign keys, checks
-- Run on an empty database named smart_bike_rental, before 02 and 03.
-- Tables are created in dependency order (referenced tables first).
-- =====================================================================

-- ---------------------------------------------------------------------
-- membership_levels : level reached by number of completed rides
-- Stories: US-19, US-27
-- ---------------------------------------------------------------------
CREATE TABLE membership_levels (
    membership_level_id SERIAL       PRIMARY KEY,
    name                VARCHAR(50)  NOT NULL UNIQUE,
    min_rides           INT          NOT NULL UNIQUE
                        CHECK (min_rides >= 0)
);

-- ---------------------------------------------------------------------
-- users : every account (Rider, Admin, Company) in one table
-- Stories: US-01, US-03, US-04, US-13, US-19, US-26
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id             SERIAL       PRIMARY KEY,
    username            VARCHAR(50)  NOT NULL UNIQUE,
    password_hash       VARCHAR(255) NOT NULL,          -- never plain text (US-04)
    phone_number        VARCHAR(20)  NOT NULL UNIQUE,
    role                VARCHAR(20)  NOT NULL DEFAULT 'rider'
                        CHECK (role IN ('rider', 'admin', 'company')),
    is_phone_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
    account_status      VARCHAR(20)  NOT NULL DEFAULT 'active'
                        CHECK (account_status IN ('active', 'suspended')),
    -- SET NULL: deleting a level must not delete riders; they simply lose the level.
    membership_level_id INT
                        REFERENCES membership_levels(membership_level_id) ON DELETE SET NULL,
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- phone_verifications : codes sent to a rider's phone
-- Stories: US-02
-- ---------------------------------------------------------------------
CREATE TABLE phone_verifications (
    phone_verification_id SERIAL     PRIMARY KEY,
    -- CASCADE: a code has no meaning without its account.
    user_id               INT        NOT NULL
                          REFERENCES users(user_id) ON DELETE CASCADE,
    code                  VARCHAR(6) NOT NULL,
    sent_at               TIMESTAMP  NOT NULL DEFAULT NOW(),
    expires_at            TIMESTAMP  NOT NULL,
    verified_at           TIMESTAMP,                    -- NULL until the code is confirmed
    CHECK (expires_at > sent_at)
);

-- ---------------------------------------------------------------------
-- id_verifications : one row per national-ID check attempt (retry = new row)
-- Stories: US-05, US-06
-- ---------------------------------------------------------------------
CREATE TABLE id_verifications (
    id_verification_id SERIAL       PRIMARY KEY,
    -- CASCADE: ID data is personal data and is removed with the account.
    user_id            INT          NOT NULL
                       REFERENCES users(user_id) ON DELETE CASCADE,
    national_id_number CHAR(14)     NOT NULL
                       CHECK (national_id_number ~ '^[0-9]{14}$'),
    full_name          VARCHAR(100) NOT NULL,
    id_photo_url       VARCHAR(255) NOT NULL,
    status             VARCHAR(20)  NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'passed', 'failed')),
    failure_reason     VARCHAR(255),                    -- shown when the rider must double-check
    submitted_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- wallets : one in-app wallet per user
-- Stories: US-10, US-11, US-12
-- ---------------------------------------------------------------------
CREATE TABLE wallets (
    wallet_id  SERIAL        PRIMARY KEY,
    -- RESTRICT: an account holding money (and a transaction history) cannot be deleted.
    user_id    INT           NOT NULL UNIQUE
               REFERENCES users(user_id) ON DELETE RESTRICT,
    balance    NUMERIC(10,2) NOT NULL DEFAULT 0
               CHECK (balance >= 0),
    updated_at TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- stations : dock stations shown on the map
-- Capacity is not stored: it is the number of rows in docks for the station.
-- Stories: US-07, US-15, US-25
-- ---------------------------------------------------------------------
CREATE TABLE stations (
    station_id SERIAL       PRIMARY KEY,
    name       VARCHAR(100) NOT NULL UNIQUE,
    latitude   NUMERIC(9,6) NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude  NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    is_active  BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------
-- docks : individual docking slots of a station
-- Stories: US-07, US-14, US-15, US-25
-- ---------------------------------------------------------------------
CREATE TABLE docks (
    dock_id     SERIAL PRIMARY KEY,
    -- CASCADE: docks are part of a station and are removed with it.
    station_id  INT    NOT NULL
                REFERENCES stations(station_id) ON DELETE CASCADE,
    dock_number INT    NOT NULL CHECK (dock_number > 0),
    UNIQUE (station_id, dock_number)
);

-- ---------------------------------------------------------------------
-- bikes : each bike with its unique QR code and live GPS position
-- Stories: US-08, US-09, US-21, US-24, US-25
-- ---------------------------------------------------------------------
CREATE TABLE bikes (
    bike_id             SERIAL       PRIMARY KEY,
    qr_code             VARCHAR(100) NOT NULL UNIQUE,
    status              VARCHAR(20)  NOT NULL DEFAULT 'available'
                        CHECK (status IN ('available', 'reserved', 'in_use', 'out_of_service')),
    -- RESTRICT: a dock that still holds a bike cannot be deleted.
    -- UNIQUE: one dock holds at most one bike. NULL = bike is not docked.
    dock_id             INT          UNIQUE
                        REFERENCES docks(dock_id) ON DELETE RESTRICT,
    current_latitude    NUMERIC(9,6) CHECK (current_latitude  BETWEEN -90  AND 90),
    current_longitude   NUMERIC(9,6) CHECK (current_longitude BETWEEN -180 AND 180),
    location_updated_at TIMESTAMP
);

-- ---------------------------------------------------------------------
-- pricing_rules : price per minute and reservation fee set by an Admin
-- One row per change, so old rentals keep the price they were charged at.
-- The row with the latest effective_from is the current one.
-- Stories: US-11, US-16, US-23, US-27
-- ---------------------------------------------------------------------
CREATE TABLE pricing_rules (
    pricing_rule_id  SERIAL        PRIMARY KEY,
    price_per_minute NUMERIC(8,2)  NOT NULL CHECK (price_per_minute > 0),
    reservation_fee  NUMERIC(8,2)  NOT NULL CHECK (reservation_fee >= 0),
    effective_from   TIMESTAMP     NOT NULL DEFAULT NOW() UNIQUE,
    -- RESTRICT: keep the record of which Admin set each price.
    set_by_user_id   INT           NOT NULL
                     REFERENCES users(user_id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- reservations : 15-minute paid hold on a bike
-- The fee charged is the reservation_fee of the linked pricing rule.
-- Stories: US-16, US-17, US-18
-- ---------------------------------------------------------------------
CREATE TABLE reservations (
    reservation_id  SERIAL      PRIMARY KEY,
    -- RESTRICT (all three): reservations carry fees, so their history is kept.
    user_id         INT         NOT NULL
                    REFERENCES users(user_id) ON DELETE RESTRICT,
    bike_id         INT         NOT NULL
                    REFERENCES bikes(bike_id) ON DELETE RESTRICT,
    pricing_rule_id INT         NOT NULL
                    REFERENCES pricing_rules(pricing_rule_id) ON DELETE RESTRICT,
    reserved_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMP   NOT NULL,               -- reserved_at + 15 minutes
    status          VARCHAR(20) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'used', 'cancelled', 'expired')),
    CHECK (expires_at > reserved_at)
);

-- ---------------------------------------------------------------------
-- rentals : one ride, from QR unlock to docking
-- Duration is not stored: it is docked_at - unlocked_at.
-- Stories: US-08, US-11, US-13, US-14, US-22
-- ---------------------------------------------------------------------
CREATE TABLE rentals (
    rental_id       SERIAL        PRIMARY KEY,
    -- RESTRICT (user, bike, pricing rule, docks): rentals are billing records.
    user_id         INT           NOT NULL
                    REFERENCES users(user_id) ON DELETE RESTRICT,
    bike_id         INT           NOT NULL
                    REFERENCES bikes(bike_id) ON DELETE RESTRICT,
    pricing_rule_id INT           NOT NULL
                    REFERENCES pricing_rules(pricing_rule_id) ON DELETE RESTRICT,
    -- SET NULL: the rental stays valid if the reservation record is removed.
    reservation_id  INT           UNIQUE
                    REFERENCES reservations(reservation_id) ON DELETE SET NULL,
    start_dock_id   INT           NOT NULL
                    REFERENCES docks(dock_id) ON DELETE RESTRICT,
    end_dock_id     INT
                    REFERENCES docks(dock_id) ON DELETE RESTRICT,
    unlocked_at     TIMESTAMP     NOT NULL DEFAULT NOW(),
    docked_at       TIMESTAMP,                          -- NULL while the ride is in progress
    total_cost      NUMERIC(10,2) CHECK (total_cost >= 0),
    payment_status  VARCHAR(20)   NOT NULL DEFAULT 'pending'
                    CHECK (payment_status IN ('pending', 'paid', 'unpaid')),
    CHECK (docked_at IS NULL OR docked_at > unlocked_at),
    -- A ride is finished only when dock, dock time and cost are all recorded.
    CHECK (
        (docked_at IS NULL     AND end_dock_id IS NULL     AND total_cost IS NULL
                               AND payment_status = 'pending')
     OR (docked_at IS NOT NULL AND end_dock_id IS NOT NULL AND total_cost IS NOT NULL
                               AND payment_status IN ('paid', 'unpaid'))
    )
);

-- ---------------------------------------------------------------------
-- wallet_transactions : every movement of money in or out of a wallet
-- Stories: US-10, US-11, US-12, US-16, US-18, US-22
-- ---------------------------------------------------------------------
CREATE TABLE wallet_transactions (
    wallet_transaction_id SERIAL        PRIMARY KEY,
    -- RESTRICT (all three): financial history must never disappear.
    wallet_id             INT           NOT NULL
                          REFERENCES wallets(wallet_id) ON DELETE RESTRICT,
    transaction_type      VARCHAR(30)   NOT NULL
                          CHECK (transaction_type IN
                                ('top_up', 'rental_charge', 'reservation_fee', 'reservation_refund')),
    amount                NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    payment_method        VARCHAR(10)   CHECK (payment_method = 'visa'),   -- Visa only (US-10)
    card_last_four        CHAR(4)       CHECK (card_last_four ~ '^[0-9]{4}$'),
    rental_id             INT
                          REFERENCES rentals(rental_id) ON DELETE RESTRICT,
    reservation_id        INT
                          REFERENCES reservations(reservation_id) ON DELETE RESTRICT,
    created_at            TIMESTAMP     NOT NULL DEFAULT NOW(),
    -- Each type carries exactly the details that belong to it.
    CHECK (
        (transaction_type = 'top_up'
            AND payment_method IS NOT NULL AND card_last_four IS NOT NULL
            AND rental_id IS NULL AND reservation_id IS NULL)
     OR (transaction_type = 'rental_charge'
            AND rental_id IS NOT NULL AND reservation_id IS NULL
            AND payment_method IS NULL AND card_last_four IS NULL)
     OR (transaction_type IN ('reservation_fee', 'reservation_refund')
            AND reservation_id IS NOT NULL AND rental_id IS NULL
            AND payment_method IS NULL AND card_last_four IS NULL)
    )
);

-- ---------------------------------------------------------------------
-- promotions : offers configured by an Admin
-- Stories: US-20, US-27
-- ---------------------------------------------------------------------
CREATE TABLE promotions (
    promotion_id     SERIAL       PRIMARY KEY,
    title            VARCHAR(100) NOT NULL UNIQUE,
    description      VARCHAR(255),
    discount_percent NUMERIC(5,2) NOT NULL
                     CHECK (discount_percent > 0 AND discount_percent <= 100),
    valid_from       DATE         NOT NULL,
    valid_to         DATE         NOT NULL,
    is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
    CHECK (valid_to >= valid_from)
);

-- ---------------------------------------------------------------------
-- promotion_levels : junction table resolving the many-to-many between
-- promotions and membership_levels
-- Stories: US-20, US-27
-- ---------------------------------------------------------------------
CREATE TABLE promotion_levels (
    -- CASCADE (both): a link row is meaningless once either side is deleted.
    promotion_id        INT NOT NULL
                        REFERENCES promotions(promotion_id) ON DELETE CASCADE,
    membership_level_id INT NOT NULL
                        REFERENCES membership_levels(membership_level_id) ON DELETE CASCADE,
    PRIMARY KEY (promotion_id, membership_level_id)
);

-- ---------------------------------------------------------------------
-- damage_reports : rider reports of damaged or faulty bikes, reviewed by Admin
-- Stories: US-21, US-24
-- ---------------------------------------------------------------------
CREATE TABLE damage_reports (
    damage_report_id    SERIAL       PRIMARY KEY,
    -- CASCADE: reports about a bike that was removed from the fleet are no longer needed.
    bike_id             INT          NOT NULL
                        REFERENCES bikes(bike_id) ON DELETE CASCADE,
    -- RESTRICT: keep who reported the damage.
    reported_by_user_id INT          NOT NULL
                        REFERENCES users(user_id) ON DELETE RESTRICT,
    description         TEXT         NOT NULL,
    photo_url           VARCHAR(255) NOT NULL,
    status              VARCHAR(30)  NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open', 'bike_cleared', 'bike_kept_out_of_service')),
    -- SET NULL: the review decision stays even if the Admin account is deleted.
    reviewed_by_user_id INT
                        REFERENCES users(user_id) ON DELETE SET NULL,
    reviewed_at         TIMESTAMP,
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),
    CHECK (status <> 'open' OR (reviewed_by_user_id IS NULL AND reviewed_at IS NULL)),
    CHECK (status = 'open' OR reviewed_at IS NOT NULL)
);

-- =====================================================================
-- Smart Bike Rental App - Milestone 2
-- 03_seed_data.sql : sample rows for testing
-- Run after 01 and 02, on freshly created (empty) tables.
--
-- All values are invented test data. Amounts that the client has not
-- decided yet (price per minute, reservation fee, level thresholds,
-- discounts) are placeholders only.
-- IDs are not typed in: SERIAL generates 1, 2, 3 ... in insert order,
-- and the comments show which ID each row receives.
-- =====================================================================

INSERT INTO membership_levels (name, min_rides) VALUES
    ('Bronze', 0),      -- 1
    ('Silver', 10),     -- 2
    ('Gold',   30);     -- 3

INSERT INTO users (username, password_hash, phone_number, role, is_phone_verified, account_status, membership_level_id) VALUES
    ('admin_one',   '$2b$12$sampleHashAdminOne000000000000000000000000000000000', '+201000000001', 'admin',   TRUE,  'active', NULL),  -- 1
    ('company_one', '$2b$12$sampleHashCompanyOne0000000000000000000000000000000', '+201000000002', 'company', TRUE,  'active', NULL),  -- 2
    ('rider_ali',   '$2b$12$sampleHashRiderAli000000000000000000000000000000000', '+201000000003', 'rider',   TRUE,  'active', 2),     -- 3
    ('rider_sara',  '$2b$12$sampleHashRiderSara00000000000000000000000000000000', '+201000000004', 'rider',   TRUE,  'active', 1),     -- 4
    ('rider_omar',  '$2b$12$sampleHashRiderOmar00000000000000000000000000000000', '+201000000005', 'rider',   TRUE,  'active', 1),     -- 5
    ('rider_new',   '$2b$12$sampleHashRiderNew000000000000000000000000000000000', '+201000000006', 'rider',   FALSE, 'active', NULL);  -- 6

INSERT INTO phone_verifications (user_id, code, sent_at, expires_at, verified_at) VALUES
    (3, '482913', '2026-10-01 09:00:00', '2026-10-01 09:10:00', '2026-10-01 09:01:30'),
    (4, '771204', '2026-10-02 11:15:00', '2026-10-02 11:25:00', '2026-10-02 11:16:10'),
    (5, '305566', '2026-10-03 14:40:00', '2026-10-03 14:50:00', '2026-10-03 14:42:00'),
    (6, '918273', '2026-11-10 08:00:00', '2026-11-10 08:10:00', NULL);              -- not confirmed yet

INSERT INTO id_verifications (user_id, national_id_number, full_name, id_photo_url, status, failure_reason, submitted_at) VALUES
    (3, '30001010100011', 'Ali Hassan',   'https://example.com/ids/3-a.jpg', 'passed', NULL, '2026-10-01 09:05:00'),
    (4, '30102020200022', 'Sara Mahmoud', 'https://example.com/ids/4-a.jpg', 'failed', 'Entered ID number does not match the photo', '2026-10-02 11:20:00'),
    (4, '30102020200023', 'Sara Mahmoud', 'https://example.com/ids/4-b.jpg', 'passed', NULL, '2026-10-02 11:24:00'),  -- retry (US-06)
    (5, '30203030300033', 'Omar Adel',    'https://example.com/ids/5-a.jpg', 'passed', NULL, '2026-10-03 14:45:00');

INSERT INTO wallets (user_id, balance) VALUES
    (3, 80.00),    -- 1
    (4, 45.00),    -- 2
    (5,  3.00),    -- 3  too low to cover the unpaid ride below
    (6,  0.00);    -- 4

INSERT INTO stations (name, latitude, longitude) VALUES
    ('Main Gate',        30.006000, 31.700000),   -- 1
    ('Library',          30.007200, 31.701500),   -- 2
    ('Engineering Hall', 30.008100, 31.699200);   -- 3

INSERT INTO docks (station_id, dock_number) VALUES
    (1, 1), (1, 2), (1, 3), (1, 4),    -- docks 1-4
    (2, 1), (2, 2), (2, 3),            -- docks 5-7
    (3, 1), (3, 2), (3, 3);            -- docks 8-10

INSERT INTO bikes (qr_code, status, dock_id, current_latitude, current_longitude, location_updated_at) VALUES
    ('GIU-BIKE-0001', 'available',      1,    30.006000, 31.700000, '2026-11-10 08:00:00'),  -- 1
    ('GIU-BIKE-0002', 'available',      2,    30.006000, 31.700000, '2026-11-10 08:00:00'),  -- 2
    ('GIU-BIKE-0003', 'available',      5,    30.007200, 31.701500, '2026-11-10 08:00:00'),  -- 3
    ('GIU-BIKE-0004', 'reserved',       8,    30.008100, 31.699200, '2026-11-10 08:00:00'),  -- 4
    ('GIU-BIKE-0005', 'in_use',         NULL, 30.007650, 31.700400, '2026-11-10 08:12:00'),  -- 5  on a ride, not docked
    ('GIU-BIKE-0006', 'out_of_service', 9,    30.008100, 31.699200, '2026-11-10 08:00:00');  -- 6

INSERT INTO pricing_rules (price_per_minute, reservation_fee, effective_from, set_by_user_id) VALUES
    (0.50, 5.00, '2026-10-01 00:00:00', 1),   -- 1  old price
    (0.75, 5.00, '2026-11-01 00:00:00', 1);   -- 2  current price

INSERT INTO reservations (user_id, bike_id, pricing_rule_id, reserved_at, expires_at, status) VALUES
    (3, 1, 1, '2026-10-05 08:50:00', '2026-10-05 09:05:00', 'used'),       -- 1  turned into rental 1
    (4, 2, 1, '2026-10-07 16:00:00', '2026-10-07 16:15:00', 'cancelled'),  -- 2  fee refunded
    (5, 3, 1, '2026-10-08 10:00:00', '2026-10-08 10:15:00', 'expired'),    -- 3  fee kept
    (3, 4, 2, '2026-11-10 08:05:00', '2026-11-10 08:20:00', 'active');     -- 4

INSERT INTO rentals (user_id, bike_id, pricing_rule_id, reservation_id, start_dock_id, end_dock_id, unlocked_at, docked_at, total_cost, payment_status) VALUES
    (3, 1, 1, 1,    5, 1,    '2026-10-05 09:00:00', '2026-10-05 09:20:00', 10.00, 'paid'),     -- 1  20 min x 0.50
    (4, 2, 1, NULL, 8, 2,    '2026-10-06 13:00:00', '2026-10-06 13:30:00', 15.00, 'paid'),     -- 2  30 min x 0.50
    (5, 3, 2, NULL, 3, 5,    '2026-11-03 17:00:00', '2026-11-03 17:40:00', 30.00, 'unpaid'),   -- 3  40 min x 0.75, rider is blocked (US-13)
    (4, 5, 2, NULL, 6, NULL, '2026-11-10 08:10:00', NULL,                  NULL,  'pending');  -- 4  ride in progress

INSERT INTO wallet_transactions (wallet_id, transaction_type, amount, payment_method, card_last_four, rental_id, reservation_id, created_at) VALUES
    (1, 'top_up',             100.00, 'visa', '4242', NULL, NULL, '2026-10-04 20:00:00'),
    (1, 'reservation_fee',      5.00, NULL,   NULL,   NULL, 1,    '2026-10-05 08:50:00'),
    (1, 'rental_charge',       10.00, NULL,   NULL,   1,    NULL, '2026-10-05 09:20:00'),
    (2, 'top_up',              60.00, 'visa', '1111', NULL, NULL, '2026-10-06 12:00:00'),
    (2, 'rental_charge',       15.00, NULL,   NULL,   2,    NULL, '2026-10-06 13:30:00'),
    (2, 'reservation_fee',      5.00, NULL,   NULL,   NULL, 2,    '2026-10-07 16:00:00'),
    (2, 'reservation_refund',   5.00, NULL,   NULL,   NULL, 2,    '2026-10-07 16:05:00'),
    (3, 'top_up',               8.00, 'visa', '5555', NULL, NULL, '2026-10-08 09:55:00'),
    (3, 'reservation_fee',      5.00, NULL,   NULL,   NULL, 3,    '2026-10-08 10:00:00'),
    (1, 'reservation_fee',      5.00, NULL,   NULL,   NULL, 4,    '2026-11-10 08:05:00');
-- Wallet balances above equal the sum of these rows:
--   wallet 1: 100 - 5 - 10 - 5 = 80.00
--   wallet 2:  60 - 15 - 5 + 5 = 45.00
--   wallet 3:   8 - 5          =  3.00

INSERT INTO promotions (title, description, discount_percent, valid_from, valid_to, is_active) VALUES
    ('Welcome Offer',   'Discount for all riders',            5.00,  '2026-10-01', '2026-12-31', TRUE),   -- 1
    ('Silver Saver',    'Discount for Silver and Gold riders', 10.00, '2026-11-01', '2026-12-31', TRUE),   -- 2
    ('Gold Weekend',    'Weekend discount for Gold riders',    20.00, '2026-11-01', '2026-11-30', TRUE);   -- 3

INSERT INTO promotion_levels (promotion_id, membership_level_id) VALUES
    (1, 1), (1, 2), (1, 3),
    (2, 2), (2, 3),
    (3, 3);

INSERT INTO damage_reports (bike_id, reported_by_user_id, description, photo_url, status, reviewed_by_user_id, reviewed_at, created_at) VALUES
    (6, 3, 'Front brake does not work',   'https://example.com/reports/1.jpg', 'bike_kept_out_of_service', 1,    '2026-11-09 10:00:00', '2026-11-09 08:30:00'),
    (2, 4, 'Seat was loose',              'https://example.com/reports/2.jpg', 'bike_cleared',             1,    '2026-10-20 12:00:00', '2026-10-20 09:00:00'),
    (6, 5, 'Chain keeps slipping',        'https://example.com/reports/3.jpg', 'open',                     NULL, NULL,                  '2026-11-10 07:45:00');

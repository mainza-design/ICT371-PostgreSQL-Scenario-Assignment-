-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 6: University Event Seat Booking

DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS events CASCADE;

-- ===== 1. Tables and sample data =====
CREATE TABLE events (
    event_id        SERIAL PRIMARY KEY,
    event_name      VARCHAR(100) NOT NULL,
    available_seats INT NOT NULL CHECK (available_seats >= 0)
);

CREATE TABLE bookings (
    booking_id     SERIAL PRIMARY KEY,
    event_id       INT NOT NULL REFERENCES events(event_id),
    student_number VARCHAR(20) NOT NULL,
    seats          INT NOT NULL CHECK (seats > 0),
    status         VARCHAR(10) NOT NULL DEFAULT 'BOOKED'
                   CHECK (status IN ('BOOKED','CANCELLED')),
    booked_on      DATE NOT NULL DEFAULT CURRENT_DATE
);

INSERT INTO events (event_name, available_seats) VALUES
    ('Career Fair', 50),
    ('Tech Talk', 8),
    ('Sports Day', 0),
    ('Open Day', 200);

SELECT * FROM events ORDER BY event_id;

-- ===== 2. IF / ELSIF / ELSE seat report (nearly full = 10 or fewer) =====
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT event_name, available_seats FROM events ORDER BY event_id LOOP
        IF r.available_seats = 0 THEN
            RAISE NOTICE '% -> FULL', r.event_name;
        ELSIF r.available_seats <= 10 THEN
            RAISE NOTICE '% -> NEARLY FULL (% seats left)', r.event_name, r.available_seats;
        ELSE
            RAISE NOTICE '% -> PLENTY of seats (%)', r.event_name, r.available_seats;
        END IF;
    END LOOP;
END $$;

-- ===== 3. WHILE and numeric FOR =====
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Booking reminder day: %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Entrance check number: %', i;
    END LOOP;
END $$;

-- ===== 4. book_seats procedure =====
CREATE OR REPLACE PROCEDURE book_seats(p_event_id INT, p_student VARCHAR, p_seats INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_seats IS NULL OR p_seats <= 0 THEN
        RAISE EXCEPTION 'Invalid number of seats: % (must be greater than zero)', p_seats
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT available_seats INTO v_available
    FROM events WHERE event_id = p_event_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Event % does not exist', p_event_id;
    END IF;

    IF v_available < p_seats THEN
        RAISE EXCEPTION 'Not enough seats for event %: requested %, remaining %',
            p_event_id, p_seats, v_available;
    END IF;

    UPDATE events SET available_seats = available_seats - p_seats WHERE event_id = p_event_id;
    INSERT INTO bookings (event_id, student_number, seats) VALUES (p_event_id, p_student, p_seats);

    RAISE NOTICE 'Booked % seat(s) at event % for student %', p_seats, p_event_id, p_student;
END $$;

-- ===== 5. Two valid bookings and one exceeding remaining seats =====
CALL book_seats(1, '2024001', 4);   -- valid
CALL book_seats(2, '2024002', 3);   -- valid

DO $$
BEGIN
    CALL book_seats(2, '2024003', 20);   -- exceeds remaining seats
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Booking rejected: %', SQLERRM;
END $$;

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- ===== 6. cancel_booking procedure (idempotent) =====
CREATE OR REPLACE PROCEDURE cancel_booking(p_booking_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event  INT;
    v_seats  INT;
    v_status VARCHAR;
BEGIN
    SELECT event_id, seats, status INTO v_event, v_seats, v_status
    FROM bookings WHERE booking_id = p_booking_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking % does not exist', p_booking_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE NOTICE 'Booking % already cancelled; seats not released again.', p_booking_id;
        RETURN;
    END IF;

    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
    UPDATE events SET available_seats = available_seats + v_seats WHERE event_id = v_event;
    RAISE NOTICE 'Booking % cancelled; % seat(s) released.', p_booking_id, v_seats;
END $$;

CALL cancel_booking(1);   -- releases seats
CALL cancel_booking(1);   -- must not release again

SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- ===== 7. Explicit cursor: full or nearly full events =====
DO $$
DECLARE
    cur_events CURSOR FOR
        SELECT event_name, available_seats FROM events
        WHERE available_seats <= 10 ORDER BY available_seats, event_name;
    rec RECORD;
BEGIN
    OPEN cur_events;
    LOOP
        FETCH cur_events INTO rec;
        EXIT WHEN NOT FOUND;
        IF rec.available_seats = 0 THEN
            RAISE NOTICE 'Event % is FULL', rec.event_name;
        ELSE
            RAISE NOTICE 'Event % is NEARLY FULL (% seats)', rec.event_name, rec.available_seats;
        END IF;
    END LOOP;
    CLOSE cur_events;
END $$;

-- ===== 8. Zero seats handled with EXCEPTION =====
DO $$
BEGIN
    CALL book_seats(1, '2024004', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled invalid quantity: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- ===== 9. Final results =====
SELECT * FROM events ORDER BY event_id;
SELECT * FROM bookings ORDER BY booking_id;

-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation

DROP TABLE IF EXISTS allocations CASCADE;
DROP TABLE IF EXISTS hostel_rooms CASCADE;

-- ===== 1. Tables and sample data =====
CREATE TABLE hostel_rooms (
    room_id          SERIAL PRIMARY KEY,
    room_name        VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id  SERIAL PRIMARY KEY,
    room_id        INT NOT NULL REFERENCES hostel_rooms(room_id),
    student_number VARCHAR(20) NOT NULL,
    status         VARCHAR(12) NOT NULL DEFAULT 'ALLOCATED'
                   CHECK (status IN ('ALLOCATED','COMPLETE')),
    allocated_on   DATE NOT NULL DEFAULT CURRENT_DATE
);

INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
    ('A101', 2),
    ('B202', 1),
    ('C303', 0),
    ('D404', 4);

SELECT * FROM hostel_rooms ORDER BY room_id;

-- ===== 2. IF / ELSIF / ELSE room report =====
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF r.available_spaces = 0 THEN
            RAISE NOTICE 'Room % is FULL', r.room_name;
        ELSIF r.available_spaces = 1 THEN
            RAISE NOTICE 'Room % has ONE space left', r.room_name;
        ELSE
            RAISE NOTICE 'Room % has SEVERAL spaces (%)', r.room_name, r.available_spaces;
        END IF;
    END LOOP;
END $$;

-- ===== 3. WHILE and numeric FOR =====
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day: %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check number: %', i;
    END LOOP;
END $$;

-- ===== 4. allocate_room procedure =====
CREATE OR REPLACE PROCEDURE allocate_room(p_room_id INT, p_student VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student IS NULL OR btrim(p_student) = '' THEN
        RAISE EXCEPTION 'Student number cannot be blank'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT available_spaces INTO v_spaces
    FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room % does not exist', p_room_id;
    END IF;

    IF v_spaces < 1 THEN
        RAISE EXCEPTION 'Room % is full; no space available', p_room_id;
    END IF;

    UPDATE hostel_rooms SET available_spaces = available_spaces - 1 WHERE room_id = p_room_id;
    INSERT INTO allocations (room_id, student_number) VALUES (p_room_id, btrim(p_student));

    RAISE NOTICE 'Student % allocated to room %', p_student, p_room_id;
END $$;

-- ===== 5. Two valid allocations and one to a full room =====
CALL allocate_room(1, '2024001');   -- valid
CALL allocate_room(2, '2024002');   -- valid

DO $$
BEGIN
    CALL allocate_room(3, '2024003');   -- room C303 is full
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Allocation rejected: %', SQLERRM;
END $$;

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- ===== 6. check_out procedure (idempotent) =====
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room   INT;
    v_status VARCHAR;
BEGIN
    SELECT room_id, status INTO v_room, v_status
    FROM allocations WHERE allocation_id = p_allocation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Allocation % does not exist', p_allocation_id;
    END IF;

    IF v_status = 'COMPLETE' THEN
        RAISE NOTICE 'Allocation % already checked out; no space freed.', p_allocation_id;
        RETURN;
    END IF;

    UPDATE allocations SET status = 'COMPLETE' WHERE allocation_id = p_allocation_id;
    UPDATE hostel_rooms SET available_spaces = available_spaces + 1 WHERE room_id = v_room;
    RAISE NOTICE 'Allocation % checked out; one space freed in room %.', p_allocation_id, v_room;
END $$;

CALL check_out(1);   -- frees a space
CALL check_out(1);   -- must not free another

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- ===== 7. Explicit cursor: full or nearly full rooms =====
DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_name, available_spaces FROM hostel_rooms
        WHERE available_spaces <= 1 ORDER BY available_spaces, room_name;
    rec RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO rec;
        EXIT WHEN NOT FOUND;
        IF rec.available_spaces = 0 THEN
            RAISE NOTICE 'Room % is FULL', rec.room_name;
        ELSE
            RAISE NOTICE 'Room % is NEARLY FULL (% space)', rec.room_name, rec.available_spaces;
        END IF;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- ===== 8. Blank student number handled with EXCEPTION =====
DO $$
BEGIN
    CALL allocate_room(4, '   ');
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled invalid input: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- ===== 9. Final results =====
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

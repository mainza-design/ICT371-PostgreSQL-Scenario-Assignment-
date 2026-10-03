-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing

DROP TABLE IF EXISTS dispensing_records CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;

-- ===== 1. Tables and sample data =====
CREATE TABLE medicines (
    medicine_id    SERIAL PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(10) NOT NULL DEFAULT 'DISPENSED'
                   CHECK (status IN ('DISPENSED','REVERSED')),
    dispensed_on   DATE NOT NULL DEFAULT CURRENT_DATE
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol', 100),
    ('Amoxicillin', 15),
    ('Ibuprofen', 0),
    ('Oral Rehydration Salts', 50);

SELECT * FROM medicines ORDER BY medicine_id;

-- ===== 2. IF / ELSIF / ELSE stock report (low stock = 20 or fewer) =====
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF r.stock_quantity = 0 THEN
            RAISE NOTICE '% -> OUT OF STOCK', r.medicine_name;
        ELSIF r.stock_quantity <= 20 THEN
            RAISE NOTICE '% -> LOW on stock (%)', r.medicine_name, r.stock_quantity;
        ELSE
            RAISE NOTICE '% -> SUFFICIENTLY stocked (%)', r.medicine_name, r.stock_quantity;
        END IF;
    END LOOP;
END $$;

-- ===== 3. WHILE and numeric FOR =====
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Stock review day: %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number: %', i;
    END LOOP;
END $$;

-- ===== 4. dispense_medicine procedure =====
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid dispensing quantity: % (must be greater than zero)', p_qty
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Medicine % does not exist', p_medicine_id;
    END IF;

    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Insufficient stock for medicine %: requested %, in stock %',
            p_medicine_id, p_qty, v_stock;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity - p_qty WHERE medicine_id = p_medicine_id;
    INSERT INTO dispensing_records (medicine_id, student_number, quantity)
    VALUES (p_medicine_id, p_student, p_qty);

    RAISE NOTICE 'Dispensed % unit(s) of medicine % to student %', p_qty, p_medicine_id, p_student;
END $$;

-- ===== 5. Two valid dispenses and one exceeding stock =====
CALL dispense_medicine(1, '2024001', 10);   -- valid
CALL dispense_medicine(2, '2024002', 5);    -- valid

DO $$
BEGIN
    CALL dispense_medicine(2, '2024003', 50);   -- exceeds stock
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Dispensing rejected: %', SQLERRM;
END $$;

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- ===== 6. reverse_dispensing procedure (stock restored only once) =====
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_med    INT;
    v_qty    INT;
    v_status VARCHAR;
BEGIN
    SELECT medicine_id, quantity, status INTO v_med, v_qty, v_status
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Dispensing record % does not exist', p_record_id;
    END IF;

    IF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed; stock not restored again.', p_record_id;
        RETURN;
    END IF;

    UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
    UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_med;
    RAISE NOTICE 'Record % reversed; % unit(s) restored.', p_record_id, v_qty;
END $$;

CALL reverse_dispensing(1);   -- restores stock
CALL reverse_dispensing(1);   -- no further stock restored

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- ===== 7. Explicit cursor with a low-stock threshold parameter =====
DO $$
DECLARE
    cur_low CURSOR (p_threshold INT) FOR
        SELECT medicine_id, medicine_name, stock_quantity FROM medicines
        WHERE stock_quantity < p_threshold ORDER BY stock_quantity;
    rec RECORD;
BEGIN
    OPEN cur_low(20);   -- threshold = 20
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below threshold: [%] % - % in stock', rec.medicine_id, rec.medicine_name, rec.stock_quantity;
    END LOOP;
    CLOSE cur_low;
END $$;

-- ===== 8. Negative quantity handled with EXCEPTION =====
DO $$
BEGIN
    CALL dispense_medicine(1, '2024004', -5);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled invalid input: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- ===== 9. Final results =====
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans

-- ===== Clean start =====
DROP TABLE IF EXISTS book_loans CASCADE;
DROP TABLE IF EXISTS books CASCADE;

-- ===== 1. Tables and sample data =====
CREATE TABLE books (
    book_id          SERIAL PRIMARY KEY,
    title            VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id        SERIAL PRIMARY KEY,
    book_id        INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(20) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    loan_status    VARCHAR(10) NOT NULL DEFAULT 'BORROWED'
                   CHECK (loan_status IN ('BORROWED','RETURNED')),
    loan_date      DATE NOT NULL DEFAULT CURRENT_DATE
);

INSERT INTO books (title, available_copies) VALUES
    ('Database Systems', 5),
    ('Computer Networks', 2),
    ('Operating Systems', 0),
    ('Software Engineering', 8);

SELECT * FROM books ORDER BY book_id;

-- ===== 2. IF / ELSIF / ELSE stock report =====
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT title, available_copies FROM books ORDER BY book_id LOOP
        IF r.available_copies = 0 THEN
            RAISE NOTICE '% -> UNAVAILABLE (% copies)', r.title, r.available_copies;
        ELSIF r.available_copies <= 3 THEN
            RAISE NOTICE '% -> LOW on copies (% left)', r.title, r.available_copies;
        ELSE
            RAISE NOTICE '% -> SUFFICIENTLY stocked (% copies)', r.title, r.available_copies;
        END IF;
    END LOOP;
END $$;

-- ===== 3. WHILE loop and numeric FOR loop =====
DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number: %', n;
        n := n + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', i;
    END LOOP;
END $$;

-- ===== 4. borrow_book procedure =====
CREATE OR REPLACE PROCEDURE borrow_book(p_book_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_copies INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_qty
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT available_copies INTO v_copies
    FROM books WHERE book_id = p_book_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book % does not exist', p_book_id;
    END IF;

    IF v_copies < p_qty THEN
        RAISE EXCEPTION 'Insufficient copies for book %: requested %, available %',
            p_book_id, p_qty, v_copies;
    END IF;

    UPDATE books SET available_copies = available_copies - p_qty WHERE book_id = p_book_id;
    INSERT INTO book_loans (book_id, student_number, quantity)
    VALUES (p_book_id, p_student, p_qty);

    RAISE NOTICE 'Loan recorded: student % borrowed % copy(ies) of book %', p_student, p_qty, p_book_id;
END $$;

-- ===== 5. Two valid loans and one request exceeding stock =====
CALL borrow_book(1, '2024001', 2);   -- valid
CALL borrow_book(2, '2024002', 1);   -- valid

DO $$
BEGIN
    CALL borrow_book(2, '2024003', 5);   -- exceeds available copies
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Loan rejected: %', SQLERRM;
END $$;

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- ===== 6. return_book procedure (idempotent) =====
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book   INT;
    v_qty    INT;
    v_status VARCHAR;
BEGIN
    SELECT book_id, quantity, loan_status INTO v_book, v_qty, v_status
    FROM book_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist', p_loan_id;
    END IF;

    IF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % was already returned; no copies restored.', p_loan_id;
        RETURN;
    END IF;

    UPDATE book_loans SET loan_status = 'RETURNED' WHERE loan_id = p_loan_id;
    UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book;
    RAISE NOTICE 'Loan % returned; % copy(ies) restored.', p_loan_id, v_qty;
END $$;

CALL return_book(1);   -- first call restores copies
CALL return_book(1);   -- second call restores nothing

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- ===== 7. Explicit cursor: books with few copies remaining =====
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT book_id, title, available_copies FROM books
        WHERE available_copies <= 3 ORDER BY available_copies;
    rec RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies: [%] % - % left', rec.book_id, rec.title, rec.available_copies;
    END LOOP;
    CLOSE cur_low;
END $$;

-- ===== 8. Invalid quantity (zero) handled with EXCEPTION =====
DO $$
BEGIN
    CALL borrow_book(1, '2024004', 0);
EXCEPTION
    WHEN invalid_parameter_value THEN
        RAISE NOTICE 'Handled invalid quantity: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- ===== 9. Final results =====
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

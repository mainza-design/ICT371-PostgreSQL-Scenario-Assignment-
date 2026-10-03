# ICT371 PostgreSQL Scenario Assignment

**Course:** ICT371
**Student number:** 202406802 
 
## Scenarios completed

| File | Scenario | Tables | Procedures |
|------|----------|--------|------------|
| `scenario_1_STUDENTNO.sql` | 1. University Library Book Loans | `books`, `book_loans` | `borrow_book`, `return_book` |
| `scenario_3_STUDENTNO.sql` | 3. Student Hostel Room Allocation | `hostel_rooms`, `allocations` | `allocate_room`, `check_out` |
| `scenario_4_STUDENTNO.sql` | 4. Campus Clinic Medicine Dispensing | `medicines`, `dispensing_records` | `dispense_medicine`, `reverse_dispensing` |
| `scenario_6_STUDENTNO.sql` | 6. University Event Seat Booking | `events`, `bookings` | `book_seats`, `cancel_booking` |

## Requirements

- PostgreSQL 11 or later (procedures and `CALL` are used)
- pgAdmin 4 (Query Tool) or `psql`

## How to run

**pgAdmin**
1. Create or select a database (for example `ict371`).
2. Open **Tools > Query Tool** and open one `.sql` file.
3. Press **F5** to run the whole script.
4. Read the printed messages in the **Messages** tab and the query results in the **Data Output** tab.

**psql**
```bash
psql -U postgres -d ict371 -f scenario_1_STUDENTNO.sql
```

Each script drops and recreates its own tables first, so it can be re-run safely. The four scripts use different table names and do not interfere with each other.

## Structure of every script

Every file follows the same nine tasks from the assignment sheet:

1. Create the tables and insert at least three sample rows (each script inserts four).
2. `IF / ELSIF / ELSE` stock or capacity report.
3. `WHILE` loop (three reminders or days) and numeric `FOR` loop (three checks).
4. Main procedure: validates the input, checks stock, reduces it and records the transaction.
5. Two valid calls and one call exceeding stock or capacity, then query both tables.
6. Reversal procedure, called twice on the same record.
7. Explicit cursor (`OPEN`, `FETCH`, `CLOSE`) listing low-stock items.
8. Invalid input handled in an `EXCEPTION` block.
9. Final queries on both tables.

## Design notes

- **Row locking:** procedures use `SELECT ... FOR UPDATE` so concurrent sessions cannot oversell stock.
- **Idempotent reversals:** the return, check-out, reverse and cancel procedures check the record's status first. A second call prints a notice and changes nothing.
- **Rejected requests:** a failed request raises an exception, so nothing is recorded and stock is unchanged. The scripts catch the error in a `DO` block so execution continues.
- **Invalid input:** raised with `ERRCODE = invalid_parameter_value` and caught specifically in task 8.
- **Constraints:** `CHECK` constraints prevent negative stock and invalid statuses.

## Thresholds used

| Scenario | Threshold |
|----------|-----------|
| 1 Library | 0 = unavailable, 1 to 3 = low, above 3 = sufficient (cursor: 3 or fewer) |
| 3 Hostel | 0 = full, 1 = one space left, above 1 = several (cursor: 1 or fewer) |
| 4 Clinic | 0 = out of stock, 1 to 20 = low, above 20 = sufficient (cursor: below 20) |
| 6 Events | 0 = full, 1 to 10 = nearly full, above 10 = plenty (cursor: 10 or fewer) |

## Expected final state (task 9)

**Scenario 1:** Database Systems 5, Computer Networks 1, Operating Systems 0, Software Engineering 8. Loan 1 is `RETURNED`, loan 2 is `BORROWED`. The over-limit request is not recorded.

**Scenario 3:** A101 has 2 spaces, B202 0, C303 0, D404 4. Allocation 1 is `COMPLETE`, allocation 2 is `ALLOCATED`. The full-room request is not recorded.

**Scenario 4:** Paracetamol 100, Amoxicillin 10, Ibuprofen 0, Oral Rehydration Salts 50. Record 1 is `REVERSED`, record 2 is `DISPENSED`. The over-stock request is not recorded.

**Scenario 6:** Career Fair 50, Tech Talk 5, Sports Day 0, Open Day 200. Booking 1 is `CANCELLED`, booking 2 is `BOOKED`. The over-limit request is not recorded.



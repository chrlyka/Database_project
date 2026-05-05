-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 05, 2026 at 02:28 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `hospital`
--

-- --------------------------------------------------------

--
-- Table structure for table `admin_staff`
--

CREATE TABLE `admin_staff` (
  `AMKA` char(11) NOT NULL,
  `role` varchar(30) NOT NULL,
  `office` varchar(50) NOT NULL,
  `department_name` varchar(50) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `admin_staff_works_shift`
--

CREATE TABLE `admin_staff_works_shift` (
  `admin_staff_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL
) ;

--
-- Triggers `admin_staff_works_shift`
--
DELIMITER $$
CREATE TRIGGER `trg_admin_works_shift_8` BEFORE INSERT ON `admin_staff_works_shift` FOR EACH ROW BEGIN
    DECLARE v_shift_date DATE;
    DECLARE v_shift_type VARCHAR(50);

    SELECT s.date, s.type
    INTO   v_shift_date, v_shift_type
    FROM   Shift s
    WHERE  s.id = NEW.shift_id;

    IF EXISTS (
        SELECT 1
        FROM Admin_Staff_Works_Shift aws
        JOIN Shift s_old ON aws.shift_id = s_old.id
        WHERE aws.admin_staff_amka = NEW.admin_staff_amka
          AND (
              (v_shift_type = 'afternoon' AND s_old.type = 'morning'   AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'night'     AND s_old.type = 'afternoon' AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'morning'   AND s_old.type = 'night'     AND s_old.date = DATE_SUB(v_shift_date, INTERVAL 1 DAY))
          )
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '8-hour rest rule violated. Staff cannot work consecutive shifts.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_max_monthly_shifts_admin` BEFORE INSERT ON `admin_staff_works_shift` FOR EACH ROW BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM Admin_Staff_Works_Shift aws
    JOIN Shift s  ON s.id  = aws.shift_id
    JOIN Shift sn ON sn.id = NEW.shift_id
    WHERE aws.admin_staff_amka = NEW.admin_staff_amka
      AND YEAR(s.date)  = YEAR(sn.date)
      AND MONTH(s.date) = MONTH(sn.date);
 
    IF v_count >= 25 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Admin staff has reached the maximum of 25 shifts this month.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_admin_double_shift` BEFORE INSERT ON `admin_staff_works_shift` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Admin_Staff_Works_Shift aws
    JOIN Shift s_existing ON s_existing.id = aws.shift_id
    JOIN Shift s_new      ON s_new.id      = NEW.shift_id
    WHERE aws.admin_staff_amka = NEW.admin_staff_amka
      AND s_existing.date = s_new.date
      AND s_existing.type = s_new.type
      AND aws.shift_id   <> NEW.shift_id;
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Admin staff is already assigned to a shift at this date and time slot.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_delete_closed_shift_admin` BEFORE DELETE ON `admin_staff_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = OLD.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot remove admin staff: shift is already closed.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_insert_closed_shift_admin` BEFORE INSERT ON `admin_staff_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = NEW.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot add admin staff: shift is already closed.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `bed`
--

CREATE TABLE `bed` (
  `number` int(11) NOT NULL,
  `bed_type` varchar(50) NOT NULL,
  `bed_status` varchar(20) NOT NULL DEFAULT 'available',
  `department_name` varchar(50) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `cost`
--

CREATE TABLE `cost` (
  `KEN_code` varchar(5) NOT NULL,
  `average_hospitalization_duration` smallint(5) UNSIGNED NOT NULL,
  `basic_cost` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `department`
--

CREATE TABLE `department` (
  `name` varchar(50) NOT NULL,
  `description` varchar(200) NOT NULL,
  `number_of_beds` int(11) NOT NULL,
  `floor` varchar(20) NOT NULL,
  `building` varchar(50) NOT NULL,
  `doctor_amka` char(11) NOT NULL
) ;

--
-- Triggers `department`
--
DELIMITER $$
CREATE TRIGGER `trg_department_head_must_be_director_insert` BEFORE INSERT ON `department` FOR EACH ROW BEGIN
    DECLARE v_rank VARCHAR(50);
    SELECT rank INTO v_rank
    FROM Doctor
    WHERE AMKA = NEW.doctor_amka;
 
    IF v_rank IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Department head must be a doctor (AMKA not found in Doctor table).';
    END IF;
 
    IF v_rank <> 'director' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Department head must be a doctor with rank director.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_department_head_must_be_director_update` BEFORE UPDATE ON `department` FOR EACH ROW BEGIN
    DECLARE v_rank VARCHAR(50);
    IF NOT (NEW.doctor_amka <=> OLD.doctor_amka) THEN        
	SELECT rank INTO v_rank
        FROM Doctor
        WHERE AMKA = NEW.doctor_amka;
 
        IF v_rank IS NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Department head must be a doctor (AMKA not found in Doctor table).';
        END IF;
 
        IF v_rank <> 'director' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Department head must be a doctor with rank director.';
        END IF;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `diagnosis`
--

CREATE TABLE `diagnosis` (
  `code` varchar(8) NOT NULL,
  `description` text NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `doctor`
--

CREATE TABLE `doctor` (
  `AMKA` char(11) NOT NULL,
  `license_number` varchar(50) NOT NULL,
  `specialty` varchar(100) NOT NULL,
  `rank` varchar(50) NOT NULL,
  `supervisor_AMKA` char(11) DEFAULT NULL
) ;

--
-- Triggers `doctor`
--
DELIMITER $$
CREATE TRIGGER `trg_director_no_supervisor_insert` BEFORE INSERT ON `doctor` FOR EACH ROW BEGIN
    IF NEW.rank = 'director' AND NEW.supervisor_AMKA IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A director cannot have a supervisor.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_director_no_supervisor_update` BEFORE UPDATE ON `doctor` FOR EACH ROW BEGIN
    IF NEW.rank = 'director' AND NEW.supervisor_AMKA IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A director cannot have a supervisor.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_intern_needs_supervisor_insert` BEFORE INSERT ON `doctor` FOR EACH ROW BEGIN
    IF NEW.rank = 'intern' AND (NEW.supervisor_AMKA IS NULL OR NEW.supervisor_AMKA = '') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'An intern must have a supervisor.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_intern_needs_supervisor_update` BEFORE UPDATE ON `doctor` FOR EACH ROW BEGIN
    IF NEW.rank = 'intern' AND (NEW.supervisor_AMKA IS NULL OR NEW.supervisor_AMKA = '') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'An intern must have a supervisor.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_circular_supervision_insert` BEFORE INSERT ON `doctor` FOR EACH ROW BEGIN
    DECLARE v_current CHAR(11);
    DECLARE v_steps   INT DEFAULT 0;
 
    SET v_current = NEW.supervisor_AMKA;
 
    WHILE v_current IS NOT NULL AND v_steps < 100 DO
        IF v_current = NEW.AMKA THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Circular supervision chain detected.';
        END IF;
        SELECT supervisor_AMKA INTO v_current
        FROM Doctor
        WHERE AMKA = v_current;
        SET v_steps = v_steps + 1;
    END WHILE;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_circular_supervision_update` BEFORE UPDATE ON `doctor` FOR EACH ROW BEGIN
    DECLARE v_current CHAR(11);
    DECLARE v_steps   INT DEFAULT 0;

    IF NOT (NEW.supervisor_AMKA <=> OLD.supervisor_AMKA) THEN

        SET v_current = NEW.supervisor_AMKA;

        WHILE v_current IS NOT NULL AND v_steps < 100 DO
            IF v_current = NEW.AMKA THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Circular supervision chain detected.';
            END IF;

            SELECT supervisor_AMKA INTO v_current
            FROM Doctor
            WHERE AMKA = v_current;

            SET v_steps = v_steps + 1;
        END WHILE;

    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_prevent_head_demotion` BEFORE UPDATE ON `doctor` FOR EACH ROW BEGIN
    DECLARE v_is_head INT DEFAULT 0;
 
    IF OLD.rank = 'director' AND NEW.rank <> 'director' THEN
        SELECT COUNT(*) INTO v_is_head
        FROM Department
        WHERE doctor_amka = OLD.AMKA;
 
        IF v_is_head > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot change rank: this doctor is currently heading a department.';
        END IF;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `doctor_works_department`
--

CREATE TABLE `doctor_works_department` (
  `doctor_amka` char(11) NOT NULL,
  `department_name` varchar(50) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `doctor_works_shift`
--

CREATE TABLE `doctor_works_shift` (
  `doctor_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL
) ;

--
-- Triggers `doctor_works_shift`
--
DELIMITER $$
CREATE TRIGGER `trg_consecutive_nights` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_night_cnt INT DEFAULT 0;
    DECLARE v_shift_date DATE;
    DECLARE v_shift_type VARCHAR(50);

    SELECT date, type INTO v_shift_date, v_shift_type
    FROM Shift
    WHERE id = NEW.shift_id;

       IF v_shift_type = 'night' THEN
        
        
        SELECT COUNT(*) INTO v_night_cnt
        FROM Doctor_Works_Shift dws
        JOIN Shift s ON dws.shift_id = s.id
        WHERE dws.doctor_amka = NEW.doctor_amka
          AND s.type = 'night'
          AND s.date IN (
                DATE_SUB(v_shift_date, INTERVAL 1 DAY), 
                DATE_SUB(v_shift_date, INTERVAL 2 DAY), 
                DATE_SUB(v_shift_date, INTERVAL 3 DAY)
              );

        IF v_night_cnt = 3 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A doctor cannot work more than 3 consecutive night shifts.';
        END IF;
        
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_doctor_works_shift_8` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_shift_date DATE;
    DECLARE v_shift_type VARCHAR(50);

    SELECT s.date, s.type
    INTO   v_shift_date, v_shift_type
    FROM   Shift s
    WHERE  s.id = NEW.shift_id;

    IF EXISTS (
        SELECT 1
        FROM Doctor_Works_Shift dws
        JOIN Shift s_old ON dws.shift_id = s_old.id
        WHERE dws.doctor_amka = NEW.doctor_amka
          AND (
              (v_shift_type = 'afternoon' AND s_old.type = 'morning'   AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'night'     AND s_old.type = 'afternoon' AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'morning'   AND s_old.type = 'night'     AND s_old.date = DATE_SUB(v_shift_date, INTERVAL 1 DAY))
          )
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '8-hour rest rule violated. Doctor cannot work consecutive shifts.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_intern_shift_needs_senior` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_is_intern  INT DEFAULT 0;
    DECLARE v_has_senior INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_is_intern
    FROM Doctor d
    WHERE d.AMKA = NEW.doctor_amka
      AND d.rank = 'intern';
 
    IF v_is_intern > 0 THEN
        SELECT COUNT(*) INTO v_has_senior
        FROM Doctor_Works_Shift dws
        JOIN Doctor d ON d.AMKA = dws.doctor_amka
        WHERE dws.shift_id = NEW.shift_id
          AND d.rank IN ('supervisor A', 'director');
 
        IF v_has_senior = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A shift with an intern must include at least one Supervisor A or Director.';
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_max_monthly_shifts_doctor` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM Doctor_Works_Shift dws
    JOIN Shift s ON s.id = dws.shift_id
    JOIN Shift sn ON sn.id = NEW.shift_id
    WHERE dws.doctor_amka = NEW.doctor_amka
      AND YEAR(s.date)  = YEAR(sn.date)
      AND MONTH(s.date) = MONTH(sn.date);
 
    IF v_count >= 15 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor has reached the maximum of 15 shifts this month.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_delete_closed_shift_doctor` BEFORE DELETE ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = OLD.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot remove doctor: shift is already closed.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_doctor_double_shift` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Doctor_Works_Shift dws
    JOIN Shift s_existing ON s_existing.id = dws.shift_id
    JOIN Shift s_new      ON s_new.id      = NEW.shift_id
    WHERE dws.doctor_amka = NEW.doctor_amka
      AND s_existing.date = s_new.date
      AND s_existing.type = s_new.type
      AND dws.shift_id   <> NEW.shift_id;
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is already assigned to a shift at this date and time slot.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_insert_closed_shift_doctor` BEFORE INSERT ON `doctor_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = NEW.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot add doctor: shift is already closed.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `drug`
--

CREATE TABLE `drug` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `substance_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `emergency_contact`
--

CREATE TABLE `emergency_contact` (
  `patient_amka` char(11) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `name` varchar(100) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `evaluation`
--

CREATE TABLE `evaluation` (
  `id` int(11) NOT NULL,
  `medical_care_score` smallint(5) UNSIGNED DEFAULT NULL,
  `nursing_care_score` smallint(5) UNSIGNED DEFAULT NULL,
  `cleanliness_score` smallint(5) UNSIGNED DEFAULT NULL,
  `food_score` smallint(5) UNSIGNED DEFAULT NULL,
  `overall_experience_score` smallint(5) UNSIGNED DEFAULT NULL,
  `hospitalization_id` int(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `doctor_amka` char(11) DEFAULT NULL
) ;

--
-- Triggers `evaluation`
--
DELIMITER $$
CREATE TRIGGER `trg_eval_doctor_prescribed` BEFORE INSERT ON `evaluation` FOR EACH ROW BEGIN
    DECLARE v_count INT DEFAULT 0;

    IF NEW.doctor_amka IS NOT NULL THEN
        SELECT COUNT(*) INTO v_count
        FROM Prescription p
        JOIN Hospitalization h ON h.patient_amka = p.patient_amka
        WHERE h.id          = NEW.hospitalization_id
          AND p.doctor_amka = NEW.doctor_amka
          AND p.patient_amka = NEW.patient_amka
          AND p.start_date  >= h.admission_date
          AND p.start_date  <= h.discharge_date;

        IF v_count = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot evaluate: this doctor did not prescribe to this patient during this hospitalization.';
        END IF;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_evaluation_bi` BEFORE INSERT ON `evaluation` FOR EACH ROW BEGIN
    DECLARE v_discharge    DATE;
    DECLARE v_hosp_patient CHAR(11);
 
    SELECT discharge_date, patient_amka
    INTO   v_discharge, v_hosp_patient
    FROM   Hospitalization
    WHERE  id = NEW.hospitalization_id;
 
    IF v_discharge IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error [Evaluation INSERT]: Evaluations can only be submitted after discharge (hospitalization not yet completed).';
    END IF;
 	
	IF v_discharge > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot evaluate: discharge date is in the future.';
    END IF;

        IF v_hosp_patient != NEW.patient_amka THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error [Evaluation INSERT]: The evaluating patient does not match the hospitalization record.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `hospitalization`
--

CREATE TABLE `hospitalization` (
  `id` int(11) NOT NULL,
  `admission_date` date NOT NULL,
  `discharge_date` date DEFAULT NULL,
  `total_cost` decimal(10,2) DEFAULT NULL,
  `triage_id` int(11) NOT NULL,
  `bed_number` int(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  `cost_KEN_code` varchar(5) NOT NULL,
  `in_diagnosis_code` varchar(8) NOT NULL,
  `out_diagnosis_code` varchar(8) DEFAULT NULL
) ;

--
-- Triggers `hospitalization`
--
DELIMITER $$
CREATE TRIGGER `trg_bed_available_on_discharge` AFTER UPDATE ON `hospitalization` FOR EACH ROW BEGIN
    IF OLD.discharge_date IS NULL AND NEW.discharge_date IS NOT NULL THEN
        UPDATE Bed
        SET bed_status = 'available'
        WHERE number = NEW.bed_number;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_bed_occupied_on_admit` AFTER INSERT ON `hospitalization` FOR EACH ROW BEGIN
    UPDATE Bed
    SET bed_status = 'occupied'
    WHERE number = NEW.bed_number;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_compute_cost_on_discharge` BEFORE UPDATE ON `hospitalization` FOR EACH ROW BEGIN
    DECLARE v_basic_cost  DECIMAL(10,2);
    DECLARE v_mdn         SMALLINT;
    DECLARE v_actual_days INT;
    DECLARE v_stay_cost   DECIMAL(10,2);
    DECLARE v_lab_cost    DECIMAL(10,2) DEFAULT 0;
    DECLARE v_proc_cost   DECIMAL(10,2) DEFAULT 0;

    IF OLD.discharge_date IS NULL AND NEW.discharge_date IS NOT NULL THEN

        SELECT basic_cost, average_hospitalization_duration
        INTO   v_basic_cost, v_mdn
        FROM   Cost
        WHERE  KEN_code = NEW.cost_KEN_code;

        SET v_actual_days = DATEDIFF(NEW.discharge_date, NEW.admission_date);

        IF v_actual_days > v_mdn THEN
            SET v_stay_cost = v_basic_cost + ((v_actual_days - v_mdn) * (v_basic_cost * 0.05));
        ELSE
            SET v_stay_cost = v_basic_cost;
        END IF;

        SELECT COALESCE(SUM(cost), 0) INTO v_lab_cost
        FROM Lab_Tests
        WHERE hospitalization_id = NEW.id;

        SELECT COALESCE(SUM(cost), 0) INTO v_proc_cost
        FROM Medical_Procedure
        WHERE hospitalization_id = NEW.id;

        SET NEW.total_cost = v_stay_cost + v_lab_cost + v_proc_cost;

    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_triage_outcome_allows_hospitalization` BEFORE INSERT ON `hospitalization` FOR EACH ROW BEGIN
    DECLARE v_outcome VARCHAR(50);
    SELECT outcome INTO v_outcome FROM Triage WHERE id = NEW.triage_id;
    IF v_outcome <> 'Referral for hospitalization' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot hospitalize a patient whose triage outcome was Discharge.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `lab_tests`
--

CREATE TABLE `lab_tests` (
  `test_code` char(7) NOT NULL,
  `test_type` varchar(50) NOT NULL,
  `conduction_date` date NOT NULL,
  `result` varchar(100) NOT NULL,
  `cost` decimal(10,2) NOT NULL,
  `hospitalization_id` int(11) NOT NULL,
  `doctor_amka` char(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `medical_procedure`
--

CREATE TABLE `medical_procedure` (
  `procedure_code` varchar(10) NOT NULL,
  `name` varchar(200) NOT NULL,
  `category` varchar(30) DEFAULT NULL,
  `start_of_procedure` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `duration` int(11) NOT NULL,
  `required_room` varchar(50) NOT NULL,
  `cost` decimal(10,2) NOT NULL,
  `doctor_amka` char(11) NOT NULL,
  `hospitalization_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Triggers `medical_procedure`
--
DELIMITER $$
CREATE TRIGGER `trg_no_doctor_overlap_insert` BEFORE INSERT ON `medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Medical_Procedure mp
    WHERE mp.doctor_amka = NEW.doctor_amka
      AND mp.procedure_code <> NEW.procedure_code
      AND NEW.start_of_procedure < TIMESTAMPADD(MINUTE, mp.duration, mp.start_of_procedure)
      AND mp.start_of_procedure < TIMESTAMPADD(MINUTE, NEW.duration, NEW.start_of_procedure);
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is already assigned to another procedure at this time.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_doctor_overlap_update` BEFORE UPDATE ON `medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Medical_Procedure mp
    WHERE mp.doctor_amka = NEW.doctor_amka
      AND mp.procedure_code <> NEW.procedure_code
      AND NEW.start_of_procedure < TIMESTAMPADD(MINUTE, mp.duration, mp.start_of_procedure)
      AND mp.start_of_procedure < TIMESTAMPADD(MINUTE, NEW.duration, NEW.start_of_procedure);
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is already assigned to another procedure at this time.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_room_overlap_insert` BEFORE INSERT ON `medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Medical_Procedure mp
    WHERE mp.required_room = NEW.required_room
      AND mp.procedure_code <> NEW.procedure_code
      AND NEW.start_of_procedure < TIMESTAMPADD(MINUTE, mp.duration, mp.start_of_procedure)
      AND mp.start_of_procedure < TIMESTAMPADD(MINUTE, NEW.duration, NEW.start_of_procedure);
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room is already booked for another procedure at this time.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_room_overlap_update` BEFORE UPDATE ON `medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Medical_Procedure mp
    WHERE mp.required_room = NEW.required_room
      AND mp.procedure_code <> NEW.procedure_code
      AND NEW.start_of_procedure < TIMESTAMPADD(MINUTE, mp.duration, mp.start_of_procedure)
      AND mp.start_of_procedure < TIMESTAMPADD(MINUTE, NEW.duration, NEW.start_of_procedure);
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Room is already booked for another procedure at this time.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `nurse`
--

CREATE TABLE `nurse` (
  `AMKA` char(11) NOT NULL,
  `rank` varchar(50) NOT NULL,
  `department_name` varchar(50) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `nurse_works_shift`
--

CREATE TABLE `nurse_works_shift` (
  `nurse_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL
) ;

--
-- Triggers `nurse_works_shift`
--
DELIMITER $$
CREATE TRIGGER `trg_max_monthly_shifts_nurse` BEFORE INSERT ON `nurse_works_shift` FOR EACH ROW BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM Nurse_Works_Shift nws
    JOIN Shift s  ON s.id  = nws.shift_id
    JOIN Shift sn ON sn.id = NEW.shift_id
    WHERE nws.nurse_amka = NEW.nurse_amka
      AND YEAR(s.date)  = YEAR(sn.date)
      AND MONTH(s.date) = MONTH(sn.date);
 
    IF v_count >= 20 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nurse has reached the maximum of 20 shifts this month.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_delete_closed_shift_nurse` BEFORE DELETE ON `nurse_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = OLD.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot remove nurse: shift is already closed.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_insert_closed_shift_nurse` BEFORE INSERT ON `nurse_works_shift` FOR EACH ROW BEGIN
    DECLARE v_status VARCHAR(10);
    SELECT status INTO v_status FROM Shift WHERE id = NEW.shift_id;
    IF v_status = 'closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot add nurse: shift is already closed.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_nurse_double_shift` BEFORE INSERT ON `nurse_works_shift` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM Nurse_Works_Shift nws
    JOIN Shift s_existing ON s_existing.id = nws.shift_id
    JOIN Shift s_new      ON s_new.id      = NEW.shift_id
    WHERE nws.nurse_amka = NEW.nurse_amka
      AND s_existing.date = s_new.date
      AND s_existing.type = s_new.type
      AND nws.shift_id   <> NEW.shift_id;
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nurse is already assigned to a shift at this date and time slot.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_nurse_works_shift_8` BEFORE INSERT ON `nurse_works_shift` FOR EACH ROW BEGIN
    DECLARE v_shift_date DATE;
    DECLARE v_shift_type VARCHAR(50);

    SELECT s.date, s.type
    INTO   v_shift_date, v_shift_type
    FROM   Shift s
    WHERE  s.id = NEW.shift_id;

    IF EXISTS (
        SELECT 1
        FROM Nurse_Works_Shift nws
        JOIN Shift s_old ON nws.shift_id = s_old.id
        WHERE nws.nurse_amka = NEW.nurse_amka
          AND (
              (v_shift_type = 'afternoon' AND s_old.type = 'morning'   AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'night'     AND s_old.type = 'afternoon' AND s_old.date = v_shift_date)
              OR
              (v_shift_type = 'morning'   AND s_old.type = 'night'     AND s_old.date = DATE_SUB(v_shift_date, INTERVAL 1 DAY))
          )
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = '8-hour rest rule violated. Nurse cannot work consecutive shifts.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `patient`
--

CREATE TABLE `patient` (
  `AMKA` char(11) NOT NULL,
  `first_name` varchar(30) NOT NULL,
  `last_name` varchar(30) NOT NULL,
  `father_name` varchar(30) NOT NULL,
  `date_of_birth` date NOT NULL,
  `gender` varchar(10) NOT NULL,
  `weight` decimal(5,2) NOT NULL,
  `height` decimal(5,2) NOT NULL,
  `address` varchar(100) NOT NULL,
  `phone_number` varchar(10) NOT NULL,
  `email` varchar(50) DEFAULT NULL,
  `profession` varchar(50) DEFAULT NULL,
  `nationality` varchar(50) NOT NULL,
  `insurance_provider` varchar(100) DEFAULT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `patient_has_allergy`
--

CREATE TABLE `patient_has_allergy` (
  `patient_amka` char(11) NOT NULL,
  `substance_name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `prescription`
--

CREATE TABLE `prescription` (
  `doctor_amka` char(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `drug_id` int(11) NOT NULL,
  `dosage` varchar(50) NOT NULL,
  `frequency` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL
) ;

--
-- Triggers `prescription`
--
DELIMITER $$
CREATE TRIGGER `trg_allergy_check_prescription` BEFORE INSERT ON `prescription` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;
 
    SELECT COUNT(*) INTO v_conflict
    FROM patient_has_allergy pha
    JOIN Drug d ON d.substance_name = pha.substance_name
    WHERE pha.patient_amka = NEW.patient_amka
      AND d.id = NEW.drug_id;
 
    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot prescribe this drug: patient is allergic to one of its substances.';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `shift`
--

CREATE TABLE `shift` (
  `id` int(11) NOT NULL,
  `date` date NOT NULL,
  `type` varchar(50) NOT NULL,
  `status` varchar(10) NOT NULL,
  `department_name` varchar(50) NOT NULL
) ;

--
-- Triggers `shift`
--
DELIMITER $$
CREATE TRIGGER `trg_no_reopen_shift` BEFORE UPDATE ON `shift` FOR EACH ROW BEGIN
    IF OLD.status = 'closed' AND NEW.status = 'open' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot reopen a closed shift.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validate_shift_on_close` BEFORE UPDATE ON `shift` FOR EACH ROW BEGIN
    DECLARE v_doctors INT DEFAULT 0;
    DECLARE v_nurses  INT DEFAULT 0;
    DECLARE v_admins  INT DEFAULT 0;
 
    IF OLD.status = 'open' AND NEW.status = 'closed' THEN
 
        IF NEW.date > CURDATE() THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot close shift: shift date has not occurred yet.';
        END IF;
 
        IF NEW.date = CURDATE() THEN
            IF NEW.type = 'morning'   AND CURTIME() < '07:00:00' THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cannot close shift: morning shift has not started yet.';
            END IF;
            IF NEW.type = 'afternoon' AND CURTIME() < '15:00:00' THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cannot close shift: afternoon shift has not started yet.';
            END IF;
            IF NEW.type = 'night'     AND CURTIME() < '23:00:00' THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Cannot close shift: night shift has not started yet.';
            END IF;
        END IF;
 
        SELECT COUNT(*) INTO v_doctors
        FROM Doctor_Works_Shift
        WHERE shift_id = NEW.id;
 
        SELECT COUNT(*) INTO v_nurses
        FROM Nurse_Works_Shift
        WHERE shift_id = NEW.id;
 
        SELECT COUNT(*) INTO v_admins
        FROM Admin_Staff_Works_Shift
        WHERE shift_id = NEW.id;
 
        IF v_doctors < 3 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot close shift: requires at least 3 doctors.';
        END IF;
 
        IF v_nurses < 6 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot close shift: requires at least 6 nurses.';
        END IF;
 
        IF v_admins < 2 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot close shift: requires at least 2 admin staff.';
        END IF;
 
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `staff`
--

CREATE TABLE `staff` (
  `AMKA` char(11) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `date_of_birth` date NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `hire_date` date NOT NULL,
  `staff_type` varchar(20) NOT NULL
) ;

-- --------------------------------------------------------

--
-- Table structure for table `staff_helps_medical_procedure`
--

CREATE TABLE `staff_helps_medical_procedure` (
  `staff_amka` char(11) NOT NULL,
  `medical_procedure_id` varchar(10) NOT NULL
) ;

--
-- Triggers `staff_helps_medical_procedure`
--
DELIMITER $$
CREATE TRIGGER `trg_no_helper_overlap_insert` BEFORE INSERT ON `staff_helps_medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;

    SELECT COUNT(*) INTO v_conflict
    FROM Staff_Helps_Medical_Procedure shmp
    JOIN Medical_Procedure mp_existing 
        ON mp_existing.procedure_code = shmp.medical_procedure_id
    JOIN Medical_Procedure mp_new 
        ON mp_new.procedure_code = NEW.medical_procedure_id
    WHERE shmp.staff_amka = NEW.staff_amka
      AND mp_new.start_of_procedure < TIMESTAMPADD(MINUTE, mp_existing.duration, mp_existing.start_of_procedure)
      AND mp_existing.start_of_procedure < TIMESTAMPADD(MINUTE, mp_new.duration, mp_new.start_of_procedure);

    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Staff member is already assisting another procedure at this time.';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_no_helper_overlap_update` BEFORE UPDATE ON `staff_helps_medical_procedure` FOR EACH ROW BEGIN
    DECLARE v_conflict INT DEFAULT 0;

	IF NOT (NEW.medical_procedure_id <=> OLD.medical_procedure_id)
	OR NOT (NEW.staff_amka <=> OLD.staff_amka) THEN

        SELECT COUNT(*) INTO v_conflict
        FROM Staff_Helps_Medical_Procedure shmp
        JOIN Medical_Procedure mp_existing 
            ON mp_existing.procedure_code = shmp.medical_procedure_id
        JOIN Medical_Procedure mp_new 
            ON mp_new.procedure_code = NEW.medical_procedure_id
        WHERE shmp.staff_amka = NEW.staff_amka
          AND NOT (shmp.staff_amka = OLD.staff_amka 
               AND shmp.medical_procedure_id = OLD.medical_procedure_id)
          AND mp_new.start_of_procedure < TIMESTAMPADD(MINUTE, mp_existing.duration, mp_existing.start_of_procedure)
          AND mp_existing.start_of_procedure < TIMESTAMPADD(MINUTE, mp_new.duration, mp_new.start_of_procedure);

        IF v_conflict > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Staff member is already assisting another procedure at this time.';
        END IF;

    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `substance`
--

CREATE TABLE `substance` (
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `triage`
--

CREATE TABLE `triage` (
  `id` int(11) NOT NULL,
  `arrival_time` datetime NOT NULL,
  `urgency_level` smallint(1) UNSIGNED NOT NULL,
  `outcome` varchar(50) NOT NULL,
  `nurse_amka` char(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `diagnosis_time` date DEFAULT NULL
) ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_staff`
--
ALTER TABLE `admin_staff`
  ADD PRIMARY KEY (`AMKA`),
  ADD KEY `department_name` (`department_name`);

--
-- Indexes for table `admin_staff_works_shift`
--
ALTER TABLE `admin_staff_works_shift`
  ADD PRIMARY KEY (`admin_staff_amka`,`shift_id`),
  ADD KEY `shift_id` (`shift_id`);

--
-- Indexes for table `bed`
--
ALTER TABLE `bed`
  ADD PRIMARY KEY (`number`),
  ADD KEY `department_name` (`department_name`);

--
-- Indexes for table `cost`
--
ALTER TABLE `cost`
  ADD PRIMARY KEY (`KEN_code`);

--
-- Indexes for table `department`
--
ALTER TABLE `department`
  ADD PRIMARY KEY (`name`),
  ADD KEY `doctor_amka` (`doctor_amka`);

--
-- Indexes for table `diagnosis`
--
ALTER TABLE `diagnosis`
  ADD PRIMARY KEY (`code`),
  ADD UNIQUE KEY `description` (`description`) USING HASH;

--
-- Indexes for table `doctor`
--
ALTER TABLE `doctor`
  ADD PRIMARY KEY (`AMKA`),
  ADD UNIQUE KEY `license_number` (`license_number`),
  ADD KEY `supervisor_AMKA` (`supervisor_AMKA`);

--
-- Indexes for table `doctor_works_department`
--
ALTER TABLE `doctor_works_department`
  ADD PRIMARY KEY (`doctor_amka`,`department_name`),
  ADD KEY `department_name` (`department_name`);

--
-- Indexes for table `doctor_works_shift`
--
ALTER TABLE `doctor_works_shift`
  ADD PRIMARY KEY (`doctor_amka`,`shift_id`),
  ADD KEY `shift_id` (`shift_id`);

--
-- Indexes for table `drug`
--
ALTER TABLE `drug`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `name` (`name`,`substance_name`),
  ADD KEY `substance_name` (`substance_name`);

--
-- Indexes for table `emergency_contact`
--
ALTER TABLE `emergency_contact`
  ADD PRIMARY KEY (`patient_amka`,`phone`);

--
-- Indexes for table `evaluation`
--
ALTER TABLE `evaluation`
  ADD PRIMARY KEY (`id`),
  ADD KEY `doctor_amka` (`doctor_amka`),
  ADD KEY `patient_amka` (`patient_amka`),
  ADD KEY `hospitalization_id` (`hospitalization_id`);

--
-- Indexes for table `hospitalization`
--
ALTER TABLE `hospitalization`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `triage_id` (`triage_id`),
  ADD KEY `patient_amka` (`patient_amka`),
  ADD KEY `department_name` (`department_name`),
  ADD KEY `cost_KEN_code` (`cost_KEN_code`),
  ADD KEY `in_diagnosis_code` (`in_diagnosis_code`),
  ADD KEY `out_diagnosis_code` (`out_diagnosis_code`),
  ADD KEY `bed_number` (`bed_number`);

--
-- Indexes for table `lab_tests`
--
ALTER TABLE `lab_tests`
  ADD PRIMARY KEY (`test_code`),
  ADD KEY `doctor_amka` (`doctor_amka`),
  ADD KEY `hospitalization_id` (`hospitalization_id`);

--
-- Indexes for table `medical_procedure`
--
ALTER TABLE `medical_procedure`
  ADD PRIMARY KEY (`procedure_code`),
  ADD KEY `doctor_amka` (`doctor_amka`),
  ADD KEY `hospitalization_id` (`hospitalization_id`);

--
-- Indexes for table `nurse`
--
ALTER TABLE `nurse`
  ADD PRIMARY KEY (`AMKA`),
  ADD KEY `department_name` (`department_name`);

--
-- Indexes for table `nurse_works_shift`
--
ALTER TABLE `nurse_works_shift`
  ADD PRIMARY KEY (`nurse_amka`,`shift_id`),
  ADD KEY `shift_id` (`shift_id`);

--
-- Indexes for table `patient`
--
ALTER TABLE `patient`
  ADD PRIMARY KEY (`AMKA`),
  ADD UNIQUE KEY `phone_number` (`phone_number`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `patient_has_allergy`
--
ALTER TABLE `patient_has_allergy`
  ADD PRIMARY KEY (`patient_amka`,`substance_name`),
  ADD KEY `substance_name` (`substance_name`);

--
-- Indexes for table `prescription`
--
ALTER TABLE `prescription`
  ADD PRIMARY KEY (`doctor_amka`,`patient_amka`,`drug_id`,`start_date`),
  ADD KEY `patient_amka` (`patient_amka`),
  ADD KEY `drug_id` (`drug_id`);

--
-- Indexes for table `shift`
--
ALTER TABLE `shift`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_shift` (`date`,`type`,`department_name`),
  ADD KEY `department_name` (`department_name`);

--
-- Indexes for table `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`AMKA`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `phone_number` (`phone_number`);

--
-- Indexes for table `staff_helps_medical_procedure`
--
ALTER TABLE `staff_helps_medical_procedure`
  ADD PRIMARY KEY (`staff_amka`,`medical_procedure_id`),
  ADD KEY `medical_procedure_id` (`medical_procedure_id`);

--
-- Indexes for table `substance`
--
ALTER TABLE `substance`
  ADD PRIMARY KEY (`name`);

--
-- Indexes for table `triage`
--
ALTER TABLE `triage`
  ADD PRIMARY KEY (`id`),
  ADD KEY `nurse_amka` (`nurse_amka`),
  ADD KEY `patient_amka` (`patient_amka`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `bed`
--
ALTER TABLE `bed`
  MODIFY `number` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `drug`
--
ALTER TABLE `drug`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `evaluation`
--
ALTER TABLE `evaluation`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `hospitalization`
--
ALTER TABLE `hospitalization`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `shift`
--
ALTER TABLE `shift`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `triage`
--
ALTER TABLE `triage`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admin_staff`
--
ALTER TABLE `admin_staff`
  ADD CONSTRAINT `admin_staff_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `admin_staff_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE;

--
-- Constraints for table `admin_staff_works_shift`
--
ALTER TABLE `admin_staff_works_shift`
  ADD CONSTRAINT `admin_staff_works_shift_ibfk_1` FOREIGN KEY (`admin_staff_amka`) REFERENCES `admin_staff` (`AMKA`),
  ADD CONSTRAINT `admin_staff_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `bed`
--
ALTER TABLE `bed`
  ADD CONSTRAINT `bed_ibfk_1` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE;

--
-- Constraints for table `department`
--
ALTER TABLE `department`
  ADD CONSTRAINT `department_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`);

--
-- Constraints for table `doctor`
--
ALTER TABLE `doctor`
  ADD CONSTRAINT `doctor_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `doctor_ibfk_2` FOREIGN KEY (`supervisor_AMKA`) REFERENCES `doctor` (`AMKA`);

--
-- Constraints for table `doctor_works_department`
--
ALTER TABLE `doctor_works_department`
  ADD CONSTRAINT `doctor_works_department_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `doctor_works_department_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE;

--
-- Constraints for table `doctor_works_shift`
--
ALTER TABLE `doctor_works_shift`
  ADD CONSTRAINT `doctor_works_shift_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  ADD CONSTRAINT `doctor_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `drug`
--
ALTER TABLE `drug`
  ADD CONSTRAINT `drug_ibfk_1` FOREIGN KEY (`substance_name`) REFERENCES `substance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `emergency_contact`
--
ALTER TABLE `emergency_contact`
  ADD CONSTRAINT `emergency_contact_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE;

--
-- Constraints for table `evaluation`
--
ALTER TABLE `evaluation`
  ADD CONSTRAINT `evaluation_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  ADD CONSTRAINT `evaluation_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `evaluation_ibfk_3` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `hospitalization`
--
ALTER TABLE `hospitalization`
  ADD CONSTRAINT `hospitalization_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`),
  ADD CONSTRAINT `hospitalization_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  ADD CONSTRAINT `hospitalization_ibfk_3` FOREIGN KEY (`triage_id`) REFERENCES `triage` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `hospitalization_ibfk_4` FOREIGN KEY (`cost_KEN_code`) REFERENCES `cost` (`KEN_code`) ON UPDATE CASCADE,
  ADD CONSTRAINT `hospitalization_ibfk_5` FOREIGN KEY (`in_diagnosis_code`) REFERENCES `diagnosis` (`code`) ON UPDATE CASCADE,
  ADD CONSTRAINT `hospitalization_ibfk_6` FOREIGN KEY (`out_diagnosis_code`) REFERENCES `diagnosis` (`code`) ON UPDATE CASCADE,
  ADD CONSTRAINT `hospitalization_ibfk_7` FOREIGN KEY (`bed_number`) REFERENCES `bed` (`number`) ON UPDATE CASCADE;

--
-- Constraints for table `lab_tests`
--
ALTER TABLE `lab_tests`
  ADD CONSTRAINT `lab_tests_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  ADD CONSTRAINT `lab_tests_ibfk_2` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `medical_procedure`
--
ALTER TABLE `medical_procedure`
  ADD CONSTRAINT `medical_procedure_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  ADD CONSTRAINT `medical_procedure_ibfk_2` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `nurse`
--
ALTER TABLE `nurse`
  ADD CONSTRAINT `nurse_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `nurse_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE;

--
-- Constraints for table `nurse_works_shift`
--
ALTER TABLE `nurse_works_shift`
  ADD CONSTRAINT `nurse_works_shift_ibfk_1` FOREIGN KEY (`nurse_amka`) REFERENCES `nurse` (`AMKA`),
  ADD CONSTRAINT `nurse_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `patient_has_allergy`
--
ALTER TABLE `patient_has_allergy`
  ADD CONSTRAINT `patient_has_allergy_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `patient_has_allergy_ibfk_2` FOREIGN KEY (`substance_name`) REFERENCES `substance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `prescription`
--
ALTER TABLE `prescription`
  ADD CONSTRAINT `prescription_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  ADD CONSTRAINT `prescription_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  ADD CONSTRAINT `prescription_ibfk_3` FOREIGN KEY (`drug_id`) REFERENCES `drug` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `shift`
--
ALTER TABLE `shift`
  ADD CONSTRAINT `shift_ibfk_1` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `staff_helps_medical_procedure`
--
ALTER TABLE `staff_helps_medical_procedure`
  ADD CONSTRAINT `staff_helps_medical_procedure_ibfk_1` FOREIGN KEY (`staff_amka`) REFERENCES `staff` (`AMKA`),
  ADD CONSTRAINT `staff_helps_medical_procedure_ibfk_2` FOREIGN KEY (`medical_procedure_id`) REFERENCES `medical_procedure` (`procedure_code`) ON DELETE CASCADE;

--
-- Constraints for table `triage`
--
ALTER TABLE `triage`
  ADD CONSTRAINT `triage_ibfk_1` FOREIGN KEY (`nurse_amka`) REFERENCES `nurse` (`AMKA`),
  ADD CONSTRAINT `triage_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

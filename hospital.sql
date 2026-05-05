-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: May 05, 2026 at 06:19 PM
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
  `name` varchar(255) NOT NULL,
  `substance_name` varchar(255) NOT NULL
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
  `hospitalization_id` int(11) NOT NULL,
  `id` int(11) NOT NULL
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
      AND mp.id <> NEW.id
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
      AND mp.id <> NEW.id
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
      AND mp.id <> NEW.id
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
      AND mp.id <> NEW.id
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

--
-- Dumping data for table `patient`
--

INSERT INTO `patient` (`AMKA`, `first_name`, `last_name`, `father_name`, `date_of_birth`, `gender`, `weight`, `height`, `address`, `phone_number`, `email`, `profession`, `nationality`, `insurance_provider`) VALUES
('00029822500', 'Liam', 'Hernandez', 'Olivia', '2011-01-10', 'Male', 108.31, 1.60, '81 Main St, USA', '5515235842', 'liam.hernandez656@example.com', 'Artist', 'USA', 'AXA'),
('00176706637', 'Amelia', 'Smith', 'Olivia', '1964-03-18', 'Female', 72.92, 1.79, '72 Main St, United Kingdom', '0756371554', 'amelia.smith972@example.com', 'Doctor', 'United Kingdom', 'Bupa'),
('00662258207', 'Elias', 'Wagner', 'Emma', '1963-01-14', 'Male', 62.77, 1.91, '108 Main St, Germany', '1507564040', 'elias.wagner693@example.com', 'Unemployed', 'Germany', 'Blue Cross'),
('00719264185', 'Ava', 'Lopez', 'James', '1959-05-31', 'Female', 58.37, 1.50, '25 Main St, USA', '5518013467', 'ava.lopez729@example.com', 'Programmer', 'USA', 'Allianz'),
('00734283574', 'William', 'Miller', 'William', '2014-11-22', 'Male', 76.57, 1.61, '194 Main St, USA', '5507621454', 'william.miller821@example.com', 'Programmer', 'USA', 'Allianz'),
('00837544363', 'Sofia', 'Papadopoulos', 'Georgios', '1975-12-15', 'Male', 87.69, 1.94, '153 Main St, Greece', '6989682746', 'sofia.papadopoulos960@example.com', 'Programmer', 'Greece', 'National Health System'),
('01746717779', 'Liam', 'Lopez', 'Isabella', '2001-10-01', 'Female', 101.15, 1.95, '50 Main St, USA', '5592586923', 'liam.lopez61@example.com', 'Doctor', 'USA', 'AXA'),
('01825720978', 'Hannah', 'Becker', 'Emma', '1975-02-13', 'Female', 87.76, 1.60, '172 Main St, Germany', '1579004481', 'hannah.becker74@example.com', 'Architect', 'Germany', 'AXA'),
('01936407368', 'William', 'Lopez', 'James', '1976-08-26', 'Female', 55.11, 1.73, '100 Main St, USA', '5538163786', 'william.lopez71@example.com', 'Doctor', 'USA', 'Bupa'),
('01956708595', 'William', 'Davis', 'Emma', '2004-10-18', 'Female', 50.02, 1.84, '90 Main St, USA', '5531557261', 'william.davis364@example.com', 'Programmer', 'USA', 'Bupa'),
('02907336702', 'Nikolaos', 'Karagiannis', 'Sofia', '2000-01-27', 'Male', 59.61, 1.57, '92 Main St, Greece', '6994241910', 'nikolaos.karagiannis779@example.com', 'Teacher', 'Greece', 'Bupa'),
('02992894108', 'Ava', 'Johnson', 'Olivia', '1972-09-07', 'Male', 54.35, 1.57, '68 Main St, USA', '5549255260', 'ava.johnson65@example.com', 'Unemployed', 'USA', 'Allianz'),
('03252315618', 'Jack', 'Wilson', 'Olivia', '1963-07-18', 'Male', 93.94, 1.71, '86 Main St, United Kingdom', '0775448515', 'jack.wilson628@example.com', 'Architect', 'United Kingdom', 'Allianz'),
('03332980331', 'Liam', 'Miller', 'Noah', '1958-04-04', 'Male', 61.04, 1.90, '117 Main St, USA', '5565242850', 'liam.miller842@example.com', 'Unemployed', 'USA', 'AXA'),
('03381671980', 'Georgios', 'Angelopoulos', 'Dimitrios', '1962-11-16', 'Female', 76.29, 1.56, '32 Main St, Greece', '6943769961', 'georgios.angelopoulos249@example.com', 'Chef', 'Greece', 'Blue Cross'),
('03794433373', 'Georgios', 'Nikolaidis', 'Maria', '1971-05-27', 'Female', 86.84, 1.77, '53 Main St, Greece', '6939213730', 'georgios.nikolaidis87@example.com', 'Nurse', 'Greece', 'Blue Cross'),
('04066054312', 'Lukas', 'Becker', 'Finn', '2008-04-26', 'Male', 91.81, 1.64, '48 Main St, Germany', '1528276025', 'lukas.becker934@example.com', 'Engineer', 'Germany', 'Allianz'),
('04453714119', 'Maria', 'Pappas', 'Dimitrios', '1984-05-14', 'Male', 50.60, 1.87, '179 Main St, Greece', '6962127885', 'maria.pappas620@example.com', 'Nurse', 'Greece', 'AXA'),
('04720525252', 'James', 'Smith', 'Amelia', '1998-12-16', 'Female', 84.73, 1.82, '39 Main St, United Kingdom', '0727384268', 'james.smith101@example.com', 'Teacher', 'United Kingdom', 'MetLife'),
('05372776177', 'Sophia', 'Rodriguez', 'Isabella', '1993-10-25', 'Female', 56.41, 1.95, '26 Main St, USA', '5541169324', 'sophia.rodriguez222@example.com', 'Nurse', 'USA', 'MetLife'),
('05881516672', 'Amelia', 'Williams', 'Isla', '2005-10-06', 'Female', 94.29, 1.81, '125 Main St, United Kingdom', '0773334513', 'amelia.williams373@example.com', 'Teacher', 'United Kingdom', 'National Health System'),
('06019786485', 'Isabella', 'Johnson', 'Ava', '1969-11-06', 'Male', 76.67, 1.89, '59 Main St, USA', '5529217945', 'isabella.johnson249@example.com', 'Chef', 'USA', 'Blue Cross'),
('06110934755', 'Mia', 'Brown', 'George', '1955-03-16', 'Female', 50.36, 1.53, '149 Main St, United Kingdom', '0761646207', 'mia.brown882@example.com', 'Engineer', 'United Kingdom', 'National Health System'),
('06131446960', 'Vasiliki', 'Papadopoulos', 'Ioannis', '1970-02-06', 'Female', 93.28, 1.79, '43 Main St, Greece', '6934697361', 'vasiliki.papadopoulos190@example.com', 'Architect', 'Greece', 'Blue Cross'),
('06310815363', 'Vasiliki', 'Dimitriou', 'Ioannis', '1982-12-03', 'Male', 58.28, 1.95, '17 Main St, Greece', '6948020410', 'vasiliki.dimitriou658@example.com', 'Engineer', 'Greece', 'National Health System'),
('06888043698', 'Sofia', 'Schneider', 'Sofia', '2012-03-26', 'Female', 104.82, 1.83, '13 Main St, Germany', '1556477083', 'sofia.schneider107@example.com', 'Doctor', 'Germany', 'Aetna'),
('07000778738', 'James', 'Hernandez', 'Noah', '1993-01-13', 'Male', 64.85, 1.61, '98 Main St, USA', '5563497922', 'james.hernandez904@example.com', 'Accountant', 'USA', 'AXA'),
('07244014629', 'Sofia', 'Müller', 'Elias', '1994-01-05', 'Male', 81.95, 1.75, '146 Main St, Germany', '1501685337', 'sofia.müller315@example.com', 'Nurse', 'Germany', 'National Health System'),
('08598100937', 'Olivia', 'Wilson', 'Isla', '1990-10-26', 'Male', 93.53, 1.54, '162 Main St, United Kingdom', '0798137802', 'olivia.wilson971@example.com', 'Engineer', 'United Kingdom', 'MetLife'),
('08619438635', 'Olivia', 'Lopez', 'James', '2014-11-06', 'Female', 58.08, 1.89, '65 Main St, USA', '5562627229', 'olivia.lopez217@example.com', 'Architect', 'USA', 'Bupa'),
('08964474961', 'Oliver', 'Smith', 'Oliver', '1977-06-19', 'Female', 62.99, 1.77, '182 Main St, United Kingdom', '0749596540', 'oliver.smith499@example.com', 'Architect', 'United Kingdom', 'Aetna'),
('09121768523', 'Olivia', 'Smith', 'Jack', '1951-06-01', 'Female', 63.84, 1.96, '14 Main St, United Kingdom', '0737422735', 'olivia.smith304@example.com', 'Teacher', 'United Kingdom', 'AXA'),
('09456855357', 'Ava', 'Williams', 'Amelia', '1982-12-05', 'Male', 91.39, 1.83, '12 Main St, United Kingdom', '0759913567', 'ava.williams261@example.com', 'Architect', 'United Kingdom', 'National Health System'),
('09537693824', 'Sofia', 'Wagner', 'Finn', '1961-02-12', 'Female', 57.76, 1.54, '125 Main St, Germany', '1578301175', 'sofia.wagner25@example.com', 'Programmer', 'Germany', 'MetLife'),
('09745262856', 'Sophia', 'Miller', 'Liam', '1972-10-11', 'Female', 101.29, 1.86, '148 Main St, USA', '5508583872', 'sophia.miller302@example.com', 'Nurse', 'USA', 'Bupa'),
('09761269707', 'Vasiliki', 'Nikolaidis', 'Eleni', '1970-11-18', 'Male', 88.75, 1.75, '173 Main St, Greece', '6939995186', 'vasiliki.nikolaidis205@example.com', 'Accountant', 'Greece', 'National Health System'),
('09765561006', 'Ava', 'Rodriguez', 'James', '2002-10-04', 'Male', 63.75, 2.00, '143 Main St, USA', '5557088851', 'ava.rodriguez90@example.com', 'Unemployed', 'USA', 'Bupa'),
('09942930404', 'Mia', 'Meyer', 'Sofia', '1984-01-10', 'Female', 92.66, 1.93, '111 Main St, Germany', '1546797323', 'mia.meyer721@example.com', 'Accountant', 'Germany', 'Blue Cross'),
('09950562876', 'Eleni', 'Nikolaidis', 'Maria', '1998-12-30', 'Male', 86.44, 1.98, '132 Main St, Greece', '6988628461', 'eleni.nikolaidis913@example.com', 'Programmer', 'Greece', 'Blue Cross'),
('10127029881', 'Sofia', 'Weber', 'Sofia', '1970-01-13', 'Female', 86.70, 1.90, '59 Main St, Germany', '1561174666', 'sofia.weber189@example.com', 'Programmer', 'Germany', 'Blue Cross'),
('10877291985', 'George', 'Evans', 'James', '2017-09-22', 'Female', 89.04, 1.86, '194 Main St, United Kingdom', '0715767679', 'george.evans648@example.com', 'Teacher', 'United Kingdom', 'AXA'),
('11244952890', 'Vasiliki', 'Angelopoulos', 'Aikaterini', '1969-05-14', 'Male', 60.26, 1.70, '110 Main St, Greece', '6998443906', 'vasiliki.angelopoulos93@example.com', 'Chef', 'Greece', 'Blue Cross'),
('11739935809', 'Mia', 'Wagner', 'Anna', '1977-03-19', 'Female', 78.27, 1.58, '119 Main St, Germany', '1551527150', 'mia.wagner41@example.com', 'Programmer', 'Germany', 'MetLife'),
('12200029768', 'George', 'Jones', 'James', '1967-05-03', 'Female', 64.73, 1.83, '145 Main St, United Kingdom', '0717133170', 'george.jones27@example.com', 'Accountant', 'United Kingdom', 'MetLife'),
('12434133185', 'Mia', 'Brown', 'Oliver', '2011-03-28', 'Male', 81.93, 1.87, '7 Main St, United Kingdom', '0743571906', 'mia.brown639@example.com', 'Nurse', 'United Kingdom', 'Blue Cross'),
('12583140774', 'Anna', 'Fischer', 'Lukas', '1967-04-05', 'Female', 81.26, 1.65, '116 Main St, Germany', '1587433509', 'anna.fischer777@example.com', 'Unemployed', 'Germany', 'MetLife'),
('12831304147', 'George', 'Davies', 'Isla', '1954-07-26', 'Male', 72.15, 1.82, '200 Main St, United Kingdom', '0789591193', 'george.davies237@example.com', 'Accountant', 'United Kingdom', 'Allianz'),
('13391894950', 'Nikolaos', 'Dimitriou', 'Dimitrios', '1964-09-02', 'Male', 67.76, 1.84, '49 Main St, Greece', '6989089592', 'nikolaos.dimitriou713@example.com', 'Accountant', 'Greece', 'Allianz'),
('13817881856', 'Mia', 'Wilson', 'Olivia', '2008-02-10', 'Male', 51.87, 1.72, '161 Main St, United Kingdom', '0720971013', 'mia.wilson113@example.com', 'Artist', 'United Kingdom', 'Blue Cross'),
('14191800525', 'Emma', 'Schneider', 'Hannah', '1995-05-17', 'Male', 61.60, 1.65, '87 Main St, Germany', '1579931788', 'emma.schneider740@example.com', 'Programmer', 'Germany', 'Blue Cross'),
('14796824528', 'Ioannis', 'Pappas', 'Ioannis', '1953-10-13', 'Male', 83.51, 1.80, '91 Main St, Greece', '6917275288', 'ioannis.pappas668@example.com', 'Accountant', 'Greece', 'Blue Cross'),
('15400404721', 'Sofia', 'Pappas', 'Aikaterini', '1970-05-29', 'Female', 75.60, 1.97, '70 Main St, Greece', '6976931508', 'sofia.pappas111@example.com', 'Accountant', 'Greece', 'Blue Cross'),
('15604325967', 'Nikolaos', 'Vlachos', 'Nikolaos', '2001-08-19', 'Female', 61.50, 1.96, '191 Main St, Greece', '6916311611', 'nikolaos.vlachos240@example.com', 'Unemployed', 'Greece', 'Blue Cross'),
('15760739622', 'Olivia', 'Taylor', 'Oliver', '1995-02-03', 'Male', 81.06, 1.74, '16 Main St, United Kingdom', '0781236431', 'olivia.taylor849@example.com', 'Doctor', 'United Kingdom', 'AXA'),
('16071486215', 'Emma', 'Davis', 'James', '1953-12-10', 'Male', 89.74, 1.66, '113 Main St, USA', '5500955944', 'emma.davis979@example.com', 'Artist', 'USA', 'AXA'),
('16187511020', 'Noah', 'Rodriguez', 'Sophia', '1967-07-18', 'Male', 58.75, 1.52, '140 Main St, USA', '5539885303', 'noah.rodriguez219@example.com', 'Doctor', 'USA', 'National Health System'),
('16559349126', 'Mia', 'Meyer', 'Elias', '2007-05-21', 'Female', 56.63, 2.00, '35 Main St, Germany', '1596934315', 'mia.meyer340@example.com', 'Engineer', 'Germany', 'Allianz'),
('16931079554', 'Sophia', 'Martinez', 'Ava', '1966-05-31', 'Male', 80.12, 1.72, '113 Main St, USA', '5513621093', 'sophia.martinez608@example.com', 'Artist', 'USA', 'Bupa'),
('17646267207', 'Noah', 'Garcia', 'Ava', '1996-05-12', 'Male', 52.19, 1.78, '128 Main St, USA', '5504967597', 'noah.garcia92@example.com', 'Nurse', 'USA', 'Bupa'),
('18131951850', 'Emma', 'Meyer', 'Finn', '1999-09-01', 'Female', 51.50, 1.89, '31 Main St, Germany', '1555501681', 'emma.meyer860@example.com', 'Accountant', 'Germany', 'National Health System'),
('18308116255', 'Aikaterini', 'Pappas', 'Maria', '1958-11-23', 'Male', 72.36, 1.75, '26 Main St, Greece', '6900700836', 'aikaterini.pappas633@example.com', 'Doctor', 'Greece', 'Allianz'),
('18623840630', 'Vasiliki', 'Karagiannis', 'Nikolaos', '1976-04-30', 'Male', 91.84, 1.57, '81 Main St, Greece', '6940013868', 'vasiliki.karagiannis265@example.com', 'Architect', 'Greece', 'Blue Cross'),
('18671126383', 'Emma', 'Schneider', 'Anna', '1997-05-05', 'Female', 108.98, 1.60, '43 Main St, Germany', '1539435473', 'emma.schneider893@example.com', 'Artist', 'Germany', 'Aetna'),
('18723637229', 'Emma', 'Fischer', 'Mia', '1955-01-13', 'Female', 63.87, 1.72, '12 Main St, Germany', '1508756280', 'emma.fischer235@example.com', 'Chef', 'Germany', 'National Health System'),
('19405692176', 'Aikaterini', 'Georgiou', 'Konstantinos', '1988-06-10', 'Female', 87.98, 1.94, '190 Main St, Greece', '6947064461', 'aikaterini.georgiou345@example.com', 'Accountant', 'Greece', 'MetLife'),
('19408058971', 'Sofia', 'Schneider', 'Mia', '1974-04-10', 'Male', 84.14, 1.84, '47 Main St, Germany', '1527103663', 'sofia.schneider497@example.com', 'Engineer', 'Germany', 'Bupa'),
('19562511241', 'Ava', 'Garcia', 'Noah', '1978-05-26', 'Male', 71.07, 1.91, '108 Main St, USA', '5551134316', 'ava.garcia296@example.com', 'Doctor', 'USA', 'Aetna'),
('19594881564', 'Elias', 'Schneider', 'Hannah', '1988-07-15', 'Male', 83.99, 1.98, '95 Main St, Germany', '1574246089', 'elias.schneider974@example.com', 'Accountant', 'Germany', 'MetLife'),
('19728216920', 'Elias', 'Wagner', 'Leon', '1970-09-09', 'Male', 56.27, 1.93, '40 Main St, Germany', '1531553965', 'elias.wagner384@example.com', 'Chef', 'Germany', 'Bupa'),
('20008661513', 'Noah', 'Johnson', 'Noah', '1966-05-17', 'Male', 54.75, 1.90, '24 Main St, USA', '5542840380', 'noah.johnson957@example.com', 'Architect', 'USA', 'National Health System'),
('20070619730', 'Ava', 'Lopez', 'Ava', '1991-12-30', 'Female', 69.57, 1.80, '56 Main St, USA', '5587288113', 'ava.lopez327@example.com', 'Chef', 'USA', 'Blue Cross'),
('20391119255', 'Isla', 'Jones', 'Amelia', '2007-06-02', 'Female', 74.36, 1.56, '53 Main St, United Kingdom', '0757122808', 'isla.jones280@example.com', 'Unemployed', 'United Kingdom', 'Allianz'),
('20888103623', 'Isabella', 'Martinez', 'Liam', '1987-10-24', 'Male', 104.98, 1.90, '161 Main St, USA', '5550674385', 'isabella.martinez495@example.com', 'Accountant', 'USA', 'AXA'),
('21025610648', 'Konstantinos', 'Georgiou', 'Aikaterini', '1989-04-18', 'Female', 58.68, 1.62, '122 Main St, Greece', '6913568251', 'konstantinos.georgiou837@example.com', 'Nurse', 'Greece', 'Blue Cross'),
('21663835091', 'Dimitrios', 'Vlachos', 'Georgios', '1957-06-29', 'Female', 80.15, 1.50, '156 Main St, Greece', '6972018741', 'dimitrios.vlachos775@example.com', 'Engineer', 'Greece', 'Bupa'),
('22142181741', 'Olivia', 'Johnson', 'Ava', '1978-07-10', 'Male', 74.58, 1.76, '163 Main St, USA', '5571379163', 'olivia.johnson101@example.com', 'Architect', 'USA', 'Allianz'),
('22233251630', 'Amelia', 'Williams', 'Jack', '2012-08-31', 'Female', 65.79, 1.64, '122 Main St, United Kingdom', '0719665784', 'amelia.williams300@example.com', 'Doctor', 'United Kingdom', 'Bupa'),
('22264335547', 'Oliver', 'Brown', 'Harry', '2012-10-09', 'Male', 85.80, 1.66, '78 Main St, United Kingdom', '0749738462', 'oliver.brown47@example.com', 'Architect', 'United Kingdom', 'Bupa'),
('22414188290', 'Maria', 'Nikolaidis', 'Maria', '1957-06-07', 'Female', 97.89, 1.90, '161 Main St, Greece', '6960642570', 'maria.nikolaidis130@example.com', 'Programmer', 'Greece', 'Aetna'),
('22943352498', 'Harry', 'Evans', 'Mia', '1951-06-24', 'Male', 107.58, 1.66, '55 Main St, United Kingdom', '0734646090', 'harry.evans798@example.com', 'Doctor', 'United Kingdom', 'Bupa'),
('23202146340', 'Maria', 'Angelopoulos', 'Aikaterini', '1999-12-20', 'Female', 87.75, 1.71, '114 Main St, Greece', '6924630986', 'maria.angelopoulos476@example.com', 'Engineer', 'Greece', 'Allianz'),
('23946279017', 'Noah', 'Lopez', 'Olivia', '1971-09-24', 'Male', 88.50, 1.83, '178 Main St, USA', '5544263101', 'noah.lopez78@example.com', 'Doctor', 'USA', 'Bupa'),
('24883505380', 'Ava', 'Hernandez', 'Liam', '2013-04-18', 'Male', 106.50, 1.70, '189 Main St, USA', '5550042008', 'ava.hernandez361@example.com', 'Accountant', 'USA', 'Bupa'),
('25631089448', 'Jack', 'Smith', 'Jack', '1955-01-22', 'Female', 71.24, 1.83, '107 Main St, United Kingdom', '0718399844', 'jack.smith933@example.com', 'Teacher', 'United Kingdom', 'AXA'),
('25693014007', 'James', 'Hernandez', 'William', '1966-03-22', 'Female', 63.86, 1.54, '64 Main St, USA', '5576540827', 'james.hernandez701@example.com', 'Doctor', 'USA', 'Allianz'),
('26244188463', 'James', 'Hernandez', 'James', '1993-03-23', 'Male', 85.82, 1.70, '158 Main St, USA', '5595900112', 'james.hernandez199@example.com', 'Doctor', 'USA', 'AXA'),
('26569781230', 'Olivia', 'Williams', 'Jack', '1971-05-04', 'Female', 76.69, 1.97, '174 Main St, United Kingdom', '0769721672', 'olivia.williams661@example.com', 'Chef', 'United Kingdom', 'Aetna'),
('27069380891', 'Nikolaos', 'Nikolaidis', 'Maria', '1990-08-03', 'Female', 94.87, 1.72, '23 Main St, Greece', '6918236057', 'nikolaos.nikolaidis166@example.com', 'Chef', 'Greece', 'Allianz'),
('27383870285', 'Vasiliki', 'Vlachos', 'Aikaterini', '1969-11-10', 'Female', 88.45, 1.51, '15 Main St, Greece', '6911962285', 'vasiliki.vlachos696@example.com', 'Artist', 'Greece', 'MetLife'),
('27524077294', 'Ioannis', 'Angelopoulos', 'Georgios', '1999-12-25', 'Male', 72.29, 1.95, '47 Main St, Greece', '6967650853', 'ioannis.angelopoulos223@example.com', 'Accountant', 'Greece', 'Bupa'),
('27689789466', 'Liam', 'Davis', 'Noah', '1973-10-28', 'Female', 55.49, 1.96, '63 Main St, USA', '5570083510', 'liam.davis843@example.com', 'Doctor', 'USA', 'Aetna'),
('27897256038', 'George', 'Evans', 'Harry', '1966-08-24', 'Male', 64.45, 1.95, '120 Main St, United Kingdom', '0754819854', 'george.evans284@example.com', 'Engineer', 'United Kingdom', 'National Health System'),
('29266873590', 'Olivia', 'Martinez', 'Ava', '1990-05-25', 'Female', 58.59, 1.82, '77 Main St, USA', '5534579574', 'olivia.martinez803@example.com', 'Doctor', 'USA', 'Aetna'),
('29389414276', 'Isabella', 'Hernandez', 'Noah', '1952-11-24', 'Female', 63.90, 1.78, '167 Main St, USA', '5569124494', 'isabella.hernandez366@example.com', 'Doctor', 'USA', 'Blue Cross'),
('29642450777', 'Eleni', 'Pappas', 'Sofia', '1966-07-11', 'Female', 91.23, 1.52, '44 Main St, Greece', '6913239637', 'eleni.pappas402@example.com', 'Accountant', 'Greece', 'MetLife'),
('30802907369', 'James', 'Jones', 'Isla', '1984-04-09', 'Female', 53.80, 2.00, '177 Main St, United Kingdom', '0783525520', 'james.jones793@example.com', 'Artist', 'United Kingdom', 'AXA'),
('30966193465', 'Anna', 'Müller', 'Emma', '1992-10-24', 'Female', 60.23, 1.58, '117 Main St, Germany', '1573014998', 'anna.müller369@example.com', 'Architect', 'Germany', 'National Health System'),
('31344554028', 'Vasiliki', 'Pappas', 'Nikolaos', '1955-02-02', 'Male', 87.81, 1.99, '180 Main St, Greece', '6952523887', 'vasiliki.pappas131@example.com', 'Accountant', 'Greece', 'MetLife'),
('31410602055', 'Ava', 'Wilson', 'James', '1952-02-16', 'Female', 59.76, 1.72, '197 Main St, United Kingdom', '0743117243', 'ava.wilson189@example.com', 'Doctor', 'United Kingdom', 'AXA'),
('31422768379', 'Anna', 'Schneider', 'Finn', '1977-09-13', 'Male', 59.82, 1.64, '177 Main St, Germany', '1550539741', 'anna.schneider201@example.com', 'Accountant', 'Germany', 'MetLife'),
('31887646744', 'George', 'Smith', 'Jack', '1957-06-08', 'Male', 55.59, 1.85, '133 Main St, United Kingdom', '0766238948', 'george.smith398@example.com', 'Nurse', 'United Kingdom', 'Blue Cross'),
('32058409100', 'Ava', 'Hernandez', 'William', '1993-06-04', 'Male', 100.70, 1.50, '151 Main St, USA', '5563233046', 'ava.hernandez657@example.com', 'Nurse', 'USA', 'Blue Cross'),
('32963650252', 'Hannah', 'Meyer', 'Emma', '1952-06-21', 'Male', 96.07, 1.86, '91 Main St, Germany', '1523894470', 'hannah.meyer988@example.com', 'Nurse', 'Germany', 'MetLife'),
('33167985142', 'Lukas', 'Schmidt', 'Mia', '1975-09-29', 'Female', 62.44, 1.72, '117 Main St, Germany', '1541342945', 'lukas.schmidt698@example.com', 'Chef', 'Germany', 'Allianz'),
('34096399108', 'Leon', 'Fischer', 'Emma', '1999-07-24', 'Female', 74.35, 1.66, '168 Main St, Germany', '1537817448', 'leon.fischer70@example.com', 'Nurse', 'Germany', 'Bupa'),
('34396949592', 'Elias', 'Fischer', 'Anna', '1971-02-27', 'Male', 107.07, 1.57, '21 Main St, Germany', '1523684454', 'elias.fischer898@example.com', 'Accountant', 'Germany', 'Bupa'),
('35415470318', 'George', 'Williams', 'Oliver', '1974-05-29', 'Male', 104.01, 1.53, '149 Main St, United Kingdom', '0767091022', 'george.williams24@example.com', 'Teacher', 'United Kingdom', 'National Health System'),
('35512975601', 'Vasiliki', 'Angelopoulos', 'Konstantinos', '2012-05-16', 'Female', 97.66, 1.86, '145 Main St, Greece', '6922599229', 'vasiliki.angelopoulos392@example.com', 'Programmer', 'Greece', 'Blue Cross'),
('35680618022', 'George', 'Smith', 'Mia', '1965-07-20', 'Female', 67.15, 1.84, '102 Main St, United Kingdom', '0738402482', 'george.smith115@example.com', 'Chef', 'United Kingdom', 'Allianz'),
('36196312082', 'Olivia', 'Davies', 'Ava', '1974-05-06', 'Female', 89.35, 1.69, '168 Main St, United Kingdom', '0751797792', 'olivia.davies665@example.com', 'Architect', 'United Kingdom', 'Allianz'),
('36436465283', 'Lukas', 'Meyer', 'Mia', '2011-10-16', 'Male', 99.13, 1.75, '75 Main St, Germany', '1598660867', 'lukas.meyer768@example.com', 'Doctor', 'Germany', 'Aetna'),
('36487902619', 'Vasiliki', 'Georgiou', 'Georgios', '1971-09-30', 'Male', 77.71, 1.86, '196 Main St, Greece', '6929034785', 'vasiliki.georgiou381@example.com', 'Chef', 'Greece', 'Bupa'),
('36523403084', 'Noah', 'Johnson', 'James', '1993-09-17', 'Female', 73.20, 1.99, '60 Main St, USA', '5548368465', 'noah.johnson422@example.com', 'Artist', 'USA', 'Aetna'),
('37660409565', 'Aikaterini', 'Karagiannis', 'Vasiliki', '1980-06-25', 'Female', 53.20, 1.74, '160 Main St, Greece', '6955681277', 'aikaterini.karagiannis118@example.com', 'Unemployed', 'Greece', 'National Health System'),
('38145427611', 'Ava', 'Martinez', 'Emma', '1958-10-05', 'Male', 82.96, 1.70, '151 Main St, USA', '5588162047', 'ava.martinez654@example.com', 'Accountant', 'USA', 'Blue Cross'),
('38705236135', 'Jack', 'Smith', 'James', '1954-02-09', 'Male', 77.21, 1.86, '155 Main St, United Kingdom', '0708760994', 'jack.smith92@example.com', 'Artist', 'United Kingdom', 'National Health System'),
('38803616768', 'Elias', 'Meyer', 'Lukas', '1953-09-26', 'Female', 64.83, 1.54, '21 Main St, Germany', '1589276717', 'elias.meyer234@example.com', 'Chef', 'Germany', 'Aetna'),
('38886802578', 'Emma', 'Schmidt', 'Hannah', '1956-09-16', 'Female', 76.16, 1.81, '14 Main St, Germany', '1521982081', 'emma.schmidt63@example.com', 'Architect', 'Germany', 'Aetna'),
('39762421163', 'Emma', 'Schmidt', 'Hannah', '2015-12-14', 'Female', 66.88, 1.79, '149 Main St, Germany', '1572929701', 'emma.schmidt979@example.com', 'Programmer', 'Germany', 'National Health System'),
('39943771225', 'Amelia', 'Evans', 'Oliver', '1980-05-18', 'Male', 74.16, 1.66, '89 Main St, United Kingdom', '0726061894', 'amelia.evans362@example.com', 'Artist', 'United Kingdom', 'MetLife'),
('40475338159', 'Maria', 'Dimitriou', 'Konstantinos', '1955-10-31', 'Female', 65.53, 1.60, '15 Main St, Greece', '6956987002', 'maria.dimitriou942@example.com', 'Accountant', 'Greece', 'National Health System'),
('40601770097', 'Jack', 'Davies', 'Oliver', '2000-11-10', 'Female', 83.83, 1.54, '168 Main St, United Kingdom', '0708850763', 'jack.davies244@example.com', 'Unemployed', 'United Kingdom', 'National Health System'),
('40705444457', 'Finn', 'Weber', 'Sofia', '1990-02-27', 'Female', 54.63, 1.53, '184 Main St, Germany', '1535349525', 'finn.weber348@example.com', 'Engineer', 'Germany', 'MetLife'),
('41776851071', 'Sofia', 'Nikolaidis', 'Dimitrios', '1982-10-10', 'Female', 63.69, 1.84, '131 Main St, Greece', '6963896235', 'sofia.nikolaidis618@example.com', 'Accountant', 'Greece', 'AXA'),
('41868931498', 'Aikaterini', 'Karagiannis', 'Eleni', '1979-07-03', 'Male', 72.74, 1.99, '155 Main St, Greece', '6948034709', 'aikaterini.karagiannis241@example.com', 'Programmer', 'Greece', 'Aetna'),
('41905832798', 'Hannah', 'Müller', 'Elias', '2007-04-04', 'Male', 104.38, 1.67, '1 Main St, Germany', '1516365367', 'hannah.müller661@example.com', 'Programmer', 'Germany', 'Bupa'),
('42024292887', 'Georgios', 'Pappas', 'Konstantinos', '1958-12-24', 'Female', 96.72, 1.55, '184 Main St, Greece', '6905158412', 'georgios.pappas839@example.com', 'Teacher', 'Greece', 'Allianz'),
('42691538176', 'Elias', 'Meyer', 'Finn', '2015-09-26', 'Male', 69.69, 1.76, '1 Main St, Germany', '1539952595', 'elias.meyer950@example.com', 'Doctor', 'Germany', 'AXA'),
('43270879960', 'Maria', 'Nikolaidis', 'Ioannis', '1952-01-30', 'Male', 83.76, 1.60, '93 Main St, Greece', '6943271338', 'maria.nikolaidis591@example.com', 'Doctor', 'Greece', 'Aetna'),
('43462540363', 'Oliver', 'Wilson', 'Harry', '2017-09-07', 'Male', 82.15, 1.61, '196 Main St, United Kingdom', '0740709227', 'oliver.wilson711@example.com', 'Unemployed', 'United Kingdom', 'National Health System'),
('43517081864', 'Hannah', 'Wagner', 'Leon', '1999-06-07', 'Female', 91.69, 1.54, '57 Main St, Germany', '1595420186', 'hannah.wagner717@example.com', 'Artist', 'Germany', 'Aetna'),
('43587975968', 'Nikolaos', 'Angelopoulos', 'Ioannis', '1983-04-06', 'Female', 83.68, 1.68, '104 Main St, Greece', '6980183066', 'nikolaos.angelopoulos520@example.com', 'Doctor', 'Greece', 'AXA'),
('43746874621', 'Olivia', 'Williams', 'Ava', '1984-10-23', 'Male', 100.54, 1.75, '71 Main St, United Kingdom', '0744066196', 'olivia.williams31@example.com', 'Nurse', 'United Kingdom', 'MetLife'),
('43797379547', 'Harry', 'Jones', 'Jack', '2011-08-21', 'Male', 78.92, 1.60, '54 Main St, United Kingdom', '0778551180', 'harry.jones145@example.com', 'Accountant', 'United Kingdom', 'AXA'),
('43904409851', 'Anna', 'Meyer', 'Sofia', '1957-04-10', 'Female', 62.17, 1.93, '120 Main St, Germany', '1594859387', 'anna.meyer760@example.com', 'Programmer', 'Germany', 'Allianz'),
('43946956730', 'Vasiliki', 'Angelopoulos', 'Dimitrios', '1998-10-07', 'Female', 82.56, 1.66, '75 Main St, Greece', '6987851439', 'vasiliki.angelopoulos695@example.com', 'Unemployed', 'Greece', 'Bupa'),
('44600847004', 'Liam', 'Johnson', 'Ava', '1996-06-27', 'Male', 83.16, 1.76, '1 Main St, USA', '5554851072', 'liam.johnson895@example.com', 'Doctor', 'USA', 'AXA'),
('44620433067', 'Eleni', 'Papadopoulos', 'Aikaterini', '2006-06-24', 'Male', 101.52, 1.80, '104 Main St, Greece', '6985709400', 'eleni.papadopoulos367@example.com', 'Chef', 'Greece', 'Blue Cross'),
('45028376491', 'Isla', 'Davies', 'Mia', '1973-08-11', 'Female', 72.30, 1.95, '68 Main St, United Kingdom', '0772955903', 'isla.davies880@example.com', 'Architect', 'United Kingdom', 'MetLife'),
('45088272344', 'James', 'Martinez', 'Noah', '1974-05-17', 'Male', 60.59, 1.60, '186 Main St, USA', '5536498000', 'james.martinez594@example.com', 'Engineer', 'USA', 'Allianz'),
('46346835044', 'Oliver', 'Brown', 'Oliver', '1997-06-08', 'Male', 55.59, 1.60, '79 Main St, United Kingdom', '0715329873', 'oliver.brown928@example.com', 'Nurse', 'United Kingdom', 'Blue Cross'),
('46538654137', 'George', 'Evans', 'Isla', '1977-12-14', 'Female', 102.97, 1.89, '156 Main St, United Kingdom', '0710105162', 'george.evans323@example.com', 'Engineer', 'United Kingdom', 'National Health System'),
('46845373398', 'Georgios', 'Dimitriou', 'Dimitrios', '1979-01-06', 'Male', 78.16, 1.85, '159 Main St, Greece', '6914075839', 'georgios.dimitriou57@example.com', 'Teacher', 'Greece', 'National Health System'),
('46950696475', 'Maria', 'Vlachos', 'Maria', '1974-10-05', 'Female', 53.29, 1.66, '23 Main St, Greece', '6964508098', 'maria.vlachos183@example.com', 'Accountant', 'Greece', 'Bupa'),
('47558391570', 'Finn', 'Schneider', 'Anna', '1988-11-04', 'Female', 76.34, 1.82, '64 Main St, Germany', '1597355900', 'finn.schneider650@example.com', 'Doctor', 'Germany', 'Blue Cross'),
('47958621002', 'Ava', 'Davis', 'William', '1972-02-02', 'Female', 91.55, 1.57, '47 Main St, USA', '5528179015', 'ava.davis114@example.com', 'Programmer', 'USA', 'Aetna'),
('48099099446', 'William', 'Lopez', 'Noah', '1984-03-17', 'Female', 102.76, 1.61, '7 Main St, USA', '5572946702', 'william.lopez654@example.com', 'Nurse', 'USA', 'AXA'),
('48258809308', 'Nikolaos', 'Angelopoulos', 'Dimitrios', '1996-12-19', 'Female', 93.60, 1.84, '128 Main St, Greece', '6936798843', 'nikolaos.angelopoulos905@example.com', 'Teacher', 'Greece', 'National Health System'),
('48310392728', 'Emma', 'Rodriguez', 'William', '2000-07-11', 'Female', 54.33, 1.52, '186 Main St, USA', '5532061154', 'emma.rodriguez146@example.com', 'Artist', 'USA', 'AXA'),
('50158614883', 'Georgios', 'Papadopoulos', 'Aikaterini', '2001-12-09', 'Female', 82.80, 1.74, '160 Main St, Greece', '6996758799', 'georgios.papadopoulos606@example.com', 'Chef', 'Greece', 'MetLife'),
('50333827805', 'Sophia', 'Johnson', 'Noah', '2014-07-03', 'Female', 98.00, 1.52, '78 Main St, USA', '5500093705', 'sophia.johnson595@example.com', 'Doctor', 'USA', 'Aetna'),
('50665559592', 'Maria', 'Nikolaidis', 'Maria', '2005-06-15', 'Male', 89.38, 1.67, '125 Main St, Greece', '6909162611', 'maria.nikolaidis758@example.com', 'Chef', 'Greece', 'National Health System'),
('50958429891', 'Liam', 'Hernandez', 'Olivia', '1986-11-30', 'Female', 76.49, 1.98, '108 Main St, USA', '5520032998', 'liam.hernandez446@example.com', 'Chef', 'USA', 'Aetna'),
('52427006496', 'Mia', 'Fischer', 'Emma', '2006-07-02', 'Female', 100.67, 1.76, '184 Main St, Germany', '1582038233', 'mia.fischer745@example.com', 'Engineer', 'Germany', 'MetLife'),
('52742804394', 'Liam', 'Martinez', 'Isabella', '1962-07-16', 'Male', 88.23, 1.53, '179 Main St, USA', '5529298838', 'liam.martinez473@example.com', 'Chef', 'USA', 'Blue Cross'),
('52828372045', 'Isla', 'Taylor', 'Mia', '1972-09-01', 'Female', 81.58, 1.94, '90 Main St, United Kingdom', '0797842020', 'isla.taylor86@example.com', 'Chef', 'United Kingdom', 'MetLife'),
('53303834171', 'Jack', 'Smith', 'Harry', '2005-05-10', 'Male', 59.17, 1.94, '47 Main St, United Kingdom', '0735985282', 'jack.smith871@example.com', 'Doctor', 'United Kingdom', 'National Health System'),
('53727380854', 'James', 'Davies', 'James', '1988-09-18', 'Male', 108.25, 1.58, '76 Main St, United Kingdom', '0721124181', 'james.davies438@example.com', 'Nurse', 'United Kingdom', 'Allianz'),
('53759475340', 'Anna', 'Schneider', 'Elias', '1961-04-10', 'Female', 100.85, 1.50, '62 Main St, Germany', '1589721348', 'anna.schneider481@example.com', 'Doctor', 'Germany', 'MetLife'),
('54378035192', 'Noah', 'Lopez', 'Isabella', '2008-03-25', 'Female', 88.19, 1.51, '12 Main St, USA', '5535238224', 'noah.lopez855@example.com', 'Doctor', 'USA', 'Blue Cross'),
('54740853849', 'Vasiliki', 'Angelopoulos', 'Ioannis', '1988-08-21', 'Female', 71.62, 1.78, '170 Main St, Greece', '6981781340', 'vasiliki.angelopoulos761@example.com', 'Unemployed', 'Greece', 'MetLife'),
('55470977692', 'Eleni', 'Dimitriou', 'Konstantinos', '1978-06-17', 'Female', 96.55, 1.72, '141 Main St, Greece', '6995658374', 'eleni.dimitriou459@example.com', 'Engineer', 'Greece', 'Blue Cross'),
('56404457498', 'Isabella', 'Hernandez', 'Olivia', '1995-12-10', 'Male', 93.31, 1.56, '187 Main St, USA', '5511163073', 'isabella.hernandez431@example.com', 'Architect', 'USA', 'Aetna'),
('56410499044', 'Dimitrios', 'Papadopoulos', 'Ioannis', '2010-01-16', 'Male', 95.77, 1.75, '73 Main St, Greece', '6973766903', 'dimitrios.papadopoulos770@example.com', 'Artist', 'Greece', 'Allianz'),
('56776395682', 'Dimitrios', 'Vlachos', 'Aikaterini', '1985-07-11', 'Female', 105.74, 1.55, '115 Main St, Greece', '6948737116', 'dimitrios.vlachos919@example.com', 'Teacher', 'Greece', 'Blue Cross'),
('57357424629', 'Oliver', 'Williams', 'Amelia', '1973-08-05', 'Male', 52.36, 1.91, '76 Main St, United Kingdom', '0735386331', 'oliver.williams698@example.com', 'Artist', 'United Kingdom', 'Allianz'),
('58136118383', 'Sofia', 'Schneider', 'Mia', '1986-03-29', 'Female', 56.69, 1.84, '165 Main St, Germany', '1512464574', 'sofia.schneider808@example.com', 'Teacher', 'Germany', 'Blue Cross'),
('58609010974', 'Ava', 'Lopez', 'Sophia', '1993-09-12', 'Male', 55.20, 1.66, '102 Main St, USA', '5536936837', 'ava.lopez922@example.com', 'Engineer', 'USA', 'AXA'),
('58915667013', 'Mia', 'Schmidt', 'Hannah', '1956-01-27', 'Female', 107.33, 1.63, '144 Main St, Germany', '1591538048', 'mia.schmidt18@example.com', 'Unemployed', 'Germany', 'Blue Cross'),
('58937176387', 'Amelia', 'Jones', 'Ava', '1990-02-08', 'Male', 108.59, 1.69, '150 Main St, United Kingdom', '0758129185', 'amelia.jones751@example.com', 'Teacher', 'United Kingdom', 'MetLife'),
('59094477721', 'James', 'Miller', 'Liam', '1980-05-14', 'Female', 56.67, 1.87, '163 Main St, USA', '5513486955', 'james.miller489@example.com', 'Programmer', 'USA', 'Aetna'),
('59275336415', 'Dimitrios', 'Angelopoulos', 'Nikolaos', '2001-10-12', 'Male', 81.31, 1.68, '33 Main St, Greece', '6976265451', 'dimitrios.angelopoulos757@example.com', 'Accountant', 'Greece', 'Bupa'),
('60287367978', 'Elias', 'Wagner', 'Elias', '1980-01-01', 'Female', 54.33, 1.83, '174 Main St, Germany', '1537778941', 'elias.wagner158@example.com', 'Doctor', 'Germany', 'MetLife'),
('60477265879', 'Lukas', 'Schmidt', 'Emma', '1988-07-11', 'Female', 81.18, 1.66, '171 Main St, Germany', '1544863477', 'lukas.schmidt7@example.com', 'Nurse', 'Germany', 'AXA'),
('61286657072', 'Ava', 'Johnson', 'Isabella', '1985-01-27', 'Male', 51.38, 1.58, '95 Main St, USA', '5588340635', 'ava.johnson463@example.com', 'Unemployed', 'USA', 'Aetna'),
('61399700112', 'Jack', 'Williams', 'Isla', '1987-03-04', 'Male', 50.92, 1.90, '1 Main St, United Kingdom', '0759701268', 'jack.williams515@example.com', 'Teacher', 'United Kingdom', 'Bupa'),
('61621448051', 'Olivia', 'Rodriguez', 'Liam', '1957-12-02', 'Female', 74.35, 1.62, '10 Main St, USA', '5551084960', 'olivia.rodriguez620@example.com', 'Doctor', 'USA', 'AXA'),
('61888878465', 'Sophia', 'Lopez', 'Sophia', '1987-09-15', 'Male', 95.75, 1.90, '152 Main St, USA', '5588840623', 'sophia.lopez461@example.com', 'Engineer', 'USA', 'Blue Cross'),
('62185108330', 'Sofia', 'Papadopoulos', 'Nikolaos', '1971-09-20', 'Female', 88.65, 1.97, '70 Main St, Greece', '6999192092', 'sofia.papadopoulos827@example.com', 'Programmer', 'Greece', 'National Health System'),
('62813540207', 'Lukas', 'Fischer', 'Lukas', '1977-10-28', 'Male', 53.20, 1.61, '48 Main St, Germany', '1528759312', 'lukas.fischer340@example.com', 'Teacher', 'Germany', 'Bupa'),
('63000026156', 'Sophia', 'Hernandez', 'Ava', '2012-08-24', 'Female', 79.56, 1.82, '173 Main St, USA', '5594479466', 'sophia.hernandez846@example.com', 'Teacher', 'USA', 'National Health System'),
('63287727198', 'Konstantinos', 'Papadopoulos', 'Nikolaos', '1983-05-30', 'Female', 88.96, 1.50, '165 Main St, Greece', '6930920911', 'konstantinos.papadopoulos968@example.com', 'Teacher', 'Greece', 'Bupa'),
('63536742347', 'Emma', 'Martinez', 'Liam', '1962-12-11', 'Male', 71.22, 1.93, '149 Main St, USA', '5569364736', 'emma.martinez636@example.com', 'Chef', 'USA', 'Aetna'),
('63631165070', 'Sophia', 'Miller', 'Noah', '1979-02-10', 'Male', 89.93, 1.86, '35 Main St, USA', '5558969802', 'sophia.miller728@example.com', 'Engineer', 'USA', 'Bupa'),
('63697517901', 'James', 'Evans', 'Isla', '1985-02-04', 'Female', 65.80, 1.93, '16 Main St, United Kingdom', '0770844739', 'james.evans705@example.com', 'Programmer', 'United Kingdom', 'MetLife'),
('63900784013', 'Olivia', 'Hernandez', 'Olivia', '1970-12-20', 'Male', 66.94, 1.82, '55 Main St, USA', '5529927919', 'olivia.hernandez167@example.com', 'Artist', 'USA', 'MetLife'),
('64002692386', 'Harry', 'Brown', 'Isla', '2008-06-23', 'Male', 99.85, 1.96, '144 Main St, United Kingdom', '0767528574', 'harry.brown242@example.com', 'Teacher', 'United Kingdom', 'Bupa'),
('64249533646', 'Noah', 'Davis', 'Noah', '2006-04-01', 'Female', 96.95, 1.96, '53 Main St, USA', '5592563158', 'noah.davis202@example.com', 'Nurse', 'USA', 'National Health System'),
('64261077692', 'Aikaterini', 'Angelopoulos', 'Maria', '1975-03-19', 'Female', 87.24, 1.93, '96 Main St, Greece', '6953638464', 'aikaterini.angelopoulos768@example.com', 'Doctor', 'Greece', 'Allianz'),
('64768691212', 'Olivia', 'Taylor', 'James', '1987-01-17', 'Male', 50.32, 1.56, '95 Main St, United Kingdom', '0728213719', 'olivia.taylor414@example.com', 'Chef', 'United Kingdom', 'Bupa'),
('65023793813', 'Noah', 'Garcia', 'Liam', '1950-06-03', 'Male', 77.65, 1.66, '194 Main St, USA', '5521956140', 'noah.garcia913@example.com', 'Architect', 'USA', 'MetLife'),
('65090379063', 'Ioannis', 'Nikolaidis', 'Georgios', '1952-09-28', 'Male', 90.11, 1.91, '100 Main St, Greece', '6968988032', 'ioannis.nikolaidis713@example.com', 'Chef', 'Greece', 'Allianz'),
('65185715300', 'George', 'Davies', 'George', '1991-01-05', 'Male', 74.47, 1.71, '172 Main St, United Kingdom', '0743004187', 'george.davies742@example.com', 'Nurse', 'United Kingdom', 'Bupa'),
('65610545789', 'Sophia', 'Johnson', 'Ava', '1991-04-18', 'Female', 70.19, 1.62, '67 Main St, USA', '5549153360', 'sophia.johnson47@example.com', 'Teacher', 'USA', 'Blue Cross'),
('66045863813', 'Ioannis', 'Georgiou', 'Sofia', '1962-10-18', 'Male', 78.16, 1.60, '167 Main St, Greece', '6982677979', 'ioannis.georgiou131@example.com', 'Accountant', 'Greece', 'AXA'),
('66705195549', 'Isla', 'Williams', 'Oliver', '1967-12-06', 'Female', 82.51, 1.65, '158 Main St, United Kingdom', '0723114133', 'isla.williams823@example.com', 'Artist', 'United Kingdom', 'Bupa'),
('66722869482', 'William', 'Garcia', 'Ava', '1998-02-12', 'Female', 89.93, 1.55, '78 Main St, USA', '5521581626', 'william.garcia386@example.com', 'Chef', 'USA', 'AXA'),
('68561433632', 'Anna', 'Müller', 'Anna', '1986-03-09', 'Male', 76.06, 1.59, '99 Main St, Germany', '1559222977', 'anna.müller886@example.com', 'Nurse', 'Germany', 'AXA'),
('68896323942', 'Hannah', 'Meyer', 'Elias', '1976-12-15', 'Female', 91.33, 1.95, '193 Main St, Germany', '1527062482', 'hannah.meyer189@example.com', 'Nurse', 'Germany', 'AXA'),
('69723514951', 'Noah', 'Davis', 'William', '2014-01-01', 'Male', 99.30, 1.61, '108 Main St, USA', '5551168089', 'noah.davis366@example.com', 'Teacher', 'USA', 'Aetna'),
('70009625317', 'Dimitrios', 'Angelopoulos', 'Sofia', '1971-10-01', 'Male', 68.09, 1.51, '42 Main St, Greece', '6968613950', 'dimitrios.angelopoulos220@example.com', 'Accountant', 'Greece', 'AXA'),
('70202805614', 'Anna', 'Becker', 'Anna', '1971-04-16', 'Female', 95.78, 1.83, '24 Main St, Germany', '1588936347', 'anna.becker731@example.com', 'Nurse', 'Germany', 'National Health System'),
('70223184360', 'Emma', 'Wagner', 'Elias', '1994-03-14', 'Male', 87.45, 1.90, '129 Main St, Germany', '1557848750', 'emma.wagner764@example.com', 'Chef', 'Germany', 'Allianz'),
('70505662730', 'Sofia', 'Wagner', 'Hannah', '1971-04-19', 'Male', 55.05, 1.75, '131 Main St, Germany', '1552600608', 'sofia.wagner82@example.com', 'Teacher', 'Germany', 'Aetna'),
('71328381466', 'Liam', 'Hernandez', 'Noah', '1988-03-28', 'Female', 66.62, 1.91, '2 Main St, USA', '5518295223', 'liam.hernandez91@example.com', 'Nurse', 'USA', 'Allianz'),
('71346626348', 'James', 'Evans', 'Mia', '1991-09-05', 'Female', 103.96, 1.52, '163 Main St, United Kingdom', '0764287733', 'james.evans750@example.com', 'Engineer', 'United Kingdom', 'National Health System'),
('71532667793', 'Ioannis', 'Pappas', 'Nikolaos', '1988-06-19', 'Male', 69.84, 1.64, '4 Main St, Greece', '6987757711', 'ioannis.pappas288@example.com', 'Architect', 'Greece', 'AXA'),
('71753735622', 'Leon', 'Weber', 'Anna', '1965-01-17', 'Male', 100.62, 1.99, '108 Main St, Germany', '1509826964', 'leon.weber199@example.com', 'Nurse', 'Germany', 'Blue Cross'),
('72276731641', 'Ioannis', 'Pappas', 'Aikaterini', '2009-10-11', 'Female', 94.81, 1.93, '50 Main St, Greece', '6990920906', 'ioannis.pappas849@example.com', 'Doctor', 'Greece', 'MetLife'),
('72324670983', 'Ava', 'Taylor', 'Isla', '1953-02-24', 'Male', 52.41, 1.79, '57 Main St, United Kingdom', '0763666988', 'ava.taylor383@example.com', 'Architect', 'United Kingdom', 'Allianz'),
('72392870508', 'William', 'Hernandez', 'Isabella', '1950-10-23', 'Male', 107.94, 1.72, '198 Main St, USA', '5513023499', 'william.hernandez475@example.com', 'Unemployed', 'USA', 'Aetna'),
('72679682259', 'Olivia', 'Lopez', 'Emma', '1973-06-12', 'Male', 76.52, 1.73, '198 Main St, USA', '5507934818', 'olivia.lopez839@example.com', 'Architect', 'USA', 'Bupa'),
('72987441059', 'Jack', 'Taylor', 'Mia', '1960-02-15', 'Male', 102.00, 1.77, '145 Main St, United Kingdom', '0730209114', 'jack.taylor702@example.com', 'Doctor', 'United Kingdom', 'Aetna'),
('73036737592', 'Lukas', 'Müller', 'Mia', '2008-07-18', 'Female', 107.96, 1.83, '36 Main St, Germany', '1595406063', 'lukas.müller853@example.com', 'Engineer', 'Germany', 'Bupa'),
('73675848566', 'Sophia', 'Lopez', 'Olivia', '1970-01-26', 'Female', 85.81, 1.60, '77 Main St, USA', '5537456814', 'sophia.lopez312@example.com', 'Programmer', 'USA', 'Blue Cross'),
('73730080923', 'Ava', 'Davis', 'Emma', '1967-06-26', 'Female', 65.50, 1.94, '138 Main St, USA', '5565128023', 'ava.davis200@example.com', 'Engineer', 'USA', 'National Health System'),
('73782829386', 'Finn', 'Fischer', 'Emma', '1981-12-16', 'Female', 51.90, 1.79, '109 Main St, Germany', '1581596838', 'finn.fischer188@example.com', 'Nurse', 'Germany', 'National Health System'),
('73907757311', 'Jack', 'Evans', 'Harry', '1981-11-29', 'Male', 73.97, 1.58, '74 Main St, United Kingdom', '0743560683', 'jack.evans505@example.com', 'Chef', 'United Kingdom', 'Allianz'),
('74271905654', 'Anna', 'Meyer', 'Sofia', '1953-11-09', 'Male', 70.47, 1.99, '37 Main St, Germany', '1511011013', 'anna.meyer413@example.com', 'Teacher', 'Germany', 'Bupa'),
('74800180951', 'William', 'Hernandez', 'Isabella', '1981-04-07', 'Male', 97.71, 1.58, '144 Main St, USA', '5505893243', 'william.hernandez940@example.com', 'Engineer', 'USA', 'Aetna'),
('75123079462', 'Mia', 'Davies', 'Mia', '1975-10-17', 'Male', 51.00, 1.63, '39 Main St, United Kingdom', '0786454534', 'mia.davies854@example.com', 'Teacher', 'United Kingdom', 'Blue Cross'),
('75155338022', 'Eleni', 'Angelopoulos', 'Konstantinos', '2009-07-09', 'Female', 97.92, 1.75, '23 Main St, Greece', '6921253258', 'eleni.angelopoulos241@example.com', 'Artist', 'Greece', 'Bupa'),
('75388488628', 'Aikaterini', 'Papadopoulos', 'Dimitrios', '2011-05-04', 'Male', 50.36, 1.96, '69 Main St, Greece', '6957075193', 'aikaterini.papadopoulos70@example.com', 'Engineer', 'Greece', 'Bupa'),
('75521368046', 'Isabella', 'Garcia', 'James', '1973-12-28', 'Male', 69.46, 1.59, '6 Main St, USA', '5502557106', 'isabella.garcia32@example.com', 'Doctor', 'USA', 'Aetna'),
('76004874263', 'Noah', 'Garcia', 'Liam', '2007-10-29', 'Female', 108.26, 1.74, '86 Main St, USA', '5502189748', 'noah.garcia449@example.com', 'Architect', 'USA', 'Blue Cross'),
('76601327924', 'William', 'Davis', 'Emma', '1982-06-26', 'Female', 52.90, 1.59, '167 Main St, USA', '5597841761', 'william.davis589@example.com', 'Artist', 'USA', 'MetLife'),
('77518670105', 'Olivia', 'Smith', 'Ava', '2014-01-16', 'Female', 76.13, 1.91, '56 Main St, United Kingdom', '0787861089', 'olivia.smith612@example.com', 'Nurse', 'United Kingdom', 'Aetna'),
('77996419068', 'Harry', 'Jones', 'Jack', '1967-11-07', 'Female', 89.73, 1.68, '115 Main St, United Kingdom', '0747491987', 'harry.jones109@example.com', 'Architect', 'United Kingdom', 'National Health System'),
('78268904370', 'Finn', 'Weber', 'Emma', '2006-10-29', 'Male', 63.32, 1.76, '89 Main St, Germany', '1533493911', 'finn.weber985@example.com', 'Doctor', 'Germany', 'AXA'),
('78431894515', 'William', 'Martinez', 'Sophia', '1966-07-12', 'Male', 89.64, 1.79, '172 Main St, USA', '5594523943', 'william.martinez845@example.com', 'Programmer', 'USA', 'AXA'),
('78836360786', 'Dimitrios', 'Georgiou', 'Aikaterini', '1952-01-01', 'Male', 99.42, 1.64, '128 Main St, Greece', '6938602869', 'dimitrios.georgiou904@example.com', 'Programmer', 'Greece', 'Bupa'),
('79021014489', 'Mia', 'Becker', 'Mia', '1963-11-20', 'Male', 60.56, 1.95, '65 Main St, Germany', '1510203341', 'mia.becker22@example.com', 'Unemployed', 'Germany', 'MetLife'),
('79900257514', 'George', 'Wilson', 'Olivia', '2000-03-30', 'Female', 107.42, 1.51, '34 Main St, United Kingdom', '0773789232', 'george.wilson845@example.com', 'Unemployed', 'United Kingdom', 'Bupa'),
('81126541784', 'Olivia', 'Garcia', 'William', '1960-10-23', 'Female', 56.81, 1.80, '197 Main St, USA', '5549539429', 'olivia.garcia473@example.com', 'Teacher', 'USA', 'Bupa'),
('82708987479', 'Lukas', 'Meyer', 'Leon', '2008-12-17', 'Male', 61.59, 1.58, '81 Main St, Germany', '1599771152', 'lukas.meyer570@example.com', 'Teacher', 'Germany', 'National Health System'),
('83093159066', 'Olivia', 'Garcia', 'James', '1973-09-09', 'Male', 82.94, 1.81, '11 Main St, USA', '5573215161', 'olivia.garcia238@example.com', 'Accountant', 'USA', 'Aetna'),
('83534668447', 'Jack', 'Brown', 'Isla', '1980-10-20', 'Male', 80.19, 1.75, '37 Main St, United Kingdom', '0725129619', 'jack.brown636@example.com', 'Nurse', 'United Kingdom', 'MetLife'),
('83561993190', 'James', 'Rodriguez', 'William', '2017-06-16', 'Male', 54.42, 1.53, '44 Main St, USA', '5564131548', 'james.rodriguez238@example.com', 'Nurse', 'USA', 'Blue Cross'),
('84170905910', 'Elias', 'Fischer', 'Sofia', '2009-04-10', 'Female', 78.41, 1.63, '137 Main St, Germany', '1588737178', 'elias.fischer760@example.com', 'Architect', 'Germany', 'National Health System'),
('84260311950', 'Sofia', 'Papadopoulos', 'Vasiliki', '1998-01-13', 'Male', 87.29, 1.88, '148 Main St, Greece', '6996760180', 'sofia.papadopoulos14@example.com', 'Doctor', 'Greece', 'Aetna'),
('84361217828', 'Dimitrios', 'Georgiou', 'Ioannis', '1984-09-23', 'Male', 82.21, 1.92, '198 Main St, Greece', '6938133778', 'dimitrios.georgiou788@example.com', 'Chef', 'Greece', 'Bupa'),
('84367566710', 'Emma', 'Miller', 'Olivia', '2002-03-21', 'Male', 103.89, 1.55, '27 Main St, USA', '5504582289', 'emma.miller127@example.com', 'Chef', 'USA', 'Allianz'),
('85080989954', 'Sophia', 'Garcia', 'James', '1977-10-16', 'Female', 72.80, 1.76, '42 Main St, USA', '5594732785', 'sophia.garcia25@example.com', 'Artist', 'USA', 'Allianz'),
('85137285825', 'James', 'Garcia', 'Sophia', '2004-06-11', 'Male', 62.42, 1.94, '196 Main St, USA', '5582607077', 'james.garcia420@example.com', 'Chef', 'USA', 'AXA'),
('85189892779', 'Sofia', 'Papadopoulos', 'Maria', '1964-05-21', 'Female', 74.87, 1.75, '185 Main St, Greece', '6988169076', 'sofia.papadopoulos28@example.com', 'Doctor', 'Greece', 'Bupa'),
('85419807455', 'William', 'Davis', 'Noah', '1997-12-06', 'Male', 75.55, 1.54, '30 Main St, USA', '5560375480', 'william.davis729@example.com', 'Engineer', 'USA', 'Allianz'),
('85590427164', 'Isla', 'Wilson', 'Olivia', '2018-05-12', 'Female', 60.55, 1.97, '145 Main St, United Kingdom', '0766057313', 'isla.wilson351@example.com', 'Unemployed', 'United Kingdom', 'Allianz'),
('85667178954', 'Liam', 'Rodriguez', 'Sophia', '1961-07-25', 'Male', 105.11, 1.82, '103 Main St, USA', '5577120745', 'liam.rodriguez559@example.com', 'Chef', 'USA', 'National Health System'),
('86388104543', 'George', 'Brown', 'Jack', '1953-11-30', 'Female', 97.63, 1.64, '123 Main St, United Kingdom', '0703491947', 'george.brown676@example.com', 'Architect', 'United Kingdom', 'Blue Cross'),
('86707313530', 'Harry', 'Taylor', 'Ava', '1968-09-29', 'Female', 88.52, 1.92, '57 Main St, United Kingdom', '0783556181', 'harry.taylor195@example.com', 'Unemployed', 'United Kingdom', 'MetLife'),
('87143524582', 'Leon', 'Schneider', 'Anna', '2018-05-19', 'Male', 63.21, 1.77, '198 Main St, Germany', '1562769056', 'leon.schneider92@example.com', 'Architect', 'Germany', 'Allianz'),
('87217547171', 'Nikolaos', 'Papadopoulos', 'Nikolaos', '1991-01-11', 'Male', 61.18, 1.88, '181 Main St, Greece', '6955458284', 'nikolaos.papadopoulos104@example.com', 'Nurse', 'Greece', 'Bupa'),
('87355757819', 'Ava', 'Smith', 'James', '1965-10-02', 'Female', 83.31, 1.72, '2 Main St, United Kingdom', '0751194101', 'ava.smith418@example.com', 'Chef', 'United Kingdom', 'National Health System'),
('87732236553', 'James', 'Martinez', 'James', '2003-12-15', 'Male', 77.86, 1.96, '64 Main St, USA', '5544399637', 'james.martinez551@example.com', 'Unemployed', 'USA', 'National Health System'),
('87852384521', 'William', 'Garcia', 'Emma', '1961-05-27', 'Male', 58.69, 1.58, '46 Main St, USA', '5555697627', 'william.garcia549@example.com', 'Chef', 'USA', 'Aetna'),
('87987860559', 'Leon', 'Becker', 'Mia', '2018-02-22', 'Male', 103.35, 1.88, '3 Main St, Germany', '1556907324', 'leon.becker873@example.com', 'Doctor', 'Germany', 'National Health System'),
('88386311562', 'Amelia', 'Taylor', 'Olivia', '1956-07-18', 'Male', 52.37, 1.83, '139 Main St, United Kingdom', '0755018494', 'amelia.taylor696@example.com', 'Nurse', 'United Kingdom', 'Aetna'),
('88566018360', 'Elias', 'Fischer', 'Leon', '2017-02-14', 'Female', 90.18, 1.74, '200 Main St, Germany', '1562228931', 'elias.fischer894@example.com', 'Engineer', 'Germany', 'AXA'),
('89019803896', 'Mia', 'Wilson', 'Olivia', '1977-11-22', 'Female', 51.95, 1.51, '181 Main St, United Kingdom', '0725921001', 'mia.wilson581@example.com', 'Artist', 'United Kingdom', 'Aetna'),
('89516503973', 'Isabella', 'Lopez', 'Liam', '2010-05-19', 'Male', 104.01, 1.75, '138 Main St, USA', '5523453406', 'isabella.lopez41@example.com', 'Teacher', 'USA', 'Aetna'),
('89542013881', 'Ioannis', 'Georgiou', 'Sofia', '1988-05-20', 'Female', 53.42, 1.74, '31 Main St, Greece', '6992953392', 'ioannis.georgiou363@example.com', 'Chef', 'Greece', 'MetLife'),
('89599308800', 'Nikolaos', 'Vlachos', 'Maria', '1961-03-29', 'Male', 81.42, 1.60, '87 Main St, Greece', '6942639082', 'nikolaos.vlachos88@example.com', 'Architect', 'Greece', 'National Health System'),
('89661145523', 'Olivia', 'Smith', 'Harry', '1975-11-11', 'Male', 89.71, 1.68, '196 Main St, United Kingdom', '0790752136', 'olivia.smith431@example.com', 'Architect', 'United Kingdom', 'National Health System'),
('89748080684', 'Ioannis', 'Georgiou', 'Eleni', '2015-05-14', 'Female', 89.06, 1.53, '124 Main St, Greece', '6911939239', 'ioannis.georgiou448@example.com', 'Architect', 'Greece', 'Aetna'),
('89970814238', 'Anna', 'Meyer', 'Anna', '2004-03-16', 'Male', 65.59, 1.64, '170 Main St, Germany', '1506499522', 'anna.meyer620@example.com', 'Programmer', 'Germany', 'Aetna'),
('90374114140', 'Hannah', 'Schneider', 'Finn', '1973-01-01', 'Female', 104.53, 1.90, '102 Main St, Germany', '1539655204', 'hannah.schneider280@example.com', 'Teacher', 'Germany', 'Bupa');
INSERT INTO `patient` (`AMKA`, `first_name`, `last_name`, `father_name`, `date_of_birth`, `gender`, `weight`, `height`, `address`, `phone_number`, `email`, `profession`, `nationality`, `insurance_provider`) VALUES
('90768769760', 'Elias', 'Müller', 'Emma', '1986-02-03', 'Male', 107.74, 1.85, '89 Main St, Germany', '1514807629', 'elias.müller554@example.com', 'Artist', 'Germany', 'National Health System'),
('90860545004', 'James', 'Johnson', 'Liam', '1990-07-20', 'Female', 98.33, 1.53, '154 Main St, USA', '5590143340', 'james.johnson484@example.com', 'Engineer', 'USA', 'Allianz'),
('91404407853', 'Georgios', 'Dimitriou', 'Eleni', '2012-10-30', 'Female', 80.32, 1.55, '61 Main St, Greece', '6956534088', 'georgios.dimitriou99@example.com', 'Architect', 'Greece', 'MetLife'),
('91658227451', 'Maria', 'Georgiou', 'Georgios', '1996-02-21', 'Male', 79.81, 1.62, '52 Main St, Greece', '6915965552', 'maria.georgiou572@example.com', 'Accountant', 'Greece', 'MetLife'),
('91798049336', 'Vasiliki', 'Vlachos', 'Eleni', '1965-07-14', 'Female', 53.60, 1.60, '147 Main St, Greece', '6998811234', 'vasiliki.vlachos420@example.com', 'Teacher', 'Greece', 'Allianz'),
('91834045869', 'William', 'Martinez', 'Isabella', '1984-09-29', 'Male', 86.45, 1.58, '168 Main St, USA', '5507108645', 'william.martinez661@example.com', 'Doctor', 'USA', 'Blue Cross'),
('92348875633', 'Isla', 'Davies', 'Amelia', '2008-09-19', 'Female', 107.11, 1.62, '25 Main St, United Kingdom', '0781112203', 'isla.davies688@example.com', 'Chef', 'United Kingdom', 'AXA'),
('92816296873', 'Emma', 'Meyer', 'Mia', '2007-10-18', 'Male', 79.10, 1.73, '156 Main St, Germany', '1518684584', 'emma.meyer923@example.com', 'Programmer', 'Germany', 'Aetna'),
('92951962296', 'Noah', 'Davis', 'Ava', '1985-07-14', 'Female', 94.31, 1.67, '103 Main St, USA', '5599378100', 'noah.davis212@example.com', 'Programmer', 'USA', 'Allianz'),
('93059821383', 'Leon', 'Schneider', 'Lukas', '1963-08-23', 'Female', 85.12, 1.83, '195 Main St, Germany', '1544269990', 'leon.schneider881@example.com', 'Teacher', 'Germany', 'Blue Cross'),
('93134161651', 'Eleni', 'Papadopoulos', 'Konstantinos', '1985-03-25', 'Male', 99.25, 1.86, '48 Main St, Greece', '6988868722', 'eleni.papadopoulos20@example.com', 'Chef', 'Greece', 'Aetna'),
('93155438517', 'Emma', 'Martinez', 'Ava', '1986-02-23', 'Male', 84.37, 1.87, '177 Main St, USA', '5516390850', 'emma.martinez922@example.com', 'Nurse', 'USA', 'Aetna'),
('93364976061', 'Vasiliki', 'Karagiannis', 'Maria', '1951-03-11', 'Female', 87.23, 1.95, '178 Main St, Greece', '6999420231', 'vasiliki.karagiannis363@example.com', 'Architect', 'Greece', 'Allianz'),
('93778552931', 'James', 'Garcia', 'Ava', '1997-08-20', 'Female', 75.11, 1.70, '73 Main St, USA', '5514617020', 'james.garcia666@example.com', 'Teacher', 'USA', 'Bupa'),
('94438577754', 'Harry', 'Evans', 'James', '1956-09-11', 'Male', 55.22, 1.92, '57 Main St, United Kingdom', '0708818704', 'harry.evans631@example.com', 'Engineer', 'United Kingdom', 'AXA'),
('94837228854', 'Mia', 'Brown', 'Jack', '2013-04-22', 'Female', 104.94, 1.67, '89 Main St, United Kingdom', '0778250033', 'mia.brown754@example.com', 'Chef', 'United Kingdom', 'MetLife'),
('95668344254', 'Ioannis', 'Vlachos', 'Nikolaos', '1997-12-08', 'Female', 77.44, 1.92, '164 Main St, Greece', '6951915234', 'ioannis.vlachos637@example.com', 'Chef', 'Greece', 'Aetna'),
('95904778313', 'Harry', 'Brown', 'George', '2006-04-04', 'Male', 97.13, 1.54, '59 Main St, United Kingdom', '0721317517', 'harry.brown660@example.com', 'Architect', 'United Kingdom', 'Bupa'),
('96883383141', 'Sophia', 'Miller', 'Sophia', '2016-02-14', 'Female', 69.30, 1.67, '149 Main St, USA', '5557146494', 'sophia.miller244@example.com', 'Accountant', 'USA', 'National Health System'),
('96986160181', 'Leon', 'Weber', 'Sofia', '1969-10-27', 'Female', 105.30, 1.61, '123 Main St, Germany', '1543107433', 'leon.weber981@example.com', 'Nurse', 'Germany', 'AXA'),
('97279103800', 'Dimitrios', 'Papadopoulos', 'Nikolaos', '2016-08-05', 'Male', 63.65, 1.65, '1 Main St, Greece', '6964853982', 'dimitrios.papadopoulos452@example.com', 'Accountant', 'Greece', 'National Health System'),
('97499014271', 'Lukas', 'Meyer', 'Mia', '1988-02-05', 'Female', 91.57, 1.74, '102 Main St, Germany', '1565415904', 'lukas.meyer564@example.com', 'Artist', 'Germany', 'AXA'),
('97542332780', 'James', 'Martinez', 'Ava', '2006-09-02', 'Female', 106.67, 1.98, '117 Main St, USA', '5512695879', 'james.martinez612@example.com', 'Programmer', 'USA', 'National Health System'),
('97652145031', 'Amelia', 'Brown', 'Harry', '1988-07-17', 'Female', 63.33, 1.63, '129 Main St, United Kingdom', '0741660354', 'amelia.brown866@example.com', 'Accountant', 'United Kingdom', 'AXA'),
('97755426502', 'Eleni', 'Angelopoulos', 'Sofia', '2015-08-13', 'Female', 80.38, 1.56, '177 Main St, Greece', '6905714929', 'eleni.angelopoulos953@example.com', 'Nurse', 'Greece', 'National Health System'),
('97817116892', 'Maria', 'Karagiannis', 'Dimitrios', '1951-11-05', 'Male', 88.06, 1.60, '4 Main St, Greece', '6902150752', 'maria.karagiannis474@example.com', 'Accountant', 'Greece', 'Allianz'),
('97899306247', 'Oliver', 'Smith', 'Amelia', '1963-10-16', 'Male', 70.73, 1.93, '178 Main St, United Kingdom', '0761516800', 'oliver.smith146@example.com', 'Teacher', 'United Kingdom', 'Bupa'),
('98206711903', 'Emma', 'Hernandez', 'Sophia', '1998-07-04', 'Male', 61.07, 1.67, '173 Main St, USA', '5503868859', 'emma.hernandez882@example.com', 'Doctor', 'USA', 'MetLife'),
('98438055215', 'Emma', 'Hernandez', 'Sophia', '2017-12-08', 'Male', 106.93, 1.83, '2 Main St, USA', '5505386463', 'emma.hernandez786@example.com', 'Architect', 'USA', 'AXA'),
('98885610482', 'Georgios', 'Angelopoulos', 'Nikolaos', '2012-05-01', 'Female', 52.70, 1.52, '82 Main St, Greece', '6978344730', 'georgios.angelopoulos623@example.com', 'Artist', 'Greece', 'MetLife'),
('98995001290', 'Ava', 'Davis', 'Olivia', '1992-11-17', 'Male', 98.17, 1.93, '40 Main St, USA', '5545215196', 'ava.davis351@example.com', 'Programmer', 'USA', 'Blue Cross'),
('99220715370', 'Liam', 'Rodriguez', 'Olivia', '1994-06-23', 'Male', 95.37, 1.99, '127 Main St, USA', '5528371687', 'liam.rodriguez156@example.com', 'Unemployed', 'USA', 'MetLife'),
('99247070919', 'Lukas', 'Becker', 'Finn', '2010-01-18', 'Male', 97.24, 1.57, '83 Main St, Germany', '1501677764', 'lukas.becker844@example.com', 'Chef', 'Germany', 'AXA'),
('99893583411', 'Sofia', 'Weber', 'Sofia', '1997-03-15', 'Female', 105.62, 1.85, '173 Main St, Germany', '1596670819', 'sofia.weber692@example.com', 'Architect', 'Germany', 'Bupa');

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
  `medical_procedure_id` int(11) NOT NULL
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
        ON mp_existing.id = shmp.medical_procedure_id
    JOIN Medical_Procedure mp_new 
        ON mp_new.id = NEW.medical_procedure_id
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
            ON mp_existing.id = shmp.medical_procedure_id
        JOIN Medical_Procedure mp_new 
            ON mp_new.id = NEW.medical_procedure_id
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
  ADD KEY `drug_ibfk_1` (`substance_name`);

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
  ADD PRIMARY KEY (`id`),
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
  ADD KEY `Staff_Helps_Medical_Procedure_ibfk_2` (`medical_procedure_id`);

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
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

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
-- AUTO_INCREMENT for table `medical_procedure`
--
ALTER TABLE `medical_procedure`
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
  ADD CONSTRAINT `Staff_Helps_Medical_Procedure_ibfk_1` FOREIGN KEY (`staff_amka`) REFERENCES `staff` (`AMKA`),
  ADD CONSTRAINT `Staff_Helps_Medical_Procedure_ibfk_2` FOREIGN KEY (`medical_procedure_id`) REFERENCES `medical_procedure` (`id`) ON DELETE CASCADE;

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

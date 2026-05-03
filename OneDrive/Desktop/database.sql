-- MariaDB dump 10.19  Distrib 10.4.32-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: hospital
-- ------------------------------------------------------
-- Server version	10.4.32-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `admin_staff`
--

DROP TABLE IF EXISTS `admin_staff`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_staff` (
  `AMKA` char(11) NOT NULL,
  `role` varchar(30) NOT NULL,
  `office` varchar(50) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  PRIMARY KEY (`AMKA`),
  KEY `department_name` (`department_name`),
  CONSTRAINT `admin_staff_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `admin_staff_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`AMKA` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_staff`
--

LOCK TABLES `admin_staff` WRITE;
/*!40000 ALTER TABLE `admin_staff` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_staff` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_staff_works_shift`
--

DROP TABLE IF EXISTS `admin_staff_works_shift`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `admin_staff_works_shift` (
  `admin_staff_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL,
  PRIMARY KEY (`admin_staff_amka`,`shift_id`),
  KEY `shift_id` (`shift_id`),
  CONSTRAINT `admin_staff_works_shift_ibfk_1` FOREIGN KEY (`admin_staff_amka`) REFERENCES `admin_staff` (`AMKA`),
  CONSTRAINT `admin_staff_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`admin_staff_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_staff_works_shift`
--

LOCK TABLES `admin_staff_works_shift` WRITE;
/*!40000 ALTER TABLE `admin_staff_works_shift` DISABLE KEYS */;
/*!40000 ALTER TABLE `admin_staff_works_shift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `bed`
--

DROP TABLE IF EXISTS `bed`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `bed` (
  `number` int(11) NOT NULL AUTO_INCREMENT,
  `bed_type` varchar(50) NOT NULL,
  `bed_status` varchar(20) NOT NULL DEFAULT 'available',
  `department_name` varchar(50) NOT NULL,
  PRIMARY KEY (`number`),
  KEY `department_name` (`department_name`),
  CONSTRAINT `bed_ibfk_1` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  CONSTRAINT `chk_status` CHECK (`bed_status` in ('occupied','available','maintenance')),
  CONSTRAINT `chk_type` CHECK (`bed_type` in ('ICU','single-bed','multi-bed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `bed`
--

LOCK TABLES `bed` WRITE;
/*!40000 ALTER TABLE `bed` DISABLE KEYS */;
/*!40000 ALTER TABLE `bed` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cost`
--

DROP TABLE IF EXISTS `cost`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cost` (
  `KEN_code` varchar(5) NOT NULL,
  `average_hospitalization_duration` smallint(5) unsigned NOT NULL,
  `basic_cost` decimal(10,2) NOT NULL,
  PRIMARY KEY (`KEN_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cost`
--

LOCK TABLES `cost` WRITE;
/*!40000 ALTER TABLE `cost` DISABLE KEYS */;
/*!40000 ALTER TABLE `cost` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `department`
--

DROP TABLE IF EXISTS `department`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `department` (
  `name` varchar(50) NOT NULL,
  `description` varchar(200) NOT NULL,
  `number_of_beds` int(11) NOT NULL,
  `floor` varchar(20) NOT NULL,
  `building` varchar(50) NOT NULL,
  `doctor_amka` char(11) NOT NULL,
  PRIMARY KEY (`name`),
  KEY `doctor_amka` (`doctor_amka`),
  CONSTRAINT `department_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `chk_floor` CHECK (`floor` in ('ground floor','first floor','second floor','third floor','fourth floor','fifth floor','sixth floor')),
  CONSTRAINT `chk_building` CHECK (`building` in ('Ward A','Ward B','Ward C','Ward D'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `department`
--

LOCK TABLES `department` WRITE;
/*!40000 ALTER TABLE `department` DISABLE KEYS */;
/*!40000 ALTER TABLE `department` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `diagnosis`
--

DROP TABLE IF EXISTS `diagnosis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `diagnosis` (
  `code` varchar(8) NOT NULL,
  `description` text NOT NULL,
  PRIMARY KEY (`code`),
  UNIQUE KEY `description` (`description`) USING HASH,
  CONSTRAINT `chk_code` CHECK (`code` regexp '^[A-Z][0-9]{2}(\\.[A-Z0-9]{1,4})?$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `diagnosis`
--

LOCK TABLES `diagnosis` WRITE;
/*!40000 ALTER TABLE `diagnosis` DISABLE KEYS */;
/*!40000 ALTER TABLE `diagnosis` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `doctor`
--

DROP TABLE IF EXISTS `doctor`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `doctor` (
  `AMKA` char(11) NOT NULL,
  `license_number` varchar(50) NOT NULL,
  `specialty` varchar(100) NOT NULL,
  `rank` varchar(50) NOT NULL,
  `supervisor_AMKA` char(11) DEFAULT NULL,
  PRIMARY KEY (`AMKA`),
  UNIQUE KEY `license_number` (`license_number`),
  KEY `supervisor_AMKA` (`supervisor_AMKA`),
  CONSTRAINT `doctor_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `doctor_ibfk_2` FOREIGN KEY (`supervisor_AMKA`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `chk_valid_rank` CHECK (`rank` in ('intern','supervisor A','supervisor B','director')),
  CONSTRAINT `chk_valid_amka` CHECK (`AMKA` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `doctor`
--

LOCK TABLES `doctor` WRITE;
/*!40000 ALTER TABLE `doctor` DISABLE KEYS */;
/*!40000 ALTER TABLE `doctor` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `doctor_works_department`
--

DROP TABLE IF EXISTS `doctor_works_department`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `doctor_works_department` (
  `doctor_amka` char(11) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  PRIMARY KEY (`doctor_amka`,`department_name`),
  KEY `department_name` (`department_name`),
  CONSTRAINT `doctor_works_department_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `doctor_works_department_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`doctor_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `doctor_works_department`
--

LOCK TABLES `doctor_works_department` WRITE;
/*!40000 ALTER TABLE `doctor_works_department` DISABLE KEYS */;
/*!40000 ALTER TABLE `doctor_works_department` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `doctor_works_shift`
--

DROP TABLE IF EXISTS `doctor_works_shift`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `doctor_works_shift` (
  `doctor_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL,
  PRIMARY KEY (`doctor_amka`,`shift_id`),
  KEY `shift_id` (`shift_id`),
  CONSTRAINT `doctor_works_shift_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `doctor_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`doctor_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `doctor_works_shift`
--

LOCK TABLES `doctor_works_shift` WRITE;
/*!40000 ALTER TABLE `doctor_works_shift` DISABLE KEYS */;
/*!40000 ALTER TABLE `doctor_works_shift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `drug`
--

DROP TABLE IF EXISTS `drug`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `drug` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `substance_name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`,`substance_name`),
  KEY `substance_name` (`substance_name`),
  CONSTRAINT `drug_ibfk_1` FOREIGN KEY (`substance_name`) REFERENCES `substance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `drug`
--

LOCK TABLES `drug` WRITE;
/*!40000 ALTER TABLE `drug` DISABLE KEYS */;
/*!40000 ALTER TABLE `drug` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `emergency_contact`
--

DROP TABLE IF EXISTS `emergency_contact`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `emergency_contact` (
  `patient_amka` char(11) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `name` varchar(100) NOT NULL,
  PRIMARY KEY (`patient_amka`,`phone`),
  CONSTRAINT `emergency_contact_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `chk_valid_phone` CHECK (`phone` regexp '^[0-9+() -]+$'),
  CONSTRAINT `chk_valid_amka` CHECK (`patient_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `emergency_contact`
--

LOCK TABLES `emergency_contact` WRITE;
/*!40000 ALTER TABLE `emergency_contact` DISABLE KEYS */;
/*!40000 ALTER TABLE `emergency_contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `evaluation`
--

DROP TABLE IF EXISTS `evaluation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `evaluation` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `medical_care_score` smallint(5) unsigned DEFAULT NULL,
  `nursing_care_score` smallint(5) unsigned DEFAULT NULL,
  `cleanliness_score` smallint(5) unsigned DEFAULT NULL,
  `food_score` smallint(5) unsigned DEFAULT NULL,
  `overall_experience_score` smallint(5) unsigned DEFAULT NULL,
  `hospitalization_id` int(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `doctor_amka` char(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `doctor_amka` (`doctor_amka`),
  KEY `patient_amka` (`patient_amka`),
  KEY `hospitalization_id` (`hospitalization_id`),
  CONSTRAINT `evaluation_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `evaluation_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `evaluation_ibfk_3` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_nursing` CHECK (`nursing_care_score` is null or `nursing_care_score` between 1 and 5),
  CONSTRAINT `chk_clean` CHECK (`cleanliness_score` is null or `cleanliness_score` between 1 and 5),
  CONSTRAINT `chk_food` CHECK (`food_score` is null or `food_score` between 1 and 5),
  CONSTRAINT `chk_medical` CHECK (`medical_care_score` is null or `medical_care_score` between 1 and 5),
  CONSTRAINT `chk_overall` CHECK (`overall_experience_score` is null or `overall_experience_score` between 1 and 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `evaluation`
--

LOCK TABLES `evaluation` WRITE;
/*!40000 ALTER TABLE `evaluation` DISABLE KEYS */;
/*!40000 ALTER TABLE `evaluation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hospitalization`
--

DROP TABLE IF EXISTS `hospitalization`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hospitalization` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `admission_date` date NOT NULL,
  `discharge_date` date DEFAULT NULL,
  `total_cost` decimal(10,2) DEFAULT NULL,
  `triage_id` int(11) NOT NULL,
  `bed_number` int(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  `cost_KEN_code` varchar(5) NOT NULL,
  `in_diagnosis_code` varchar(8) NOT NULL,
  `out_diagnosis_code` varchar(8) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `triage_id` (`triage_id`),
  KEY `patient_amka` (`patient_amka`),
  KEY `department_name` (`department_name`),
  KEY `cost_KEN_code` (`cost_KEN_code`),
  KEY `in_diagnosis_code` (`in_diagnosis_code`),
  KEY `out_diagnosis_code` (`out_diagnosis_code`),
  KEY `bed_number` (`bed_number`),
  CONSTRAINT `hospitalization_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`),
  CONSTRAINT `hospitalization_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  CONSTRAINT `hospitalization_ibfk_3` FOREIGN KEY (`triage_id`) REFERENCES `triage` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `hospitalization_ibfk_4` FOREIGN KEY (`cost_KEN_code`) REFERENCES `cost` (`KEN_code`) ON UPDATE CASCADE,
  CONSTRAINT `hospitalization_ibfk_5` FOREIGN KEY (`in_diagnosis_code`) REFERENCES `diagnosis` (`code`) ON UPDATE CASCADE,
  CONSTRAINT `hospitalization_ibfk_6` FOREIGN KEY (`out_diagnosis_code`) REFERENCES `diagnosis` (`code`) ON UPDATE CASCADE,
  CONSTRAINT `hospitalization_ibfk_7` FOREIGN KEY (`bed_number`) REFERENCES `bed` (`number`) ON UPDATE CASCADE,
  CONSTRAINT `chk_dates` CHECK (`discharge_date` is null or `discharge_date` > `admission_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hospitalization`
--

LOCK TABLES `hospitalization` WRITE;
/*!40000 ALTER TABLE `hospitalization` DISABLE KEYS */;
/*!40000 ALTER TABLE `hospitalization` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lab_tests`
--

DROP TABLE IF EXISTS `lab_tests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `lab_tests` (
  `test_code` char(7) NOT NULL,
  `test_type` varchar(50) NOT NULL,
  `conduction_date` date NOT NULL,
  `result` varchar(100) NOT NULL,
  `cost` decimal(10,2) NOT NULL,
  `hospitalization_id` int(11) NOT NULL,
  `doctor_amka` char(11) NOT NULL,
  PRIMARY KEY (`test_code`),
  KEY `doctor_amka` (`doctor_amka`),
  KEY `hospitalization_id` (`hospitalization_id`),
  CONSTRAINT `lab_tests_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `lab_tests_ibfk_2` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lab_tests`
--

LOCK TABLES `lab_tests` WRITE;
/*!40000 ALTER TABLE `lab_tests` DISABLE KEYS */;
/*!40000 ALTER TABLE `lab_tests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `medical_procedure`
--

DROP TABLE IF EXISTS `medical_procedure`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
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
  PRIMARY KEY (`procedure_code`),
  KEY `doctor_amka` (`doctor_amka`),
  KEY `hospitalization_id` (`hospitalization_id`),
  CONSTRAINT `medical_procedure_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `medical_procedure_ibfk_2` FOREIGN KEY (`hospitalization_id`) REFERENCES `hospitalization` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `medical_procedure`
--

LOCK TABLES `medical_procedure` WRITE;
/*!40000 ALTER TABLE `medical_procedure` DISABLE KEYS */;
/*!40000 ALTER TABLE `medical_procedure` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nurse`
--

DROP TABLE IF EXISTS `nurse`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `nurse` (
  `AMKA` char(11) NOT NULL,
  `rank` varchar(50) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  PRIMARY KEY (`AMKA`),
  KEY `department_name` (`department_name`),
  CONSTRAINT `nurse_ibfk_1` FOREIGN KEY (`AMKA`) REFERENCES `staff` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `nurse_ibfk_2` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON UPDATE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`AMKA` regexp '^[0-9]{11}$'),
  CONSTRAINT `chk_valid_rank` CHECK (`rank` in ('staff nurse','senior nurse','supervisor'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nurse`
--

LOCK TABLES `nurse` WRITE;
/*!40000 ALTER TABLE `nurse` DISABLE KEYS */;
/*!40000 ALTER TABLE `nurse` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `nurse_works_shift`
--

DROP TABLE IF EXISTS `nurse_works_shift`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `nurse_works_shift` (
  `nurse_amka` char(11) NOT NULL,
  `shift_id` int(11) NOT NULL,
  PRIMARY KEY (`nurse_amka`,`shift_id`),
  KEY `shift_id` (`shift_id`),
  CONSTRAINT `nurse_works_shift_ibfk_1` FOREIGN KEY (`nurse_amka`) REFERENCES `nurse` (`AMKA`),
  CONSTRAINT `nurse_works_shift_ibfk_2` FOREIGN KEY (`shift_id`) REFERENCES `shift` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`nurse_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `nurse_works_shift`
--

LOCK TABLES `nurse_works_shift` WRITE;
/*!40000 ALTER TABLE `nurse_works_shift` DISABLE KEYS */;
/*!40000 ALTER TABLE `nurse_works_shift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `patient`
--

DROP TABLE IF EXISTS `patient`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
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
  `insurance_provider` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`AMKA`),
  UNIQUE KEY `phone_number` (`phone_number`),
  UNIQUE KEY `email` (`email`),
  CONSTRAINT `chk_patient_gender` CHECK (`gender` in ('Female','Male')),
  CONSTRAINT `chk_phone_length` CHECK (octet_length(`phone_number`) = 10),
  CONSTRAINT `chk_valid_amka` CHECK (`AMKA` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `patient`
--

LOCK TABLES `patient` WRITE;
/*!40000 ALTER TABLE `patient` DISABLE KEYS */;
/*!40000 ALTER TABLE `patient` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `patient_has_allergy`
--

DROP TABLE IF EXISTS `patient_has_allergy`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `patient_has_allergy` (
  `patient_amka` char(11) NOT NULL,
  `substance_name` varchar(50) NOT NULL,
  PRIMARY KEY (`patient_amka`,`substance_name`),
  KEY `substance_name` (`substance_name`),
  CONSTRAINT `patient_has_allergy_ibfk_1` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `patient_has_allergy_ibfk_2` FOREIGN KEY (`substance_name`) REFERENCES `substance` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `patient_has_allergy`
--

LOCK TABLES `patient_has_allergy` WRITE;
/*!40000 ALTER TABLE `patient_has_allergy` DISABLE KEYS */;
/*!40000 ALTER TABLE `patient_has_allergy` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `prescription`
--

DROP TABLE IF EXISTS `prescription`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `prescription` (
  `doctor_amka` char(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `drug_id` int(11) NOT NULL,
  `dosage` varchar(50) NOT NULL,
  `frequency` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  PRIMARY KEY (`doctor_amka`,`patient_amka`,`drug_id`,`start_date`),
  KEY `patient_amka` (`patient_amka`),
  KEY `drug_id` (`drug_id`),
  CONSTRAINT `prescription_ibfk_1` FOREIGN KEY (`doctor_amka`) REFERENCES `doctor` (`AMKA`),
  CONSTRAINT `prescription_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `prescription_ibfk_3` FOREIGN KEY (`drug_id`) REFERENCES `drug` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_valid_pat_amka` CHECK (`patient_amka` regexp '^[0-9]{11}$'),
  CONSTRAINT `chk_valid_doc_amka` CHECK (`doctor_amka` regexp '^[0-9]{11}$'),
  CONSTRAINT `chk_valid_dates` CHECK (`start_date` < `end_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `prescription`
--

LOCK TABLES `prescription` WRITE;
/*!40000 ALTER TABLE `prescription` DISABLE KEYS */;
/*!40000 ALTER TABLE `prescription` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `shift`
--

DROP TABLE IF EXISTS `shift`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `shift` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` date NOT NULL,
  `type` varchar(50) NOT NULL,
  `status` varchar(10) NOT NULL,
  `department_name` varchar(50) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_shift` (`date`,`type`,`department_name`),
  KEY `department_name` (`department_name`),
  CONSTRAINT `shift_ibfk_1` FOREIGN KEY (`department_name`) REFERENCES `department` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `chk_type` CHECK (`type` in ('morning','afternoon','night')),
  CONSTRAINT `chk_status` CHECK (`status` in ('open','closed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `shift`
--

LOCK TABLES `shift` WRITE;
/*!40000 ALTER TABLE `shift` DISABLE KEYS */;
/*!40000 ALTER TABLE `shift` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staff`
--

DROP TABLE IF EXISTS `staff`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staff` (
  `AMKA` char(11) NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `date_of_birth` date NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `hire_date` date NOT NULL,
  `staff_type` varchar(20) NOT NULL,
  PRIMARY KEY (`AMKA`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone_number` (`phone_number`),
  CONSTRAINT `chk_valid_amka` CHECK (`AMKA` regexp '^[0-9]{11}$'),
  CONSTRAINT `chk_valid_phone_number` CHECK (`phone_number` regexp '^[0-9+() -]+$'),
  CONSTRAINT `chk_valid_type` CHECK (`staff_type` in ('doctor','nurse','admin_staff'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staff`
--

LOCK TABLES `staff` WRITE;
/*!40000 ALTER TABLE `staff` DISABLE KEYS */;
/*!40000 ALTER TABLE `staff` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `staff_helps_medical_procedure`
--

DROP TABLE IF EXISTS `staff_helps_medical_procedure`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `staff_helps_medical_procedure` (
  `staff_amka` char(11) NOT NULL,
  `medical_procedure_id` varchar(10) NOT NULL,
  PRIMARY KEY (`staff_amka`,`medical_procedure_id`),
  KEY `medical_procedure_id` (`medical_procedure_id`),
  CONSTRAINT `staff_helps_medical_procedure_ibfk_1` FOREIGN KEY (`staff_amka`) REFERENCES `staff` (`AMKA`),
  CONSTRAINT `staff_helps_medical_procedure_ibfk_2` FOREIGN KEY (`medical_procedure_id`) REFERENCES `medical_procedure` (`procedure_code`) ON DELETE CASCADE,
  CONSTRAINT `chk_valid_amka` CHECK (`staff_amka` regexp '^[0-9]{11}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `staff_helps_medical_procedure`
--

LOCK TABLES `staff_helps_medical_procedure` WRITE;
/*!40000 ALTER TABLE `staff_helps_medical_procedure` DISABLE KEYS */;
/*!40000 ALTER TABLE `staff_helps_medical_procedure` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `substance`
--

DROP TABLE IF EXISTS `substance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `substance` (
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `substance`
--

LOCK TABLES `substance` WRITE;
/*!40000 ALTER TABLE `substance` DISABLE KEYS */;
/*!40000 ALTER TABLE `substance` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `triage`
--

DROP TABLE IF EXISTS `triage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `triage` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `arrival_time` datetime NOT NULL,
  `urgency_level` smallint(1) unsigned NOT NULL,
  `outcome` varchar(50) NOT NULL,
  `nurse_amka` char(11) NOT NULL,
  `patient_amka` char(11) NOT NULL,
  `diagnosis_time` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `nurse_amka` (`nurse_amka`),
  KEY `patient_amka` (`patient_amka`),
  CONSTRAINT `triage_ibfk_1` FOREIGN KEY (`nurse_amka`) REFERENCES `nurse` (`AMKA`),
  CONSTRAINT `triage_ibfk_2` FOREIGN KEY (`patient_amka`) REFERENCES `patient` (`AMKA`) ON DELETE CASCADE,
  CONSTRAINT `chk_level` CHECK (`urgency_level` in (1,2,3,4,5)),
  CONSTRAINT `chk_diagnosis_after_arrival` CHECK (`diagnosis_time` is null or `diagnosis_time` >= `arrival_time`),
  CONSTRAINT `chk_outcome` CHECK (`outcome` in ('Discharge','Referral for hospitalization'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `triage`
--

LOCK TABLES `triage` WRITE;
/*!40000 ALTER TABLE `triage` DISABLE KEYS */;
/*!40000 ALTER TABLE `triage` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-05-03 15:43:43

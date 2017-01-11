--
-- PostgreSQL database dump
--

-- Dumped from database version 9.5.1
-- Dumped by pg_dump version 9.5.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: clerk_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE clerk_type AS ENUM (
    'Clerk',
    'Office Head'
);


ALTER TYPE clerk_type OWNER TO postgres;

--
-- Name: clusters; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE clusters AS ENUM (
    'Arts and Humanities',
    'Management',
    'Sciences',
    'Social Sciences',
    'Administration'
);


ALTER TYPE clusters OWNER TO postgres;

--
-- Name: condition_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE condition_type AS ENUM (
    'Working',
    'Disposed'
);


ALTER TYPE condition_type OWNER TO postgres;

--
-- Name: disposaltypes; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE disposaltypes AS ENUM (
    'Sale',
    'Transfer',
    'Destruction'
);


ALTER TYPE disposaltypes OWNER TO postgres;

--
-- Name: equipmenttypes; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE equipmenttypes AS ENUM (
    'IT Equipments',
    'Non-IT Equipment',
    'Furnitures and Fixtures',
    'Aircons',
    'Lab Equipment'
);


ALTER TYPE equipmenttypes OWNER TO postgres;

--
-- Name: mode_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE mode_type AS ENUM (
    'Inventory',
    'Disposal'
);


ALTER TYPE mode_type OWNER TO postgres;

--
-- Name: role_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE role_type AS ENUM (
    'SPMO',
    'Checker',
    'Clerk',
    'Office Head'
);


ALTER TYPE role_type OWNER TO postgres;

--
-- Name: sched_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE sched_status AS ENUM (
    'Ongoing',
    'Done',
    'Upcoming'
);


ALTER TYPE sched_status OWNER TO postgres;

--
-- Name: statustypes; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE statustypes AS ENUM (
    'Found',
    'Not Found'
);


ALTER TYPE statustypes OWNER TO postgres;

--
-- Name: auto_ins_working(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION auto_ins_working() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO working_equipment(qrcode, status) values (NEW.qrcode, 'Found');
   return NEW;
END
$$;


ALTER FUNCTION public.auto_ins_working() OWNER TO postgres;

--
-- Name: auto_insert_clerk_roles(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION auto_insert_clerk_roles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
   BEGIN
   IF NEW.role = 'Clerk'
   THEN
INSERT INTO clerk VALUES (NEW.staff_id, NEW.office_id, 'Clerk');
   END IF;
   IF NEW.role = 'Office Head'
   THEN
INSERT INTO clerk VALUES (NEW.staff_id, NEW.office_id, 'Office Head');
   END IF;
   RETURN NEW;
END
$$;


ALTER FUNCTION public.auto_insert_clerk_roles() OWNER TO postgres;

--
-- Name: check_insert_assigned_to(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_insert_assigned_to() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
   BEGIN
   IF (SELECT office_id from staff where office_id = NEW.office_id_holder and staff_id = NEW.staff_id) is NULL
   THEN
	RAISE EXCEPTION 'The staff and office doesnt match!';
   END IF;
   RETURN NEW;
END
$$;


ALTER FUNCTION public.check_insert_assigned_to() OWNER TO postgres;

--
-- Name: check_insert_inventory_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION check_insert_inventory_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
   BEGIN
   IF ((SELECT title from schedule where id = NEW.inventory_id) != 'Inventory')
   THEN
RAISE EXCEPTION 'Schedule specified is not an Inventory';
   END IF;
   RETURN NEW;
END
$$;


ALTER FUNCTION public.check_insert_inventory_details() OWNER TO postgres;

--
-- Name: copy_equip(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION copy_equip() RETURNS boolean
    LANGUAGE plpgsql
    AS $$
  begin
insert into dummy_inventory(equipment_qrcode) select qrcode from equipment;
return true;
  end;
$$;


ALTER FUNCTION public.copy_equip() OWNER TO postgres;

--
-- Name: encryptqr(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION encryptqr() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
   BEGIN 
   IF NEW.component_no is NULL
   THEN
   	NEW.qrcode := md5(NEW.property_no::text);
   ELSE 
	NEW.qrcode := md5((NEW.property_no::text || NEW.component_no::text)::text);
   END IF;
   return NEW;
END
$$;


ALTER FUNCTION public.encryptqr() OWNER TO postgres;

--
-- Name: new_assignment(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION new_assignment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
UPDATE equipment_history set end_date = NEW.date_assigned where equip_qrcode=NEW.equipment_qr_code and end_date is null;

INSERT INTO equipment_history (equip_qrcode,start_date,staff_id,office_id) values(NEW.equipment_qr_code,NEW.date_assigned,NEW.staff_id,NEW.office_id_holder);

RETURN NEW;

END
$$;


ALTER FUNCTION public.new_assignment() OWNER TO postgres;

--
-- Name: new_equip_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION new_equip_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF(TG_OP = 'INSERT') THEN
INSERT INTO transaction_log (staff_id,transaction_details,equip_qrcode) values ('sbmagdadaro','added an equipment',NEW.qrcode);
RETURN NEW;
ELSEIF(TG_OP = 'UPDATE') THEN
INSERT INTO transaction_log (staff_id,transaction_details,equip_qrcode) values ('sbmagdadaro','updated an equipment',NEW.qrcode);
RETURN NEW;
ELSEIF(TG_OP = 'DELETE') THEN
INSERT INTO transaction_log (staff_id,transaction_details) values ('sbmagdadaro','discarded an equipment');
RETURN NEW;
END IF;
RETURN NULL;
END
$$;


ALTER FUNCTION public.new_equip_transaction() OWNER TO postgres;

--
-- Name: new_sched_transaction(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION new_sched_transaction() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
IF(TG_OP = 'INSERT') THEN
INSERT INTO transaction_log (staff_id,transaction_details) values ('sbmagdadaro','created a schedule');
RETURN NEW;
ELSEIF(TG_OP = 'UPDATE') THEN
INSERT INTO transaction_log (staff_id,transaction_details) values ('sbmagdadaro','updated a schedule');
RETURN NEW;
ELSEIF(TG_OP = 'DELETE') THEN
INSERT INTO transaction_log (staff_id,transaction_details) values ('sbmagdadaro','removed a schedule');
RETURN NEW;
END IF;
RETURN NULL;
END
$$;


ALTER FUNCTION public.new_sched_transaction() OWNER TO postgres;

--
-- Name: reset_equip_stat(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION reset_equip_stat() RETURNS void
    LANGUAGE plpgsql
    AS $$
 BEGIN
EXECUTE 'UPDATE working_equipment set status=' || quote_literal('Not Found');
 END
$$;


ALTER FUNCTION public.reset_equip_stat() OWNER TO postgres;

--
-- Name: update_sched(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION update_sched() RETURNS void
    LANGUAGE plpgsql
    AS $$
 BEGIN
EXECUTE 'UPDATE schedule SET event_status = ' || quote_literal('Ongoing') || ' WHERE event_status=' || quote_literal('Upcoming') || ' AND now() >= schedule.start AND now() <= schedule.end';
EXECUTE 'UPDATE schedule SET event_status = ' || quote_literal('Done') || ' WHERE event_status=' || quote_literal('Ongoing') || ' AND now() > schedule.end';
 END
$$;


ALTER FUNCTION public.update_sched() OWNER TO postgres;

--
-- Name: valid_start(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION valid_start() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
 BEGIN
IF NEW.start <= CURRENT_DATE
THEN
RAISE EXCEPTION 'Starting Date should be at least tomorrow.';
RETURN NULL;
END IF;
RETURN NEW;
 END
$$;


ALTER FUNCTION public.valid_start() OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: assigned_to; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE assigned_to (
    equipment_qr_code text NOT NULL,
    office_id_holder integer NOT NULL,
    date_assigned date NOT NULL,
    staff_id text NOT NULL,
    CONSTRAINT validassignmentdate CHECK ((date_assigned <= ('now'::text)::date))
);


ALTER TABLE assigned_to OWNER TO postgres;

--
-- Name: checker; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE checker (
    username text NOT NULL,
    password text NOT NULL,
    type equipmenttypes NOT NULL,
    md5 text NOT NULL,
    email character varying(254) NOT NULL
);


ALTER TABLE checker OWNER TO postgres;

--
-- Name: clerk; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE clerk (
    username text NOT NULL,
    designated_office integer NOT NULL,
    clerk_type clerk_type
);


ALTER TABLE clerk OWNER TO postgres;

--
-- Name: mobile_trans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE mobile_trans (
    id integer NOT NULL,
    username character varying(30) NOT NULL,
    transaction character varying(100) NOT NULL,
    parameter text,
    result text,
    remarks character varying(30) NOT NULL,
    "time" timestamp without time zone DEFAULT timezone('utc'::text, now()),
    office_name text
);


ALTER TABLE mobile_trans OWNER TO postgres;

--
-- Name: dates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW dates AS
 SELECT mobile_trans."time",
    date_part('month'::text, date(mobile_trans."time")) AS month,
    date_part('day'::text, date(mobile_trans."time")) AS day,
    date_part('year'::text, date(mobile_trans."time")) AS year,
    mobile_trans.parameter
   FROM mobile_trans;


ALTER TABLE dates OWNER TO postgres;

--
-- Name: office; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE office (
    office_id integer NOT NULL,
    email character varying(254) NOT NULL,
    password text NOT NULL,
    office_name text NOT NULL,
    cluster_name clusters,
    md5 text NOT NULL,
    short_office_name text NOT NULL
);


ALTER TABLE office OWNER TO postgres;

--
-- Name: extract_office_trans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW extract_office_trans AS
 SELECT DISTINCT mobile_trans.parameter,
    mobile_trans.username,
    mobile_trans.office_name,
    dates.month,
    dates.day,
    dates.year
   FROM office,
    mobile_trans,
    assigned_to,
    dates
  WHERE (((mobile_trans.transaction)::text = 'Disposal Confirmation'::text) AND (mobile_trans.parameter = assigned_to.equipment_qr_code) AND (assigned_to.office_id_holder = office.office_id) AND (dates.parameter = mobile_trans.parameter));


ALTER TABLE extract_office_trans OWNER TO postgres;

--
-- Name: dis_count; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW dis_count AS
 SELECT DISTINCT extract_office_trans.office_name,
    count(extract_office_trans.parameter) AS count
   FROM extract_office_trans,
    office,
    assigned_to
  WHERE ((extract_office_trans.parameter = assigned_to.equipment_qr_code) AND (assigned_to.office_id_holder = office.office_id) AND (office.office_name = extract_office_trans.office_name))
  GROUP BY extract_office_trans.office_name;


ALTER TABLE dis_count OWNER TO postgres;

--
-- Name: equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE equipment (
    qrcode text NOT NULL,
    article_name text NOT NULL,
    property_no numeric(4,0) NOT NULL,
    component_no integer,
    date_acquired date NOT NULL,
    description text,
    unit_cost integer NOT NULL,
    type equipmenttypes NOT NULL,
    condition condition_type NOT NULL,
    image_file character varying NOT NULL,
    CONSTRAINT validdateacquired CHECK ((date_acquired < ('now'::text)::date))
);


ALTER TABLE equipment OWNER TO postgres;

--
-- Name: disp_trans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW disp_trans AS
 SELECT mobile_trans.id,
    mobile_trans.username,
    mobile_trans.parameter,
    mobile_trans.transaction,
    mobile_trans.result,
    mobile_trans.remarks,
    mobile_trans."time",
    mobile_trans.office_name,
    equipment.article_name,
    equipment.property_no,
    equipment.component_no,
    dates.month,
    dates.day,
    dates.year
   FROM mobile_trans,
    equipment,
    dates
  WHERE (((mobile_trans.transaction)::text = 'Disposal Confirmation'::text) AND (mobile_trans.parameter = equipment.qrcode));


ALTER TABLE disp_trans OWNER TO postgres;

--
-- Name: disposal_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE disposal_requests (
    id integer NOT NULL,
    username text NOT NULL,
    type equipmenttypes NOT NULL,
    office_name text,
    content json,
    transaction text
);


ALTER TABLE disposal_requests OWNER TO postgres;

--
-- Name: disposal_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE disposal_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE disposal_requests_id_seq OWNER TO postgres;

--
-- Name: disposal_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE disposal_requests_id_seq OWNED BY disposal_requests.id;


--
-- Name: disposed_equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE disposed_equipment (
    qrcode text NOT NULL,
    appraised_value integer,
    way_of_disposal disposaltypes NOT NULL,
    or_no text,
    amount integer,
    "time" timestamp without time zone DEFAULT timezone('utc'::text, now())
);


ALTER TABLE disposed_equipment OWNER TO postgres;

--
-- Name: dummy_transaction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE dummy_transaction (
    trans_num integer NOT NULL,
    category text,
    "time" timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    read boolean DEFAULT false
);


ALTER TABLE dummy_transaction OWNER TO postgres;

--
-- Name: dummy_transaction_trans_num_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE dummy_transaction_trans_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dummy_transaction_trans_num_seq OWNER TO postgres;

--
-- Name: dummy_transaction_trans_num_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE dummy_transaction_trans_num_seq OWNED BY dummy_transaction.trans_num;


--
-- Name: staff; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE staff (
    office_id integer NOT NULL,
    staff_id text NOT NULL,
    first_name text NOT NULL,
    middle_init character(1),
    last_name text NOT NULL,
    role role_type
);


ALTER TABLE staff OWNER TO postgres;

--
-- Name: equipment_date_extracted_office_staff; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW equipment_date_extracted_office_staff AS
 SELECT equipment.qrcode,
    equipment.article_name,
    equipment.property_no,
    equipment.component_no,
    ( SELECT date_part('year'::text, equipment.date_acquired) AS year) AS year,
    ( SELECT date_part('month'::text, equipment.date_acquired) AS month) AS month,
    ( SELECT date_part('day'::text, equipment.date_acquired) AS day) AS day,
    equipment.description,
    equipment.unit_cost,
    equipment.type,
    equipment.condition,
    office.office_id,
    office.office_name,
    staff.staff_id,
    staff.first_name,
    staff.middle_init,
    staff.last_name,
    equipment.image_file
   FROM equipment,
    office,
    assigned_to,
    staff
  WHERE ((equipment.qrcode = assigned_to.equipment_qr_code) AND (assigned_to.office_id_holder = office.office_id) AND (staff.staff_id = assigned_to.staff_id));


ALTER TABLE equipment_date_extracted_office_staff OWNER TO postgres;

--
-- Name: eq_count; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW eq_count AS
 SELECT equipment_date_extracted_office_staff.article_name,
    equipment_date_extracted_office_staff.property_no,
    equipment_date_extracted_office_staff.office_name,
    count(equipment_date_extracted_office_staff.component_no) AS no_of_eq
   FROM equipment_date_extracted_office_staff
  GROUP BY equipment_date_extracted_office_staff.article_name, equipment_date_extracted_office_staff.property_no, equipment_date_extracted_office_staff.office_name;


ALTER TABLE eq_count OWNER TO postgres;

--
-- Name: equipment_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE equipment_history (
    record_no integer NOT NULL,
    equip_qrcode text NOT NULL,
    start_date date DEFAULT timezone('utc'::text, now()) NOT NULL,
    end_date date,
    staff_id text NOT NULL,
    office_id integer NOT NULL,
    CONSTRAINT valid_dates CHECK ((end_date >= start_date)),
    CONSTRAINT valid_edate CHECK ((end_date <= ('now'::text)::date)),
    CONSTRAINT valid_sdate CHECK ((start_date <= ('now'::text)::date))
);


ALTER TABLE equipment_history OWNER TO postgres;

--
-- Name: equipment_history_record_no_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE equipment_history_record_no_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE equipment_history_record_no_seq OWNER TO postgres;

--
-- Name: equipment_history_record_no_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE equipment_history_record_no_seq OWNED BY equipment_history.record_no;


--
-- Name: hist_dates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW hist_dates AS
 SELECT equipment_history.start_date,
    equipment_history.end_date,
    date_part('month'::text, equipment_history.start_date) AS month_start,
    date_part('day'::text, equipment_history.start_date) AS day_start,
    date_part('year'::text, equipment_history.start_date) AS year_start,
    date_part('month'::text, equipment_history.end_date) AS month_end,
    date_part('day'::text, equipment_history.end_date) AS day_end,
    date_part('year'::text, equipment_history.end_date) AS year_end,
    equipment_history.record_no,
    equipment_history.equip_qrcode,
    equipment_history.staff_id,
    office.office_id,
    office.short_office_name
   FROM equipment_history,
    office
  WHERE (office.office_id = equipment_history.office_id);


ALTER TABLE hist_dates OWNER TO postgres;

--
-- Name: inventory_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE inventory_details (
    inventory_id integer NOT NULL,
    initiated_by character varying NOT NULL
);


ALTER TABLE inventory_details OWNER TO postgres;

--
-- Name: mobile_trans_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE mobile_trans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE mobile_trans_id_seq OWNER TO postgres;

--
-- Name: mobile_trans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE mobile_trans_id_seq OWNED BY mobile_trans.id;


--
-- Name: office_office_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE office_office_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE office_office_id_seq OWNER TO postgres;

--
-- Name: office_office_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE office_office_id_seq OWNED BY office.office_id;


--
-- Name: schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE schedule (
    id integer NOT NULL,
    title mode_type NOT NULL,
    start date NOT NULL,
    "end" date NOT NULL,
    event_status sched_status DEFAULT 'Upcoming'::sched_status,
    CONSTRAINT validenddate CHECK ((("end" >= ('now'::text)::date) AND ("end" >= start))),
    CONSTRAINT validstartdate CHECK ((start >= ('now'::text)::date))
);


ALTER TABLE schedule OWNER TO postgres;

--
-- Name: sched_dates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sched_dates AS
 SELECT schedule.start,
    schedule."end",
    date_part('month'::text, schedule.start) AS month_start,
    date_part('day'::text, schedule.start) AS day_start,
    date_part('year'::text, schedule.start) AS year_start,
    date_part('month'::text, schedule."end") AS month_end,
    date_part('day'::text, schedule."end") AS day_end,
    date_part('year'::text, schedule."end") AS year_end,
    schedule.id,
    schedule.title
   FROM schedule;


ALTER TABLE sched_dates OWNER TO postgres;

--
-- Name: sched_simple; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW sched_simple AS
 SELECT schedule.id,
    schedule.start,
    ( SELECT date_part('year'::text, schedule.start) AS start_year) AS start_year,
    ( SELECT date_part('month'::text, schedule.start) AS start_month) AS start_month,
    ( SELECT date_part('day'::text, schedule.start) AS start_day) AS start_day,
    ( SELECT date_part('year'::text, schedule."end") AS end_year) AS end_year,
    ( SELECT date_part('month'::text, schedule."end") AS end_month) AS end_month,
    ( SELECT date_part('day'::text, schedule."end") AS end_day) AS end_day
   FROM schedule;


ALTER TABLE sched_simple OWNER TO postgres;

--
-- Name: schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE schedule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE schedule_id_seq OWNER TO postgres;

--
-- Name: schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE schedule_id_seq OWNED BY schedule.id;


--
-- Name: spmo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE spmo (
    username text NOT NULL,
    password text NOT NULL,
    email character varying(254),
    md5 text NOT NULL
);


ALTER TABLE spmo OWNER TO postgres;

--
-- Name: spmo_staff_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE spmo_staff_assignment (
    inventory_id integer NOT NULL,
    inventory_office integer NOT NULL,
    spmo_assigned character varying NOT NULL
);


ALTER TABLE spmo_staff_assignment OWNER TO postgres;

--
-- Name: transaction_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE transaction_log (
    transaction_no integer NOT NULL,
    staff_id text NOT NULL,
    transaction_date date DEFAULT now() NOT NULL,
    transaction_time time without time zone DEFAULT now() NOT NULL,
    transaction_details text NOT NULL,
    equip_qrcode text,
    CONSTRAINT validtransactiondate CHECK ((transaction_date <= ('now'::text)::date))
);


ALTER TABLE transaction_log OWNER TO postgres;

--
-- Name: trans_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW trans_details AS
 SELECT transaction_log.transaction_date,
    date_part('month'::text, transaction_log.transaction_date) AS month_trans,
    date_part('day'::text, transaction_log.transaction_date) AS day_trans,
    date_part('year'::text, transaction_log.transaction_date) AS year_trans,
    transaction_log.transaction_no,
    transaction_log.staff_id,
    to_char((transaction_log.transaction_time)::interval, 'HH12:MI:SS AM'::text) AS "time",
    transaction_log.transaction_details
   FROM transaction_log
  ORDER BY transaction_log.transaction_no;


ALTER TABLE trans_details OWNER TO postgres;

--
-- Name: transaction_log_transaction_no_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_log_transaction_no_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE transaction_log_transaction_no_seq OWNER TO postgres;

--
-- Name: transaction_log_transaction_no_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_log_transaction_no_seq OWNED BY transaction_log.transaction_no;


--
-- Name: working_equipment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE working_equipment (
    qrcode text NOT NULL,
    date_last_inventoried date,
    status statustypes NOT NULL,
    CONSTRAINT validdateinventory CHECK ((date_last_inventoried < ('now'::text)::date))
);


ALTER TABLE working_equipment OWNER TO postgres;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposal_requests ALTER COLUMN id SET DEFAULT nextval('disposal_requests_id_seq'::regclass);


--
-- Name: trans_num; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dummy_transaction ALTER COLUMN trans_num SET DEFAULT nextval('dummy_transaction_trans_num_seq'::regclass);


--
-- Name: record_no; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment_history ALTER COLUMN record_no SET DEFAULT nextval('equipment_history_record_no_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mobile_trans ALTER COLUMN id SET DEFAULT nextval('mobile_trans_id_seq'::regclass);


--
-- Name: office_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY office ALTER COLUMN office_id SET DEFAULT nextval('office_office_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedule ALTER COLUMN id SET DEFAULT nextval('schedule_id_seq'::regclass);


--
-- Name: transaction_no; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_log ALTER COLUMN transaction_no SET DEFAULT nextval('transaction_log_transaction_no_seq'::regclass);


--
-- Data for Name: assigned_to; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY assigned_to (equipment_qr_code, office_id_holder, date_assigned, staff_id) FROM stdin;
81dc9bdb52d04dc20036dbd8313ed055	14	2016-12-02	mjmatero
d897133013752d0a321202676961c579	44	2016-11-01	rrroxas
66f7b045db373d410f4f0c317378f679	44	2016-11-01	rrroxas
7f6f70d8bb2a189bd7414a63f36c5b75	44	2016-11-01	rrroxas
402df1281dc6d87253e7dca987b359e2	44	2016-11-01	rrroxas
eb007223a9ca6ab699c5070ced080113	44	2016-11-01	rrroxas
b421bedcc4030881312979f5a511c8e8	44	2016-11-01	rrroxas
30f3361bd6e97b8109893d55a8432556	44	2016-11-01	rrroxas
3865247de92da30d35f38538d71a9c40	44	2016-11-01	rrroxas
a9cfebcdb4e20ed975e82b7fd877693f	44	2016-11-01	rrroxas
1ad62710278671e5baf60606a23388b7	44	2016-11-01	rrroxas
546f7901282eee42b1e4e9d7f62aa324	44	2016-11-01	rrroxas
0a207b240a7b6e5710c3296016852169	44	2016-11-01	rrroxas
ef0eccbf66798ea2fde3af20ec426faf	44	2016-11-01	rrroxas
0664921765ed9f23a0e7c353b369f6a1	44	2016-11-01	rrroxas
5ca3f29f98b7e6f0f2a69960e7a3dc79	44	2016-11-01	rrroxas
8a1101b5e318825614c27c328d643705	44	2016-11-01	rrroxas
2d95415113278181485917e2d3b92ab7	44	2016-11-01	rrroxas
0d4d4a73c7f711e9993c1ec9f8529d9d	44	2016-11-01	rrroxas
3d744532750f482c4210255f577d11db	44	2016-11-01	rrroxas
64ea235f0e9a1be992067533b744e11a	44	2016-11-01	rrroxas
49e7ef6aa2d9b8d7dfcb90328397fa64	44	2016-11-01	rrroxas
67e5f7fec3e2e5d4759de4801e1b72a7	44	2016-11-01	rrroxas
335f9d06f26ea8d095e5da9f214fad42	44	2016-11-01	rrroxas
e7161c6dabce5fe6cb5ed42bf1df1f35	44	2016-11-01	rrroxas
33b46d01b27aa353d5058106d39071f4	44	2016-11-01	rrroxas
6d7ef78a926cc98799b8ac5afa9ed957	44	2016-11-01	rrroxas
81437f8bd31824435ec008d35d7ce159	44	2016-11-01	rrroxas
dfc374d85d0cd0540a0a9f9fb1267c45	44	2016-11-01	rrroxas
9c092041bba216f1b4316594e3f22ef8	44	2016-11-01	rrroxas
41aab22bfd978b692ff1926a631c110e	44	2016-11-01	rrroxas
b79ded847fcced1e28547fe2344e76ff	44	2016-11-01	rrroxas
bfd0abe791d0f74c4bce646e1ef07715	44	2016-11-01	rrroxas
4c53387320a3f2bafa538cc7a1f4d455	44	2016-11-01	rrroxas
b49d6cf78ba207dd1f910bb60905367f	44	2016-11-01	rrroxas
a9ac2713a25f8f8b21100eb61857fd48	44	2016-11-01	rrroxas
c7a2f923e4829c32a3733e9fc2666689	44	2016-11-01	rrroxas
68330ef57d6ed7e6d738003c8c67c530	44	2016-11-01	rrroxas
988516f58039b3543d75c96cf826691a	44	2016-11-01	rrroxas
483012929d5e1f37018c9c8c4ad34f37	44	2016-11-01	rrroxas
363224cff7fac6df72a21d4f717546eb	44	2016-11-01	rrroxas
9d5ab86eb7679e018310f3206fd5ed42	44	2016-11-01	rrroxas
b6ecfe392f41953fe398097345d8a723	44	2016-11-01	rrroxas
1e88a1fd71accb98cd25e5f3ba78fabf	44	2016-11-01	rrroxas
a5480fcdcb62bb35b9042ee4219f30b4	44	2016-11-01	rrroxas
254ced7a9d32b5bd0e2275803d09f988	44	2016-11-01	rrroxas
3c03b3502017eb8342a0bc5c38231be1	44	2016-11-01	rrroxas
7ab7241a2c7f74808daa2de02f2d6ba6	44	2016-11-01	rrroxas
5951c179de43573583e7d4281df3f495	44	2016-11-01	rrroxas
4fbe067e7e30cbc426ab27b1aeb2b7ed	44	2016-11-01	rrroxas
6887ab8b8b4ce0926a5dcf75110a9a6c	44	2016-11-01	rrroxas
88f3ede619f967ae916d0fc660341855	44	2016-11-01	rrroxas
838c45b2ac84a63d5cc28b9ee9079ec2	44	2016-11-01	rrroxas
43c0c26bac45cc3b9c3ce0baf1641ae8	44	2016-11-01	rrroxas
f1527ffd33a24ece7ba43ca178a576ed	40	2016-12-07	tevasquez
6e150682aa07c7413d49b3a31b1b7b00	44	2016-11-01	rrroxas
83d3be02314f7d74c4c50e109dbabbf4	44	2016-11-01	rrroxas
45f5cfd0809889f67f797665aa3515c5	44	2016-11-01	rrroxas
0f48cb31cb530841b68d302661d22009	44	2016-11-01	rrroxas
1b3bcbdea24bea9f3ada1a3e8828c3a9	44	2016-11-01	rrroxas
398d858256d6029dca9230882b499689	44	2016-11-01	rrroxas
5c604c70b18685218c9d0dccfc3a0827	44	2016-11-01	rrroxas
48c51968abe79f10ae22510fc6ac18c8	44	2016-11-01	rrroxas
6cf65ebce72a1088f3a458859e2dc666	44	2016-11-01	rrroxas
19854dc4891b66e4c96de4edd7d5ada0	44	2016-11-01	rrroxas
54159f0fedf9d40e7f328134de0857b0	44	2016-11-01	rrroxas
205759c4f297af0a062088add4fea246	44	2016-11-01	rrroxas
e961c2482c6dfda5c5e3968b70836ba6	44	2016-11-01	rrroxas
83a7a2bda8bac4960d0e7070addaface	44	2016-11-01	rrroxas
22719ac4686c6abdd9dae8ef5b4b8f9d	44	2016-11-01	rrroxas
1546df2fce5bed78cd33bedde1aff58b	44	2016-11-01	rrroxas
7769db69a040492ddda35c8fc23d1c4b	44	2016-11-01	rrroxas
376fd50f094f0a67026e655e4cdd453f	44	2016-11-01	rrroxas
a670c97d7803c06154c7f8782178f6f4	44	2016-11-01	rrroxas
06703e0008e33c211fc9e9e0ee35c230	44	2016-11-01	rrroxas
5917ad1d94b7275c14f0f25ffba9122c	44	2016-11-01	rrroxas
d491a7de92b19e5f4b09670cdf2706ba	44	2016-11-01	rrroxas
e2102b8bde911503336460b14bb97886	44	2016-11-01	rrroxas
12a257147a51bd0a445e171c7857a46d	44	2016-11-01	rrroxas
7949a56231d8e13573d0b7834371cfcb	44	2016-11-01	rrroxas
d4ccd18e192fbeca26dfdc111397d228	44	2016-11-01	rrroxas
41857c1fafe2ed5b86844c92b6df84ae	44	2016-11-01	rrroxas
d0da4f9170ab57d98a07ece62d138ec1	44	2016-11-01	rrroxas
97adebe60938ceb3907c7eb22488ec94	44	2016-11-01	rrroxas
27d088da323408c4b11778aa614692a7	44	2016-11-01	rrroxas
594d35e12c546f55b2980b34a0af5c7d	44	2016-11-01	rrroxas
89d6d3107abf73968c33f5d1acfae7d1	44	2016-11-01	rrroxas
c5055d37f7761d5ac1dbe1c7aa4c91f7	44	2016-11-01	rrroxas
97198bc234cd6d0d1b77f91bb473d1b5	44	2016-11-01	rrroxas
964e317a1689b33b20099b79a9aa2cc4	44	2016-11-01	rrroxas
c326218cd16f94f581684ddf000dcc97	44	2016-11-01	rrroxas
5f2015c3451c9ab0909aeffc65a0acad	44	2016-11-01	rrroxas
aa8fa69892be87c21091df242109a28d	44	2016-11-01	rrroxas
81688afbe5cd5880e758823b93610179	44	2016-11-01	rrroxas
42522a0e20f3ad9d89c858970b9b956e	44	2016-11-01	rrroxas
c68ce8d267e8cb58065e8ca6da71ca3d	44	2016-11-01	rrroxas
7e5e5143ed6f3b348f6f75da7f5ebebe	44	2016-11-01	rrroxas
dfd9a349b60da403621c955e189adc5e	44	2016-11-01	rrroxas
d4a936d3c1f8a3407e7bcaa15c51f839	44	2016-11-01	rrroxas
45627f67d98c16ff2a33a451014656a6	44	2016-11-01	rrroxas
64843ad6de7a39dd092c57f430936c27	44	2016-11-01	rrroxas
b9d66dabc87adc325461a48c280133f8	44	2016-11-01	rrroxas
0d400289b80c906f3bd466491db73ab0	44	2016-11-01	rrroxas
321a964bbe6b111d85029dc9b25fafb7	44	2016-11-01	rrroxas
53e5de741470c1935eaedf3daf417b03	44	2016-11-01	rrroxas
d1cf403a99a57fd7360d97ce5c652295	44	2016-11-01	rrroxas
4de2d61497ada3e0e8942ed48c3cbb89	44	2016-11-01	rrroxas
a0b6dea6748841384f9f687289a061fa	44	2016-11-01	rrroxas
cd0238302cbde1bd2bf12dce32390fe2	44	2016-11-01	rrroxas
7b393f8e48d7b396d866add75db9352b	44	2016-11-01	rrroxas
fd035aa26fbfbf0ebdf9e7d7c60863e3	44	2016-11-01	rrroxas
b045d64f68c5790d4fb44f1d762713da	44	2016-11-01	rrroxas
269d39bd56225bd133aec58c267a916f	44	2016-11-01	rrroxas
fc34a63ea6d95041adccc5381d312d6f	44	2016-11-01	rrroxas
965de5c5dbfaeee6e9b6f0ac304db335	44	2016-11-01	rrroxas
48f3a3e0c4d674da2521282f90bddd7f	44	2016-11-01	rrroxas
2474748c706d32d2d9f63be16db3b960	44	2016-11-01	rrroxas
d62017747b8cb88466ffe6b76eb2a83f	44	2016-11-01	rrroxas
9bff0fd479d2cd964c1cf4132905150f	44	2016-11-01	rrroxas
2c74afa78eed38c11ed5a8e3e48d757b	44	2016-11-01	rrroxas
dca3b6c4435fa89c408cda19783054e6	44	2016-11-01	rrroxas
f9fc57cc8d048306d847e879a7ff6573	44	2016-11-01	rrroxas
5a67f582d77c40f163d41a43d87de21e	44	2016-11-01	rrroxas
097a3bbc7bfae7fe08a497faa56249af	44	2016-11-01	rrroxas
f93a76dd3a48af98848e789c6647940f	44	2016-11-01	rrroxas
3402785e7f940364c6e4219d446dc8ed	44	2016-11-01	rrroxas
69813c68ad3af82ba76f7467828b19c6	44	2016-11-01	rrroxas
27c469e4f12a5d57456b063ab27fa3ad	44	2016-11-01	rrroxas
2a51fceea363092885dca92a42e10a07	44	2016-11-01	rrroxas
5ed831e47471086174b1f6e2fe916aeb	44	2016-11-01	rrroxas
1105d911187c2822d149c49d1c95c706	44	2016-11-01	rrroxas
30015199ad94bbf7a6be0a9c5157cff2	44	2016-11-01	rrroxas
7492a0b74118dc87e101bc88a7ede11d	44	2016-11-01	rrroxas
ce18721aef97f3c2bed7122d1b57a5e3	44	2016-11-01	rrroxas
dc87f8810ba7a0d6f81fa84614c2bfbc	44	2016-11-01	rrroxas
bd93f06ae0c0d4afa78a1a1d4e1b8793	44	2016-11-01	rrroxas
def7924e3199be5e18060bb3e1d547a7	44	2016-11-11	aovicente
e53a0a2978c28872a4505bdb51db06dc	4	2016-12-01	mnmacasil
6b3c49bdba5be0d322334e30c459f8bd	14	2016-12-06	mjmatero
3d8a0e750ff4f9b65d2c112a7095d1ce	22	2016-11-16	rmdulaca
b8b8c345f81f0479515a0da0add9a159	15	2016-10-12	tgtan
e353b610e9ce20f963b4cca5da565605	15	2016-10-12	tgtan
1bcaea6d00884aeafe0c076bd322f825	15	2016-10-12	tgtan
5bd7f2feff1f11170a507fcd0c0e9734	15	2016-10-12	tgtan
5c6ef67e6079f0cdd640a5ad7c288e36	15	2016-10-12	tgtan
ccd986d2de4c75133c049e26005b3dbc	15	2016-10-12	tgtan
c6c209418814b5cee2107e6e744bb737	15	2016-10-12	tgtan
0bc58258e6f3c040a65fa2bfc9d0c907	15	2016-10-12	tgtan
0668a01b2098b4335c37c1a1ac0dd71a	15	2016-10-12	tgtan
9ac0faa70d798a4598ce2655d8b54232	15	2016-10-12	tgtan
b0baee9d279d34fa1dfd71aadb908c3f	8	2016-12-01	bfespiritu
afcb7a2f1c158286b48062cd885a9866	8	2016-12-01	bfespiritu
4b009c2f8e8d230c498c2db26678dd77	8	2016-12-01	bfespiritu
ed1db771321105b3c0dbc70a661b9b10	8	2016-12-01	bfespiritu
d7dcd79b773dc85c89b84862cdedb6cf	8	2016-12-01	bfespiritu
4e4faae72b1c3cbd446a70e89e59d8fc	8	2016-12-01	bfespiritu
307eb8ee16198da891c521eca21464c1	8	2016-12-01	bfespiritu
d585d095b00cd2f5b50acb64add23834	8	2016-12-01	bfespiritu
e2d56b6b53ce40332aec920b78d030c1	8	2016-12-01	bfespiritu
867c4bc5f2010a95f9971b91ddaa8f47	8	2016-12-01	bfespiritu
96e79218965eb72c92a549dd5a330112	8	2016-12-01	bfespiritu
9a952cd91000872a8d7d1f5ee0c87317	8	2016-12-01	bfespiritu
f6be2ff0d88a9434a04a79c0e1a28066	8	2016-12-01	bfespiritu
2707b2f06a3967105746389278bdf01d	8	2016-12-01	bfespiritu
0097d9f20753f2e606a36c45693562b2	8	2016-12-01	bfespiritu
1d2f816fd3c2e0a226c43f5b19e60007	8	2016-12-01	bfespiritu
f48f7bb1bc6b73e178f57f632d312b3d	8	2016-12-01	bfespiritu
5429d3157f649805adc2d506df2c31b5	8	2016-12-01	bfespiritu
0d659ddc03566cb9c55c9ccf0eb2f1bb	8	2016-12-01	bfespiritu
d1ec29d7366e8b4cbebbd9f63797ebeb	8	2016-12-01	bfespiritu
fbe5432b9d3f71f3c03c9d7fd0297c2d	8	2016-12-01	bfespiritu
0b7da663c8a1ee358aa8dbb6e55d0d2b	8	2016-12-01	bfespiritu
e49274516a27487f894ae956166eb7a4	8	2016-12-01	bfespiritu
1e14e388e4042dc43defefb9f88695e1	8	2016-12-01	bfespiritu
ce43ec4b39fa77a2030d73f8855c4396	8	2016-12-01	bfespiritu
3949350cebfd1d32e7278eaed55dc2f1	8	2016-12-01	bfespiritu
c52f5ca65357bf402df21e7db538007e	8	2016-12-01	bfespiritu
e23c30d902f86fc06f700bc4cbe9d67e	8	2016-12-01	bfespiritu
3447ce251398f59b274e0acfe1541df7	8	2016-12-01	bfespiritu
03a892d43834d530f2e81de80c96384d	8	2016-12-01	bfespiritu
e044fb795495fd22d8146e50b961e852	22	2016-08-02	rmdulaca
a25ae004eadf95406855ffbad5653993	44	2016-10-03	aovicente
ef80af910fa07870e25b1a4c86d10402	44	2016-10-03	aovicente
2167fcf808b8f383e7e44e25305a08a8	44	2016-10-03	aovicente
4d82271bc2fdb95a9de38ba9e30ab36e	29	2016-11-08	mrpedrano
0f4443a0b35f23e2d2a485be3d07ed84	29	2016-11-08	mrpedrano
6fa825177a4f6f5a6ff57c739e8311fd	29	2016-11-08	mrpedrano
95458099dedf800e701d8bf723ace65a	29	2016-11-08	mrpedrano
82b57e60cd5cd5d41a14ffc31b255f5b	29	2016-09-19	mrpedrano
8b6089269d17381873ec2207506aa62a	29	2016-09-19	mrpedrano
2ffe5ae29bb6b60145835654b541b443	29	2016-09-19	mrpedrano
6264104f24cbc6849b7e6ad298862a24	29	2016-09-19	mrpedrano
0a5de450e625177a977f2b7a488c72f5	29	2016-09-19	mrpedrano
b52bd057e37fc8688dddf113c39501e2	29	2016-09-19	mrpedrano
02d4ad74e410990974be404efcd00ec1	29	2016-09-19	mrpedrano
f338ee966b0240a58cc1dbf24855dd26	29	2016-09-19	mrpedrano
e9729543bbfbd7d2677d43bc67c5dc87	29	2016-09-19	mrpedrano
400e5b95e612e990cc5a1891d52b0212	29	2016-09-19	mrpedrano
24ebad661415bb82ae9f9e92167a80d2	29	2016-09-19	mrpedrano
8e693391276cd4fd2397434cdfb5480c	29	2016-09-19	mrpedrano
a8c9bd7685d48510c0a01c2537384363	29	2016-09-19	mrpedrano
05c5bec0698ccaeb128fd431b606b318	29	2016-09-19	mrpedrano
209ae57722bd1bd436646951f80617cc	29	2016-09-19	mrpedrano
24dc2b5d421e7f6eda94ba6188e6fbc4	29	2016-10-01	mrpedrano
670f33f3cfb5217bcf008786165f1dc7	29	2016-10-01	mrpedrano
dda4087216e15d1784efc310005dd683	29	2016-10-01	mrpedrano
d8585cb93fef89c4cf932574e6554c9c	29	2016-10-01	mrpedrano
c3e71101f147210be216f85bf76a067a	29	2016-10-01	mrpedrano
36125352638845f5a20223ba6a55e522	26	2016-12-05	rpbayawa
8923d70c1cfa2fb0690ca3b912600332	26	2016-12-05	rpbayawa
39b32dfc9ed18533ee98b921687ad87a	28	2016-12-01	fcabad
f477b7bc78101c4ae91008a6a403104e	28	2016-12-01	fcabad
4756c3d11a0e0bafae44c135837f15d2	27	2016-12-04	eobensig
20f817b9520d57dd7b9f725537816cbb	27	2016-12-04	eobensig
43bf67f752b620ea7bcaafa1a4e8ec0d	27	2016-12-04	eobensig
476ffbfb78ef9adcf5c6010723c04947	30	2016-05-16	rdimbong
d6e44245b7dcf2a1fa100f95bae0f3d8	30	2016-05-16	rdimbong
d31432767374d7df1f49036637540469	30	2016-05-16	rdimbong
48efe880ae65dac453536b2d9ff74104	30	2016-05-16	rdimbong
dd4719a433e583c8e9e9a0e0722e4e51	30	2016-05-16	rdimbong
0948165ee93e1b462588da88a79abdf6	30	2016-05-16	rdimbong
4d441f107ac494bd09add43376ad68d1	30	2016-05-16	rdimbong
866c4cda6901e9214d16c6f8e155941a	30	2016-05-16	rdimbong
39b8f1905c82dda81dcb616f89cd94f0	30	2016-05-16	rdimbong
136b00d6262e70a75e86200fa494cd15	30	2016-05-16	rdimbong
4e0df9f8468af3566ecc97d7afb106da	64	2016-11-07	asarbuis
d66d0d00bb7f294c9a9127f437dd3702	64	2016-11-07	asarbuis
\.


--
-- Data for Name: checker; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY checker (username, password, type, md5, email) FROM stdin;
fdaday	$1$mXokoWfb$V4kzIpuDALlU0CzGSmM581	IT Equipments	a4e3287c349cefa03f29a85fc596197f	fdaday@up.edu.ph
rbbasadre	$1$KIop4DzJ$qfofHZWNNZDSzlOGPELAt1	Furnitures and Fixtures	2bd87cf22c40d4aa65a2e747ab8988a4	rbbasadre@up.edu.ph
\.


--
-- Data for Name: clerk; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY clerk (username, designated_office, clerk_type) FROM stdin;
jegumalal	60	Office Head
fcabad	28	Office Head
rdimbong	30	Office Head
agmaglasang	31	Office Head
emfunesto	35	Office Head
rpgalapate	9	Office Head
lasia	10	Office Head
mgbugash	36	Office Head
mfchavez	59	Office Head
jeyap	38	Office Head
gocadiz	42	Office Head
jrsinogaya	39	Office Head
tevasquez	40	Office Head
ffmaglangit	41	Office Head
mvmende	48	Office Head
cmrodel	51	Office Head
fggeneralao	52	Office Head
jdlumagbas	56	Office Head
mrpedrano	29	Office Head
ldcorro	21	Office Head
jklepiten	1	Office Head
mnmacasil	4	Office Head
pptudtud	6	Office Head
jcpinzon	5	Office Head
bfespiritu	8	Office Head
mjmatero	14	Office Head
tgtan	15	Office Head
abbascon	16	Office Head
rcbinagatan	17	Office Head
yrorillo	18	Office Head
vmsesaldo	20	Office Head
rrroxas	44	Office Head
rmdulaca	22	Office Head
lsdee	25	Office Head
rpbayawa	26	Office Head
eobensig	27	Office Head
hbespiritu	23	Office Head
\.


--
-- Data for Name: disposal_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY disposal_requests (id, username, type, office_name, content, transaction) FROM stdin;
\.


--
-- Name: disposal_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('disposal_requests_id_seq', 13, true);


--
-- Data for Name: disposed_equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY disposed_equipment (qrcode, appraised_value, way_of_disposal, or_no, amount, "time") FROM stdin;
a25ae004eadf95406855ffbad5653993	500	Destruction	\N	\N	2016-12-08 04:22:59.102171
82b57e60cd5cd5d41a14ffc31b255f5b	500	Destruction	\N	\N	2016-12-08 04:28:34.878535
02d4ad74e410990974be404efcd00ec1	300	Destruction	\N	\N	2016-12-08 16:59:55.871214
\.


--
-- Data for Name: dummy_transaction; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY dummy_transaction (trans_num, category, "time", read) FROM stdin;
1	1 New Disposal Request	2016-11-10 15:49:11.978728	f
2	1 New Disposal Request	2016-11-10 15:49:11.978728	f
3	1 New Disposal Request	2016-11-14 05:48:08.894157	f
\.


--
-- Name: dummy_transaction_trans_num_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('dummy_transaction_trans_num_seq', 3, true);


--
-- Data for Name: equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY equipment (qrcode, article_name, property_no, component_no, date_acquired, description, unit_cost, type, condition, image_file) FROM stdin;
81dc9bdb52d04dc20036dbd8313ed055	Fax Machine	1234	\N	2016-12-02	Laser Fax with built-in handset.	9362	Non-IT Equipment	Working	Fax Machine.jpg
d897133013752d0a321202676961c579	Monoblock Armchair	9989	1	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
66f7b045db373d410f4f0c317378f679	Monoblock Armchair	9989	2	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7f6f70d8bb2a189bd7414a63f36c5b75	Monoblock Armchair	9989	3	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
402df1281dc6d87253e7dca987b359e2	Monoblock Armchair	9989	4	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
eb007223a9ca6ab699c5070ced080113	Monoblock Armchair	9989	5	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b421bedcc4030881312979f5a511c8e8	Monoblock Armchair	9989	6	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
30f3361bd6e97b8109893d55a8432556	Monoblock Armchair	9989	7	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
3865247de92da30d35f38538d71a9c40	Monoblock Armchair	9989	8	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
a9cfebcdb4e20ed975e82b7fd877693f	Monoblock Armchair	9989	9	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
f1527ffd33a24ece7ba43ca178a576ed	Monoblock Armchair	9989	10	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
1ad62710278671e5baf60606a23388b7	Monoblock Armchair	9989	11	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
546f7901282eee42b1e4e9d7f62aa324	Monoblock Armchair	9989	12	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
0a207b240a7b6e5710c3296016852169	Monoblock Armchair	9989	13	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
ef0eccbf66798ea2fde3af20ec426faf	Monoblock Armchair	9989	14	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
0664921765ed9f23a0e7c353b369f6a1	Monoblock Armchair	9989	15	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5ca3f29f98b7e6f0f2a69960e7a3dc79	Monoblock Armchair	9989	16	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
8a1101b5e318825614c27c328d643705	Monoblock Armchair	9989	17	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
2d95415113278181485917e2d3b92ab7	Monoblock Armchair	9989	18	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
0d4d4a73c7f711e9993c1ec9f8529d9d	Monoblock Armchair	9989	19	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
3d744532750f482c4210255f577d11db	Monoblock Armchair	9989	20	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
64ea235f0e9a1be992067533b744e11a	Monoblock Armchair	9989	21	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
49e7ef6aa2d9b8d7dfcb90328397fa64	Monoblock Armchair	9989	22	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
67e5f7fec3e2e5d4759de4801e1b72a7	Monoblock Armchair	9989	23	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
335f9d06f26ea8d095e5da9f214fad42	Monoblock Armchair	9989	24	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
e7161c6dabce5fe6cb5ed42bf1df1f35	Monoblock Armchair	9989	25	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
33b46d01b27aa353d5058106d39071f4	Monoblock Armchair	9989	26	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
6d7ef78a926cc98799b8ac5afa9ed957	Monoblock Armchair	9989	27	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
81437f8bd31824435ec008d35d7ce159	Monoblock Armchair	9989	28	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
dfc374d85d0cd0540a0a9f9fb1267c45	Monoblock Armchair	9989	29	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
9c092041bba216f1b4316594e3f22ef8	Monoblock Armchair	9989	30	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
41aab22bfd978b692ff1926a631c110e	Monoblock Armchair	9989	31	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b79ded847fcced1e28547fe2344e76ff	Monoblock Armchair	9989	32	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
bfd0abe791d0f74c4bce646e1ef07715	Monoblock Armchair	9989	33	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
4c53387320a3f2bafa538cc7a1f4d455	Monoblock Armchair	9989	34	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b49d6cf78ba207dd1f910bb60905367f	Monoblock Armchair	9989	35	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
a9ac2713a25f8f8b21100eb61857fd48	Monoblock Armchair	9989	36	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
c7a2f923e4829c32a3733e9fc2666689	Monoblock Armchair	9989	37	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
68330ef57d6ed7e6d738003c8c67c530	Monoblock Armchair	9989	38	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
988516f58039b3543d75c96cf826691a	Monoblock Armchair	9989	39	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
483012929d5e1f37018c9c8c4ad34f37	Monoblock Armchair	9989	40	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
363224cff7fac6df72a21d4f717546eb	Monoblock Armchair	9989	41	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
9d5ab86eb7679e018310f3206fd5ed42	Monoblock Armchair	9989	42	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b6ecfe392f41953fe398097345d8a723	Monoblock Armchair	9989	43	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
1e88a1fd71accb98cd25e5f3ba78fabf	Monoblock Armchair	9989	44	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
a5480fcdcb62bb35b9042ee4219f30b4	Monoblock Armchair	9989	45	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
254ced7a9d32b5bd0e2275803d09f988	Monoblock Armchair	9989	46	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
3c03b3502017eb8342a0bc5c38231be1	Monoblock Armchair	9989	47	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7ab7241a2c7f74808daa2de02f2d6ba6	Monoblock Armchair	9989	48	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5951c179de43573583e7d4281df3f495	Monoblock Armchair	9989	49	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
4fbe067e7e30cbc426ab27b1aeb2b7ed	Monoblock Armchair	9989	50	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
6887ab8b8b4ce0926a5dcf75110a9a6c	Monoblock Armchair	9989	51	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
88f3ede619f967ae916d0fc660341855	Monoblock Armchair	9989	52	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
838c45b2ac84a63d5cc28b9ee9079ec2	Monoblock Armchair	9989	53	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
43c0c26bac45cc3b9c3ce0baf1641ae8	Monoblock Armchair	9989	54	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
6e150682aa07c7413d49b3a31b1b7b00	Monoblock Armchair	9989	55	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
83d3be02314f7d74c4c50e109dbabbf4	Monoblock Armchair	9989	56	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
45f5cfd0809889f67f797665aa3515c5	Monoblock Armchair	9989	57	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
0f48cb31cb530841b68d302661d22009	Monoblock Armchair	9989	58	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
1b3bcbdea24bea9f3ada1a3e8828c3a9	Monoblock Armchair	9989	59	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
398d858256d6029dca9230882b499689	Monoblock Armchair	9989	60	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5c604c70b18685218c9d0dccfc3a0827	Monoblock Armchair	9989	61	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
48c51968abe79f10ae22510fc6ac18c8	Monoblock Armchair	9989	62	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
6cf65ebce72a1088f3a458859e2dc666	Monoblock Armchair	9989	63	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
19854dc4891b66e4c96de4edd7d5ada0	Monoblock Armchair	9989	64	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
54159f0fedf9d40e7f328134de0857b0	Monoblock Armchair	9989	65	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
205759c4f297af0a062088add4fea246	Monoblock Armchair	9989	66	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
e961c2482c6dfda5c5e3968b70836ba6	Monoblock Armchair	9989	67	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
83a7a2bda8bac4960d0e7070addaface	Monoblock Armchair	9989	68	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
22719ac4686c6abdd9dae8ef5b4b8f9d	Monoblock Armchair	9989	69	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
1546df2fce5bed78cd33bedde1aff58b	Monoblock Armchair	9989	70	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7769db69a040492ddda35c8fc23d1c4b	Monoblock Armchair	9989	71	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
376fd50f094f0a67026e655e4cdd453f	Monoblock Armchair	9989	72	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
a670c97d7803c06154c7f8782178f6f4	Monoblock Armchair	9989	73	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
06703e0008e33c211fc9e9e0ee35c230	Monoblock Armchair	9989	74	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5917ad1d94b7275c14f0f25ffba9122c	Monoblock Armchair	9989	75	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d491a7de92b19e5f4b09670cdf2706ba	Monoblock Armchair	9989	76	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
e2102b8bde911503336460b14bb97886	Monoblock Armchair	9989	77	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
12a257147a51bd0a445e171c7857a46d	Monoblock Armchair	9989	78	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7949a56231d8e13573d0b7834371cfcb	Monoblock Armchair	9989	79	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d4ccd18e192fbeca26dfdc111397d228	Monoblock Armchair	9989	80	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
41857c1fafe2ed5b86844c92b6df84ae	Monoblock Armchair	9989	81	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d0da4f9170ab57d98a07ece62d138ec1	Monoblock Armchair	9989	82	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
97adebe60938ceb3907c7eb22488ec94	Monoblock Armchair	9989	83	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
27d088da323408c4b11778aa614692a7	Monoblock Armchair	9989	84	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
594d35e12c546f55b2980b34a0af5c7d	Monoblock Armchair	9989	85	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
89d6d3107abf73968c33f5d1acfae7d1	Monoblock Armchair	9989	86	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
c5055d37f7761d5ac1dbe1c7aa4c91f7	Monoblock Armchair	9989	87	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
97198bc234cd6d0d1b77f91bb473d1b5	Monoblock Armchair	9989	88	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
964e317a1689b33b20099b79a9aa2cc4	Monoblock Armchair	9989	89	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
c326218cd16f94f581684ddf000dcc97	Monoblock Armchair	9989	90	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5f2015c3451c9ab0909aeffc65a0acad	Monoblock Armchair	9989	91	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
aa8fa69892be87c21091df242109a28d	Monoblock Armchair	9989	92	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
81688afbe5cd5880e758823b93610179	Monoblock Armchair	9989	93	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
42522a0e20f3ad9d89c858970b9b956e	Monoblock Armchair	9989	94	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
c68ce8d267e8cb58065e8ca6da71ca3d	Monoblock Armchair	9989	95	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7e5e5143ed6f3b348f6f75da7f5ebebe	Monoblock Armchair	9989	96	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
dfd9a349b60da403621c955e189adc5e	Monoblock Armchair	9989	97	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d4a936d3c1f8a3407e7bcaa15c51f839	Monoblock Armchair	9989	98	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
45627f67d98c16ff2a33a451014656a6	Monoblock Armchair	9989	99	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
64843ad6de7a39dd092c57f430936c27	Monoblock Armchair	9989	100	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b9d66dabc87adc325461a48c280133f8	Monoblock Armchair	9989	101	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
0d400289b80c906f3bd466491db73ab0	Monoblock Armchair	9989	102	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
321a964bbe6b111d85029dc9b25fafb7	Monoblock Armchair	9989	103	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
53e5de741470c1935eaedf3daf417b03	Monoblock Armchair	9989	104	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d1cf403a99a57fd7360d97ce5c652295	Monoblock Armchair	9989	105	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
4de2d61497ada3e0e8942ed48c3cbb89	Monoblock Armchair	9989	106	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
a0b6dea6748841384f9f687289a061fa	Monoblock Armchair	9989	107	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
cd0238302cbde1bd2bf12dce32390fe2	Monoblock Armchair	9989	108	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7b393f8e48d7b396d866add75db9352b	Monoblock Armchair	9989	109	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
fd035aa26fbfbf0ebdf9e7d7c60863e3	Monoblock Armchair	9989	110	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
b045d64f68c5790d4fb44f1d762713da	Monoblock Armchair	9989	111	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
269d39bd56225bd133aec58c267a916f	Monoblock Armchair	9989	112	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
fc34a63ea6d95041adccc5381d312d6f	Monoblock Armchair	9989	113	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
965de5c5dbfaeee6e9b6f0ac304db335	Monoblock Armchair	9989	114	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
48f3a3e0c4d674da2521282f90bddd7f	Monoblock Armchair	9989	115	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
2474748c706d32d2d9f63be16db3b960	Monoblock Armchair	9989	116	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
d62017747b8cb88466ffe6b76eb2a83f	Monoblock Armchair	9989	117	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
9bff0fd479d2cd964c1cf4132905150f	Monoblock Armchair	9989	118	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
2c74afa78eed38c11ed5a8e3e48d757b	Monoblock Armchair	9989	119	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
dca3b6c4435fa89c408cda19783054e6	Monoblock Armchair	9989	120	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
f9fc57cc8d048306d847e879a7ff6573	Monoblock Armchair	9989	121	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5a67f582d77c40f163d41a43d87de21e	Monoblock Armchair	9989	122	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
097a3bbc7bfae7fe08a497faa56249af	Monoblock Armchair	9989	123	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
f93a76dd3a48af98848e789c6647940f	Monoblock Armchair	9989	124	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
3402785e7f940364c6e4219d446dc8ed	Monoblock Armchair	9989	125	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
69813c68ad3af82ba76f7467828b19c6	Monoblock Armchair	9989	126	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
27c469e4f12a5d57456b063ab27fa3ad	Monoblock Armchair	9989	127	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
2a51fceea363092885dca92a42e10a07	Monoblock Armchair	9989	128	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
5ed831e47471086174b1f6e2fe916aeb	Monoblock Armchair	9989	129	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
1105d911187c2822d149c49d1c95c706	Monoblock Armchair	9989	130	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
30015199ad94bbf7a6be0a9c5157cff2	Monoblock Armchair	9989	131	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
7492a0b74118dc87e101bc88a7ede11d	Monoblock Armchair	9989	132	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
ce18721aef97f3c2bed7122d1b57a5e3	Monoblock Armchair	9989	133	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
dc87f8810ba7a0d6f81fa84614c2bfbc	Monoblock Armchair	9989	134	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
bd93f06ae0c0d4afa78a1a1d4e1b8793	Monoblock Armchair	9989	135	2016-11-01	Brown monoblock armchair for classrooms	725	Furnitures and Fixtures	Working	Monoblock Armchair.jpg
def7924e3199be5e18060bb3e1d547a7	Computer Set	3456	\N	2016-11-11	ASUS Intel Core i7 with AVR	100000	IT Equipments	Working	IMG20161122164249.jpg
e53a0a2978c28872a4505bdb51db06dc	Laptop	1232	\N	2016-12-01	MacBook Pro	60000	IT Equipments	Working	15416859_676024839243055_1460234153_n.jpg
6b3c49bdba5be0d322334e30c459f8bd	Laptop	7677	\N	2016-12-06	MacBook Air	50000	IT Equipments	Working	15356792_676024835909722_1408029351_n.jpg
3d8a0e750ff4f9b65d2c112a7095d1ce	Telephone	9823	\N	2016-11-16	Black	10000	IT Equipments	Working	15328385_676032145908991_1091652288_n.jpg
b8b8c345f81f0479515a0da0add9a159	Bench	3443	1	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
e353b610e9ce20f963b4cca5da565605	Bench	3443	2	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
1bcaea6d00884aeafe0c076bd322f825	Bench	3443	3	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
5bd7f2feff1f11170a507fcd0c0e9734	Bench	3443	4	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
5c6ef67e6079f0cdd640a5ad7c288e36	Bench	3443	5	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
ccd986d2de4c75133c049e26005b3dbc	Bench	3443	6	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
c6c209418814b5cee2107e6e744bb737	Bench	3443	7	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
0bc58258e6f3c040a65fa2bfc9d0c907	Bench	3443	8	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
0668a01b2098b4335c37c1a1ac0dd71a	Bench	3443	9	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
9ac0faa70d798a4598ce2655d8b54232	Bench	3443	10	2016-10-12	Monoblock, white	323	Furnitures and Fixtures	Working	15320426_676032015909004_2011525731_n.jpg
b0baee9d279d34fa1dfd71aadb908c3f	Monoblock Armchair	1111	1	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
afcb7a2f1c158286b48062cd885a9866	Monoblock Armchair	1111	2	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
4b009c2f8e8d230c498c2db26678dd77	Monoblock Armchair	1111	3	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
ed1db771321105b3c0dbc70a661b9b10	Monoblock Armchair	1111	4	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
d7dcd79b773dc85c89b84862cdedb6cf	Monoblock Armchair	1111	5	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
4e4faae72b1c3cbd446a70e89e59d8fc	Monoblock Armchair	1111	6	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
307eb8ee16198da891c521eca21464c1	Monoblock Armchair	1111	7	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
d585d095b00cd2f5b50acb64add23834	Monoblock Armchair	1111	8	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
e2d56b6b53ce40332aec920b78d030c1	Monoblock Armchair	1111	9	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
867c4bc5f2010a95f9971b91ddaa8f47	Monoblock Armchair	1111	10	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
96e79218965eb72c92a549dd5a330112	Monoblock Armchair	1111	11	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
9a952cd91000872a8d7d1f5ee0c87317	Monoblock Armchair	1111	12	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
f6be2ff0d88a9434a04a79c0e1a28066	Monoblock Armchair	1111	13	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
2707b2f06a3967105746389278bdf01d	Monoblock Armchair	1111	14	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
0097d9f20753f2e606a36c45693562b2	Monoblock Armchair	1111	15	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
1d2f816fd3c2e0a226c43f5b19e60007	Monoblock Armchair	1111	16	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
f48f7bb1bc6b73e178f57f632d312b3d	Monoblock Armchair	1111	17	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
5429d3157f649805adc2d506df2c31b5	Monoblock Armchair	1111	18	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
0d659ddc03566cb9c55c9ccf0eb2f1bb	Monoblock Armchair	1111	19	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
d1ec29d7366e8b4cbebbd9f63797ebeb	Monoblock Armchair	1111	20	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
fbe5432b9d3f71f3c03c9d7fd0297c2d	Monoblock Armchair	1111	21	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
0b7da663c8a1ee358aa8dbb6e55d0d2b	Monoblock Armchair	1111	22	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
e49274516a27487f894ae956166eb7a4	Monoblock Armchair	1111	23	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
1e14e388e4042dc43defefb9f88695e1	Monoblock Armchair	1111	24	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
ce43ec4b39fa77a2030d73f8855c4396	Monoblock Armchair	1111	25	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
3949350cebfd1d32e7278eaed55dc2f1	Monoblock Armchair	1111	26	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
c52f5ca65357bf402df21e7db538007e	Monoblock Armchair	1111	27	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
e23c30d902f86fc06f700bc4cbe9d67e	Monoblock Armchair	1111	28	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
3447ce251398f59b274e0acfe1541df7	Monoblock Armchair	1111	29	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
03a892d43834d530f2e81de80c96384d	Monoblock Armchair	1111	30	2016-12-01	White Monoblock Armchair	750	Furnitures and Fixtures	Working	824218463_1_644x461.jpg
e044fb795495fd22d8146e50b961e852	Water Heater	8976	\N	2016-08-02	white, 5 Liters	3034	Non-IT Equipment	Working	15416017_676032155908990_688743044_n.jpg
ef80af910fa07870e25b1a4c86d10402	Whiteboard	2121	2	2016-10-03	Office Whiteboard 8x6 ft.	1400	Furnitures and Fixtures	Working	613vnv1h+lL._SL1500_.jpg
2167fcf808b8f383e7e44e25305a08a8	Whiteboard	2121	3	2016-10-03	Office Whiteboard 8x6 ft.	1400	Furnitures and Fixtures	Working	613vnv1h+lL._SL1500_.jpg
4d82271bc2fdb95a9de38ba9e30ab36e	Fire Extinguisher	7768	1	2016-11-08	Firetek	8039	Non-IT Equipment	Working	15356050_676032112575661_302616898_n.jpg
0f4443a0b35f23e2d2a485be3d07ed84	Fire Extinguisher	7768	2	2016-11-08	Firetek	8039	Non-IT Equipment	Working	15356050_676032112575661_302616898_n.jpg
6fa825177a4f6f5a6ff57c739e8311fd	Fire Extinguisher	7768	3	2016-11-08	Firetek	8039	Non-IT Equipment	Working	15356050_676032112575661_302616898_n.jpg
95458099dedf800e701d8bf723ace65a	Fire Extinguisher	7768	4	2016-11-08	Firetek	8039	Non-IT Equipment	Working	15356050_676032112575661_302616898_n.jpg
a25ae004eadf95406855ffbad5653993	Whiteboard	2121	1	2016-10-03	Office Whiteboard 8x6 ft.	1400	Furnitures and Fixtures	Disposed	613vnv1h+lL._SL1500_.jpg
8b6089269d17381873ec2207506aa62a	Book Rack	3321	2	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
2ffe5ae29bb6b60145835654b541b443	Book Rack	3321	3	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
6264104f24cbc6849b7e6ad298862a24	Book Rack	3321	4	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
0a5de450e625177a977f2b7a488c72f5	Book Rack	3321	5	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
b52bd057e37fc8688dddf113c39501e2	Book Rack	3321	6	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
f338ee966b0240a58cc1dbf24855dd26	Book Rack	3321	8	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
e9729543bbfbd7d2677d43bc67c5dc87	Book Rack	3321	9	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
400e5b95e612e990cc5a1891d52b0212	Book Rack	3321	10	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
24ebad661415bb82ae9f9e92167a80d2	Book Rack	3321	11	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
8e693391276cd4fd2397434cdfb5480c	Book Rack	3321	12	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
a8c9bd7685d48510c0a01c2537384363	Book Rack	3321	13	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
05c5bec0698ccaeb128fd431b606b318	Book Rack	3321	14	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
209ae57722bd1bd436646951f80617cc	Book Rack	3321	15	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Working	$_3.JPG
f4d87ed3b0dbf9c79746d00cedbb5e78	Printer	890	1	2016-12-07	Canon, white	3000	IT Equipments	Working	15415962_676024832576389_711313683_n.jpg
c56030557e55275663bd45b48cd0223e	Printer	890	2	2016-12-07	Canon, white	3000	IT Equipments	Working	15415962_676024832576389_711313683_n.jpg
24dc2b5d421e7f6eda94ba6188e6fbc4	Aircon	3432	1	2016-10-01	Split Type Aircon	9750	Aircons	Working	samsung-triangle-ar9000-premium-inverter-airconditioning.jpg
670f33f3cfb5217bcf008786165f1dc7	Aircon	3432	2	2016-10-01	Split Type Aircon	9750	Aircons	Working	samsung-triangle-ar9000-premium-inverter-airconditioning.jpg
dda4087216e15d1784efc310005dd683	Aircon	3432	3	2016-10-01	Split Type Aircon	9750	Aircons	Working	samsung-triangle-ar9000-premium-inverter-airconditioning.jpg
d8585cb93fef89c4cf932574e6554c9c	Aircon	3432	4	2016-10-01	Split Type Aircon	9750	Aircons	Working	samsung-triangle-ar9000-premium-inverter-airconditioning.jpg
c3e71101f147210be216f85bf76a067a	Aircon	3432	5	2016-10-01	Split Type Aircon	9750	Aircons	Working	samsung-triangle-ar9000-premium-inverter-airconditioning.jpg
36125352638845f5a20223ba6a55e522	Printer	8877	1	2016-12-05	Canon, black	4000	IT Equipments	Working	15397724_676024842576388_205134839_o.jpg
8923d70c1cfa2fb0690ca3b912600332	Printer	8877	2	2016-12-05	Canon, black	4000	IT Equipments	Working	15397724_676024842576388_205134839_o.jpg
39b32dfc9ed18533ee98b921687ad87a	Vacuum Cleaner	1997	1	2016-12-01	Cumvac, Water Resistant	8992	IT Equipments	Working	canister-vacuum-cleaner-te-801.jpg
f477b7bc78101c4ae91008a6a403104e	Vacuum Cleaner	1997	2	2016-12-01	Cumvac, Water Resistant	8992	IT Equipments	Working	canister-vacuum-cleaner-te-801.jpg
4756c3d11a0e0bafae44c135837f15d2	Aircon	8987	1	2016-12-04	white, koppei	20000	Aircons	Working	15416935_676025215909684_936472183_n.jpg
20f817b9520d57dd7b9f725537816cbb	Aircon	8987	2	2016-12-04	white, koppei	20000	Aircons	Working	15416935_676025215909684_936472183_n.jpg
43bf67f752b620ea7bcaafa1a4e8ec0d	Aircon	8987	3	2016-12-04	white, koppei	20000	Aircons	Working	15416935_676025215909684_936472183_n.jpg
476ffbfb78ef9adcf5c6010723c04947	Fan	9666	1	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
d6e44245b7dcf2a1fa100f95bae0f3d8	Fan	9666	2	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
d31432767374d7df1f49036637540469	Fan	9666	3	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
48efe880ae65dac453536b2d9ff74104	Fan	9666	4	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
dd4719a433e583c8e9e9a0e0722e4e51	Fan	9666	5	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
0948165ee93e1b462588da88a79abdf6	Fan	9666	6	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
4d441f107ac494bd09add43376ad68d1	Fan	9666	7	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
866c4cda6901e9214d16c6f8e155941a	Fan	9666	8	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
39b8f1905c82dda81dcb616f89cd94f0	Fan	9666	9	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
136b00d6262e70a75e86200fa494cd15	Fan	9666	10	2016-05-16	Asahi, blue and white	7000	Non-IT Equipment	Working	15415964_676031819242357_774772181_n.jpg
fa60438ac1719d11eb95899af86e27c6	Speaker	990	1	2016-12-04	Xenon, black	3000	IT Equipments	Working	15328233_676031952575677_1381844014_n.jpg
a729d76292a6a72fc99598bbc1e33ae6	Speaker	990	2	2016-12-04	Xenon, black	3000	IT Equipments	Working	15328233_676031952575677_1381844014_n.jpg
05d8cccb5f47e5072f0a05b5f514941a	Speaker	998	1	2016-12-04	black and silver	10000	Non-IT Equipment	Working	15218658_676032099242329_469822650_n.jpg
1b932eaf9f7c0cb84f471a560097ddb8	Speaker	998	2	2016-12-04	black and silver	10000	Non-IT Equipment	Working	15218658_676032099242329_469822650_n.jpg
82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	3321	1	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Disposed	$_3.JPG
4e0df9f8468af3566ecc97d7afb106da	Drawer	8285	1	2016-11-07	Brown File Drawer	600	Furnitures and Fixtures	Working	IMG20161122165114.jpg
d66d0d00bb7f294c9a9127f437dd3702	Drawer	8285	2	2016-11-07	Brown File Drawer	600	Furnitures and Fixtures	Working	IMG20161122165114.jpg
02d4ad74e410990974be404efcd00ec1	Book Rack	3321	7	2016-09-19	Book Rack (Brown)	3450	Furnitures and Fixtures	Disposed	$_3.JPG
\.


--
-- Data for Name: equipment_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY equipment_history (record_no, equip_qrcode, start_date, end_date, staff_id, office_id) FROM stdin;
18	81dc9bdb52d04dc20036dbd8313ed055	2016-12-02	\N	mjmatero	14
19	d897133013752d0a321202676961c579	2016-11-01	\N	rrroxas	44
20	66f7b045db373d410f4f0c317378f679	2016-11-01	\N	rrroxas	44
21	7f6f70d8bb2a189bd7414a63f36c5b75	2016-11-01	\N	rrroxas	44
22	402df1281dc6d87253e7dca987b359e2	2016-11-01	\N	rrroxas	44
23	eb007223a9ca6ab699c5070ced080113	2016-11-01	\N	rrroxas	44
24	b421bedcc4030881312979f5a511c8e8	2016-11-01	\N	rrroxas	44
25	30f3361bd6e97b8109893d55a8432556	2016-11-01	\N	rrroxas	44
26	3865247de92da30d35f38538d71a9c40	2016-11-01	\N	rrroxas	44
27	a9cfebcdb4e20ed975e82b7fd877693f	2016-11-01	\N	rrroxas	44
29	1ad62710278671e5baf60606a23388b7	2016-11-01	\N	rrroxas	44
30	546f7901282eee42b1e4e9d7f62aa324	2016-11-01	\N	rrroxas	44
31	0a207b240a7b6e5710c3296016852169	2016-11-01	\N	rrroxas	44
32	ef0eccbf66798ea2fde3af20ec426faf	2016-11-01	\N	rrroxas	44
33	0664921765ed9f23a0e7c353b369f6a1	2016-11-01	\N	rrroxas	44
34	5ca3f29f98b7e6f0f2a69960e7a3dc79	2016-11-01	\N	rrroxas	44
35	8a1101b5e318825614c27c328d643705	2016-11-01	\N	rrroxas	44
36	2d95415113278181485917e2d3b92ab7	2016-11-01	\N	rrroxas	44
37	0d4d4a73c7f711e9993c1ec9f8529d9d	2016-11-01	\N	rrroxas	44
38	3d744532750f482c4210255f577d11db	2016-11-01	\N	rrroxas	44
39	64ea235f0e9a1be992067533b744e11a	2016-11-01	\N	rrroxas	44
40	49e7ef6aa2d9b8d7dfcb90328397fa64	2016-11-01	\N	rrroxas	44
41	67e5f7fec3e2e5d4759de4801e1b72a7	2016-11-01	\N	rrroxas	44
42	335f9d06f26ea8d095e5da9f214fad42	2016-11-01	\N	rrroxas	44
43	e7161c6dabce5fe6cb5ed42bf1df1f35	2016-11-01	\N	rrroxas	44
44	33b46d01b27aa353d5058106d39071f4	2016-11-01	\N	rrroxas	44
45	6d7ef78a926cc98799b8ac5afa9ed957	2016-11-01	\N	rrroxas	44
46	81437f8bd31824435ec008d35d7ce159	2016-11-01	\N	rrroxas	44
47	dfc374d85d0cd0540a0a9f9fb1267c45	2016-11-01	\N	rrroxas	44
48	9c092041bba216f1b4316594e3f22ef8	2016-11-01	\N	rrroxas	44
49	41aab22bfd978b692ff1926a631c110e	2016-11-01	\N	rrroxas	44
50	b79ded847fcced1e28547fe2344e76ff	2016-11-01	\N	rrroxas	44
51	bfd0abe791d0f74c4bce646e1ef07715	2016-11-01	\N	rrroxas	44
52	4c53387320a3f2bafa538cc7a1f4d455	2016-11-01	\N	rrroxas	44
53	b49d6cf78ba207dd1f910bb60905367f	2016-11-01	\N	rrroxas	44
54	a9ac2713a25f8f8b21100eb61857fd48	2016-11-01	\N	rrroxas	44
55	c7a2f923e4829c32a3733e9fc2666689	2016-11-01	\N	rrroxas	44
56	68330ef57d6ed7e6d738003c8c67c530	2016-11-01	\N	rrroxas	44
57	988516f58039b3543d75c96cf826691a	2016-11-01	\N	rrroxas	44
58	483012929d5e1f37018c9c8c4ad34f37	2016-11-01	\N	rrroxas	44
59	363224cff7fac6df72a21d4f717546eb	2016-11-01	\N	rrroxas	44
60	9d5ab86eb7679e018310f3206fd5ed42	2016-11-01	\N	rrroxas	44
61	b6ecfe392f41953fe398097345d8a723	2016-11-01	\N	rrroxas	44
62	1e88a1fd71accb98cd25e5f3ba78fabf	2016-11-01	\N	rrroxas	44
63	a5480fcdcb62bb35b9042ee4219f30b4	2016-11-01	\N	rrroxas	44
64	254ced7a9d32b5bd0e2275803d09f988	2016-11-01	\N	rrroxas	44
65	3c03b3502017eb8342a0bc5c38231be1	2016-11-01	\N	rrroxas	44
66	7ab7241a2c7f74808daa2de02f2d6ba6	2016-11-01	\N	rrroxas	44
67	5951c179de43573583e7d4281df3f495	2016-11-01	\N	rrroxas	44
68	4fbe067e7e30cbc426ab27b1aeb2b7ed	2016-11-01	\N	rrroxas	44
69	6887ab8b8b4ce0926a5dcf75110a9a6c	2016-11-01	\N	rrroxas	44
70	88f3ede619f967ae916d0fc660341855	2016-11-01	\N	rrroxas	44
71	838c45b2ac84a63d5cc28b9ee9079ec2	2016-11-01	\N	rrroxas	44
72	43c0c26bac45cc3b9c3ce0baf1641ae8	2016-11-01	\N	rrroxas	44
73	6e150682aa07c7413d49b3a31b1b7b00	2016-11-01	\N	rrroxas	44
74	83d3be02314f7d74c4c50e109dbabbf4	2016-11-01	\N	rrroxas	44
75	45f5cfd0809889f67f797665aa3515c5	2016-11-01	\N	rrroxas	44
76	0f48cb31cb530841b68d302661d22009	2016-11-01	\N	rrroxas	44
77	1b3bcbdea24bea9f3ada1a3e8828c3a9	2016-11-01	\N	rrroxas	44
78	398d858256d6029dca9230882b499689	2016-11-01	\N	rrroxas	44
79	5c604c70b18685218c9d0dccfc3a0827	2016-11-01	\N	rrroxas	44
80	48c51968abe79f10ae22510fc6ac18c8	2016-11-01	\N	rrroxas	44
81	6cf65ebce72a1088f3a458859e2dc666	2016-11-01	\N	rrroxas	44
82	19854dc4891b66e4c96de4edd7d5ada0	2016-11-01	\N	rrroxas	44
83	54159f0fedf9d40e7f328134de0857b0	2016-11-01	\N	rrroxas	44
84	205759c4f297af0a062088add4fea246	2016-11-01	\N	rrroxas	44
85	e961c2482c6dfda5c5e3968b70836ba6	2016-11-01	\N	rrroxas	44
86	83a7a2bda8bac4960d0e7070addaface	2016-11-01	\N	rrroxas	44
87	22719ac4686c6abdd9dae8ef5b4b8f9d	2016-11-01	\N	rrroxas	44
88	1546df2fce5bed78cd33bedde1aff58b	2016-11-01	\N	rrroxas	44
89	7769db69a040492ddda35c8fc23d1c4b	2016-11-01	\N	rrroxas	44
90	376fd50f094f0a67026e655e4cdd453f	2016-11-01	\N	rrroxas	44
91	a670c97d7803c06154c7f8782178f6f4	2016-11-01	\N	rrroxas	44
92	06703e0008e33c211fc9e9e0ee35c230	2016-11-01	\N	rrroxas	44
93	5917ad1d94b7275c14f0f25ffba9122c	2016-11-01	\N	rrroxas	44
94	d491a7de92b19e5f4b09670cdf2706ba	2016-11-01	\N	rrroxas	44
95	e2102b8bde911503336460b14bb97886	2016-11-01	\N	rrroxas	44
96	12a257147a51bd0a445e171c7857a46d	2016-11-01	\N	rrroxas	44
97	7949a56231d8e13573d0b7834371cfcb	2016-11-01	\N	rrroxas	44
98	d4ccd18e192fbeca26dfdc111397d228	2016-11-01	\N	rrroxas	44
99	41857c1fafe2ed5b86844c92b6df84ae	2016-11-01	\N	rrroxas	44
100	d0da4f9170ab57d98a07ece62d138ec1	2016-11-01	\N	rrroxas	44
101	97adebe60938ceb3907c7eb22488ec94	2016-11-01	\N	rrroxas	44
102	27d088da323408c4b11778aa614692a7	2016-11-01	\N	rrroxas	44
103	594d35e12c546f55b2980b34a0af5c7d	2016-11-01	\N	rrroxas	44
104	89d6d3107abf73968c33f5d1acfae7d1	2016-11-01	\N	rrroxas	44
105	c5055d37f7761d5ac1dbe1c7aa4c91f7	2016-11-01	\N	rrroxas	44
106	97198bc234cd6d0d1b77f91bb473d1b5	2016-11-01	\N	rrroxas	44
107	964e317a1689b33b20099b79a9aa2cc4	2016-11-01	\N	rrroxas	44
108	c326218cd16f94f581684ddf000dcc97	2016-11-01	\N	rrroxas	44
109	5f2015c3451c9ab0909aeffc65a0acad	2016-11-01	\N	rrroxas	44
110	aa8fa69892be87c21091df242109a28d	2016-11-01	\N	rrroxas	44
111	81688afbe5cd5880e758823b93610179	2016-11-01	\N	rrroxas	44
112	42522a0e20f3ad9d89c858970b9b956e	2016-11-01	\N	rrroxas	44
113	c68ce8d267e8cb58065e8ca6da71ca3d	2016-11-01	\N	rrroxas	44
114	7e5e5143ed6f3b348f6f75da7f5ebebe	2016-11-01	\N	rrroxas	44
115	dfd9a349b60da403621c955e189adc5e	2016-11-01	\N	rrroxas	44
116	d4a936d3c1f8a3407e7bcaa15c51f839	2016-11-01	\N	rrroxas	44
117	45627f67d98c16ff2a33a451014656a6	2016-11-01	\N	rrroxas	44
118	64843ad6de7a39dd092c57f430936c27	2016-11-01	\N	rrroxas	44
119	b9d66dabc87adc325461a48c280133f8	2016-11-01	\N	rrroxas	44
120	0d400289b80c906f3bd466491db73ab0	2016-11-01	\N	rrroxas	44
121	321a964bbe6b111d85029dc9b25fafb7	2016-11-01	\N	rrroxas	44
122	53e5de741470c1935eaedf3daf417b03	2016-11-01	\N	rrroxas	44
123	d1cf403a99a57fd7360d97ce5c652295	2016-11-01	\N	rrroxas	44
124	4de2d61497ada3e0e8942ed48c3cbb89	2016-11-01	\N	rrroxas	44
125	a0b6dea6748841384f9f687289a061fa	2016-11-01	\N	rrroxas	44
126	cd0238302cbde1bd2bf12dce32390fe2	2016-11-01	\N	rrroxas	44
127	7b393f8e48d7b396d866add75db9352b	2016-11-01	\N	rrroxas	44
128	fd035aa26fbfbf0ebdf9e7d7c60863e3	2016-11-01	\N	rrroxas	44
129	b045d64f68c5790d4fb44f1d762713da	2016-11-01	\N	rrroxas	44
130	269d39bd56225bd133aec58c267a916f	2016-11-01	\N	rrroxas	44
131	fc34a63ea6d95041adccc5381d312d6f	2016-11-01	\N	rrroxas	44
132	965de5c5dbfaeee6e9b6f0ac304db335	2016-11-01	\N	rrroxas	44
133	48f3a3e0c4d674da2521282f90bddd7f	2016-11-01	\N	rrroxas	44
134	2474748c706d32d2d9f63be16db3b960	2016-11-01	\N	rrroxas	44
135	d62017747b8cb88466ffe6b76eb2a83f	2016-11-01	\N	rrroxas	44
136	9bff0fd479d2cd964c1cf4132905150f	2016-11-01	\N	rrroxas	44
137	2c74afa78eed38c11ed5a8e3e48d757b	2016-11-01	\N	rrroxas	44
138	dca3b6c4435fa89c408cda19783054e6	2016-11-01	\N	rrroxas	44
139	f9fc57cc8d048306d847e879a7ff6573	2016-11-01	\N	rrroxas	44
140	5a67f582d77c40f163d41a43d87de21e	2016-11-01	\N	rrroxas	44
141	097a3bbc7bfae7fe08a497faa56249af	2016-11-01	\N	rrroxas	44
142	f93a76dd3a48af98848e789c6647940f	2016-11-01	\N	rrroxas	44
143	3402785e7f940364c6e4219d446dc8ed	2016-11-01	\N	rrroxas	44
144	69813c68ad3af82ba76f7467828b19c6	2016-11-01	\N	rrroxas	44
145	27c469e4f12a5d57456b063ab27fa3ad	2016-11-01	\N	rrroxas	44
146	2a51fceea363092885dca92a42e10a07	2016-11-01	\N	rrroxas	44
147	5ed831e47471086174b1f6e2fe916aeb	2016-11-01	\N	rrroxas	44
148	1105d911187c2822d149c49d1c95c706	2016-11-01	\N	rrroxas	44
149	30015199ad94bbf7a6be0a9c5157cff2	2016-11-01	\N	rrroxas	44
150	7492a0b74118dc87e101bc88a7ede11d	2016-11-01	\N	rrroxas	44
151	ce18721aef97f3c2bed7122d1b57a5e3	2016-11-01	\N	rrroxas	44
152	dc87f8810ba7a0d6f81fa84614c2bfbc	2016-11-01	\N	rrroxas	44
153	bd93f06ae0c0d4afa78a1a1d4e1b8793	2016-11-01	\N	rrroxas	44
28	f1527ffd33a24ece7ba43ca178a576ed	2016-11-01	2016-12-07	rrroxas	44
154	f1527ffd33a24ece7ba43ca178a576ed	2016-12-07	\N	tevasquez	40
155	def7924e3199be5e18060bb3e1d547a7	2016-11-11	\N	aovicente	44
156	e53a0a2978c28872a4505bdb51db06dc	2016-12-01	\N	mnmacasil	4
157	6b3c49bdba5be0d322334e30c459f8bd	2016-12-06	\N	mjmatero	14
158	3d8a0e750ff4f9b65d2c112a7095d1ce	2016-11-16	\N	rmdulaca	22
159	b8b8c345f81f0479515a0da0add9a159	2016-10-12	\N	tgtan	15
160	e353b610e9ce20f963b4cca5da565605	2016-10-12	\N	tgtan	15
161	1bcaea6d00884aeafe0c076bd322f825	2016-10-12	\N	tgtan	15
162	5bd7f2feff1f11170a507fcd0c0e9734	2016-10-12	\N	tgtan	15
163	5c6ef67e6079f0cdd640a5ad7c288e36	2016-10-12	\N	tgtan	15
164	ccd986d2de4c75133c049e26005b3dbc	2016-10-12	\N	tgtan	15
165	c6c209418814b5cee2107e6e744bb737	2016-10-12	\N	tgtan	15
166	0bc58258e6f3c040a65fa2bfc9d0c907	2016-10-12	\N	tgtan	15
167	0668a01b2098b4335c37c1a1ac0dd71a	2016-10-12	\N	tgtan	15
168	9ac0faa70d798a4598ce2655d8b54232	2016-10-12	\N	tgtan	15
169	b0baee9d279d34fa1dfd71aadb908c3f	2016-12-01	\N	bfespiritu	8
170	afcb7a2f1c158286b48062cd885a9866	2016-12-01	\N	bfespiritu	8
171	4b009c2f8e8d230c498c2db26678dd77	2016-12-01	\N	bfespiritu	8
172	ed1db771321105b3c0dbc70a661b9b10	2016-12-01	\N	bfespiritu	8
173	d7dcd79b773dc85c89b84862cdedb6cf	2016-12-01	\N	bfespiritu	8
174	4e4faae72b1c3cbd446a70e89e59d8fc	2016-12-01	\N	bfespiritu	8
175	307eb8ee16198da891c521eca21464c1	2016-12-01	\N	bfespiritu	8
176	d585d095b00cd2f5b50acb64add23834	2016-12-01	\N	bfespiritu	8
177	e2d56b6b53ce40332aec920b78d030c1	2016-12-01	\N	bfespiritu	8
178	867c4bc5f2010a95f9971b91ddaa8f47	2016-12-01	\N	bfespiritu	8
179	96e79218965eb72c92a549dd5a330112	2016-12-01	\N	bfespiritu	8
180	9a952cd91000872a8d7d1f5ee0c87317	2016-12-01	\N	bfespiritu	8
181	f6be2ff0d88a9434a04a79c0e1a28066	2016-12-01	\N	bfespiritu	8
182	2707b2f06a3967105746389278bdf01d	2016-12-01	\N	bfespiritu	8
183	0097d9f20753f2e606a36c45693562b2	2016-12-01	\N	bfespiritu	8
184	1d2f816fd3c2e0a226c43f5b19e60007	2016-12-01	\N	bfespiritu	8
185	f48f7bb1bc6b73e178f57f632d312b3d	2016-12-01	\N	bfespiritu	8
186	5429d3157f649805adc2d506df2c31b5	2016-12-01	\N	bfespiritu	8
187	0d659ddc03566cb9c55c9ccf0eb2f1bb	2016-12-01	\N	bfespiritu	8
188	d1ec29d7366e8b4cbebbd9f63797ebeb	2016-12-01	\N	bfespiritu	8
189	fbe5432b9d3f71f3c03c9d7fd0297c2d	2016-12-01	\N	bfespiritu	8
190	0b7da663c8a1ee358aa8dbb6e55d0d2b	2016-12-01	\N	bfespiritu	8
191	e49274516a27487f894ae956166eb7a4	2016-12-01	\N	bfespiritu	8
192	1e14e388e4042dc43defefb9f88695e1	2016-12-01	\N	bfespiritu	8
193	ce43ec4b39fa77a2030d73f8855c4396	2016-12-01	\N	bfespiritu	8
194	3949350cebfd1d32e7278eaed55dc2f1	2016-12-01	\N	bfespiritu	8
195	c52f5ca65357bf402df21e7db538007e	2016-12-01	\N	bfespiritu	8
196	e23c30d902f86fc06f700bc4cbe9d67e	2016-12-01	\N	bfespiritu	8
197	3447ce251398f59b274e0acfe1541df7	2016-12-01	\N	bfespiritu	8
198	03a892d43834d530f2e81de80c96384d	2016-12-01	\N	bfespiritu	8
199	e044fb795495fd22d8146e50b961e852	2016-08-02	\N	rmdulaca	22
200	a25ae004eadf95406855ffbad5653993	2016-10-03	\N	aovicente	44
201	ef80af910fa07870e25b1a4c86d10402	2016-10-03	\N	aovicente	44
202	2167fcf808b8f383e7e44e25305a08a8	2016-10-03	\N	aovicente	44
203	4d82271bc2fdb95a9de38ba9e30ab36e	2016-11-08	\N	mrpedrano	29
204	0f4443a0b35f23e2d2a485be3d07ed84	2016-11-08	\N	mrpedrano	29
205	6fa825177a4f6f5a6ff57c739e8311fd	2016-11-08	\N	mrpedrano	29
206	95458099dedf800e701d8bf723ace65a	2016-11-08	\N	mrpedrano	29
207	82b57e60cd5cd5d41a14ffc31b255f5b	2016-09-19	\N	mrpedrano	29
208	8b6089269d17381873ec2207506aa62a	2016-09-19	\N	mrpedrano	29
209	2ffe5ae29bb6b60145835654b541b443	2016-09-19	\N	mrpedrano	29
210	6264104f24cbc6849b7e6ad298862a24	2016-09-19	\N	mrpedrano	29
211	0a5de450e625177a977f2b7a488c72f5	2016-09-19	\N	mrpedrano	29
212	b52bd057e37fc8688dddf113c39501e2	2016-09-19	\N	mrpedrano	29
213	02d4ad74e410990974be404efcd00ec1	2016-09-19	\N	mrpedrano	29
214	f338ee966b0240a58cc1dbf24855dd26	2016-09-19	\N	mrpedrano	29
215	e9729543bbfbd7d2677d43bc67c5dc87	2016-09-19	\N	mrpedrano	29
216	400e5b95e612e990cc5a1891d52b0212	2016-09-19	\N	mrpedrano	29
217	24ebad661415bb82ae9f9e92167a80d2	2016-09-19	\N	mrpedrano	29
218	8e693391276cd4fd2397434cdfb5480c	2016-09-19	\N	mrpedrano	29
219	a8c9bd7685d48510c0a01c2537384363	2016-09-19	\N	mrpedrano	29
220	05c5bec0698ccaeb128fd431b606b318	2016-09-19	\N	mrpedrano	29
221	209ae57722bd1bd436646951f80617cc	2016-09-19	\N	mrpedrano	29
222	24dc2b5d421e7f6eda94ba6188e6fbc4	2016-10-01	\N	mrpedrano	29
223	670f33f3cfb5217bcf008786165f1dc7	2016-10-01	\N	mrpedrano	29
224	dda4087216e15d1784efc310005dd683	2016-10-01	\N	mrpedrano	29
225	d8585cb93fef89c4cf932574e6554c9c	2016-10-01	\N	mrpedrano	29
226	c3e71101f147210be216f85bf76a067a	2016-10-01	\N	mrpedrano	29
228	36125352638845f5a20223ba6a55e522	2016-12-05	\N	rpbayawa	26
229	8923d70c1cfa2fb0690ca3b912600332	2016-12-05	\N	rpbayawa	26
231	39b32dfc9ed18533ee98b921687ad87a	2016-12-01	\N	fcabad	28
232	f477b7bc78101c4ae91008a6a403104e	2016-12-01	\N	fcabad	28
233	4756c3d11a0e0bafae44c135837f15d2	2016-12-04	\N	eobensig	27
234	20f817b9520d57dd7b9f725537816cbb	2016-12-04	\N	eobensig	27
235	43bf67f752b620ea7bcaafa1a4e8ec0d	2016-12-04	\N	eobensig	27
236	476ffbfb78ef9adcf5c6010723c04947	2016-05-16	\N	rdimbong	30
237	d6e44245b7dcf2a1fa100f95bae0f3d8	2016-05-16	\N	rdimbong	30
238	d31432767374d7df1f49036637540469	2016-05-16	\N	rdimbong	30
239	48efe880ae65dac453536b2d9ff74104	2016-05-16	\N	rdimbong	30
240	dd4719a433e583c8e9e9a0e0722e4e51	2016-05-16	\N	rdimbong	30
241	0948165ee93e1b462588da88a79abdf6	2016-05-16	\N	rdimbong	30
242	4d441f107ac494bd09add43376ad68d1	2016-05-16	\N	rdimbong	30
243	866c4cda6901e9214d16c6f8e155941a	2016-05-16	\N	rdimbong	30
244	39b8f1905c82dda81dcb616f89cd94f0	2016-05-16	\N	rdimbong	30
245	136b00d6262e70a75e86200fa494cd15	2016-05-16	\N	rdimbong	30
246	4e0df9f8468af3566ecc97d7afb106da	2016-11-07	\N	asarbuis	64
247	d66d0d00bb7f294c9a9127f437dd3702	2016-11-07	\N	asarbuis	64
\.


--
-- Name: equipment_history_record_no_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('equipment_history_record_no_seq', 247, true);


--
-- Data for Name: inventory_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY inventory_details (inventory_id, initiated_by) FROM stdin;
13	jbdelgado
\.


--
-- Data for Name: mobile_trans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY mobile_trans (id, username, transaction, parameter, result, remarks, "time", office_name) FROM stdin;
31	mrpedrano	Disposal Request	24dc2b5d421e7f6eda94ba6188e6fbc4	For checking	Aircons	2016-12-08 04:24:58.651397	Library
32	mrpedrano	Disposal Request	95458099dedf800e701d8bf723ace65a	For checking	Non-IT Equipment	2016-12-08 04:24:58.684256	Library
33	mrpedrano	Disposal Request	95458099dedf800e701d8bf723ace65a	For checking	Non-IT Equipment	2016-12-08 04:24:58.685465	Library
34	mrpedrano	Disposal Request	24dc2b5d421e7f6eda94ba6188e6fbc4	For checking	Aircons	2016-12-08 04:26:01.420284	Library
37	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:29:15.557833	\N
38	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:33:28.699066	\N
40	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 04:33:51.298702	Library
42	rbbasadre	Disposal Confirmation	82b57e60cd5cd5d41a14ffc31b255f5b	For disposal	Success	2016-12-08 04:38:15.090779	Library
43	rbbasadre	Disposal Confirmation	82b57e60cd5cd5d41a14ffc31b255f5b	For disposal	Success	2016-12-08 04:38:20.73092	Library
46	rbbasadre	Disposal Confirmation	66f7b045db373d410f4f0c317378f679	For disposal	Success	2016-12-08 04:42:09.934279	Sciences Cluster - Department of Computer Science
47	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:54:54.862763	\N
48	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:56:56.702607	\N
49	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:58:08.986204	\N
50	mrpedrano	Scan QR Code	82b57e60cd5cd5d41a14ffc31b255f5b	Book Rack	Success	2016-12-08 04:58:17.479859	\N
52	jbdelgado	Update Equipment Status	4d82271bc2fdb95a9de38ba9e30ab36e	Updated	Success	2016-12-08 16:04:41.855704	\N
53	rrroxas	Scan QR Code	def7924e3199be5e18060bb3e1d547a7	Computer Set	Success	2016-12-08 16:29:40.033447	\N
57	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:43.32272	Library
58	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:43.328042	Library
59	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:43.91112	Library
60	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:43.953713	Library
61	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:45.581032	Library
62	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:45.592073	Library
63	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:55:58.638649	Library
64	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:56:13.068921	Library
66	mrpedrano	Disposal Request	4d82271bc2fdb95a9de38ba9e30ab36e	For checking	Non-IT Equipment	2016-12-08 16:56:41.10473	Library
\.


--
-- Name: mobile_trans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('mobile_trans_id_seq', 67, true);


--
-- Data for Name: office; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY office (office_id, email, password, office_name, cluster_name, md5, short_office_name) FROM stdin;
4	upcebuartsandculture@up.edu.ph	$1$jCvohuMJ$OXtI8aiLNol0gVAS8iT8R/	Arts and Culture	Arts and Humanities	3a3105e049caed5c168d6bcc0b1f5038	Arts and Culture
14	upcebubudgetoffice@up.edu.ph	$1$p2vDGCkQ$rBWkWUudfJE8Pjw396tOf0	Budget Office	Administration	278dc9afd33a2f4b156064721bcbc94c	Budget Office
15	upcebubmc@up.edu.ph	$1$Jzaz9fKR$6LJYeOv5NvfGWkjbUQ8.U/	Business Management Cluster	Management	9589bfb537acab198074e720b60dcdda	Management Cluster
22	upcebudorm@up.edu.ph	$1$pDN6yZ2Z$Thz.v3Sev6gecRUx2Y2Cc0	Dormitory	Administration	5c7184cbc8199da473d7b4ef4f2865b2	Dormitory
26	upcebuhrdo@up.edu.ph	$1$TQ7kd/A5$DKTXnDYKmJn4IN45cNnve0	Human Resource and Development Office	Administration	8f280deac20abff1c000f69d49641c73	HRDO
27	upcebuitso@up.edu.ph	$1$A9vq9XZi$UoLCYdDyNgTfIyWZdwu6R0	Innovation Technology Support Office	Administration	bdcfaf9e08910498159204aa7a88d5f9	ITSO
28	upcebulegaloffice@up.edu.ph	$1$Vo39f1qZ$pCM/pFl57uCrpmuhndBY60	Legal Office	Administration	9345b4e983973212313e4c809b94f75d	Legal Office
30	upcebunstp@up.edu.ph	$1$KNENw4wL$cbb1hrkuZvJEL8ilG2nq71	National Service Training Program	Social Sciences	81ad67bdedd7367dbce7cda841584ee8	NSTP Office
31	upcebuoash@up.edu.ph	$1$MIV6egu.$e6SIn9cPgqMUq95Z.ccDT1	Office of Anti-Sexual Harassment	Administration	029c69acc26d71b938f615bf44ccf21a	OASH
32	upcebuocep@up.edu.ph	$1$xxT3SehW$0e8AAi0bL16V/L1hGAw2H.	Office of Continuing Education and Pahinungod	Administration	43e58212cc7a767fe98d5c68d609994b	OCEP
33	upcebuoca@up.edu.ph	$1$5LWekrg5$CUBxTKhWw5g.ZgNT2k3aD0	Office of the Campus Architect	Administration	efe79c321127e9bcc1ad7f6956d52ca6	OCA
34	upcebuoil@up.edu.ph	$1$1KpKGZae$2GImzqhK8vtu8YzOW6haK1	Office of the International Linkages	Administration	f6a08b944f7078520423ad9f699def40	OIL
35	upcebuosa@up.edu.ph	$1$G2/wKz9F$AlMjY8lfEnYNxPZ/RHyXU.	Office of the Student Affairs	Administration	abe54cc8d0711f64236c9baed23d858c	OSA
36	upcebuocsr@up.edu.ph	$1$z507vTkn$/dIq9WVynRYSDn9pehi77.	Office of the College Secretary and Registrar	Administration	5940569cd1d60781f856f93235b072ee	OCSR
37	upcebupah@up.edu.ph	$1$Bw2yy8.p$IKx4ySPwIAEK85qHUcQ2b1	Performing Arts Hall	Arts and Humanities	b6dbf9d2bc82d946d2171bba213b6b5f	PAH
38	upcebupio@up.edu.ph	$1$IO97xt9q$.pgQWu1D6oNANZdtN0L3/1	Public Information Office	Administration	ebcd6ca0b6321d6bb944a04648c0333c	PIO
5	upcebuahcluster@up.edu.ph	$1$RdNqy1xR$kmaAWcLfc5fZ53GhzQuBx/	Arts and Humanities Cluster	Arts and Humanities	b6be3428bf00819ccf5b32ddfc92fdef	AH Cluster
39	upcebusciences@up.edu.ph	$1$b8AeyZuE$LcJ3tZkZDoKr5z1HIQ9qK0	Sciences Cluster	Sciences	d1c176de45c578b9c0a1b50bdf99df26	Sciences Cluster
1	upcebuaccounting@up.edu.ph	$1$SHurXg5a$SgFIRTP7EeFixQliVWtcq0	Accounting Office	Administration	9726255eec083aa56dc0449a21b33190	Arts and Culture
2	upcebuallworkers@up.edu.ph	$1$qvETVpWl$h29n1D9OWi/Lj999HT6RK1	All UP Workers Union	Administration	a06be211ee1b949b0dc8cef92a4373a9	All UP WU
3	upcebualumniaffairs@up.edu.ph	$1$StSLVexA$q9dzN/SCrPD9BAy/0sAJp/	Alumni Office	Administration	9855f5cdff0306ae33a49f89e087ccbc	Alumni Office
6	upcebuahclusterfa@up.edu.ph	$1$ARSyzavg$/UkVdq4HJZ/UXSjzpoa7s/	Arts and Humanities Cluster - Fine Arts	Arts and Humanities	b6be3428bf00819ccf5b32ddfc92fdef	Fine Arts Dept.
7	upcebuminigallery@up.edu.ph	$1$NlMWptA4$Mvr/elcfbbwEtvvzWHG1Q/	Arts and Humanities Cluster - Mini Gallery	Arts and Humanities	7abcee9bc5052d5567af5162c475c32b	Mini Gallery
8	upcebuahclustermc@up.edu.ph	$1$kW4HayYP$5nnaGAIVB5tIUQ6N8DdpD.	Arts and Humanities Cluster - Mass Communication	Arts and Humanities	b6be3428bf00819ccf5b32ddfc92fdef	Mass Comm Dept.
9	upcebuadaa@up.edu.ph	$1$Wnjw7MtX$R7NBhcif/y8slaLAslda71	Associate Dean for Academic Affairs	Administration	c9c486b04879da93ffdc9989fa91d48a	ADAA
10	upcebuada@up.edu.ph	$1$fuFcEiAr$z4kRKDJ3VXd78D8qPGkpS/	Associate Dean for Administration	Administration	e52e7ce4ac2458867d05eaad577560db	ADAA
11	upcebuavr1@up.edu.ph	$1$MXU.UZjk$EbwNVf7omeakC0/YXYaim1	Audio Visual Room 1	Administration	481189a085be54668725d022a22b8c62	AVR1
12	upcebuavr2@up.edu.ph	$1$UD3wpgVL$puL1KH78Uf2aZqgr7gbPX0	Audio Visual Room 2	Administration	18615b8f292a41582d0de23c9223148d	AVR2
13	upcebubidsandawards@up.edu.ph	$1$HjpmU7f3$4ZEJVtK92bBpP8AxoSPAG1	Bids and Awards	Administration	0456eaad58d067b5a10b00b49d49b436	Bids and Awards
16	upcebucdmo@up.edu.ph	$1$heanKN.V$7uytNIlSEW0ZivhFIMUhS1	Campus Development and Maintenance Office	Administration	7354c69225a7fb103e051803d3503514	CDMO
17	upcebucashoffice@up.edu.ph	$1$ahIMe/U5$xslBvJDMnmdFbL2ODbePu.	Cash Office	Administration	f444695b98e665224743401db947cda9	Cash Office
18	upcebucvsc@up.edu.ph	$1$80T2Nf23$.0cpYa70xo07JGCXJMuHN1	Central Visayas Studies Center	Arts and Humanities	a6bcc94cb4105d93c7cd391af9532d95	CVSC
19	upcebucoa@up.edu.ph	$1$vWuJMPXg$wxao/eo81ajJCCKyfbYaJ1	Commission on Audit	Administration	51f0d23ac735a2bd56bca18645843840	COA
20	upcebucsu@up.edu.ph	$1$A83h2RS4$sEHmKvi3SRpEiaCw3A7/y0	Computing Services Unit	Administration	c4f3b745b1780458f9fd3c27b49cd24b	CSU
21	upcebudean@up.edu.ph	$1$KBCuEwn8$QddJe12I7ChABZIppQtUV/	Deans Office	Administration	c467e56db62b8e21026c60cbeb20d308	Deans Office
23	upcebugad@up.edu.ph	$1$BQdQLNz/$S1DdsXyDSDSIY3sjA71Mn.	Gender and Development Office	Administration	104ffb77ee168098c6b689fe59d666d4	GAD
24	upcebugh@up.edu.ph	$1$/8um9ECW$WxPFsjPwIlamdX7.PAhEM0	Guesthouse	Administration	1bc44065d36bc88bf9b55c2a8aaa3c59	Guesthouse
25	upcebuhsu@up.edu.ph	$1$dZ.y4u1m$rkCGdPDCL4ciAIUpmpTCv0	Health Services Unit	Administration	75371e7e4287a757bf721d999f0e75d5	HSU / Clinic
40	upcebummc@up.edu.ph	$1$gZGxhdpm$8gIW86nDDvLATljVxLK9r0	Sciences Cluster - Math Department	Sciences	51434272ddcb40e9ca2e2a3ae6231fa9	Math Department
49	upcebumed@up.edu.ph	$1$PYJ5ZQei$SMkeIdT7m.B.UEjBfe5BR/	Social Sciences - Master of Education	Social Sciences	6a92cc847768907d5c1967628ff40ea4	M Ed.
50	upcebupe@up.edu.ph	$1$ZfqIYNyi$zS9spnzOJYqnbQ9Kg.aFT1	Social Sciences - P.E Department	Social Sciences	53ead7d604e6b0ca03af9db265338b43	PE Department
51	upcebuhs@up.edu.ph	$1$CfUj3n9m$XCw/3oWeLzs7qZGjjif8H0	Social Sciences - High School Department	Social Sciences	23809ff572ab8160ef781946260c3b57	High School Dept.
52	upcebuuppsyma@up.edu.ph	$1$fobrz1Q4$6UAZM/Z7HtrHlRtOUxNL40	Social Sciences - Psychology Department	Social Sciences	f105e934b96b41b8c48cb5d3a30a9cc5	Psych Dept.
53	upcebuuppss@up.edu.ph	$1$JR1WITHV$4D1mgwM5a4y6JCCU.Ix6H0	Social Sciences - Political Science Department	Social Sciences	67d1600ee0fcd7644f1141aaaf2853ea	Pol Sci Dept.
54	upcebuspmo@up.edu.ph	$1$iDkGpxj.$oplJBDV0aWZDTLZvJPSbo/	Supply and Property Management Office	Administration	7a1eabc3deb7fd02ceb1e16eafc41073	SPMO
55	upcebutlrc@up.edu.ph	$1$XMuO83ls$89mOwhRL6LJxVh9vmA8lH1	Teaching and Learning Resource Center	Administration	77306354a57dccde2214fbe3d5427c6c	TLRC
29	upcebulibrary@gmail.com	$1$.NjbyoWE$VufZNetxZpNOjNxq0KEu31	Library	Administration	2ea7fe2bd051ec076a226b7dab76aaa3	Library
41	upcebumses@up.edu.ph	$1$GepbMeOB$MTqNnnxVi7.4yTEQSDUHR/	Sciences Cluster - Masters of Sciences in Environmental Science	Sciences	e900e40bc91d3f9f7f0a99fed68a2e96	MSES
42	upcebubio@up.edu.ph	$1$t2mPkNnA$xbRjZRhFmGF/WBSb/NDUr/	Sciences Cluster - Biology Department	Sciences	8f1c04b89761789593adc6d19f4cefad	Biology Department
43	upcebuchemlab@up.edu.ph	$1$STj.HHpJ$6AendxVuEKGwJHH.wB1LY1	Sciences Cluster - Chemistry Laboratory	Sciences	d4ac1478a4d8a4f591d35e3d75f3de65	Chem Lab
44	upcebudcs@up.edu.ph	$1$Y4HFAAkQ$M3d14xDogiIbf3jLqpWsS/	Sciences Cluster - Department of Computer Science	Sciences	4c37917ab90d78a68c113ae8f57ca070	DCS
45	upcebuphyslab@up.edu.ph	$1$kjOuwLT1$0/Ae2n/w7OmbHNRynl9.Q0	Sciences Cluster - Physics Laboratory	Sciences	370757d2df51ae456bf63c165fc71817	Physics Lab
46	upcebusecurity@up.edu.ph	$1$ejIgFlxs$T5RnZ..1VNNw1bs72QuJD.	Security Office	Administration	9371e9ae61dff55d5d6d6d050943301b	Security Office
47	upcebusnwf@up.edu.ph	$1$GUaPJ1jw$ljPXFeeMMo.erzdcabzU20	Sentro ng Wikang Filipino	Administration	a969b40f85202d86b69b1de49de10823	SWF
48	upcebusocsci@up.edu.ph	$1$VisT6vlH$IpHuY27yYoouu/sXVUZOl.	Social Sciences Cluster	Social Sciences	3b783ae84abf6f89932f84d2036da818	Soc Sci Cluster
56	upcebutbi@up.edu.ph	$1$CgGDHjsv$2rVnxSAqn8s3R35nrUNkO/	Technological Business Incubation	Sciences	4fc92a91ed496f3d76ff3b2a370c508c	TBI
57	upcebutugani@up.edu.ph	$1$xIewZ8ks$QnlSRKeDyKoO2KgfMJ5t7/	Tug-ani Office	\N	e16704d9e243b23b4f4e557748d6eef6	Tug-ani
58	upcebuusc@up.edu.ph	$1$yb0cPZzr$gDOhW3yiwAiBZXmrwjkvG0	University Student Council	\N	81ad67bdedd7367dbce7cda841584ee8	University Student Council
59	upcebusrp@up.edu.ph	$1$p50RDcxz$Ey83wZrhFB8VGAwF8KaK6/	UP Professionals School SRP	Administration	714a2e07b69985b76d21439c63679eb6	UP SRP
60	upcebuilc@up.edu.ph	$1$yfRUPg7i$GzwIVZl2DloG25klPPRJw1	Interactive Learning Center	Administration	25a9ac406aceb47a0c6cade972bc26fa	ILC
61	lidar1@up.edu.ph	$1$F/kUAN22$bDsVpsFCMD8ovVMjVMRSX1	UP Phil Lidar 1	\N	b44d019506ed50e480764e73531dcd1e	Lidar 1
62	lidar2@up.edu.ph	$1$GysY38Pz$V2KnZM0CklzrpKW/OG8C21	UP Phil Lidar 2	\N	06e63a24f83f18232a95f34e47220ec5	Lidar 2
63	athleticsoffice@up.edu.ph	$1$WMhGeik3$BilfLoYxIsDQb7yMZSTCE0	Athletic's Office	Social Sciences	6b2d61f4b07d99352559670b8eb22f4a	Athletic's Office
64	pta@up.edu.ph	$1$er/N8XWs$1Ya25V0y37/UojwCtnMGP/	Parent's and Teacher's Association Office	Administration	7dfa942088bb1894f9d5b5ae8d3c5973	PTA Office
\.


--
-- Name: office_office_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('office_office_id_seq', 64, true);


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY schedule (id, title, start, "end", event_status) FROM stdin;
12	Disposal	2016-12-14	2016-12-21	Upcoming
\.


--
-- Name: schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('schedule_id_seq', 13, true);


--
-- Data for Name: spmo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY spmo (username, password, email, md5) FROM stdin;
jbdelgado	$1$m5J/D/oz$S/fBmfQ2QZiOTd15dXg300	jbdelgado@up.edu.ph	c4ff3e66d10a832816eb74e7a38c3da4
sbmagdadaro	$1$mOuW4Xrr$Lv6NCAuaUDSBYscjS13.W0	sbmagdadaro@up.edu.ph	0949aaa92ab95474138f07f54c104cb5
\.


--
-- Data for Name: spmo_staff_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY spmo_staff_assignment (inventory_id, inventory_office, spmo_assigned) FROM stdin;
\.


--
-- Data for Name: staff; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY staff (office_id, staff_id, first_name, middle_init, last_name, role) FROM stdin;
29	mrpedrano	Mylah	R	Pedrano	Office Head
54	jbdelgado	Jenny	B	Delgado	SPMO
21	ldcorro	Liza	D	Corro	Office Head
1	jklepiten	Jannette	K	Lepiten	Office Head
4	mnmacasil	Ma. Alena	N	Macasil	Office Head
6	pptudtud	Palmy Marinel	P	Tudtud	Office Head
5	jcpinzon	Jocelyn	C	Pinzon	Office Head
8	bfespiritu	Belinda	F	Espiritu	Office Head
14	mjmatero	Marie Jane	J	Matero	Office Head
15	tgtan	Tiffany Adelaine	G	Tan	Office Head
16	abbascon	Albert	B	Bascon	Office Head
17	rcbinagatan	Rita	C	Binagatan	Office Head
18	yrorillo	Yuleta	R	Orillo	Office Head
20	vmsesaldo	Van Owen	M	Sesaldo	Office Head
44	rrroxas	Robert	R	Roxas	Office Head
22	rmdulaca	Ryan Ciriaco	M	Dulaca	Office Head
25	lsdee	Lorel	S	Dee	Office Head
26	rpbayawa	Rebecca	P	Bayawa	Office Head
27	eobensig	Eukene	O	Bensig	Office Head
23	hbespiritu	Henry Francis	B	Espiritu	Office Head
60	jegumalal	Jeraline	E	Gumalal	Office Head
28	fcabad	Francis Michael	C	Abad	Office Head
30	rdimbong	Regletto Aldrich	D	Imbong	Office Head
31	agmaglasang	Anabelle	G	Maglasang	Office Head
35	emfunesto	Ellen Grace	M	Funesto	Office Head
9	rpgalapate	Ritchielita	P	Galapate	Office Head
10	lasia	Leahlizbeth	A	Sia	Office Head
36	mgbugash	May Christina	G	Bugash	Office Head
59	mfchavez	May Gretchen	F	Chavez	Office Head
38	jeyap	Januar	E	Yap	Office Head
42	gocadiz	Geofe	O	Cadiz	Office Head
39	jrsinogaya	Jonnifer	R	Sinogaya	Office Head
40	tevasquez	Trilbe Lizann	E	Vasquez	Office Head
41	ffmaglangit	Fleurdeliz	F	Maglangit	Office Head
48	mvmende	Ma. Rowena	V	Mende	Office Head
51	cmrodel	Catherine	M	Rodel	Office Head
52	fggeneralao	Flora	G	Generalao	Office Head
54	sbmagdadaro	Stineli	B	Magdadaro	SPMO
56	jdlumagbas	Jedaiah Joel	D	Lumagb	Office Head
54	fdaday	Francis	D	Aday	Checker
44	aovicente	Aileen Joan	O	Vicente	\N
51	rbbasadre	Robert	B	Basadre	Checker
64	asarbuis	Arvin	S	Arbuis	Clerk
\.


--
-- Data for Name: transaction_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY transaction_log (transaction_no, staff_id, transaction_date, transaction_time, transaction_details, equip_qrcode) FROM stdin;
137	jbdelgado	2016-12-07	15:49:34.864707	added a staff	\N
138	jbdelgado	2016-12-07	15:58:03.125309	added a staff	\N
139	jbdelgado	2016-12-07	15:59:44.102516	added a staff	\N
140	jbdelgado	2016-12-07	16:00:45.831677	added a staff	\N
141	jbdelgado	2016-12-07	16:01:13.933539	added a staff	\N
142	jbdelgado	2016-12-07	16:01:43.302824	added a staff	\N
143	jbdelgado	2016-12-07	16:02:04.342441	added a staff	\N
144	jbdelgado	2016-12-07	16:02:43.039172	added a staff	\N
145	jbdelgado	2016-12-07	16:04:47.626737	added a staff	\N
146	jbdelgado	2016-12-07	16:05:20.233283	added a staff	\N
147	jbdelgado	2016-12-07	16:14:52.45002	added a staff	\N
148	jbdelgado	2016-12-07	16:16:20.693238	added a staff	\N
149	jbdelgado	2016-12-07	16:16:43.068657	added a staff	\N
150	jbdelgado	2016-12-07	16:17:22.914685	added a staff	\N
151	jbdelgado	2016-12-07	16:17:47.268733	added a staff	\N
152	jbdelgado	2016-12-07	16:18:40.321397	added a staff	\N
153	jbdelgado	2016-12-07	16:21:58.016281	added a staff	\N
154	jbdelgado	2016-12-07	16:22:31.298912	added a staff	\N
155	jbdelgado	2016-12-07	16:23:08.78528	added a staff	\N
156	jbdelgado	2016-12-07	16:23:39.430685	added a staff	\N
157	jbdelgado	2016-12-07	16:34:47.023835	added a staff	\N
158	jbdelgado	2016-12-07	16:35:22.079695	added a staff	\N
159	jbdelgado	2016-12-07	16:36:10.599845	added a staff	\N
160	jbdelgado	2016-12-07	16:37:08.174167	added a staff	\N
161	jbdelgado	2016-12-07	16:38:01.04723	added a staff	\N
162	jbdelgado	2016-12-07	16:38:35.026334	added a staff	\N
163	jbdelgado	2016-12-07	16:39:31.686423	added a staff	\N
164	jbdelgado	2016-12-07	16:40:40.902369	added a staff	\N
165	jbdelgado	2016-12-07	16:41:44.139046	added a staff	\N
166	jbdelgado	2016-12-07	16:42:10.541217	added a staff	\N
167	jbdelgado	2016-12-07	16:45:20.851476	added a staff	\N
168	jbdelgado	2016-12-07	16:46:54.307914	added a staff	\N
169	jbdelgado	2016-12-07	16:50:26.053959	added a staff	\N
170	jbdelgado	2016-12-07	16:52:01.788503	added a staff	\N
172	jbdelgado	2016-12-07	16:55:34.971909	added a staff	\N
173	jbdelgado	2016-12-07	16:56:03.532664	added a staff	\N
174	jbdelgado	2016-12-07	16:56:32.441855	added a staff	\N
175	jbdelgado	2016-12-07	16:58:05.917634	added a staff	\N
176	jbdelgado	2016-12-07	16:58:47.542399	added a staff	\N
177	jbdelgado	2016-12-07	17:01:31.015766	added a staff	\N
178	jbdelgado	2016-12-07	17:02:35.298465	added a staff	\N
179	jbdelgado	2016-12-07	17:03:45.925867	added a staff	\N
180	jbdelgado	2016-12-07	17:09:15.836165	added an equipment	d897133013752d0a321202676961c579
181	jbdelgado	2016-12-07	17:09:15.840427	added an equipment	66f7b045db373d410f4f0c317378f679
182	jbdelgado	2016-12-07	17:09:15.847917	added an equipment	7f6f70d8bb2a189bd7414a63f36c5b75
183	jbdelgado	2016-12-07	17:09:15.85135	added an equipment	402df1281dc6d87253e7dca987b359e2
184	jbdelgado	2016-12-07	17:09:15.857976	added an equipment	eb007223a9ca6ab699c5070ced080113
185	jbdelgado	2016-12-07	17:09:15.866665	added an equipment	b421bedcc4030881312979f5a511c8e8
186	jbdelgado	2016-12-07	17:09:15.873447	added an equipment	30f3361bd6e97b8109893d55a8432556
187	jbdelgado	2016-12-07	17:09:15.87645	added an equipment	3865247de92da30d35f38538d71a9c40
188	jbdelgado	2016-12-07	17:09:15.879616	added an equipment	a9cfebcdb4e20ed975e82b7fd877693f
189	jbdelgado	2016-12-07	17:09:15.88277	added an equipment	f1527ffd33a24ece7ba43ca178a576ed
190	jbdelgado	2016-12-07	17:09:15.888279	added an equipment	1ad62710278671e5baf60606a23388b7
191	jbdelgado	2016-12-07	17:09:15.893209	added an equipment	546f7901282eee42b1e4e9d7f62aa324
192	jbdelgado	2016-12-07	17:09:15.896544	added an equipment	0a207b240a7b6e5710c3296016852169
193	jbdelgado	2016-12-07	17:09:15.899663	added an equipment	ef0eccbf66798ea2fde3af20ec426faf
194	jbdelgado	2016-12-07	17:09:15.902584	added an equipment	0664921765ed9f23a0e7c353b369f6a1
195	jbdelgado	2016-12-07	17:09:15.957328	added an equipment	5ca3f29f98b7e6f0f2a69960e7a3dc79
196	jbdelgado	2016-12-07	17:09:15.969818	added an equipment	8a1101b5e318825614c27c328d643705
197	jbdelgado	2016-12-07	17:09:15.973058	added an equipment	2d95415113278181485917e2d3b92ab7
198	jbdelgado	2016-12-07	17:09:15.990326	added an equipment	0d4d4a73c7f711e9993c1ec9f8529d9d
199	jbdelgado	2016-12-07	17:09:15.994914	added an equipment	3d744532750f482c4210255f577d11db
200	jbdelgado	2016-12-07	17:09:15.999333	added an equipment	64ea235f0e9a1be992067533b744e11a
201	jbdelgado	2016-12-07	17:09:16.003114	added an equipment	49e7ef6aa2d9b8d7dfcb90328397fa64
202	jbdelgado	2016-12-07	17:09:16.006641	added an equipment	67e5f7fec3e2e5d4759de4801e1b72a7
203	jbdelgado	2016-12-07	17:09:16.010689	added an equipment	335f9d06f26ea8d095e5da9f214fad42
204	jbdelgado	2016-12-07	17:09:16.033712	added an equipment	e7161c6dabce5fe6cb5ed42bf1df1f35
205	jbdelgado	2016-12-07	17:09:16.037312	added an equipment	33b46d01b27aa353d5058106d39071f4
206	jbdelgado	2016-12-07	17:09:16.040476	added an equipment	6d7ef78a926cc98799b8ac5afa9ed957
207	jbdelgado	2016-12-07	17:09:16.054482	added an equipment	81437f8bd31824435ec008d35d7ce159
208	jbdelgado	2016-12-07	17:09:16.060552	added an equipment	dfc374d85d0cd0540a0a9f9fb1267c45
209	jbdelgado	2016-12-07	17:09:16.075836	added an equipment	9c092041bba216f1b4316594e3f22ef8
210	jbdelgado	2016-12-07	17:09:16.079068	added an equipment	41aab22bfd978b692ff1926a631c110e
211	jbdelgado	2016-12-07	17:09:16.090426	added an equipment	b79ded847fcced1e28547fe2344e76ff
212	jbdelgado	2016-12-07	17:09:16.094002	added an equipment	bfd0abe791d0f74c4bce646e1ef07715
213	jbdelgado	2016-12-07	17:09:16.097024	added an equipment	4c53387320a3f2bafa538cc7a1f4d455
214	jbdelgado	2016-12-07	17:09:16.100337	added an equipment	b49d6cf78ba207dd1f910bb60905367f
215	jbdelgado	2016-12-07	17:09:16.105587	added an equipment	a9ac2713a25f8f8b21100eb61857fd48
216	jbdelgado	2016-12-07	17:09:16.12308	added an equipment	c7a2f923e4829c32a3733e9fc2666689
217	jbdelgado	2016-12-07	17:09:16.127236	added an equipment	68330ef57d6ed7e6d738003c8c67c530
218	jbdelgado	2016-12-07	17:09:16.130556	added an equipment	988516f58039b3543d75c96cf826691a
219	jbdelgado	2016-12-07	17:09:16.135688	added an equipment	483012929d5e1f37018c9c8c4ad34f37
220	jbdelgado	2016-12-07	17:09:16.143424	added an equipment	363224cff7fac6df72a21d4f717546eb
221	jbdelgado	2016-12-07	17:09:16.154614	added an equipment	9d5ab86eb7679e018310f3206fd5ed42
222	jbdelgado	2016-12-07	17:09:16.158636	added an equipment	b6ecfe392f41953fe398097345d8a723
223	jbdelgado	2016-12-07	17:09:16.162625	added an equipment	1e88a1fd71accb98cd25e5f3ba78fabf
224	jbdelgado	2016-12-07	17:09:16.165777	added an equipment	a5480fcdcb62bb35b9042ee4219f30b4
225	jbdelgado	2016-12-07	17:09:16.176705	added an equipment	254ced7a9d32b5bd0e2275803d09f988
226	jbdelgado	2016-12-07	17:09:16.180076	added an equipment	3c03b3502017eb8342a0bc5c38231be1
227	jbdelgado	2016-12-07	17:09:16.183394	added an equipment	7ab7241a2c7f74808daa2de02f2d6ba6
228	jbdelgado	2016-12-07	17:09:16.186693	added an equipment	5951c179de43573583e7d4281df3f495
229	jbdelgado	2016-12-07	17:09:16.18974	added an equipment	4fbe067e7e30cbc426ab27b1aeb2b7ed
230	jbdelgado	2016-12-07	17:09:16.192589	added an equipment	6887ab8b8b4ce0926a5dcf75110a9a6c
231	jbdelgado	2016-12-07	17:09:16.195218	added an equipment	88f3ede619f967ae916d0fc660341855
232	jbdelgado	2016-12-07	17:09:16.199571	added an equipment	838c45b2ac84a63d5cc28b9ee9079ec2
233	jbdelgado	2016-12-07	17:09:16.203103	added an equipment	43c0c26bac45cc3b9c3ce0baf1641ae8
234	jbdelgado	2016-12-07	17:09:16.206982	added an equipment	6e150682aa07c7413d49b3a31b1b7b00
235	jbdelgado	2016-12-07	17:09:16.210317	added an equipment	83d3be02314f7d74c4c50e109dbabbf4
236	jbdelgado	2016-12-07	17:09:16.213361	added an equipment	45f5cfd0809889f67f797665aa3515c5
237	jbdelgado	2016-12-07	17:09:16.216232	added an equipment	0f48cb31cb530841b68d302661d22009
238	jbdelgado	2016-12-07	17:09:16.219129	added an equipment	1b3bcbdea24bea9f3ada1a3e8828c3a9
239	jbdelgado	2016-12-07	17:09:16.221896	added an equipment	398d858256d6029dca9230882b499689
240	jbdelgado	2016-12-07	17:09:16.224631	added an equipment	5c604c70b18685218c9d0dccfc3a0827
241	jbdelgado	2016-12-07	17:09:16.227391	added an equipment	48c51968abe79f10ae22510fc6ac18c8
242	jbdelgado	2016-12-07	17:09:16.229848	added an equipment	6cf65ebce72a1088f3a458859e2dc666
243	jbdelgado	2016-12-07	17:09:16.233371	added an equipment	19854dc4891b66e4c96de4edd7d5ada0
244	jbdelgado	2016-12-07	17:09:16.236635	added an equipment	54159f0fedf9d40e7f328134de0857b0
245	jbdelgado	2016-12-07	17:09:16.23928	added an equipment	205759c4f297af0a062088add4fea246
246	jbdelgado	2016-12-07	17:09:16.241933	added an equipment	e961c2482c6dfda5c5e3968b70836ba6
247	jbdelgado	2016-12-07	17:09:16.244688	added an equipment	83a7a2bda8bac4960d0e7070addaface
248	jbdelgado	2016-12-07	17:09:16.247328	added an equipment	22719ac4686c6abdd9dae8ef5b4b8f9d
249	jbdelgado	2016-12-07	17:09:16.249793	added an equipment	1546df2fce5bed78cd33bedde1aff58b
250	jbdelgado	2016-12-07	17:09:16.251775	added an equipment	7769db69a040492ddda35c8fc23d1c4b
251	jbdelgado	2016-12-07	17:09:16.253768	added an equipment	376fd50f094f0a67026e655e4cdd453f
252	jbdelgado	2016-12-07	17:09:16.25576	added an equipment	a670c97d7803c06154c7f8782178f6f4
253	jbdelgado	2016-12-07	17:09:16.257743	added an equipment	06703e0008e33c211fc9e9e0ee35c230
254	jbdelgado	2016-12-07	17:09:16.259932	added an equipment	5917ad1d94b7275c14f0f25ffba9122c
255	jbdelgado	2016-12-07	17:09:16.262004	added an equipment	d491a7de92b19e5f4b09670cdf2706ba
256	jbdelgado	2016-12-07	17:09:16.265956	added an equipment	e2102b8bde911503336460b14bb97886
257	jbdelgado	2016-12-07	17:09:16.272121	added an equipment	12a257147a51bd0a445e171c7857a46d
258	jbdelgado	2016-12-07	17:09:16.275351	added an equipment	7949a56231d8e13573d0b7834371cfcb
259	jbdelgado	2016-12-07	17:09:16.279234	added an equipment	d4ccd18e192fbeca26dfdc111397d228
260	jbdelgado	2016-12-07	17:09:16.282496	added an equipment	41857c1fafe2ed5b86844c92b6df84ae
261	jbdelgado	2016-12-07	17:09:16.285381	added an equipment	d0da4f9170ab57d98a07ece62d138ec1
262	jbdelgado	2016-12-07	17:09:16.28824	added an equipment	97adebe60938ceb3907c7eb22488ec94
263	jbdelgado	2016-12-07	17:09:16.290956	added an equipment	27d088da323408c4b11778aa614692a7
264	jbdelgado	2016-12-07	17:09:16.293577	added an equipment	594d35e12c546f55b2980b34a0af5c7d
265	jbdelgado	2016-12-07	17:09:16.296203	added an equipment	89d6d3107abf73968c33f5d1acfae7d1
266	jbdelgado	2016-12-07	17:09:16.29891	added an equipment	c5055d37f7761d5ac1dbe1c7aa4c91f7
267	jbdelgado	2016-12-07	17:09:16.301531	added an equipment	97198bc234cd6d0d1b77f91bb473d1b5
268	jbdelgado	2016-12-07	17:09:16.304206	added an equipment	964e317a1689b33b20099b79a9aa2cc4
269	jbdelgado	2016-12-07	17:09:16.306844	added an equipment	c326218cd16f94f581684ddf000dcc97
270	jbdelgado	2016-12-07	17:09:16.310308	added an equipment	5f2015c3451c9ab0909aeffc65a0acad
271	jbdelgado	2016-12-07	17:09:16.312978	added an equipment	aa8fa69892be87c21091df242109a28d
272	jbdelgado	2016-12-07	17:09:16.315703	added an equipment	81688afbe5cd5880e758823b93610179
273	jbdelgado	2016-12-07	17:09:16.318304	added an equipment	42522a0e20f3ad9d89c858970b9b956e
274	jbdelgado	2016-12-07	17:09:16.320847	added an equipment	c68ce8d267e8cb58065e8ca6da71ca3d
275	jbdelgado	2016-12-07	17:09:16.32458	added an equipment	7e5e5143ed6f3b348f6f75da7f5ebebe
276	jbdelgado	2016-12-07	17:09:16.327344	added an equipment	dfd9a349b60da403621c955e189adc5e
277	jbdelgado	2016-12-07	17:09:16.330051	added an equipment	d4a936d3c1f8a3407e7bcaa15c51f839
278	jbdelgado	2016-12-07	17:09:16.332713	added an equipment	45627f67d98c16ff2a33a451014656a6
279	jbdelgado	2016-12-07	17:09:16.335425	added an equipment	64843ad6de7a39dd092c57f430936c27
280	jbdelgado	2016-12-07	17:09:16.337567	added an equipment	b9d66dabc87adc325461a48c280133f8
281	jbdelgado	2016-12-07	17:09:16.339816	added an equipment	0d400289b80c906f3bd466491db73ab0
282	jbdelgado	2016-12-07	17:09:16.342732	added an equipment	321a964bbe6b111d85029dc9b25fafb7
283	jbdelgado	2016-12-07	17:09:16.346393	added an equipment	53e5de741470c1935eaedf3daf417b03
284	jbdelgado	2016-12-07	17:09:16.34983	added an equipment	d1cf403a99a57fd7360d97ce5c652295
285	jbdelgado	2016-12-07	17:09:16.353121	added an equipment	4de2d61497ada3e0e8942ed48c3cbb89
286	jbdelgado	2016-12-07	17:09:16.355956	added an equipment	a0b6dea6748841384f9f687289a061fa
287	jbdelgado	2016-12-07	17:09:16.358635	added an equipment	cd0238302cbde1bd2bf12dce32390fe2
288	jbdelgado	2016-12-07	17:09:16.361732	added an equipment	7b393f8e48d7b396d866add75db9352b
289	jbdelgado	2016-12-07	17:09:16.364333	added an equipment	fd035aa26fbfbf0ebdf9e7d7c60863e3
290	jbdelgado	2016-12-07	17:09:16.367051	added an equipment	b045d64f68c5790d4fb44f1d762713da
291	jbdelgado	2016-12-07	17:09:16.369828	added an equipment	269d39bd56225bd133aec58c267a916f
292	jbdelgado	2016-12-07	17:09:16.372523	added an equipment	fc34a63ea6d95041adccc5381d312d6f
293	jbdelgado	2016-12-07	17:09:16.375192	added an equipment	965de5c5dbfaeee6e9b6f0ac304db335
294	jbdelgado	2016-12-07	17:09:16.378464	added an equipment	48f3a3e0c4d674da2521282f90bddd7f
295	jbdelgado	2016-12-07	17:09:16.381116	added an equipment	2474748c706d32d2d9f63be16db3b960
296	jbdelgado	2016-12-07	17:09:16.383835	added an equipment	d62017747b8cb88466ffe6b76eb2a83f
297	jbdelgado	2016-12-07	17:09:16.386469	added an equipment	9bff0fd479d2cd964c1cf4132905150f
298	jbdelgado	2016-12-07	17:09:16.39002	added an equipment	2c74afa78eed38c11ed5a8e3e48d757b
299	jbdelgado	2016-12-07	17:09:16.392846	added an equipment	dca3b6c4435fa89c408cda19783054e6
300	jbdelgado	2016-12-07	17:09:16.396558	added an equipment	f9fc57cc8d048306d847e879a7ff6573
301	jbdelgado	2016-12-07	17:09:16.399393	added an equipment	5a67f582d77c40f163d41a43d87de21e
302	jbdelgado	2016-12-07	17:09:16.402144	added an equipment	097a3bbc7bfae7fe08a497faa56249af
303	jbdelgado	2016-12-07	17:09:16.404763	added an equipment	f93a76dd3a48af98848e789c6647940f
304	jbdelgado	2016-12-07	17:09:16.407496	added an equipment	3402785e7f940364c6e4219d446dc8ed
305	jbdelgado	2016-12-07	17:09:16.410181	added an equipment	69813c68ad3af82ba76f7467828b19c6
306	jbdelgado	2016-12-07	17:09:16.412903	added an equipment	27c469e4f12a5d57456b063ab27fa3ad
307	jbdelgado	2016-12-07	17:09:16.415604	added an equipment	2a51fceea363092885dca92a42e10a07
308	jbdelgado	2016-12-07	17:09:16.419589	added an equipment	5ed831e47471086174b1f6e2fe916aeb
309	jbdelgado	2016-12-07	17:09:16.422869	added an equipment	1105d911187c2822d149c49d1c95c706
310	jbdelgado	2016-12-07	17:09:16.425801	added an equipment	30015199ad94bbf7a6be0a9c5157cff2
311	jbdelgado	2016-12-07	17:09:16.445868	added an equipment	7492a0b74118dc87e101bc88a7ede11d
312	jbdelgado	2016-12-07	17:09:16.44922	added an equipment	ce18721aef97f3c2bed7122d1b57a5e3
313	jbdelgado	2016-12-07	17:09:16.452808	added an equipment	dc87f8810ba7a0d6f81fa84614c2bfbc
314	jbdelgado	2016-12-07	17:09:16.456297	added an equipment	bd93f06ae0c0d4afa78a1a1d4e1b8793
315	jbdelgado	2016-12-07	17:25:53.897849	added a staff	\N
316	sbmagdadaro	2016-12-07	17:31:03.552892	created a schedule	\N
317	sbmagdadaro	2016-12-07	17:34:17.654008	moved an equipment	f1527ffd33a24ece7ba43ca178a576ed
318	sbmagdadaro	2016-12-07	22:22:12.952848	added a staff	\N
320	jbdelgado	2016-12-08	08:44:46.816371	added an office	\N
321	jbdelgado	2016-12-08	08:46:57.080489	added an office	\N
322	jbdelgado	2016-12-08	08:50:52.442333	added an office	\N
323	jbdelgado	2016-12-08	08:53:50.741331	added an office	\N
324	jbdelgado	2016-12-08	09:40:04.883702	added a staff	\N
325	jbdelgado	2016-12-08	09:42:37.805226	added a staff	\N
326	jbdelgado	2016-12-08	09:45:13.49127	added a staff	\N
327	jbdelgado	2016-12-08	09:46:53.973642	added a staff	\N
333	sbmagdadaro	2016-12-08	10:23:25.713885	added an equipment	b8b8c345f81f0479515a0da0add9a159
334	sbmagdadaro	2016-12-08	10:23:25.718776	added an equipment	e353b610e9ce20f963b4cca5da565605
335	sbmagdadaro	2016-12-08	10:23:25.722875	added an equipment	1bcaea6d00884aeafe0c076bd322f825
336	sbmagdadaro	2016-12-08	10:23:25.727165	added an equipment	5bd7f2feff1f11170a507fcd0c0e9734
337	sbmagdadaro	2016-12-08	10:23:25.733511	added an equipment	5c6ef67e6079f0cdd640a5ad7c288e36
338	sbmagdadaro	2016-12-08	10:23:25.738008	added an equipment	ccd986d2de4c75133c049e26005b3dbc
339	sbmagdadaro	2016-12-08	10:23:25.744463	added an equipment	c6c209418814b5cee2107e6e744bb737
340	sbmagdadaro	2016-12-08	10:23:25.748547	added an equipment	0bc58258e6f3c040a65fa2bfc9d0c907
341	sbmagdadaro	2016-12-08	10:23:25.751403	added an equipment	0668a01b2098b4335c37c1a1ac0dd71a
342	sbmagdadaro	2016-12-08	10:23:25.754063	added an equipment	9ac0faa70d798a4598ce2655d8b54232
343	sbmagdadaro	2016-12-08	10:27:39.234815	added an equipment	b0baee9d279d34fa1dfd71aadb908c3f
344	sbmagdadaro	2016-12-08	10:27:39.240735	added an equipment	afcb7a2f1c158286b48062cd885a9866
345	sbmagdadaro	2016-12-08	10:27:39.245479	added an equipment	4b009c2f8e8d230c498c2db26678dd77
346	sbmagdadaro	2016-12-08	10:27:39.251426	added an equipment	ed1db771321105b3c0dbc70a661b9b10
347	sbmagdadaro	2016-12-08	10:27:39.258289	added an equipment	d7dcd79b773dc85c89b84862cdedb6cf
348	sbmagdadaro	2016-12-08	10:27:39.262431	added an equipment	4e4faae72b1c3cbd446a70e89e59d8fc
349	sbmagdadaro	2016-12-08	10:27:39.265863	added an equipment	307eb8ee16198da891c521eca21464c1
350	sbmagdadaro	2016-12-08	10:27:39.272007	added an equipment	d585d095b00cd2f5b50acb64add23834
351	sbmagdadaro	2016-12-08	10:27:39.280624	added an equipment	e2d56b6b53ce40332aec920b78d030c1
352	sbmagdadaro	2016-12-08	10:27:39.284718	added an equipment	867c4bc5f2010a95f9971b91ddaa8f47
353	sbmagdadaro	2016-12-08	10:27:39.289739	added an equipment	96e79218965eb72c92a549dd5a330112
354	sbmagdadaro	2016-12-08	10:27:39.29374	added an equipment	9a952cd91000872a8d7d1f5ee0c87317
355	sbmagdadaro	2016-12-08	10:27:39.298534	added an equipment	f6be2ff0d88a9434a04a79c0e1a28066
356	sbmagdadaro	2016-12-08	10:27:39.302657	added an equipment	2707b2f06a3967105746389278bdf01d
357	sbmagdadaro	2016-12-08	10:27:39.305537	added an equipment	0097d9f20753f2e606a36c45693562b2
358	sbmagdadaro	2016-12-08	10:27:39.308722	added an equipment	1d2f816fd3c2e0a226c43f5b19e60007
359	sbmagdadaro	2016-12-08	10:27:39.311584	added an equipment	f48f7bb1bc6b73e178f57f632d312b3d
360	sbmagdadaro	2016-12-08	10:27:39.314289	added an equipment	5429d3157f649805adc2d506df2c31b5
361	sbmagdadaro	2016-12-08	10:27:39.317965	added an equipment	0d659ddc03566cb9c55c9ccf0eb2f1bb
362	sbmagdadaro	2016-12-08	10:27:39.322972	added an equipment	d1ec29d7366e8b4cbebbd9f63797ebeb
363	sbmagdadaro	2016-12-08	10:27:39.32683	added an equipment	fbe5432b9d3f71f3c03c9d7fd0297c2d
364	sbmagdadaro	2016-12-08	10:27:39.332395	added an equipment	0b7da663c8a1ee358aa8dbb6e55d0d2b
365	sbmagdadaro	2016-12-08	10:27:39.335548	added an equipment	e49274516a27487f894ae956166eb7a4
366	sbmagdadaro	2016-12-08	10:27:39.338303	added an equipment	1e14e388e4042dc43defefb9f88695e1
367	sbmagdadaro	2016-12-08	10:27:39.342133	added an equipment	ce43ec4b39fa77a2030d73f8855c4396
368	sbmagdadaro	2016-12-08	10:27:39.346652	added an equipment	3949350cebfd1d32e7278eaed55dc2f1
369	sbmagdadaro	2016-12-08	10:27:39.350212	added an equipment	c52f5ca65357bf402df21e7db538007e
370	sbmagdadaro	2016-12-08	10:27:39.352937	added an equipment	e23c30d902f86fc06f700bc4cbe9d67e
371	sbmagdadaro	2016-12-08	10:27:39.355526	added an equipment	3447ce251398f59b274e0acfe1541df7
372	sbmagdadaro	2016-12-08	10:27:39.358312	added an equipment	03a892d43834d530f2e81de80c96384d
374	sbmagdadaro	2016-12-08	10:31:47.132698	added an equipment	a25ae004eadf95406855ffbad5653993
375	sbmagdadaro	2016-12-08	10:31:47.137761	added an equipment	ef80af910fa07870e25b1a4c86d10402
376	sbmagdadaro	2016-12-08	10:31:47.142375	added an equipment	2167fcf808b8f383e7e44e25305a08a8
377	sbmagdadaro	2016-12-08	10:33:34.568582	added an equipment	4d82271bc2fdb95a9de38ba9e30ab36e
378	sbmagdadaro	2016-12-08	10:33:34.573406	added an equipment	0f4443a0b35f23e2d2a485be3d07ed84
379	sbmagdadaro	2016-12-08	10:33:34.578004	added an equipment	6fa825177a4f6f5a6ff57c739e8311fd
380	sbmagdadaro	2016-12-08	10:33:34.582137	added an equipment	95458099dedf800e701d8bf723ace65a
381	sbmagdadaro	2016-12-08	10:34:55.897215	added an equipment	a25ae004eadf95406855ffbad5653993
382	sbmagdadaro	2016-12-08	10:34:55.919414	added an equipment	ef80af910fa07870e25b1a4c86d10402
383	sbmagdadaro	2016-12-08	10:35:57.647424	added an equipment	82b57e60cd5cd5d41a14ffc31b255f5b
384	sbmagdadaro	2016-12-08	10:35:57.652296	added an equipment	8b6089269d17381873ec2207506aa62a
385	sbmagdadaro	2016-12-08	10:35:57.659672	added an equipment	2ffe5ae29bb6b60145835654b541b443
386	sbmagdadaro	2016-12-08	10:35:57.675931	added an equipment	6264104f24cbc6849b7e6ad298862a24
387	sbmagdadaro	2016-12-08	10:35:57.680002	added an equipment	0a5de450e625177a977f2b7a488c72f5
388	sbmagdadaro	2016-12-08	10:35:57.684041	added an equipment	b52bd057e37fc8688dddf113c39501e2
389	sbmagdadaro	2016-12-08	10:35:57.687834	added an equipment	02d4ad74e410990974be404efcd00ec1
390	sbmagdadaro	2016-12-08	10:35:57.691653	added an equipment	f338ee966b0240a58cc1dbf24855dd26
391	sbmagdadaro	2016-12-08	10:35:57.695215	added an equipment	e9729543bbfbd7d2677d43bc67c5dc87
392	sbmagdadaro	2016-12-08	10:35:57.698344	added an equipment	400e5b95e612e990cc5a1891d52b0212
393	sbmagdadaro	2016-12-08	10:35:57.701283	added an equipment	24ebad661415bb82ae9f9e92167a80d2
394	sbmagdadaro	2016-12-08	10:35:57.705486	added an equipment	8e693391276cd4fd2397434cdfb5480c
395	sbmagdadaro	2016-12-08	10:35:57.710179	added an equipment	a8c9bd7685d48510c0a01c2537384363
396	sbmagdadaro	2016-12-08	10:35:57.713839	added an equipment	05c5bec0698ccaeb128fd431b606b318
397	sbmagdadaro	2016-12-08	10:35:57.717113	added an equipment	209ae57722bd1bd436646951f80617cc
400	sbmagdadaro	2016-12-08	10:37:39.756305	added an equipment	24dc2b5d421e7f6eda94ba6188e6fbc4
401	sbmagdadaro	2016-12-08	10:37:39.762605	added an equipment	670f33f3cfb5217bcf008786165f1dc7
402	sbmagdadaro	2016-12-08	10:37:39.769083	added an equipment	dda4087216e15d1784efc310005dd683
403	sbmagdadaro	2016-12-08	10:37:39.773059	added an equipment	d8585cb93fef89c4cf932574e6554c9c
404	sbmagdadaro	2016-12-08	10:37:39.778303	added an equipment	c3e71101f147210be216f85bf76a067a
406	sbmagdadaro	2016-12-08	10:40:30.295781	added an equipment	36125352638845f5a20223ba6a55e522
407	sbmagdadaro	2016-12-08	10:40:30.300963	added an equipment	8923d70c1cfa2fb0690ca3b912600332
405	sbmagdadaro	2016-12-08	10:37:39.782481	added an equipment	\N
409	jbdelgado	2016-12-08	10:54:42.079567	added an equipment	39b32dfc9ed18533ee98b921687ad87a
410	jbdelgado	2016-12-08	10:54:42.108365	added an equipment	f477b7bc78101c4ae91008a6a403104e
411	sbmagdadaro	2016-12-08	10:55:36.044786	added an equipment	4756c3d11a0e0bafae44c135837f15d2
412	sbmagdadaro	2016-12-08	10:55:36.049652	added an equipment	20f817b9520d57dd7b9f725537816cbb
413	sbmagdadaro	2016-12-08	10:55:36.056671	added an equipment	43bf67f752b620ea7bcaafa1a4e8ec0d
414	sbmagdadaro	2016-12-08	10:57:08.649399	updated an equipment by batch	\N
415	sbmagdadaro	2016-12-08	10:59:19.587836	added an equipment	476ffbfb78ef9adcf5c6010723c04947
416	sbmagdadaro	2016-12-08	10:59:19.607566	added an equipment	d6e44245b7dcf2a1fa100f95bae0f3d8
417	sbmagdadaro	2016-12-08	10:59:19.613458	added an equipment	d31432767374d7df1f49036637540469
418	sbmagdadaro	2016-12-08	10:59:19.618583	added an equipment	48efe880ae65dac453536b2d9ff74104
419	sbmagdadaro	2016-12-08	10:59:19.622774	added an equipment	dd4719a433e583c8e9e9a0e0722e4e51
420	sbmagdadaro	2016-12-08	10:59:19.626282	added an equipment	0948165ee93e1b462588da88a79abdf6
421	sbmagdadaro	2016-12-08	10:59:19.629419	added an equipment	4d441f107ac494bd09add43376ad68d1
422	sbmagdadaro	2016-12-08	10:59:19.634367	added an equipment	866c4cda6901e9214d16c6f8e155941a
423	sbmagdadaro	2016-12-08	10:59:19.63904	added an equipment	39b8f1905c82dda81dcb616f89cd94f0
424	sbmagdadaro	2016-12-08	10:59:19.642963	added an equipment	136b00d6262e70a75e86200fa494cd15
425	sbmagdadaro	2016-12-08	11:05:49.717603	added a staff	\N
430	jbdelgado	2016-12-08	12:22:59.113226	disposed an equipment	a25ae004eadf95406855ffbad5653993
431	jbdelgado	2016-12-08	12:28:34.956959	disposed an equipment	82b57e60cd5cd5d41a14ffc31b255f5b
432	jbdelgado	2016-12-08	13:56:27.88204	added an office	\N
433	jbdelgado	2016-12-08	13:57:14.299318	added a staff	\N
434	jbdelgado	2016-12-08	13:59:36.196069	added an equipment	4e0df9f8468af3566ecc97d7afb106da
435	jbdelgado	2016-12-08	13:59:36.201625	added an equipment	d66d0d00bb7f294c9a9127f437dd3702
436	sbmagdadaro	2016-12-08	14:01:37.481163	created a schedule	\N
437	sbmagdadaro	2016-12-09	00:00:19.762751	updated a schedule	\N
438	sbmagdadaro	2016-12-09	00:05:44.777717	removed a schedule	\N
439	jbdelgado	2016-12-09	00:59:55.876663	disposed an equipment	02d4ad74e410990974be404efcd00ec1
\.


--
-- Name: transaction_log_transaction_no_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_log_transaction_no_seq', 439, true);


--
-- Data for Name: working_equipment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY working_equipment (qrcode, date_last_inventoried, status) FROM stdin;
81dc9bdb52d04dc20036dbd8313ed055	\N	Not Found
d897133013752d0a321202676961c579	\N	Not Found
66f7b045db373d410f4f0c317378f679	\N	Not Found
7f6f70d8bb2a189bd7414a63f36c5b75	\N	Not Found
402df1281dc6d87253e7dca987b359e2	\N	Not Found
eb007223a9ca6ab699c5070ced080113	\N	Not Found
b421bedcc4030881312979f5a511c8e8	\N	Not Found
30f3361bd6e97b8109893d55a8432556	\N	Not Found
3865247de92da30d35f38538d71a9c40	\N	Not Found
a9cfebcdb4e20ed975e82b7fd877693f	\N	Not Found
f1527ffd33a24ece7ba43ca178a576ed	\N	Not Found
1ad62710278671e5baf60606a23388b7	\N	Not Found
546f7901282eee42b1e4e9d7f62aa324	\N	Not Found
0a207b240a7b6e5710c3296016852169	\N	Not Found
ef0eccbf66798ea2fde3af20ec426faf	\N	Not Found
0664921765ed9f23a0e7c353b369f6a1	\N	Not Found
5ca3f29f98b7e6f0f2a69960e7a3dc79	\N	Not Found
8a1101b5e318825614c27c328d643705	\N	Not Found
2d95415113278181485917e2d3b92ab7	\N	Not Found
0d4d4a73c7f711e9993c1ec9f8529d9d	\N	Not Found
3d744532750f482c4210255f577d11db	\N	Not Found
64ea235f0e9a1be992067533b744e11a	\N	Not Found
49e7ef6aa2d9b8d7dfcb90328397fa64	\N	Not Found
67e5f7fec3e2e5d4759de4801e1b72a7	\N	Not Found
335f9d06f26ea8d095e5da9f214fad42	\N	Not Found
e7161c6dabce5fe6cb5ed42bf1df1f35	\N	Not Found
33b46d01b27aa353d5058106d39071f4	\N	Not Found
5f2015c3451c9ab0909aeffc65a0acad	\N	Not Found
aa8fa69892be87c21091df242109a28d	\N	Not Found
6d7ef78a926cc98799b8ac5afa9ed957	\N	Not Found
81437f8bd31824435ec008d35d7ce159	\N	Not Found
dfc374d85d0cd0540a0a9f9fb1267c45	\N	Not Found
9c092041bba216f1b4316594e3f22ef8	\N	Not Found
41aab22bfd978b692ff1926a631c110e	\N	Not Found
b79ded847fcced1e28547fe2344e76ff	\N	Not Found
bfd0abe791d0f74c4bce646e1ef07715	\N	Not Found
4c53387320a3f2bafa538cc7a1f4d455	\N	Not Found
b49d6cf78ba207dd1f910bb60905367f	\N	Not Found
a9ac2713a25f8f8b21100eb61857fd48	\N	Not Found
c7a2f923e4829c32a3733e9fc2666689	\N	Not Found
68330ef57d6ed7e6d738003c8c67c530	\N	Not Found
988516f58039b3543d75c96cf826691a	\N	Not Found
483012929d5e1f37018c9c8c4ad34f37	\N	Not Found
363224cff7fac6df72a21d4f717546eb	\N	Not Found
9d5ab86eb7679e018310f3206fd5ed42	\N	Not Found
b6ecfe392f41953fe398097345d8a723	\N	Not Found
1e88a1fd71accb98cd25e5f3ba78fabf	\N	Not Found
a5480fcdcb62bb35b9042ee4219f30b4	\N	Not Found
254ced7a9d32b5bd0e2275803d09f988	\N	Not Found
3c03b3502017eb8342a0bc5c38231be1	\N	Not Found
7ab7241a2c7f74808daa2de02f2d6ba6	\N	Not Found
5951c179de43573583e7d4281df3f495	\N	Not Found
4fbe067e7e30cbc426ab27b1aeb2b7ed	\N	Not Found
6887ab8b8b4ce0926a5dcf75110a9a6c	\N	Not Found
88f3ede619f967ae916d0fc660341855	\N	Not Found
838c45b2ac84a63d5cc28b9ee9079ec2	\N	Not Found
43c0c26bac45cc3b9c3ce0baf1641ae8	\N	Not Found
6e150682aa07c7413d49b3a31b1b7b00	\N	Not Found
83d3be02314f7d74c4c50e109dbabbf4	\N	Not Found
45f5cfd0809889f67f797665aa3515c5	\N	Not Found
0f48cb31cb530841b68d302661d22009	\N	Not Found
1b3bcbdea24bea9f3ada1a3e8828c3a9	\N	Not Found
398d858256d6029dca9230882b499689	\N	Not Found
5c604c70b18685218c9d0dccfc3a0827	\N	Not Found
48c51968abe79f10ae22510fc6ac18c8	\N	Not Found
6cf65ebce72a1088f3a458859e2dc666	\N	Not Found
19854dc4891b66e4c96de4edd7d5ada0	\N	Not Found
54159f0fedf9d40e7f328134de0857b0	\N	Not Found
205759c4f297af0a062088add4fea246	\N	Not Found
e961c2482c6dfda5c5e3968b70836ba6	\N	Not Found
83a7a2bda8bac4960d0e7070addaface	\N	Not Found
22719ac4686c6abdd9dae8ef5b4b8f9d	\N	Not Found
1546df2fce5bed78cd33bedde1aff58b	\N	Not Found
7769db69a040492ddda35c8fc23d1c4b	\N	Not Found
376fd50f094f0a67026e655e4cdd453f	\N	Not Found
a670c97d7803c06154c7f8782178f6f4	\N	Not Found
06703e0008e33c211fc9e9e0ee35c230	\N	Not Found
5917ad1d94b7275c14f0f25ffba9122c	\N	Not Found
d491a7de92b19e5f4b09670cdf2706ba	\N	Not Found
e2102b8bde911503336460b14bb97886	\N	Not Found
12a257147a51bd0a445e171c7857a46d	\N	Not Found
7949a56231d8e13573d0b7834371cfcb	\N	Not Found
d4ccd18e192fbeca26dfdc111397d228	\N	Not Found
41857c1fafe2ed5b86844c92b6df84ae	\N	Not Found
d0da4f9170ab57d98a07ece62d138ec1	\N	Not Found
97adebe60938ceb3907c7eb22488ec94	\N	Not Found
27d088da323408c4b11778aa614692a7	\N	Not Found
594d35e12c546f55b2980b34a0af5c7d	\N	Not Found
89d6d3107abf73968c33f5d1acfae7d1	\N	Not Found
c5055d37f7761d5ac1dbe1c7aa4c91f7	\N	Not Found
97198bc234cd6d0d1b77f91bb473d1b5	\N	Not Found
964e317a1689b33b20099b79a9aa2cc4	\N	Not Found
c326218cd16f94f581684ddf000dcc97	\N	Not Found
81688afbe5cd5880e758823b93610179	\N	Not Found
42522a0e20f3ad9d89c858970b9b956e	\N	Not Found
c68ce8d267e8cb58065e8ca6da71ca3d	\N	Not Found
7e5e5143ed6f3b348f6f75da7f5ebebe	\N	Not Found
dfd9a349b60da403621c955e189adc5e	\N	Not Found
d4a936d3c1f8a3407e7bcaa15c51f839	\N	Not Found
45627f67d98c16ff2a33a451014656a6	\N	Not Found
64843ad6de7a39dd092c57f430936c27	\N	Not Found
b9d66dabc87adc325461a48c280133f8	\N	Not Found
0d400289b80c906f3bd466491db73ab0	\N	Not Found
321a964bbe6b111d85029dc9b25fafb7	\N	Not Found
53e5de741470c1935eaedf3daf417b03	\N	Not Found
d1cf403a99a57fd7360d97ce5c652295	\N	Not Found
4de2d61497ada3e0e8942ed48c3cbb89	\N	Not Found
a0b6dea6748841384f9f687289a061fa	\N	Not Found
cd0238302cbde1bd2bf12dce32390fe2	\N	Not Found
7b393f8e48d7b396d866add75db9352b	\N	Not Found
fd035aa26fbfbf0ebdf9e7d7c60863e3	\N	Not Found
b045d64f68c5790d4fb44f1d762713da	\N	Not Found
269d39bd56225bd133aec58c267a916f	\N	Not Found
fc34a63ea6d95041adccc5381d312d6f	\N	Not Found
965de5c5dbfaeee6e9b6f0ac304db335	\N	Not Found
48f3a3e0c4d674da2521282f90bddd7f	\N	Not Found
2474748c706d32d2d9f63be16db3b960	\N	Not Found
d62017747b8cb88466ffe6b76eb2a83f	\N	Not Found
9bff0fd479d2cd964c1cf4132905150f	\N	Not Found
2c74afa78eed38c11ed5a8e3e48d757b	\N	Not Found
dca3b6c4435fa89c408cda19783054e6	\N	Not Found
f9fc57cc8d048306d847e879a7ff6573	\N	Not Found
5a67f582d77c40f163d41a43d87de21e	\N	Not Found
097a3bbc7bfae7fe08a497faa56249af	\N	Not Found
f93a76dd3a48af98848e789c6647940f	\N	Not Found
36125352638845f5a20223ba6a55e522	\N	Not Found
3402785e7f940364c6e4219d446dc8ed	\N	Not Found
69813c68ad3af82ba76f7467828b19c6	\N	Not Found
27c469e4f12a5d57456b063ab27fa3ad	\N	Not Found
2a51fceea363092885dca92a42e10a07	\N	Not Found
5ed831e47471086174b1f6e2fe916aeb	\N	Not Found
1105d911187c2822d149c49d1c95c706	\N	Not Found
30015199ad94bbf7a6be0a9c5157cff2	\N	Not Found
7492a0b74118dc87e101bc88a7ede11d	\N	Not Found
ce18721aef97f3c2bed7122d1b57a5e3	\N	Not Found
dc87f8810ba7a0d6f81fa84614c2bfbc	\N	Not Found
bd93f06ae0c0d4afa78a1a1d4e1b8793	\N	Not Found
def7924e3199be5e18060bb3e1d547a7	\N	Not Found
e53a0a2978c28872a4505bdb51db06dc	\N	Not Found
6b3c49bdba5be0d322334e30c459f8bd	\N	Not Found
3d8a0e750ff4f9b65d2c112a7095d1ce	\N	Not Found
b8b8c345f81f0479515a0da0add9a159	\N	Not Found
e353b610e9ce20f963b4cca5da565605	\N	Not Found
1bcaea6d00884aeafe0c076bd322f825	\N	Not Found
5bd7f2feff1f11170a507fcd0c0e9734	\N	Not Found
5c6ef67e6079f0cdd640a5ad7c288e36	\N	Not Found
ccd986d2de4c75133c049e26005b3dbc	\N	Not Found
c6c209418814b5cee2107e6e744bb737	\N	Not Found
0bc58258e6f3c040a65fa2bfc9d0c907	\N	Not Found
0668a01b2098b4335c37c1a1ac0dd71a	\N	Not Found
9ac0faa70d798a4598ce2655d8b54232	\N	Not Found
b0baee9d279d34fa1dfd71aadb908c3f	\N	Not Found
afcb7a2f1c158286b48062cd885a9866	\N	Not Found
4b009c2f8e8d230c498c2db26678dd77	\N	Not Found
ed1db771321105b3c0dbc70a661b9b10	\N	Not Found
d7dcd79b773dc85c89b84862cdedb6cf	\N	Not Found
4e4faae72b1c3cbd446a70e89e59d8fc	\N	Not Found
307eb8ee16198da891c521eca21464c1	\N	Not Found
d585d095b00cd2f5b50acb64add23834	\N	Not Found
e2d56b6b53ce40332aec920b78d030c1	\N	Not Found
867c4bc5f2010a95f9971b91ddaa8f47	\N	Not Found
96e79218965eb72c92a549dd5a330112	\N	Not Found
9a952cd91000872a8d7d1f5ee0c87317	\N	Not Found
f6be2ff0d88a9434a04a79c0e1a28066	\N	Not Found
2707b2f06a3967105746389278bdf01d	\N	Not Found
0097d9f20753f2e606a36c45693562b2	\N	Not Found
1d2f816fd3c2e0a226c43f5b19e60007	\N	Not Found
f48f7bb1bc6b73e178f57f632d312b3d	\N	Not Found
5429d3157f649805adc2d506df2c31b5	\N	Not Found
0d659ddc03566cb9c55c9ccf0eb2f1bb	\N	Not Found
d1ec29d7366e8b4cbebbd9f63797ebeb	\N	Not Found
fbe5432b9d3f71f3c03c9d7fd0297c2d	\N	Not Found
0b7da663c8a1ee358aa8dbb6e55d0d2b	\N	Not Found
e49274516a27487f894ae956166eb7a4	\N	Not Found
1e14e388e4042dc43defefb9f88695e1	\N	Not Found
ce43ec4b39fa77a2030d73f8855c4396	\N	Not Found
3949350cebfd1d32e7278eaed55dc2f1	\N	Not Found
c52f5ca65357bf402df21e7db538007e	\N	Not Found
e23c30d902f86fc06f700bc4cbe9d67e	\N	Not Found
3447ce251398f59b274e0acfe1541df7	\N	Not Found
03a892d43834d530f2e81de80c96384d	\N	Not Found
e044fb795495fd22d8146e50b961e852	\N	Not Found
ef80af910fa07870e25b1a4c86d10402	\N	Not Found
2167fcf808b8f383e7e44e25305a08a8	\N	Not Found
0f4443a0b35f23e2d2a485be3d07ed84	\N	Not Found
6fa825177a4f6f5a6ff57c739e8311fd	\N	Not Found
95458099dedf800e701d8bf723ace65a	\N	Not Found
8b6089269d17381873ec2207506aa62a	\N	Not Found
2ffe5ae29bb6b60145835654b541b443	\N	Not Found
6264104f24cbc6849b7e6ad298862a24	\N	Not Found
0a5de450e625177a977f2b7a488c72f5	\N	Not Found
b52bd057e37fc8688dddf113c39501e2	\N	Not Found
f338ee966b0240a58cc1dbf24855dd26	\N	Not Found
e9729543bbfbd7d2677d43bc67c5dc87	\N	Not Found
400e5b95e612e990cc5a1891d52b0212	\N	Not Found
24ebad661415bb82ae9f9e92167a80d2	\N	Not Found
8e693391276cd4fd2397434cdfb5480c	\N	Not Found
a8c9bd7685d48510c0a01c2537384363	\N	Not Found
05c5bec0698ccaeb128fd431b606b318	\N	Not Found
209ae57722bd1bd436646951f80617cc	\N	Not Found
f4d87ed3b0dbf9c79746d00cedbb5e78	\N	Not Found
c56030557e55275663bd45b48cd0223e	\N	Not Found
24dc2b5d421e7f6eda94ba6188e6fbc4	\N	Not Found
670f33f3cfb5217bcf008786165f1dc7	\N	Not Found
dda4087216e15d1784efc310005dd683	\N	Not Found
d8585cb93fef89c4cf932574e6554c9c	\N	Not Found
c3e71101f147210be216f85bf76a067a	\N	Not Found
8923d70c1cfa2fb0690ca3b912600332	\N	Not Found
39b32dfc9ed18533ee98b921687ad87a	\N	Not Found
f477b7bc78101c4ae91008a6a403104e	\N	Not Found
4756c3d11a0e0bafae44c135837f15d2	\N	Not Found
20f817b9520d57dd7b9f725537816cbb	\N	Not Found
43bf67f752b620ea7bcaafa1a4e8ec0d	\N	Not Found
476ffbfb78ef9adcf5c6010723c04947	\N	Not Found
d6e44245b7dcf2a1fa100f95bae0f3d8	\N	Not Found
d31432767374d7df1f49036637540469	\N	Not Found
48efe880ae65dac453536b2d9ff74104	\N	Not Found
dd4719a433e583c8e9e9a0e0722e4e51	\N	Not Found
0948165ee93e1b462588da88a79abdf6	\N	Not Found
4d441f107ac494bd09add43376ad68d1	\N	Not Found
866c4cda6901e9214d16c6f8e155941a	\N	Not Found
39b8f1905c82dda81dcb616f89cd94f0	\N	Not Found
136b00d6262e70a75e86200fa494cd15	\N	Not Found
fa60438ac1719d11eb95899af86e27c6	\N	Not Found
a729d76292a6a72fc99598bbc1e33ae6	\N	Not Found
05d8cccb5f47e5072f0a05b5f514941a	\N	Not Found
1b932eaf9f7c0cb84f471a560097ddb8	\N	Not Found
4e0df9f8468af3566ecc97d7afb106da	\N	Not Found
d66d0d00bb7f294c9a9127f437dd3702	\N	Not Found
4d82271bc2fdb95a9de38ba9e30ab36e	\N	Found
\.


--
-- Name: assigned_to_equipment_qr_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assigned_to
    ADD CONSTRAINT assigned_to_equipment_qr_code_key UNIQUE (equipment_qr_code);


--
-- Name: assigned_to_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assigned_to
    ADD CONSTRAINT assigned_to_pkey PRIMARY KEY (equipment_qr_code, office_id_holder);


--
-- Name: clerk_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY clerk
    ADD CONSTRAINT clerk_pkey PRIMARY KEY (username);


--
-- Name: disposal_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposal_requests
    ADD CONSTRAINT disposal_requests_pkey PRIMARY KEY (id);


--
-- Name: disposed_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposed_equipment
    ADD CONSTRAINT disposed_equipment_pkey PRIMARY KEY (qrcode);


--
-- Name: dummy_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY dummy_transaction
    ADD CONSTRAINT dummy_transaction_pkey PRIMARY KEY (trans_num);


--
-- Name: equipment_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment_history
    ADD CONSTRAINT equipment_history_pkey PRIMARY KEY (record_no);


--
-- Name: equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment
    ADD CONSTRAINT equipment_pkey PRIMARY KEY (qrcode);


--
-- Name: inventory_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY inventory_details
    ADD CONSTRAINT inventory_details_pkey PRIMARY KEY (inventory_id);


--
-- Name: mobile_trans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mobile_trans
    ADD CONSTRAINT mobile_trans_pkey PRIMARY KEY (id);


--
-- Name: office_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY office
    ADD CONSTRAINT office_email_key UNIQUE (email);


--
-- Name: office_office_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY office
    ADD CONSTRAINT office_office_name_key UNIQUE (office_name);


--
-- Name: office_password_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY office
    ADD CONSTRAINT office_password_key UNIQUE (password);


--
-- Name: office_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY office
    ADD CONSTRAINT office_pkey PRIMARY KEY (office_id);


--
-- Name: schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY (id);


--
-- Name: spmo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo
    ADD CONSTRAINT spmo_pkey PRIMARY KEY (username);


--
-- Name: spmo_staff_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo_staff_assignment
    ADD CONSTRAINT spmo_staff_assignment_pkey PRIMARY KEY (inventory_id, inventory_office);


--
-- Name: staff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
    ADD CONSTRAINT staff_pkey PRIMARY KEY (office_id, staff_id);


--
-- Name: staff_staff_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
    ADD CONSTRAINT staff_staff_id_key UNIQUE (staff_id);


--
-- Name: transaction_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_log
    ADD CONSTRAINT transaction_log_pkey PRIMARY KEY (transaction_no);


--
-- Name: uniquestaff; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
    ADD CONSTRAINT uniquestaff UNIQUE (staff_id);


--
-- Name: working_equipment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY working_equipment
    ADD CONSTRAINT working_equipment_pkey PRIMARY KEY (qrcode);


--
-- Name: check_assignment; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_assignment BEFORE INSERT ON assigned_to FOR EACH ROW EXECUTE PROCEDURE check_insert_assigned_to();


--
-- Name: check_inventory; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_inventory BEFORE INSERT ON inventory_details FOR EACH ROW EXECUTE PROCEDURE check_insert_inventory_details();


--
-- Name: check_startdate; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_startdate BEFORE INSERT ON schedule FOR EACH ROW EXECUTE PROCEDURE valid_start();


--
-- Name: create_equip_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER create_equip_transaction AFTER INSERT OR UPDATE ON assigned_to FOR EACH ROW EXECUTE PROCEDURE new_assignment();


--
-- Name: create_sched_transaction; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER create_sched_transaction AFTER INSERT OR DELETE OR UPDATE ON schedule FOR EACH ROW EXECUTE PROCEDURE new_sched_transaction();


--
-- Name: detect_clerk_update; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER detect_clerk_update AFTER UPDATE ON staff FOR EACH ROW EXECUTE PROCEDURE auto_insert_clerk_roles();


--
-- Name: encrypt_qrcode; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER encrypt_qrcode BEFORE INSERT ON equipment FOR EACH ROW EXECUTE PROCEDURE encryptqr();


--
-- Name: insert_working; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_working AFTER INSERT ON equipment FOR EACH ROW EXECUTE PROCEDURE auto_ins_working();


--
-- Name: assigned_to_equipment_qr_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assigned_to
    ADD CONSTRAINT assigned_to_equipment_qr_code_fkey FOREIGN KEY (equipment_qr_code) REFERENCES equipment(qrcode) ON DELETE CASCADE;


--
-- Name: assigned_to_office_id_holder_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assigned_to
    ADD CONSTRAINT assigned_to_office_id_holder_fkey FOREIGN KEY (office_id_holder) REFERENCES office(office_id) ON DELETE CASCADE;


--
-- Name: assigned_to_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY assigned_to
    ADD CONSTRAINT assigned_to_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: checker_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checker
    ADD CONSTRAINT checker_username_fkey FOREIGN KEY (username) REFERENCES staff(staff_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: clerk_designated_office_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY clerk
    ADD CONSTRAINT clerk_designated_office_fkey FOREIGN KEY (designated_office) REFERENCES office(office_id);


--
-- Name: clerk_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY clerk
    ADD CONSTRAINT clerk_username_fkey FOREIGN KEY (username) REFERENCES staff(staff_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: disposal_requests_office_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposal_requests
    ADD CONSTRAINT disposal_requests_office_name_fkey FOREIGN KEY (office_name) REFERENCES office(office_name);


--
-- Name: disposal_requests_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposal_requests
    ADD CONSTRAINT disposal_requests_username_fkey FOREIGN KEY (username) REFERENCES staff(staff_id);


--
-- Name: disposed_equipment_qrcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY disposed_equipment
    ADD CONSTRAINT disposed_equipment_qrcode_fkey FOREIGN KEY (qrcode) REFERENCES equipment(qrcode) ON DELETE CASCADE;


--
-- Name: equipment_history_equip_qrcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment_history
    ADD CONSTRAINT equipment_history_equip_qrcode_fkey FOREIGN KEY (equip_qrcode) REFERENCES equipment(qrcode);


--
-- Name: equipment_history_office_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment_history
    ADD CONSTRAINT equipment_history_office_id_fkey FOREIGN KEY (office_id) REFERENCES office(office_id);


--
-- Name: equipment_history_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY equipment_history
    ADD CONSTRAINT equipment_history_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(staff_id);


--
-- Name: inventory_details_initiated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY inventory_details
    ADD CONSTRAINT inventory_details_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES spmo(username) ON DELETE CASCADE;


--
-- Name: mobile_trans_office_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mobile_trans
    ADD CONSTRAINT mobile_trans_office_name_fkey FOREIGN KEY (office_name) REFERENCES office(office_name);


--
-- Name: spmo_staff_assignment_inventory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo_staff_assignment
    ADD CONSTRAINT spmo_staff_assignment_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES inventory_details(inventory_id) ON DELETE CASCADE;


--
-- Name: spmo_staff_assignment_inventory_office_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo_staff_assignment
    ADD CONSTRAINT spmo_staff_assignment_inventory_office_fkey FOREIGN KEY (inventory_office) REFERENCES office(office_id) ON DELETE CASCADE;


--
-- Name: spmo_staff_assignment_spmo_assigned_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo_staff_assignment
    ADD CONSTRAINT spmo_staff_assignment_spmo_assigned_fkey FOREIGN KEY (spmo_assigned) REFERENCES spmo(username) ON DELETE CASCADE;


--
-- Name: spmo_username_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY spmo
    ADD CONSTRAINT spmo_username_fkey FOREIGN KEY (username) REFERENCES staff(staff_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: staff_office_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY staff
    ADD CONSTRAINT staff_office_id_fkey FOREIGN KEY (office_id) REFERENCES office(office_id);


--
-- Name: transaction_log_equip_qrcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_log
    ADD CONSTRAINT transaction_log_equip_qrcode_fkey FOREIGN KEY (equip_qrcode) REFERENCES equipment(qrcode) ON DELETE SET NULL;


--
-- Name: transaction_log_staff_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_log
    ADD CONSTRAINT transaction_log_staff_id_fkey FOREIGN KEY (staff_id) REFERENCES staff(staff_id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: working_equipment_qrcode_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY working_equipment
    ADD CONSTRAINT working_equipment_qrcode_fkey FOREIGN KEY (qrcode) REFERENCES equipment(qrcode) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: office; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE office FROM PUBLIC;
REVOKE ALL ON TABLE office FROM postgres;
GRANT ALL ON TABLE office TO postgres;


--
-- PostgreSQL database dump complete
--


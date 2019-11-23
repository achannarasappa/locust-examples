--
-- PostgreSQL database dump
--

-- Dumped from database version 10.10 (Debian 10.10-1.pgdg90+1)
-- Dumped by pg_dump version 10.10 (Ubuntu 10.10-0ubuntu0.18.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: listing; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA listing;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: home; Type: TABLE; Schema: listing; Owner: -
--

CREATE TABLE listing.home (
    id integer NOT NULL,
    title character varying,
    price numeric,
    location character varying,
    bedroom_count numeric,
    size character varying,
    date_posted timestamp with time zone,
    attributes jsonb,
    images jsonb,
    description character varying,
    latitude character varying,
    longitude character varying
);


--
-- Name: listing_id_seq; Type: SEQUENCE; Schema: listing; Owner: -
--

ALTER TABLE listing.home ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME listing.listing_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- PostgreSQL database dump complete
--


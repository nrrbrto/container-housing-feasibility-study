--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: analyze_housing_sensitivity(numeric, numeric, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.analyze_housing_sensitivity(p_container_price_increase numeric, p_rental_income numeric, p_expected_lifespan_years integer) RETURNS TABLE(model_name character varying, adjusted_investment numeric, annual_maintenance numeric, annual_rental_income numeric, annual_net_income numeric, payback_years numeric, annual_roi_percentage numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH params AS (
        SELECT 
            p_expected_lifespan_years AS expected_lifespan_years,
            0.03 AS annual_maintenance_pct_traditional,
            0.035 AS annual_maintenance_pct_container,
            p_rental_income AS annual_rental_income
    )
    SELECT 
        h.model_name,
        CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END AS adjusted_investment,
        ROUND((CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END)::numeric, 2) AS annual_maintenance,
        p.annual_rental_income,
        p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END) AS annual_net_income,
        ROUND(((CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END) / (p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END)))::numeric, 2) AS payback_years,
        ROUND((((p.annual_rental_income - (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END * 
            CASE 
                WHEN h.model_name = 'Traditional Housing' THEN p.annual_maintenance_pct_traditional
                ELSE p.annual_maintenance_pct_container
            END)) / (CASE 
            WHEN h.model_name LIKE '%Container%' 
            THEN h.total_cost * (1 + p_container_price_increase/100)
            ELSE h.total_cost
        END)) * 100)::numeric, 2) AS annual_roi_percentage
    FROM housing_models h
    CROSS JOIN params p
    ORDER BY annual_roi_percentage DESC;
END;
$$;


ALTER FUNCTION public.analyze_housing_sensitivity(p_container_price_increase numeric, p_rental_income numeric, p_expected_lifespan_years integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: container_price_forecast; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.container_price_forecast (
    id integer NOT NULL,
    year integer NOT NULL,
    month integer NOT NULL,
    time_index integer NOT NULL,
    year_fraction numeric(10,2) NOT NULL,
    avg_price numeric(12,2),
    lower_bound numeric(12,2),
    upper_bound numeric(12,2),
    avg_freight_index numeric(12,2),
    freight_lower_bound numeric(12,2),
    freight_upper_bound numeric(12,2),
    price_pct_change numeric(10,2),
    price_lower_pct numeric(10,2),
    price_upper_pct numeric(10,2),
    freight_pct_change numeric(10,2),
    freight_lower_pct numeric(10,2),
    freight_upper_pct numeric(10,2),
    cumulative_price_pct numeric(10,2),
    cumulative_freight_pct numeric(10,2),
    calculated_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.container_price_forecast OWNER TO postgres;

--
-- Name: container_price_forecast_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.container_price_forecast_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.container_price_forecast_id_seq OWNER TO postgres;

--
-- Name: container_price_forecast_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.container_price_forecast_id_seq OWNED BY public.container_price_forecast.id;


--
-- Name: shipping_container_prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shipping_container_prices (
    id integer NOT NULL,
    ship_date date NOT NULL,
    freight_index numeric(10,2) NOT NULL,
    base_price numeric(12,2) NOT NULL,
    calculated_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.shipping_container_prices OWNER TO postgres;

--
-- Name: container_price_trends; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.container_price_trends AS
 SELECT EXTRACT(year FROM ship_date) AS year,
    EXTRACT(month FROM ship_date) AS month,
    avg(base_price) AS avg_price,
    max(base_price) AS max_price,
    min(base_price) AS min_price,
    (max(base_price) - min(base_price)) AS price_range,
    avg(freight_index) AS avg_freight_index,
    max(freight_index) AS max_freight_index,
    min(freight_index) AS min_freight_index,
    (max(freight_index) - min(freight_index)) AS freight_index_range,
        CASE
            WHEN (lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))) IS NULL) THEN 'Initial'::text
            WHEN ((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) > (10)::numeric) THEN 'Sharp Increase'::text
            WHEN (((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) >= (2)::numeric) AND ((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) <= (10)::numeric)) THEN 'Moderate Increase'::text
            WHEN (((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) >= ('-2'::integer)::numeric) AND ((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) <= (2)::numeric)) THEN 'Stable'::text
            WHEN (((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) >= ('-10'::integer)::numeric) AND ((((avg(base_price) - lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date)))) / NULLIF(lag(avg(base_price)) OVER (ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))), (0)::numeric)) * (100)::numeric) <= ('-2'::integer)::numeric)) THEN 'Moderate Decrease'::text
            ELSE 'Sharp Decrease'::text
        END AS trend_classification
   FROM public.shipping_container_prices
  GROUP BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date))
  ORDER BY (EXTRACT(year FROM ship_date)), (EXTRACT(month FROM ship_date));


ALTER VIEW public.container_price_trends OWNER TO postgres;

--
-- Name: container_prices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.container_prices (
    id integer NOT NULL,
    ship_date date NOT NULL,
    freight_index numeric(12,2) NOT NULL,
    base_price numeric(12,2) NOT NULL
);


ALTER TABLE public.container_prices OWNER TO postgres;

--
-- Name: container_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.container_prices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.container_prices_id_seq OWNER TO postgres;

--
-- Name: container_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.container_prices_id_seq OWNED BY public.container_prices.id;


--
-- Name: container_prices_raw; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.container_prices_raw (
    id integer NOT NULL,
    ship_date date NOT NULL,
    freight_index numeric(12,2) NOT NULL,
    base_price numeric(12,2) NOT NULL,
    source character varying(100)
);


ALTER TABLE public.container_prices_raw OWNER TO postgres;

--
-- Name: container_prices_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.container_prices_raw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.container_prices_raw_id_seq OWNER TO postgres;

--
-- Name: container_prices_raw_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.container_prices_raw_id_seq OWNED BY public.container_prices_raw.id;


--
-- Name: cost_breakdown; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_breakdown (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    materials_cost numeric(12,2) NOT NULL,
    labor_cost numeric(12,2) NOT NULL,
    finishings_cost numeric(12,2) NOT NULL,
    total_cost numeric(12,2) NOT NULL,
    citation text
);


ALTER TABLE public.cost_breakdown OWNER TO postgres;

--
-- Name: cost_breakdown_analysis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_breakdown_analysis (
    id bigint,
    model_name text,
    materials_cost double precision,
    labor_cost double precision,
    finishings_cost double precision,
    total_cost double precision,
    citation text,
    materials_percentage double precision,
    labor_percentage double precision,
    finishings_percentage double precision,
    materials_vs_trad double precision,
    labor_vs_trad double precision,
    finishings_vs_trad double precision
);


ALTER TABLE public.cost_breakdown_analysis OWNER TO postgres;

--
-- Name: cost_breakdown_concmod; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_breakdown_concmod (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    component_name character varying(50) NOT NULL,
    cost numeric(12,2) NOT NULL,
    citation text
);


ALTER TABLE public.cost_breakdown_concmod OWNER TO postgres;

--
-- Name: cost_breakdown_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cost_breakdown_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cost_breakdown_id_seq OWNER TO postgres;

--
-- Name: cost_breakdown_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cost_breakdown_id_seq OWNED BY public.cost_breakdown.id;


--
-- Name: cost_breakdownconcmod_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cost_breakdownconcmod_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cost_breakdownconcmod_id_seq OWNER TO postgres;

--
-- Name: cost_breakdownconcmod_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cost_breakdownconcmod_id_seq OWNED BY public.cost_breakdown_concmod.id;


--
-- Name: cost_efficiency_analysis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_efficiency_analysis (
    id bigint,
    model_name text,
    total_cost double precision,
    cost_per_sqm double precision,
    construction_time_days bigint,
    waste_percentage double precision,
    cost_savings double precision,
    savings_percentage double precision,
    percent_of_traditional double precision,
    sqm_savings double precision,
    sqm_savings_percentage double precision
);


ALTER TABLE public.cost_efficiency_analysis OWNER TO postgres;

--
-- Name: cost_per_sqm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cost_per_sqm (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    cost_per_sqm numeric(10,2) NOT NULL,
    total_cost numeric(12,2) NOT NULL,
    citation text
);


ALTER TABLE public.cost_per_sqm OWNER TO postgres;

--
-- Name: cost_per_sqm_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cost_per_sqm_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cost_per_sqm_id_seq OWNER TO postgres;

--
-- Name: cost_per_sqm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cost_per_sqm_id_seq OWNED BY public.cost_per_sqm.id;


--
-- Name: efficiency_metrics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.efficiency_metrics (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    cost_efficiency numeric(5,2) NOT NULL,
    time_efficiency numeric(5,2) NOT NULL,
    waste_reduction numeric(5,2) NOT NULL,
    material_usage numeric(5,2) NOT NULL,
    citation text
);


ALTER TABLE public.efficiency_metrics OWNER TO postgres;

--
-- Name: efficiency_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.efficiency_metrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.efficiency_metrics_id_seq OWNER TO postgres;

--
-- Name: efficiency_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.efficiency_metrics_id_seq OWNED BY public.efficiency_metrics.id;


--
-- Name: historical_price_changes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historical_price_changes (
    year double precision,
    month double precision,
    avg_price double precision,
    avg_freight_index double precision,
    price_pct_change double precision,
    freight_pct_change double precision
);


ALTER TABLE public.historical_price_changes OWNER TO postgres;

--
-- Name: housing_models; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.housing_models (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    total_cost numeric(12,2) NOT NULL,
    cost_per_sqm numeric(10,2) NOT NULL,
    construction_time_days integer NOT NULL,
    waste_percentage numeric(5,2) NOT NULL
);


ALTER TABLE public.housing_models OWNER TO postgres;

--
-- Name: housing_roi; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.housing_roi AS
 WITH params AS (
         SELECT 25 AS expected_lifespan_years,
            0.03 AS annual_maintenance_pct_traditional,
            0.035 AS annual_maintenance_pct_container,
            12000 AS annual_rental_income
        )
 SELECT h.model_name,
    h.total_cost AS initial_investment,
    round((h.total_cost *
        CASE
            WHEN ((h.model_name)::text = 'Traditional Housing'::text) THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END), 2) AS annual_maintenance,
    p.annual_rental_income,
    ((p.annual_rental_income)::numeric - (h.total_cost *
        CASE
            WHEN ((h.model_name)::text = 'Traditional Housing'::text) THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END)) AS annual_net_income,
    round((h.total_cost / ((p.annual_rental_income)::numeric - (h.total_cost *
        CASE
            WHEN ((h.model_name)::text = 'Traditional Housing'::text) THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END))), 2) AS payback_years,
    round(((((p.annual_rental_income)::numeric - (h.total_cost *
        CASE
            WHEN ((h.model_name)::text = 'Traditional Housing'::text) THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END)) / h.total_cost) * (100)::numeric), 2) AS annual_roi_percentage
   FROM (public.housing_models h
     CROSS JOIN params p)
  ORDER BY (round(((((p.annual_rental_income)::numeric - (h.total_cost *
        CASE
            WHEN ((h.model_name)::text = 'Traditional Housing'::text) THEN p.annual_maintenance_pct_traditional
            ELSE p.annual_maintenance_pct_container
        END)) / h.total_cost) * (100)::numeric), 2)) DESC;


ALTER VIEW public.housing_roi OWNER TO postgres;

--
-- Name: housing_dashboard; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.housing_dashboard AS
 SELECT m.model_name,
    m.total_cost,
    m.cost_per_sqm,
    m.construction_time_days,
    m.waste_percentage,
    round((((( SELECT housing_models.total_cost
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text)) - m.total_cost) / ( SELECT housing_models.total_cost
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text))) * (100)::numeric), 2) AS cost_efficiency,
    round(((((( SELECT housing_models.construction_time_days
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text)) - m.construction_time_days) / ( SELECT housing_models.construction_time_days
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text))) * 100))::numeric, 2) AS time_efficiency,
    round((((( SELECT housing_models.waste_percentage
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text)) - m.waste_percentage) / ( SELECT housing_models.waste_percentage
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text))) * (100)::numeric), 2) AS waste_reduction,
    r.annual_roi_percentage,
    r.payback_years
   FROM (public.housing_models m
     JOIN public.housing_roi r ON (((m.model_name)::text = (r.model_name)::text)))
  ORDER BY (round((((( SELECT housing_models.total_cost
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text)) - m.total_cost) / ( SELECT housing_models.total_cost
           FROM public.housing_models
          WHERE ((housing_models.model_name)::text = 'Traditional Housing'::text))) * (100)::numeric), 2)) DESC;


ALTER VIEW public.housing_dashboard OWNER TO postgres;

--
-- Name: housing_models_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.housing_models_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.housing_models_id_seq OWNER TO postgres;

--
-- Name: housing_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.housing_models_id_seq OWNED BY public.housing_models.id;


--
-- Name: shipping_container_raw; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shipping_container_raw (
    id integer NOT NULL,
    container_id character varying(20),
    ship_date date,
    delivery_date date,
    producer character varying(100),
    producer_type character varying(50),
    container_type character varying(50),
    container_qty numeric(10,1),
    origin character varying(50),
    destination character varying(50),
    freight_index numeric(10,2),
    base_price numeric(12,2),
    priority character varying(20),
    status character varying(20),
    import_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.shipping_container_raw OWNER TO postgres;

--
-- Name: monthly_shipping_volume; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.monthly_shipping_volume AS
 SELECT (date_trunc('month'::text, (ship_date)::timestamp with time zone))::date AS month,
    count(*) AS shipment_count,
    sum(container_qty) AS total_containers,
    avg(freight_index) AS avg_freight_index,
    sum(base_price) AS total_shipping_cost
   FROM public.shipping_container_raw
  WHERE (ship_date IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (ship_date)::timestamp with time zone))
  ORDER BY ((date_trunc('month'::text, (ship_date)::timestamp with time zone))::date);


ALTER VIEW public.monthly_shipping_volume OWNER TO postgres;

--
-- Name: priority_impact; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.priority_impact AS
 SELECT priority,
    count(*) AS shipment_count,
    avg(base_price) AS avg_base_price,
    avg(
        CASE
            WHEN (((status)::text = 'delivered'::text) OR ((status)::text = 'dlvrd'::text) OR ((status)::text = 'DELIVERED'::text)) THEN (delivery_date - ship_date)
            ELSE NULL::integer
        END) AS avg_delivery_days,
    (((avg(base_price) / COALESCE(NULLIF(( SELECT avg(shipping_container_raw_1.base_price) AS avg
           FROM public.shipping_container_raw shipping_container_raw_1
          WHERE (((shipping_container_raw_1.priority)::text = 'STD'::text) OR ((shipping_container_raw_1.priority)::text = 'standard'::text) OR ((shipping_container_raw_1.priority)::text = 'std'::text))), (0)::numeric), (1)::numeric)) * (100)::numeric) - (100)::numeric) AS price_premium_percent
   FROM public.shipping_container_raw
  WHERE (priority IS NOT NULL)
  GROUP BY priority
  ORDER BY (avg(
        CASE
            WHEN (((status)::text = 'delivered'::text) OR ((status)::text = 'dlvrd'::text) OR ((status)::text = 'DELIVERED'::text)) THEN (delivery_date - ship_date)
            ELSE NULL::integer
        END));


ALTER VIEW public.priority_impact OWNER TO postgres;

--
-- Name: producer_performance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.producer_performance AS
 SELECT producer,
    producer_type,
    count(*) AS shipment_count,
    sum(container_qty) AS total_containers,
    avg(container_qty) AS avg_containers_per_shipment,
    avg(base_price) AS avg_base_price,
    COALESCE(avg(
        CASE
            WHEN (((status)::text = 'delivered'::text) OR ((status)::text = 'dlvrd'::text) OR ((status)::text = 'DELIVERED'::text)) THEN (delivery_date - ship_date)
            ELSE NULL::integer
        END), (0)::numeric) AS avg_delivery_days
   FROM public.shipping_container_raw
  WHERE (producer IS NOT NULL)
  GROUP BY producer, producer_type
  ORDER BY (count(*)) DESC;


ALTER VIEW public.producer_performance OWNER TO postgres;

--
-- Name: resource_usage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resource_usage (
    id integer NOT NULL,
    resource_type character varying(50) NOT NULL,
    traditional_usage integer NOT NULL,
    container_usage integer NOT NULL,
    citation text
);


ALTER TABLE public.resource_usage OWNER TO postgres;

--
-- Name: resource_usage_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.resource_usage_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.resource_usage_id_seq OWNER TO postgres;

--
-- Name: resource_usage_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.resource_usage_id_seq OWNED BY public.resource_usage.id;


--
-- Name: route_analysis; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.route_analysis AS
 SELECT origin,
    destination,
    count(*) AS shipment_count,
    avg(freight_index) AS avg_freight_index,
    avg(base_price) AS avg_base_price,
    avg((base_price / NULLIF(container_qty, (0)::numeric))) AS avg_price_per_container,
    avg(
        CASE
            WHEN (((status)::text = 'delivered'::text) OR ((status)::text = 'dlvrd'::text) OR ((status)::text = 'DELIVERED'::text)) THEN (delivery_date - ship_date)
            ELSE NULL::integer
        END) AS avg_transit_days
   FROM public.shipping_container_raw
  WHERE ((origin IS NOT NULL) AND (destination IS NOT NULL))
  GROUP BY origin, destination
  ORDER BY (count(*)) DESC;


ALTER VIEW public.route_analysis OWNER TO postgres;

--
-- Name: sensitivity_analysis_non_viable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_analysis_non_viable (
    model_name text,
    adjusted_investment double precision,
    annual_maintenance double precision,
    annual_net_income double precision,
    payback_years bigint,
    annual_roi_percentage bigint,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint,
    maintenance_pct double precision,
    income_segment text,
    iteration bigint,
    viability_issue text
);


ALTER TABLE public.sensitivity_analysis_non_viable OWNER TO postgres;

--
-- Name: sensitivity_analysis_results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_analysis_results (
    model_name text,
    adjusted_investment double precision,
    annual_maintenance double precision,
    annual_net_income double precision,
    payback_years double precision,
    annual_roi_percentage double precision,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint,
    maintenance_pct double precision,
    income_segment text,
    iteration bigint,
    viability_issue text
);


ALTER TABLE public.sensitivity_analysis_results OWNER TO postgres;

--
-- Name: sensitivity_analysis_viable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_analysis_viable (
    model_name text,
    adjusted_investment double precision,
    annual_maintenance double precision,
    annual_net_income double precision,
    payback_years double precision,
    annual_roi_percentage double precision,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint,
    maintenance_pct double precision,
    income_segment text,
    iteration bigint
);


ALTER TABLE public.sensitivity_analysis_viable OWNER TO postgres;

--
-- Name: sensitivity_model_summary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_model_summary (
    model_name text,
    annual_roi_percentage_mean double precision,
    annual_roi_percentage_std double precision,
    annual_roi_percentage_min double precision,
    annual_roi_percentage_max double precision,
    payback_years_mean double precision,
    payback_years_std double precision,
    payback_years_min double precision,
    payback_years_max double precision,
    roi_classification text,
    payback_feasibility text
);


ALTER TABLE public.sensitivity_model_summary OWNER TO postgres;

--
-- Name: sensitivity_optimal_scenarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_optimal_scenarios (
    model_name text,
    adjusted_investment double precision,
    annual_maintenance double precision,
    annual_net_income double precision,
    payback_years double precision,
    annual_roi_percentage double precision,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint,
    maintenance_pct double precision,
    income_segment text,
    iteration bigint,
    viability_issue text
);


ALTER TABLE public.sensitivity_optimal_scenarios OWNER TO postgres;

--
-- Name: shipping_container_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shipping_container_prices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shipping_container_prices_id_seq OWNER TO postgres;

--
-- Name: shipping_container_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shipping_container_prices_id_seq OWNED BY public.shipping_container_prices.id;


--
-- Name: shipping_container_raw_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shipping_container_raw_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shipping_container_raw_id_seq OWNER TO postgres;

--
-- Name: shipping_container_raw_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shipping_container_raw_id_seq OWNED BY public.shipping_container_raw.id;


--
-- Name: total_cost_comparison; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.total_cost_comparison (
    id integer NOT NULL,
    model_name character varying(50) NOT NULL,
    total_cost numeric(12,2) NOT NULL,
    citation text
);


ALTER TABLE public.total_cost_comparison OWNER TO postgres;

--
-- Name: total_cost_comparison_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.total_cost_comparison_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.total_cost_comparison_id_seq OWNER TO postgres;

--
-- Name: total_cost_comparison_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.total_cost_comparison_id_seq OWNED BY public.total_cost_comparison.id;


--
-- Name: container_price_forecast id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_price_forecast ALTER COLUMN id SET DEFAULT nextval('public.container_price_forecast_id_seq'::regclass);


--
-- Name: container_prices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_prices ALTER COLUMN id SET DEFAULT nextval('public.container_prices_id_seq'::regclass);


--
-- Name: container_prices_raw id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_prices_raw ALTER COLUMN id SET DEFAULT nextval('public.container_prices_raw_id_seq'::regclass);


--
-- Name: cost_breakdown id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_breakdown ALTER COLUMN id SET DEFAULT nextval('public.cost_breakdown_id_seq'::regclass);


--
-- Name: cost_breakdown_concmod id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_breakdown_concmod ALTER COLUMN id SET DEFAULT nextval('public.cost_breakdownconcmod_id_seq'::regclass);


--
-- Name: cost_per_sqm id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_per_sqm ALTER COLUMN id SET DEFAULT nextval('public.cost_per_sqm_id_seq'::regclass);


--
-- Name: efficiency_metrics id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.efficiency_metrics ALTER COLUMN id SET DEFAULT nextval('public.efficiency_metrics_id_seq'::regclass);


--
-- Name: housing_models id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.housing_models ALTER COLUMN id SET DEFAULT nextval('public.housing_models_id_seq'::regclass);


--
-- Name: resource_usage id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource_usage ALTER COLUMN id SET DEFAULT nextval('public.resource_usage_id_seq'::regclass);


--
-- Name: shipping_container_prices id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shipping_container_prices ALTER COLUMN id SET DEFAULT nextval('public.shipping_container_prices_id_seq'::regclass);


--
-- Name: shipping_container_raw id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shipping_container_raw ALTER COLUMN id SET DEFAULT nextval('public.shipping_container_raw_id_seq'::regclass);


--
-- Name: total_cost_comparison id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.total_cost_comparison ALTER COLUMN id SET DEFAULT nextval('public.total_cost_comparison_id_seq'::regclass);


--
-- Data for Name: container_price_forecast; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.container_price_forecast (id, year, month, time_index, year_fraction, avg_price, lower_bound, upper_bound, avg_freight_index, freight_lower_bound, freight_upper_bound, price_pct_change, price_lower_pct, price_upper_pct, freight_pct_change, freight_lower_pct, freight_upper_pct, cumulative_price_pct, cumulative_freight_pct, calculated_date) FROM stdin;
1	2025	1	96	2025.00	2584.39	2325.95	2842.82	2450.88	2205.80	2695.97	-0.22	\N	\N	-0.38	\N	\N	-0.22	-0.38	2025-03-21 14:04:16.493223
2	2025	2	97	2025.08	2585.16	2326.64	2843.67	2505.14	2254.62	2755.65	0.03	0.03	0.03	2.21	2.21	2.21	-0.19	1.82	2025-03-21 14:04:16.493223
3	2025	3	98	2025.17	2584.79	2326.31	2843.27	2505.14	2254.62	2755.65	-0.01	-0.01	-0.01	0.00	0.00	0.00	-0.20	1.82	2025-03-21 14:04:16.493223
4	2025	4	99	2025.25	2584.29	2325.86	2842.72	2507.34	2256.61	2758.08	-0.02	-0.02	-0.02	0.09	0.09	0.09	-0.22	1.91	2025-03-21 14:04:16.493223
5	2025	5	100	2025.33	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	-0.04	-0.04	-0.04	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
6	2025	6	101	2025.42	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
7	2025	7	102	2025.50	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
8	2025	8	103	2025.58	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
9	2025	9	104	2025.67	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
10	2025	10	105	2025.75	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
11	2025	11	106	2025.83	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
12	2025	12	107	2025.92	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.493223
13	2025	1	96	2025.00	2584.39	2325.95	2842.82	2450.88	2205.80	2695.97	-0.22	\N	\N	-0.38	\N	\N	-0.22	-0.38	2025-03-21 14:04:16.536526
14	2025	2	97	2025.08	2585.16	2326.64	2843.67	2505.14	2254.62	2755.65	0.03	0.03	0.03	2.21	2.21	2.21	-0.19	1.82	2025-03-21 14:04:16.536526
15	2025	3	98	2025.17	2584.79	2326.31	2843.27	2505.14	2254.62	2755.65	-0.01	-0.01	-0.01	0.00	0.00	0.00	-0.20	1.82	2025-03-21 14:04:16.536526
16	2025	4	99	2025.25	2584.29	2325.86	2842.72	2507.34	2256.61	2758.08	-0.02	-0.02	-0.02	0.09	0.09	0.09	-0.22	1.91	2025-03-21 14:04:16.536526
17	2025	5	100	2025.33	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	-0.04	-0.04	-0.04	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
18	2025	6	101	2025.42	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
19	2025	7	102	2025.50	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
20	2025	8	103	2025.58	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
21	2025	9	104	2025.67	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
22	2025	10	105	2025.75	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
23	2025	11	106	2025.83	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
24	2025	12	107	2025.92	2583.22	2324.90	2841.54	2507.34	2256.61	2758.08	0.00	0.00	0.00	0.00	0.00	0.00	-0.26	1.91	2025-03-21 14:04:16.536526
\.


--
-- Data for Name: container_prices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.container_prices (id, ship_date, freight_index, base_price) FROM stdin;
\.


--
-- Data for Name: container_prices_raw; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.container_prices_raw (id, ship_date, freight_index, base_price, source) FROM stdin;
\.


--
-- Data for Name: cost_breakdown; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cost_breakdown (id, model_name, materials_cost, labor_cost, finishings_cost, total_cost, citation) FROM stdin;
9	Traditional Housing	242136.00	212400.00	253464.00	708000.00	CLMA labor rates (30%) & NAHB finishing rates (35.8%)
10	ODD Cubes	231120.00	60000.00	128880.00	420000.00	Base unit with estimated finishing percentage + fenestration
11	Container (Base)	124826.80	96516.00	102000.00	323343.00	Base container cost + modifications
12	Container (Max)	124826.80	164178.00	291000.00	580005.00	Base container cost + premium modifications
13	Traditional Housing	242136.00	212400.00	253464.00	708000.00	CLMA labor rates (30%) & NAHB finishing rates (35.8%)
14	ODD Cubes	231120.00	60000.00	128880.00	420000.00	Base unit with estimated finishing percentage + fenestration
15	Container (Base)	124826.80	96516.00	102000.00	323343.00	Base container cost + modifications
16	Container (Max)	124826.80	164178.00	291000.00	580005.00	Base container cost + premium modifications
\.


--
-- Data for Name: cost_breakdown_analysis; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cost_breakdown_analysis (id, model_name, materials_cost, labor_cost, finishings_cost, total_cost, citation, materials_percentage, labor_percentage, finishings_percentage, materials_vs_trad, labor_vs_trad, finishings_vs_trad) FROM stdin;
9	Traditional Housing	242136	212400	253464	708000	CLMA labor rates (30%) & NAHB finishing rates (35.8%)	34.2	30	35.8	100	100	100
10	ODD Cubes	231120	60000	128880	420000	Base unit with estimated finishing percentage + fenestration	55.028571428571425	14.285714285714285	30.685714285714287	95.45049063336307	28.24858757062147	50.847457627118644
11	Container (Base)	124826.8	96516	102000	323343	Base container cost + modifications	38.605072631849154	29.849416873103795	31.545448641226194	51.552350745035845	45.440677966101696	40.24240128775684
12	Container (Max)	124826.8	164178	291000	580005	Base container cost + premium modifications	21.52167653727123	28.306307704243928	50.17198127602348	51.552350745035845	77.29661016949153	114.80920367389452
13	Traditional Housing	242136	212400	253464	708000	CLMA labor rates (30%) & NAHB finishing rates (35.8%)	34.2	30	35.8	100	100	100
14	ODD Cubes	231120	60000	128880	420000	Base unit with estimated finishing percentage + fenestration	55.028571428571425	14.285714285714285	30.685714285714287	95.45049063336307	28.24858757062147	50.847457627118644
15	Container (Base)	124826.8	96516	102000	323343	Base container cost + modifications	38.605072631849154	29.849416873103795	31.545448641226194	51.552350745035845	45.440677966101696	40.24240128775684
16	Container (Max)	124826.8	164178	291000	580005	Base container cost + premium modifications	21.52167653727123	28.306307704243928	50.17198127602348	51.552350745035845	77.29661016949153	114.80920367389452
\.


--
-- Data for Name: cost_breakdown_concmod; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cost_breakdown_concmod (id, model_name, component_name, cost, citation) FROM stdin;
1	Container (Base)	Container Cost	124826.80	Current market rates
2	Container (Base)	Fenestration	60000.00	₱10,000 per cut, 6 cuts required
3	Container (Base)	Base Alterations	102000.00	Base estimate for modifications
4	Container (Max)	Container Cost	124826.80	Current market rates
5	Container (Max)	Fenestration	60000.00	₱10,000 per cut, 6 cuts required
6	Container (Max)	Max Alterations	291000.00	Max estimate for modifications
7	Container (Base)	Container Cost	124826.80	Current market rates
8	Container (Base)	Fenestration	60000.00	₱10,000 per cut, 6 cuts required
9	Container (Base)	Base Alterations	102000.00	Base estimate for modifications
10	Container (Max)	Container Cost	124826.80	Current market rates
11	Container (Max)	Fenestration	60000.00	₱10,000 per cut, 6 cuts required
12	Container (Max)	Max Alterations	291000.00	Max estimate for modifications
\.


--
-- Data for Name: cost_efficiency_analysis; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cost_efficiency_analysis (id, model_name, total_cost, cost_per_sqm, construction_time_days, waste_percentage, cost_savings, savings_percentage, percent_of_traditional, sqm_savings, sqm_savings_percentage) FROM stdin;
1	Traditional Housing	708000	29500	150	30	0	0	100	0	0
2	ODD Cubes Basic	420000	17500	90	15	288000	40.67796610169492	59.32203389830508	12000	40.67796610169492
3	Container (Base)	323343	13473	68	9	384657	54.330084745762704	45.66991525423729	16027	54.32881355932203
4	Container (Max)	580005	24167	68	9	127995	18.078389830508474	81.92161016949152	5333	18.077966101694916
\.


--
-- Data for Name: cost_per_sqm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cost_per_sqm (id, model_name, cost_per_sqm, total_cost, citation) FROM stdin;
17	Traditional Housing	29500.00	708000.00	2024 rates: Total average of Ian Fulgar and ACDC Contractors
18	ODD Cubes Basic	17500.00	420000.00	ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)
19	Container (Base)	13473.00	323343.00	Sum of materials, labor, and base modifications
20	Container (Max)	24167.00	580005.00	Sum of materials, labor, and premium modifications
21	Traditional Housing	29500.00	708000.00	2024 rates: Total average of Ian Fulgar and ACDC Contractors
22	ODD Cubes Basic	17500.00	420000.00	ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)
23	Container (Base)	13473.00	323343.00	Sum of materials, labor, and base modifications
24	Container (Max)	24167.00	580005.00	Sum of materials, labor, and premium modifications
\.


--
-- Data for Name: efficiency_metrics; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.efficiency_metrics (id, model_name, cost_efficiency, time_efficiency, waste_reduction, material_usage, citation) FROM stdin;
7	Traditional Housing	0.00	0.00	0.00	0.00	Baseline - Traditional construction methods
8	ODD Cubes	29.41	40.00	50.00	45.00	Cost and timeline from ODD Cubes
9	Container Housing	25.33	54.67	70.00	75.00	CE10_Proj.pdf [18]: 70% waste reduction, 40-60% faster construction
10	Traditional Housing	0.00	0.00	0.00	0.00	Baseline - Traditional construction methods
11	ODD Cubes	29.41	40.00	50.00	45.00	Cost and timeline from ODD Cubes
12	Container Housing	25.33	54.67	70.00	75.00	CE10_Proj.pdf [18]: 70% waste reduction, 40-60% faster construction
\.


--
-- Data for Name: historical_price_changes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.historical_price_changes (year, month, avg_price, avg_freight_index, price_pct_change, freight_pct_change) FROM stdin;
2017	1	1420.15	954.27	0	0
2017	2	1509.99	815.1	6.3260923141921666	-14.583922789147719
2017	3	1765.18	830.02	16.900111921271012	1.8304502515028798
2017	4	1892.92	909.25	7.236655751821353	9.545553119201955
2017	5	1853.51	853.43	-2.0819685987786163	-6.1391256530107245
2017	6	1838.11	918.83	-0.830856051491502	7.663194403758955
2017	7	1947.89	925.45	5.9724390814478	0.7204814818845717
2017	8	2070.8	715.97	6.309904563399371	-22.63547463396186
2017	9	2384.88	806.81	15.167085184469764	12.687682444795168
2017	10	2152.64	705.19	-9.738016168528407	-12.595282656387486
2017	11	2173.18	824.18	0.9541771963728296	16.873466725279695
2017	12	2456.76	824.18	13.04908014982653	0
2018	1	2420.84	858.6	-1.4620882788713652	4.176272173554341
2018	2	2335.61	854.19	-3.5206787726574262	-0.5136268343815531
2018	3	2331.98	658.68	-0.15541978326861772	-22.888350367014375
2018	4	2392.02	760.67	2.5746361461076006	15.483998299629565
2018	5	2444.68	764.34	2.2014866096437213	0.48246940197458343
2018	6	2534.68	821.18	3.6814634226156384	7.436481147133467
2018	7	2306.63	868.59	-8.997190966907054	5.773399254731015
2018	8	2223.22	939.48	-3.616097943753449	8.161503125755543
2018	9	2271.45	870.58	2.169375950198371	-7.3338442542683175
2018	10	2397.73	956.63	5.559444407757175	9.884215120953833
2018	11	2394.04	890.41	-0.15389555955007683	-6.922216530947178
2018	12	2545.57	910.81	6.32946817931197	2.2910793903931914
2019	1	2442.95	945.44	-4.031317150972091	3.8021102095936676
2019	2	2355.88	847.75	-3.5641335270881425	-10.332755119309533
2019	3	2307.86	793.49	-2.0383041581065187	-6.400471837216159
2019	4	2315.46	778	0.3293094035166755	-1.9521355026528409
2019	5	2411.14	782.12	4.1322242664524556	0.5295629820051495
2019	6	2143.9	829.7	-11.083553837603777	6.083465452871684
2019	7	2247.81	788.93	4.846774569709411	-4.913824273833923
2019	8	2168.15	819.65	-3.5438938344433013	3.893881586452541
2019	9	2114.81	722.9	-2.4601618891681887	-11.803818703104984
2019	10	2042.28	705.28	-3.429622519280695	-2.437404896942874
2019	11	1990.81	819.63	-2.5202224964255615	16.213418784029045
2019	12	1976.95	958.57	-0.6961990345638158	16.951551309737333
2020	1	1735.97	981.19	-12.189483800804268	2.359765066713959
2020	2	1898.27	875.76	9.349239906219564	-10.745115624904455
2020	3	2074.1	889.18	9.262644407802888	1.5323833013610955
2020	4	1973.7	852.27	-4.840653777542059	-4.151015542409853
2020	5	2037.92	920.38	3.2537873030349163	7.991598906449826
2020	6	2065.78	1001.3	1.3670801601633142	8.792020687107494
2020	7	1973.78	1103.5	-4.453523608515919	10.20673124937581
2020	8	2387.25	1263.3	20.948129984091434	14.481196193928403
2020	9	2312.53	1443	-3.129961252487168	14.224649726905735
2020	10	2314.33	1530	0.0778368280627495	6.029106029106024
2020	11	2473.81	2048.3	6.890979246693418	33.87581699346407
2020	12	3008.21	2641.9	21.602305755090324	28.980129863789482
2021	1	4071.73	2861.7	35.353914786534176	8.31976986259888
2021	2	3935.67	2775.3	-3.341577167444798	-3.0191844008805813
2021	3	4307.26	2570.7	9.44159444262349	-7.372175980975038
2021	4	4560.04	3100.7	5.868696108430882	20.616952581009063
2021	5	5142.27	3495.8	12.768089753598666	12.742284000387016
2021	6	6615.43	3785.4	28.648048429973528	8.284226786429416
2021	7	4735.52	4196.2	-28.417049231871548	10.852221693876473
2021	8	4915.5	4385.6	3.800638578234272	4.513607549687837
2021	9	4209.95	4643.8	-14.353575424677045	5.887449835826342
2021	10	4720.62	4567.3	12.13007280371501	-1.647357767345703
2021	11	4284.2	4602	-9.244972058754996	0.7597486479977267
2021	12	3533.33	5046.7	-17.52649269408524	9.663189917427207
2022	1	3423.21	5010.4	-3.1166067137799125	-0.7192819069887335
2022	2	3284.18	4818.5	-4.061392669453534	-3.83003353025706
2022	3	3508.14	4434.1	6.819358256855601	-7.9775863858047025
2022	4	3445.58	4177.3	-1.783281168938522	-5.7914796689294334
2022	5	3388.88	4175.4	-1.6455865195409758	-0.045483925023348526
2022	6	3375.52	4216.1	-0.3942305422440451	0.9747569095176711
2022	7	3278.26	3887.8	-2.881333838934441	-7.786817200730534
2022	8	3168.62	3154.3	-3.344457120545663	-18.866711250578728
2022	9	2656.75	1923	-16.154351105528587	-39.03560219383064
2022	10	2640.37	1663.75	-0.6165427684200697	-13.481539261570463
2022	11	2637.31	1397.15	-0.11589284835079594	-16.02404207362884
2022	12	2619.72	1107.5	-0.6669674782259216	-20.731489102816457
2023	1	2627.46	1029.8	0.2954514222894167	-7.015801354401807
2023	2	2613.53	946.68	-0.5301698218050821	-8.071470188386098
2023	3	2590.85	923.78	-0.8677918370939008	-2.41898001436599
2023	4	2596.26	999.73	0.20881177991780575	8.221654506484244
2023	5	2586.56	983.46	-0.3736143529538771	-1.6274394086403299
2023	6	2583.17	953.6	-0.13106210565383414	-3.0362190633070996
2023	7	2568.65	1029.2	-0.5621000553583388	7.927852348993292
2023	8	2565.52	1013.8	-0.12185389212232556	-1.4963078118927386
2023	9	2548.18	886.85	-0.6758863700146667	-12.522193726573283
2023	10	2550.05	1012.6	0.07338571058561616	14.17939899644811
2023	11	2552.08	993.21	0.07960628222976052	-1.9148726051748
2023	12	2560.14	1759.6	0.3158208206639257	77.16293633773319
2024	1	2549.53	2179.1	-0.4144304608341587	23.840645601273014
2024	2	2540.68	2109.9	-0.34712280302645615	-3.1756229636088262
2024	3	2547.39	1731	0.26410252373381127	-17.958197070951233
2024	4	2540.82	1940.6	-0.257911038356895	12.108607741190047
2024	5	2545.24	3044.8	0.17395958784958143	56.89992785736371
2024	6	2550.43	3714.3	0.20391004384654465	21.988307934839725
2024	7	2559.88	3447.9	0.37052575448062175	-7.172280106614981
2024	8	2552.16	2963.4	-0.30157663640484333	-14.052031671452191
2024	9	2550.68	2135.1	-0.057990094664917	-27.951002227171497
2024	10	2560.32	2141.59	0.3779384321043855	0.3039670273055295
2024	11	2567.48	2232.2	0.279652543432074	4.230968579419958
2024	12	2590.06	2460.3	0.8794615732157673	10.218618403368884
\.


--
-- Data for Name: housing_models; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.housing_models (id, model_name, total_cost, cost_per_sqm, construction_time_days, waste_percentage) FROM stdin;
1	Traditional Housing	708000.00	29500.00	150	30.00
2	ODD Cubes Basic	420000.00	17500.00	90	15.00
3	Container (Base)	323343.00	13473.00	68	9.00
4	Container (Max)	580005.00	24167.00	68	9.00
\.


--
-- Data for Name: resource_usage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.resource_usage (id, resource_type, traditional_usage, container_usage, citation) FROM stdin;
5	Construction Waste	100	30	CE10_Proj.pdf [18]: Produced 70% less onsite waste than traditional building methods
6	Material Usage	100	25	CE10_Proj.pdf: A container home can be constructed of about 75% recycled materials by weight
7	Construction Waste	100	30	CE10_Proj.pdf [18]: Produced 70% less onsite waste than traditional building methods
8	Material Usage	100	25	CE10_Proj.pdf: A container home can be constructed of about 75% recycled materials by weight
\.


--
-- Data for Name: sensitivity_analysis_non_viable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_analysis_non_viable (model_name, adjusted_investment, annual_maintenance, annual_net_income, payback_years, annual_roi_percentage, container_price_increase, rental_income, expected_lifespan, maintenance_pct, income_segment, iteration, viability_issue) FROM stdin;
Traditional Housing	591134.7519994621	17226.915086037923	-1688.6021731497385	100	0	3.4570251762184423	15538.312912888185	116	0.02914211189203371	low	57	Negative cash flow
Traditional Housing	579900.955453463	16101.714899636987	-365.35710274903977	100	0	0.47384927807721766	15736.357796887947	129	0.027766318969152222	low	82	Negative cash flow
Traditional Housing	553590.2453717139	16207.189808309711	-351.2912116876705	100	0	3.727628450132114	15855.89859662204	111	0.02927650901331765	low	141	Negative cash flow
Traditional Housing	562313.3673443231	15681.703279928242	-122.83763651749359	100	0	-1.2520732389627365	15558.865643410749	142	0.027887836552755854	low	170	Negative cash flow
Traditional Housing	598847.8244705778	17155.765386199622	-1436.186891273026	100	0	3.3312264553036144	15719.578494926596	139	0.028647954764411954	low	216	Negative cash flow
Traditional Housing	594253.2425299683	16151.22818460174	-429.39366683586013	100	0	-4.917756988805021	15721.83451776588	132	0.027179032487630442	low	330	Negative cash flow
Traditional Housing	595192.3715388945	17508.190303445183	-1558.3778394840538	100	0	1.289076975441386	15949.812463961129	101	0.02941601932527635	low	333	Negative cash flow
Traditional Housing	571743.2820605744	16807.860695094147	-863.2280118804501	100	0	1.7231814089865969	15944.632683213697	99	0.029397565695076074	low	361	Negative cash flow
Traditional Housing	586116.4475772458	16955.61856399632	-1258.3132277333425	100	0	-4.841266541710528	15697.305336262976	121	0.0289287540625819	low	374	Negative cash flow
Traditional Housing	580342.2474131446	16238.75386574214	-282.3431291251145	100	0	-3.500242293842053	15956.410736617025	100	0.027981340214547228	low	380	Negative cash flow
Traditional Housing	583884.9110955144	17213.865596987052	-1737.0191973610054	100	0	-3.681721485187083	15476.846399626047	112	0.02948160719668115	low	384	Negative cash flow
Traditional Housing	564458.5917379266	16286.015105191656	-479.7215204790864	100	0	-2.9301423193934353	15806.29358471257	115	0.028852453206617355	low	432	Negative cash flow
Traditional Housing	576452.7628922216	16901.25570654184	-1146.078355922471	100	0	0.2883827495877611	15755.17735061937	82	0.029319411397637524	low	440	Negative cash flow
Traditional Housing	595232.7306107583	17038.284486090335	-1455.1046067738607	100	0	4.77838061511582	15583.179879316474	135	0.028624575917738322	low	451	Negative cash flow
Traditional Housing	591496.5509033935	16782.2548963166	-1321.6675135526639	100	0	4.571093552478022	15460.587382763937	124	0.028372532131734393	low	466	Negative cash flow
Traditional Housing	586391.964794892	16485.744445374192	-633.7863716209486	100	0	-1.843582037643856	15851.958073753243	112	0.028113864846597225	low	495	Negative cash flow
Traditional Housing	590576.4426340358	16256.18506518678	-713.2017385963991	100	0	-1.262711477726116	15542.983326590382	85	0.027525962587810662	low	496	Negative cash flow
Traditional Housing	572171.5405649251	17027.51151639881	-1097.0124139311538	100	0	-2.4464826253744976	15930.499102467655	95	0.029759452033540412	low	499	Negative cash flow
\.


--
-- Data for Name: sensitivity_analysis_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_analysis_results (model_name, adjusted_investment, annual_maintenance, annual_net_income, payback_years, annual_roi_percentage, container_price_increase, rental_income, expected_lifespan, maintenance_pct, income_segment, iteration, viability_issue) FROM stdin;
Traditional Housing	517649.01041189744	9172.831876971128	21002.77452629232	24.646696547824128	4.057338873222271	0.7703804702650334	30175.606403263446	83	0.017720176591610272	middle	0	\N
ODD Cubes Basic	296317.56031330064	2812.055973055085	27363.55043020836	10.828914949069507	9.234535543987505	0.7703804702650334	30175.606403263446	124	0.00949000784861302	middle	0	\N
Container (Base)	231645.27719749612	2198.315498698377	27977.29090456507	8.279760824151078	12.077643560465164	0.7703804702650334	30175.606403263446	53	0.00949000784861302	middle	0	\N
Container (Max)	451812.12149269413	4287.700579064167	25887.90582419928	17.452633077425403	5.729794441696468	0.7703804702650334	30175.606403263446	140	0.00949000784861302	middle	0	\N
Traditional Housing	495732.15514430945	10900.489017538046	5043.041579499752	98.30023158236264	1.0172916013551117	-4.840352258163661	15943.530597037798	137	0.02198866646922444	low	1	\N
ODD Cubes Basic	349213.0578026544	6773.10140179286	9170.429195244938	38.08033957491638	2.626027002812503	-4.840352258163661	15943.530597037798	118	0.019395326865527585	low	1	\N
Container (Base)	218772.22496454028	4243.158812285993	11700.371784751806	18.697886613282606	5.348198011264118	-4.840352258163661	15943.530597037798	107	0.019395326865527585	low	1	\N
Container (Max)	448547.2224262026	8699.719993580704	7243.810603457094	61.92144535255165	1.6149493835398532	-4.840352258163661	15943.530597037798	49	0.019395326865527585	low	1	\N
Traditional Housing	503437.0383992262	14674.013700182128	15917.020788914058	31.628848455727454	3.161670591326624	-3.0261476342201954	30591.034489096186	88	0.0291476641187167	middle	2	\N
ODD Cubes Basic	328963.3077274993	3254.6249219107704	27336.409567185416	12.033888609950676	8.309865849789503	-3.0261476342201954	30591.034489096186	90	0.009893580364308527	middle	2	\N
Container (Base)	228693.80811136958	2262.6005693695884	28328.433919726598	8.072942145669334	12.387057679292823	-3.0261476342201954	30591.034489096186	90	0.009893580364308527	middle	2	\N
Container (Max)	430499.66802182194	4259.183062382037	26331.85142671415	16.349008698456807	6.11657879963322	-3.0261476342201954	30591.034489096186	136	0.009893580364308527	middle	2	\N
Traditional Housing	548188.4716893081	7920.630817828205	22114.67367401829	24.788449505061173	4.034136946709093	0.6175415805011255	30035.304491846495	136	0.014448736569413504	middle	3	\N
ODD Cubes Basic	304737.39699500706	5916.688894236539	24118.615597609954	12.634945640296417	7.914557200869286	0.6175415805011255	30035.304491846495	137	0.019415696769023334	middle	3	\N
Container (Base)	241562.1149276532	4690.09677431928	25345.207717527213	9.53087927389932	10.492211382202045	0.6175415805011255	30035.304491846495	47	0.019415696769023334	middle	3	\N
Container (Max)	436521.02058409154	8475.359768965314	21559.94472288118	20.246852494052067	4.939039291631975	0.6175415805011255	30035.304491846495	65	0.019415696769023334	middle	3	\N
Traditional Housing	550109.932322854	8262.83762883622	22468.992126310157	24.483071124436442	4.084454907300843	1.7165564757741567	30731.829755146377	100	0.01502033892379686	middle	4	\N
ODD Cubes Basic	345067.26446911815	8390.564321831576	22341.265433314802	15.445287353981367	6.474466787710671	1.7165564757741567	30731.829755146377	59	0.024315735468968227	middle	4	\N
Container (Base)	250884.6823694555	6100.445569711796	24631.38418543458	10.185569778811399	9.81781109663847	1.7165564757741567	30731.829755146377	131	0.024315735468968227	middle	4	\N
Container (Max)	425742.3231065597	10352.237706603104	20379.592048543273	20.89062048408332	4.786837235217142	1.7165564757741567	30731.829755146377	99	0.024315735468968227	middle	4	\N
Traditional Housing	534893.6386266353	10225.972816259393	5469.376381177379	97.79792088682149	1.0225166250285311	2.5504202293387586	15695.349197436772	82	0.01911776861380341	low	5	\N
ODD Cubes Basic	316589.56356190424	4427.276086784267	11268.073110652505	28.09615809668556	3.5592054848166863	2.5504202293387586	15695.349197436772	98	0.013984276793503905	low	5	\N
Container (Base)	280851.1389154173	3927.500064364012	11767.84913307276	23.865970385879933	4.190066374135955	2.5504202293387586	15695.349197436772	41	0.013984276793503905	low	5	\N
Container (Max)	416637.79320278665	5826.378222782409	9868.970974654363	42.216943820465374	2.368717177284712	2.5504202293387586	15695.349197436772	117	0.013984276793503905	low	5	\N
Traditional Housing	506742.4832243047	10044.241395331901	5696.19076226658	88.96164197679819	1.1240799717487306	-4.630705080392298	15740.432157598481	99	0.019821194645892586	low	6	\N
ODD Cubes Basic	334660.34908505995	5835.723950667222	9904.70820693126	33.78800688453058	2.9596300350519864	-4.630705080392298	15740.432157598481	80	0.017437751339893476	low	6	\N
Container (Base)	219146.10393637407	3821.4152675489418	11919.01689004954	18.386256681901827	5.438844987867115	-4.630705080392298	15740.432157598481	60	0.017437751339893476	low	6	\N
Container (Max)	416692.2147942313	7266.175226851286	8474.256930747195	49.17153423592156	2.033696966220477	-4.630705080392298	15740.432157598481	77	0.017437751339893476	low	6	\N
Traditional Housing	587211.294877589	17105.13770378095	13019.585826469935	45.10214861702728	2.2171892707179652	-3.6024523364870653	30124.723530250885	90	0.029129442592460204	middle	7	\N
ODD Cubes Basic	302975.2856478367	6481.420165875131	23643.303364375755	12.814422797803322	7.80370693068924	-3.6024523364870653	30124.723530250885	138	0.021392570526062013	middle	7	\N
Container (Base)	233143.45758450468	4987.537859066464	25137.185671184423	9.274843279363793	10.781853341122922	-3.6024523364870653	30124.723530250885	62	0.021392570526062013	middle	7	\N
Container (Max)	418858.72617453034	8960.464840145138	21164.258690105748	19.79085269687929	5.052839386539845	-3.6024523364870653	30124.723530250885	128	0.021392570526062013	middle	7	\N
Traditional Housing	580020.8311786394	9677.997190155229	6147.985648140622	94.34323116125996	1.059959456222895	-0.9383515991140134	15825.982838295851	148	0.016685602774798483	low	8	\N
ODD Cubes Basic	318893.39006097766	7915.543165757523	7910.4396725383285	40.31297920999757	2.480590667315407	-0.9383515991140134	15825.982838295851	102	0.024821910432963005	low	8	\N
Container (Base)	260066.5567392118	6455.348777989807	9370.634060306045	27.753357463915098	3.603167657463424	-0.9383515991140134	15825.982838295851	144	0.024821910432963005	low	8	\N
Container (Max)	439730.25115442974	10914.944908819582	4911.03792947627	89.53916818991543	1.1168296737791534	-0.9383515991140134	15825.982838295851	89	0.024821910432963005	low	8	\N
Traditional Housing	534490.530359727	9074.092311923418	21069.350777912463	25.368153769600106	3.9419502462900895	-4.005383522945508	30143.44308983588	119	0.01697708714468019	middle	9	\N
ODD Cubes Basic	324738.18381558324	5388.65343686842	24754.78965296746	13.11819604884647	7.622999353542468	-4.005383522945508	30143.44308983588	144	0.01659383991606174	middle	9	\N
Container (Base)	252952.77786123136	4197.4579021524	25945.98518768348	9.749206901625291	10.257244615798337	-4.005383522945508	30143.44308983588	115	0.01659383991606174	middle	9	\N
Container (Max)	451216.5320851143	7487.414900900922	22656.028188934957	19.915959157637577	5.021098868926479	-4.005383522945508	30143.44308983588	101	0.01659383991606174	middle	9	\N
Traditional Housing	558050.1181461299	6351.37083003797	23841.39388704153	23.406773982684204	4.272267509994231	-3.597336392017482	30192.7647170795	113	0.011381362754903698	middle	10	\N
ODD Cubes Basic	307509.57970219775	6428.78075709356	23763.98395998594	12.940152636863658	7.727884114374503	-3.597336392017482	30192.7647170795	124	0.02090595279444432	middle	10	\N
Container (Base)	255754.73906808492	5346.796501912808	24845.968215166693	10.293611295532644	9.714763568292044	-3.597336392017482	30192.7647170795	72	0.02090595279444432	middle	10	\N
Container (Max)	460428.8201998245	9625.703180299224	20567.061536780275	22.38670893148422	4.466936176552597	-3.597336392017482	30192.7647170795	143	0.02090595279444432	middle	10	\N
Traditional Housing	534893.3448299464	15732.481047867715	15234.13776204012	35.11149453845524	2.848070163760098	2.98508452175943	30966.618809907835	83	0.029412370148051467	middle	11	\N
ODD Cubes Basic	308153.18477182876	5774.8786939379515	25191.740115969886	12.23231040623828	8.175070504178967	2.98508452175943	30966.618809907835	83	0.01874028560897057	middle	11	\N
Container (Base)	264596.73640429304	4958.618411417952	26008.000398489883	10.173667038995296	9.829297500763849	2.98508452175943	30966.618809907835	49	0.01874028560897057	middle	11	\N
Container (Max)	432169.8982254792	8098.987324345224	22867.63148556261	18.898760831366726	5.291352215750972	2.98508452175943	30966.618809907835	102	0.01874028560897057	middle	11	\N
Traditional Housing	538758.7313028405	14033.374328467222	1552.8932270204023	100	0.2882353708245535	-1.545113032750145	15586.267555487624	139	0.02604760445279717	low	12	\N
ODD Cubes Basic	307074.4362670338	3581.4429614532487	12004.824594034375	25.579252229943453	3.909418426350185	-1.545113032750145	15586.267555487624	63	0.011663110107735585	low	12	\N
Container (Base)	255251.4943054113	2977.026283248055	12609.24127223957	20.243208040389508	4.939928483690862	-1.545113032750145	15586.267555487624	98	0.011663110107735585	low	12	\N
Container (Max)	444868.55167710275	5188.550901678907	10397.716653808717	42.7852158785406	2.3372559410213496	-1.545113032750145	15586.267555487624	55	0.011663110107735585	low	12	\N
Traditional Housing	572212.7041182733	12753.043111232755	17525.416287812324	32.650448623934054	3.0627450529637166	0.4630598243594761	30278.459399045078	122	0.02228724217314261	middle	13	\N
ODD Cubes Basic	316255.8025691777	6793.453456758787	23485.00594228629	13.466285822808263	7.425952583794629	0.4630598243594761	30278.459399045078	98	0.02148088162041798	middle	13	\N
Container (Base)	258907.34498071086	5561.558028187369	24716.901370857708	10.474911118348102	9.546620383712625	0.4630598243594761	30278.459399045078	126	0.02148088162041798	middle	13	\N
Container (Max)	492903.52128746524	10588.002191063215	19690.45720798186	25.032609252346788	3.9947893162845207	0.4630598243594761	30278.459399045078	123	0.02148088162041798	middle	13	\N
Traditional Housing	597378.5371539098	14901.185978514553	704.066583195814	100	0.11785937046720794	-2.4030417521358824	15605.252561710367	113	0.02494429419829555	low	14	\N
ODD Cubes Basic	347675.6319001927	3280.303746730271	12324.948814980096	28.209093369833532	3.5449561844812356	-2.4030417521358824	15605.252561710367	84	0.009434954439579327	low	14	\N
Container (Base)	248282.19885097552	2342.5312343175287	13262.72132739284	18.72030578959487	5.34179308414834	-2.4030417521358824	15605.252561710367	110	0.009434954439579327	low	14	\N
Container (Max)	448300.312583678	4229.6930244761725	11375.559537234196	39.40907795491841	2.5374864165660997	-2.4030417521358824	15605.252561710367	82	0.009434954439579327	low	14	\N
Traditional Housing	590313.2131821362	16782.34258444059	13464.856235664447	43.84103349121322	2.2809681259006442	-2.707748116580664	30247.198820105037	120	0.028429556055460575	middle	15	\N
ODD Cubes Basic	309431.3317024648	6420.644310847338	23826.5545092577	12.986826592247596	7.700110515042556	-2.707748116580664	30247.198820105037	111	0.020749819598169003	middle	15	\N
Container (Base)	266682.24414488295	5533.608456041183	24713.590364063853	10.790914643170053	9.267055046468514	-2.707748116580664	30247.198820105037	99	0.020749819598169003	middle	15	\N
Container (Max)	435959.1073042967	9046.07282874296	21201.125991362078	20.563016675714223	4.863099688972394	-2.707748116580664	30247.198820105037	54	0.020749819598169003	middle	15	\N
Traditional Housing	503079.13947024866	9782.442610894475	20306.341427599116	24.774484427140322	4.0364109410265065	0.14387375309400596	30088.78403849359	113	0.01944513664628504	middle	16	\N
ODD Cubes Basic	327460.2697344112	4717.110803391175	25371.67323510242	12.906530314341301	7.7480157381169565	0.14387375309400596	30088.78403849359	85	0.014405139308096882	middle	16	\N
Container (Base)	259897.44114111445	3743.8588454556634	26344.92519303793	9.865180456454533	10.136662014588143	0.14387375309400596	30088.78403849359	72	0.014405139308096882	middle	16	\N
Container (Max)	425922.8692552474	6135.478266126173	23953.305772367417	17.781381547201427	5.623859975927393	0.14387375309400596	30088.78403849359	58	0.014405139308096882	middle	16	\N
Traditional Housing	601117.0171990747	8904.526125616687	6667.636584086518	90.15443622613532	1.1092077571110195	-2.5966675663693684	15572.162709703205	138	0.014813299026381968	low	17	\N
ODD Cubes Basic	329664.5569595979	2655.811924422522	12916.350785280683	25.523041487482644	3.9180283450561078	-2.5966675663693684	15572.162709703205	69	0.008056103904272626	low	17	\N
Container (Base)	259960.18845513114	2094.2662891688296	13477.896420534376	19.287890360922074	5.18460018844795	-2.5966675663693684	15572.162709703205	131	0.008056103904272626	low	17	\N
Container (Max)	447202.1133017486	3602.7066909691857	11969.45601873402	37.36194131143548	2.676520450755933	-2.5966675663693684	15572.162709703205	99	0.008056103904272626	low	17	\N
Traditional Housing	495968.9006739617	9371.763313545967	20741.34995920893	23.912083912057856	4.18198599368306	4.127169113187204	30113.113272754897	99	0.018895868875671188	middle	18	\N
ODD Cubes Basic	320220.52152859815	5964.941557156659	24148.17171559824	13.260652827052546	7.541106859836784	4.127169113187204	30113.113272754897	121	0.018627605528473114	middle	18	\N
Container (Base)	258461.243194314	4814.514082622438	25298.59919013246	10.216425077603704	9.788159678204709	4.127169113187204	30113.113272754897	75	0.018627605528473114	middle	18	\N
Container (Max)	494703.4826877472	9215.141329069183	20897.971943685712	23.672320166800734	4.2243430004062335	4.127169113187204	30113.113272754897	105	0.018627605528473114	middle	18	\N
Traditional Housing	509635.5524860908	8641.478660865983	21559.292116697216	23.638788775044652	4.23033518982874	3.3595403254472664	30200.7707775632	84	0.016956192751293248	middle	19	\N
ODD Cubes Basic	335898.98512398975	7473.5553907521025	22727.215386811098	14.77959263407678	6.766086351354067	3.3595403254472664	30200.7707775632	101	0.022249413430032852	middle	19	\N
Container (Base)	238318.8325795497	5302.454234225183	24898.316543338016	9.571684582157667	10.44748175116504	3.3595403254472664	30200.7707775632	106	0.022249413430032852	middle	19	\N
Container (Max)	501864.44288514875	11166.189475584784	19034.58130197842	26.365930246807473	3.7927734414797873	3.3595403254472664	30200.7707775632	52	0.022249413430032852	middle	19	\N
Traditional Housing	517573.35253230965	6679.690677939935	9182.599615582163	56.36457802799412	1.7741639075224487	1.8454179749420039	15862.2902935221	84	0.012905785518629368	low	20	\N
ODD Cubes Basic	320412.3403587035	7370.141469047161	8492.148824474938	37.73041982439754	2.650381322694353	1.8454179749420039	15862.2902935221	45	0.023002052482735978	low	20	\N
Container (Base)	240289.36546528453	5527.148595475801	10335.141698046298	23.249740785915648	4.3011232220093625	1.8454179749420039	15862.2902935221	48	0.023002052482735978	low	20	\N
Container (Max)	445405.4419336295	10245.239351453558	5617.050942068541	79.29524701259056	1.2611096347820432	1.8454179749420039	15862.2902935221	66	0.023002052482735978	low	20	\N
Traditional Housing	498238.6160149148	10184.426716983131	20034.138848097813	24.86948003069377	4.0209927942434085	2.204667047720621	30218.565565080942	140	0.020440861847364836	middle	21	\N
ODD Cubes Basic	312917.5220636433	5482.744085525597	24735.821479555343	12.65037922117428	7.904901367116285	2.204667047720621	30218.565565080942	50	0.017521371284572804	middle	21	\N
Container (Base)	268829.64987064	4710.264107685193	25508.301457395748	10.538908296957455	9.488648841253285	2.204667047720621	30218.565565080942	104	0.017521371284572804	middle	21	\N
Container (Max)	472973.7465454238	8287.148621077804	21931.41694400314	21.56603687545835	4.636920569944758	2.204667047720621	30218.565565080942	114	0.017521371284572804	middle	21	\N
Traditional Housing	519751.28516189626	9207.944092001448	6625.641754152448	78.4454252806765	1.2747715962046424	2.814927422170671	15833.585846153896	92	0.017716058343431096	low	22	\N
ODD Cubes Basic	346011.53249800095	6673.159153254739	9160.426692899156	37.77242524807464	2.6474339241719003	2.814927422170671	15833.585846153896	85	0.019285944329885285	low	22	\N
Container (Base)	272658.6353961233	5258.479263312123	10575.106582841772	25.783062634897217	3.8785151871232943	2.814927422170671	15833.585846153896	102	0.019285944329885285	low	22	\N
Container (Max)	430195.48961645464	8296.726263710687	7536.859582443209	57.078878133616364	1.7519615533772275	2.814927422170671	15833.585846153896	80	0.019285944329885285	low	22	\N
Traditional Housing	518211.0969715355	12582.851598192974	17982.756983789575	28.817110604267913	3.470160536677457	3.0314927865949066	30565.60858198255	142	0.024281324100792326	middle	23	\N
ODD Cubes Basic	318629.7011286422	5966.561648775494	24599.046933207057	12.952928704669185	7.720261747750736	3.0314927865949066	30565.60858198255	57	0.018725692010634565	middle	23	\N
Container (Base)	243628.75202432706	4562.11697534281	26003.491606639738	9.369078418765842	10.673408368501274	3.0314927865949066	30565.60858198255	126	0.018725692010634565	middle	23	\N
Container (Max)	507480.3103330713	9502.919992758343	21062.688589224206	24.093804937737204	4.15044449220114	3.0314927865949066	30565.60858198255	51	0.018725692010634565	middle	23	\N
Traditional Housing	561795.6350610123	6213.986503449943	9565.590638185404	58.73088827556028	1.702681552010734	2.0286320198048893	15779.577141635347	81	0.011060937671356397	low	24	\N
ODD Cubes Basic	317196.4492983958	5085.704054839206	10693.873086796142	29.661512412190692	3.3713722554113805	2.0286320198048893	15779.577141635347	137	0.016033294401902144	low	24	\N
Container (Base)	245647.88467003507	3938.5448541191768	11841.032287516171	20.7454788320287	4.820327398064739	2.0286320198048893	15779.577141635347	84	0.016033294401902144	low	24	\N
Container (Max)	435626.83795194613	6984.53334225327	8795.043799382078	49.53094582457366	2.018939843268393	2.0286320198048893	15779.577141635347	134	0.016033294401902144	low	24	\N
Traditional Housing	583740.670137931	14172.159579222796	16448.458513617195	35.48908061230597	2.8177681211985144	-0.0635923545710888	30620.61809283999	110	0.024278177458277976	middle	25	\N
ODD Cubes Basic	335493.80610604835	5787.732557592181	24832.88553524781	13.510061310831086	7.4018909092462435	-0.0635923545710888	30620.61809283999	129	0.01725138423498257	middle	25	\N
Container (Base)	243018.25057961568	4192.401216862226	26428.216875977767	9.195408518102102	10.874992644768286	-0.0635923545710888	30620.61809283999	112	0.01725138423498257	middle	25	\N
Container (Max)	482955.2287448956	8331.646219372093	22288.971873467897	21.667900676916847	4.615121764266326	-0.0635923545710888	30620.61809283999	136	0.01725138423498257	middle	25	\N
Traditional Housing	541711.7056512954	6955.493969582517	23826.359356132274	22.735815302469746	4.398346778843563	-2.215975716343388	30781.85332571479	105	0.012839844324980915	middle	26	\N
ODD Cubes Basic	330020.10920920264	5989.821380354248	24792.03194536054	13.311539366218064	7.512279177401476	-2.215975716343388	30781.85332571479	59	0.018149867881406122	middle	26	\N
Container (Base)	259074.8658802993	4702.174587120443	26079.678738594346	9.933974589069766	10.066464243831346	-2.215975716343388	30781.85332571479	99	0.018149867881406122	middle	26	\N
Container (Max)	402994.08541266096	7314.2894072278905	23467.5639184869	17.17238682346559	5.82330231830981	-2.215975716343388	30781.85332571479	145	0.018149867881406122	middle	26	\N
Traditional Housing	582530.4316677522	17213.09754342119	13757.104697347339	42.3439702236239	2.361611333842511	0.23064797156548522	30970.20224076853	146	0.02954883832273114	middle	27	\N
ODD Cubes Basic	306548.24363817443	3703.704490289755	27266.497750478775	11.24267027043441	8.894684055884532	0.23064797156548522	30970.20224076853	75	0.012081962846478802	middle	27	\N
Container (Base)	256133.38676687217	3094.5940626601346	27875.608178108396	9.18844120387737	10.88323881942039	0.23064797156548522	30970.20224076853	99	0.012081962846478802	middle	27	\N
Container (Max)	461583.5313196784	5576.835075950839	25393.36716481769	18.177326713851432	5.501359004775894	0.23064797156548522	30970.20224076853	43	0.012081962846478802	middle	27	\N
Traditional Housing	504532.1791465531	5217.307054304506	10670.876833575301	47.28122974478269	2.1150042107573275	-3.296532991771264	15888.183887879808	93	0.010340880661229375	low	28	\N
ODD Cubes Basic	315489.88032067224	6877.904875008138	9010.27901287167	35.01444071487441	2.8559645094522157	-3.296532991771264	15888.183887879808	44	0.02180071471077695	low	28	\N
Container (Base)	237847.15340081102	5185.237936061482	10702.945951818325	22.222587544731375	4.499926023408035	-3.296532991771264	15888.183887879808	49	0.02180071471077695	low	28	\N
Container (Max)	393505.6856807379	8578.705190594434	7309.478697285374	53.83498632082747	1.8575281027110133	-3.296532991771264	15888.183887879808	76	0.02180071471077695	low	28	\N
Traditional Housing	538378.4378028224	6826.983486007292	8725.155205067942	61.704167450237364	1.620636079088939	-3.875041924924151	15552.138691075234	119	0.012680640617534595	low	29	\N
ODD Cubes Basic	319843.04461229354	2742.8886106488426	12809.250080426391	24.96969319859252	4.004854973774238	-3.875041924924151	15552.138691075234	95	0.008575733181797683	low	29	\N
Container (Base)	252772.07765798288	2167.7058938035048	13384.43279727173	18.885527798347027	5.295059850471989	-3.875041924924151	15552.138691075234	80	0.008575733181797683	low	29	\N
Container (Max)	400655.26987672254	3435.9126923439153	12116.22599873132	33.06766231652289	3.0241024915158	-3.875041924924151	15552.138691075234	93	0.008575733181797683	low	29	\N
Traditional Housing	555913.3188853199	6657.273985558344	24143.048378998486	23.025813068779534	4.342951960102074	4.75248191808347	30800.32236455683	117	0.011975381339858997	middle	30	\N
ODD Cubes Basic	326115.4540009571	6608.694365691933	24191.627998864897	13.480508794871467	7.418117633515736	4.75248191808347	30800.32236455683	54	0.020264891726574044	middle	30	\N
Container (Base)	286189.76798931434	5799.604661556801	25000.717703000028	11.447262090198803	8.735713327086346	4.75248191808347	30800.32236455683	89	0.020264891726574044	middle	30	\N
Container (Max)	485201.93267625343	9832.564631208745	20967.757733348084	23.140382431287158	4.321449755505947	4.75248191808347	30800.32236455683	117	0.020264891726574044	middle	30	\N
Traditional Housing	571681.573600836	8336.93277968641	21950.981975165734	26.043553506973332	3.839721794233047	-0.2800474402003381	30287.914754852147	97	0.014583175608013369	middle	31	\N
ODD Cubes Basic	322092.5759656739	7021.898425461952	23266.016329390193	13.84390741438614	7.22339416226399	-0.2800474402003381	30287.914754852147	129	0.02180087015172399	middle	31	\N
Container (Base)	237821.08478077507	5184.706588647819	25103.208166204327	9.473732727952527	10.555501497835913	-0.2800474402003381	30287.914754852147	88	0.02180087015172399	middle	31	\N
Container (Max)	460076.90198183316	10030.076799913391	20257.837954938754	22.71105648121096	4.403141706892007	-0.2800474402003381	30287.914754852147	45	0.02180087015172399	middle	31	\N
Traditional Housing	497233.8177145429	6513.312568703581	9438.854272053846	52.67946759033365	1.8982727915486635	3.7271174187297493	15952.166840757427	147	0.013099094101525512	low	32	\N
ODD Cubes Basic	298958.42989025783	5705.527966840355	10246.638873917072	29.176243407119546	3.427446042474342	3.7271174187297493	15952.166840757427	109	0.019084686686823817	low	32	\N
Container (Base)	265569.2482344539	5068.305896209892	10883.860944547534	24.40027942175204	4.09831372303275	3.7271174187297493	15952.166840757427	65	0.019084686686823817	low	32	\N
Container (Max)	472322.09014745767	9014.119105729984	6938.047735027443	68.07708856814163	1.468922982802139	3.7271174187297493	15952.166840757427	52	0.019084686686823817	low	32	\N
Traditional Housing	590242.0273513797	15865.353434626802	14887.09831199425	39.6478893993622	2.522202354650653	3.3946765211958994	30752.451746621053	145	0.02687940319299209	middle	33	\N
ODD Cubes Basic	339595.4805813377	4967.137674269433	25785.31407235162	13.170112244064926	7.592949714233812	3.3946765211958994	30752.451746621053	70	0.014626630677671035	middle	33	\N
Container (Base)	273453.9471207438	3999.7098918865045	26752.741854734548	10.221529763400662	9.783271419710703	3.3946765211958994	30752.451746621053	131	0.014626630677671035	middle	33	\N
Container (Max)	479009.70922152844	7006.29810780189	23746.153638819163	20.17209677437884	4.957342864179239	3.3946765211958994	30752.451746621053	45	0.014626630677671035	middle	33	\N
Traditional Housing	526845.0329605674	6058.5019846298665	9445.377731031047	55.77807981460764	1.7928189771389573	4.064408737972716	15503.879715660914	85	0.011499590212675166	low	34	\N
ODD Cubes Basic	347094.7196792189	7669.316554543329	7834.563161117585	44.30300867339061	2.2571830445470913	4.064408737972716	15503.879715660914	119	0.022095745396620344	low	34	\N
Container (Base)	264953.02953049616	5854.334682569075	9649.54503309184	27.4575670274479	3.6419832791461526	4.064408737972716	15503.879715660914	87	0.022095745396620344	low	34	\N
Container (Max)	451843.6953818083	9983.823252224516	5520.056463436398	81.85490463271861	1.2216738929536122	4.064408737972716	15503.879715660914	104	0.022095745396620344	low	34	\N
Traditional Housing	558859.6009679814	5962.281303952827	9855.641164274919	56.70454023770221	1.7635272163534998	-3.5081453473096715	15817.922468227745	81	0.010668656839080453	low	35	\N
ODD Cubes Basic	316578.29941767664	7044.518273926135	8773.40419430161	36.08386122496175	2.7713220427425584	-3.5081453473096715	15817.922468227745	40	0.02225205671672388	low	35	\N
Container (Base)	257575.0475366449	5731.574566598272	10086.347901629473	25.53699813339108	3.915887038784104	-3.5081453473096715	15817.922468227745	72	0.02225205671672388	low	35	\N
Container (Max)	406152.28278047766	9037.723632058065	6780.19883616968	59.902709727894084	1.6693735634706082	-3.5081453473096715	15817.922468227745	56	0.02225205671672388	low	35	\N
Traditional Housing	501397.6268640795	11619.38439292764	19234.931196218968	26.067035111757498	3.836262911039512	-1.1334558452181631	30854.31558914661	144	0.02317399159944062	middle	36	\N
ODD Cubes Basic	295575.7668193162	6399.131295858348	24455.18429328826	12.08642565414799	8.273744683622043	-1.1334558452181631	30854.31558914661	102	0.021649715620191898	middle	36	\N
Container (Base)	262764.68386715173	5688.780680753461	25165.534908393147	10.441450373443686	9.577213550172637	-1.1334558452181631	30854.31558914661	108	0.021649715620191898	middle	36	\N
Container (Max)	476502.12526958133	10316.13550450349	20538.180084643118	23.200795947147878	4.31019695306157	-1.1334558452181631	30854.31558914661	106	0.021649715620191898	middle	36	\N
Traditional Housing	594255.4806887214	10908.019332146352	19131.78322419108	31.061165272734133	3.2194542323813335	3.423822957982365	30039.802556337432	105	0.018355774051093877	middle	37	\N
ODD Cubes Basic	324159.2839424088	7792.631392377343	22247.17116396009	14.57080909538465	6.863036866749926	3.423822957982365	30039.802556337432	148	0.02403951322203009	middle	37	\N
Container (Base)	240673.5328350133	5785.674574779995	24254.127981557438	9.922992614618785	10.077605001204743	3.423822957982365	30039.802556337432	71	0.02403951322203009	middle	37	\N
Container (Max)	467713.27188598976	11243.599383622206	18796.203172715228	24.883390948068033	4.01874488122223	3.423822957982365	30039.802556337432	112	0.02403951322203009	middle	37	\N
Traditional Housing	522355.86426314927	11942.631526453048	3663.531612758552	100	0.701347847970739	3.055960316833941	15606.1631392116	99	0.02286301799884965	low	38	\N
ODD Cubes Basic	329012.4923233508	6438.971064624097	9167.192074587503	35.89021476220737	2.786274773292821	3.055960316833941	15606.1631392116	95	0.01957059751486861	low	38	\N
Container (Base)	268064.88391798653	5246.18995102889	10359.97318818271	25.875055760159647	3.8647259711019464	3.055960316833941	15606.1631392116	74	0.01957059751486861	low	38	\N
Container (Max)	506523.34368223103	9912.96449109041	5693.19864812119	88.96990514275988	1.1239755717345252	3.055960316833941	15606.1631392116	135	0.01957059751486861	low	38	\N
Traditional Housing	541041.4024417275	10658.167425868452	20065.412260415535	26.963881699509276	3.7086648396703183	3.514567450636573	30723.579686283985	115	0.019699356422203537	middle	39	\N
ODD Cubes Basic	331849.9562488769	5267.599428792449	25455.980257491537	13.036227750499432	7.670930725812833	3.514567450636573	30723.579686283985	122	0.015873437165204618	middle	39	\N
Container (Base)	243085.88423659277	3858.608509177759	26864.971177106225	9.048432720588421	11.051637680022115	3.514567450636573	30723.579686283985	108	0.015873437165204618	middle	39	\N
Container (Max)	424276.09284855844	6734.719900530113	23988.859785753873	17.686380121347863	5.654068232950491	3.514567450636573	30723.579686283985	80	0.015873437165204618	middle	39	\N
Traditional Housing	528636.1046272902	14024.526079988143	16408.35381942813	32.21749789435699	3.1039033610836477	-3.1132830161656146	30432.87989941627	147	0.026529641008678363	middle	40	\N
ODD Cubes Basic	295080.74564342335	3243.669656180165	27189.210243236106	10.852861962654137	9.214159393541605	-3.1132830161656146	30432.87989941627	147	0.010992481563333947	middle	40	\N
Container (Base)	229128.46011587355	2518.6903734588377	27914.189525957434	8.208314982701065	12.182768352670301	-3.1132830161656146	30432.87989941627	41	0.010992481563333947	middle	40	\N
Container (Max)	404894.81132071273	4450.798748532512	25982.081150883758	15.583617377276207	6.416995334203884	-3.1132830161656146	30432.87989941627	126	0.010992481563333947	middle	40	\N
Traditional Housing	546568.8422040304	9444.821964804363	20662.508730339174	26.452201392248774	3.780403699379922	-1.398476773148781	30107.330695143537	100	0.01728020559444674	middle	41	\N
ODD Cubes Basic	347942.26614512596	5528.262303632777	24579.06839151076	14.156039627006368	7.064122638454876	-1.398476773148781	30107.330695143537	116	0.015888447140615422	middle	41	\N
Container (Base)	224492.70694884722	3566.8405078104274	26540.49018733311	8.458498895999671	11.822428687351795	-1.398476773148781	30107.330695143537	66	0.015888447140615422	middle	41	\N
Container (Max)	440448.0961983402	6998.036294632025	23109.294400511513	19.059348527257114	5.246769051785176	-1.398476773148781	30107.330695143537	59	0.015888447140615422	middle	41	\N
Traditional Housing	530158.9257367243	14682.074561047419	1189.9581339914894	100	0.22445309816068623	1.4442109349716041	15872.032695038908	116	0.02769372323713079	low	42	\N
ODD Cubes Basic	348524.05010359397	6793.502789121524	9078.529905917385	38.38992146475456	2.604850340519949	1.4442109349716041	15872.032695038908	127	0.01949220659837463	low	42	\N
Container (Base)	252030.86923241985	4912.637772246268	10959.39492279264	22.99678686715289	4.34843356933631	1.4442109349716041	15872.032695038908	59	0.01949220659837463	low	42	\N
Container (Max)	429594.9358921149	8373.753244024607	7498.279451014301	57.29246805198799	1.745430130698133	1.4442109349716041	15872.032695038908	122	0.01949220659837463	low	42	\N
Traditional Housing	589979.4519620815	14360.565682901857	1453.6034970243782	100	0.2463820548648197	-0.06199242535041005	15814.169179926235	119	0.024340789556557003	low	43	\N
ODD Cubes Basic	299665.0988263299	4096.456991017462	11717.712188908772	25.5736865691217	3.910269242164814	-0.06199242535041005	15814.169179926235	74	0.013670117097592176	low	43	\N
Container (Base)	237240.81756702557	3243.1097564697425	12571.059423456492	18.871982827823967	5.298860268808887	-0.06199242535041005	15814.169179926235	99	0.013670117097592176	low	43	\N
Container (Max)	412273.34490844357	5635.824901114431	10178.344278811805	40.504951848275596	2.4688339434294937	-0.06199242535041005	15814.169179926235	140	0.013670117097592176	low	43	\N
Traditional Housing	573764.5880243147	11590.759203982017	18473.530925681785	31.058739681793632	3.219705661740652	-2.353096012872926	30064.290129663805	132	0.020201245329366388	middle	44	\N
ODD Cubes Basic	320245.22710132494	6186.971486598014	23877.31864306579	13.412110123777541	7.455948324098224	-2.353096012872926	30064.290129663805	83	0.01931948070732829	middle	44	\N
Container (Base)	249323.56529514687	4816.801809601895	25247.488320061908	9.875182914612218	10.126394707284959	-2.353096012872926	30064.290129663805	123	0.01931948070732829	middle	44	\N
Container (Max)	404345.54535064567	7811.745962495935	22252.54416716787	18.1707557712538	5.503348416481408	-2.353096012872926	30064.290129663805	86	0.01931948070732829	middle	44	\N
Traditional Housing	546305.2373621521	5604.235731831557	10069.506700190785	54.25342607416919	1.8432015678289373	2.7626376270426976	15673.742432022342	149	0.010258433103976347	low	45	\N
ODD Cubes Basic	329891.83035050635	8166.641664217183	7507.100767805159	43.943972587297026	2.275624940402116	2.7626376270426976	15673.742432022342	131	0.024755513513445356	low	45	\N
Container (Base)	258822.62774644908	6407.287058762658	9266.455373259683	27.931136267416395	3.5802338666993982	2.7626376270426976	15673.742432022342	145	0.024755513513445356	low	45	\N
Container (Max)	458438.38964151795	11348.877749852725	4324.864682169617	100	0.9433906016360242	2.7626376270426976	15673.742432022342	108	0.024755513513445356	low	45	\N
Traditional Housing	515960.249491754	11601.93560270868	3862.4054740447737	100	0.7485858606063998	-3.2942424439039444	15464.341076753453	149	0.02248610355960009	low	46	\N
ODD Cubes Basic	336224.98105041427	4380.023743376242	11084.31733337721	30.33339545755968	3.2966965448992633	-3.2942424439039444	15464.341076753453	44	0.013027062206063424	low	46	\N
Container (Base)	240376.3396335402	3131.397529271957	12332.943547481496	19.49058946942373	5.130681150350895	-3.2942424439039444	15464.341076753453	99	0.013027062206063424	low	46	\N
Container (Max)	468017.90997845004	6096.89842684106	9367.442649912393	49.96218578213843	2.0015137135123138	-3.2942424439039444	15464.341076753453	120	0.013027062206063424	low	46	\N
Traditional Housing	583273.6038102169	6416.349909470337	9341.438557927968	62.439376996726004	1.6015534556862006	4.190032119713871	15757.788467398304	124	0.011000583375547476	low	47	\N
ODD Cubes Basic	339612.3396021584	5179.53577576501	10578.252691633294	32.104767157885114	3.1148022195027636	4.190032119713871	15757.788467398304	123	0.015251317963983931	low	47	\N
Container (Base)	264766.73673731816	4038.041688267265	11719.74677913104	22.591506602239857	4.4264422803074766	4.190032119713871	15757.788467398304	108	0.015251317963983931	low	47	\N
Container (Max)	503234.2677353234	7674.985827604037	8082.802639794268	62.25987323477841	1.6061709541698828	4.190032119713871	15757.788467398304	98	0.015251317963983931	low	47	\N
Traditional Housing	495671.7046127075	12569.271288719157	17761.097608301796	27.907718066986092	3.5832381479550883	-3.5913191947114975	30330.36889702095	86	0.025358056898850304	middle	48	\N
ODD Cubes Basic	302925.2408941967	4601.679161763349	25728.6897352576	11.773830848411983	8.493412321571418	-3.5913191947114975	30330.36889702095	135	0.015190807963640729	middle	48	\N
Container (Base)	246583.4082504908	3745.8012017532283	26584.567695267724	9.27543419464311	10.781166455555637	-3.5913191947114975	30330.36889702095	134	0.015190807963640729	middle	48	\N
Container (Max)	424372.82654429576	6446.566113021814	23883.802783999137	17.7682268766933	5.628023589183828	-3.5913191947114975	30330.36889702095	143	0.015190807963640729	middle	48	\N
Traditional Housing	561341.5871853097	7106.404713049487	8769.543388584687	64.01035519318006	1.5622472285648936	-0.9260363253910997	15875.948101634174	97	0.01265967973027362	low	49	\N
ODD Cubes Basic	343493.7826875886	7529.43490356006	8346.513198074113	41.154165162866676	2.429887706487357	-0.9260363253910997	15875.948101634174	46	0.02192014901884895	low	49	\N
Container (Base)	233970.85642984198	5128.676039009849	10747.272062624324	21.77025528585249	4.59342339751916	-0.9260363253910997	15875.948101634174	99	0.02192014901884895	low	49	\N
Container (Max)	481575.91034178674	10556.215718579806	5319.732383054368	90.52634148962319	1.104650849183635	-0.9260363253910997	15875.948101634174	142	0.02192014901884895	low	49	\N
Traditional Housing	527172.2641022946	9592.15081121057	6113.653506065266	86.22867874001932	1.1597069729144454	-2.524122320339673	15705.804317275835	98	0.018195477008914246	low	50	\N
ODD Cubes Basic	302097.3612590788	4648.328773348617	11057.47554392722	27.32064475828672	3.66023572594013	-2.524122320339673	15705.804317275835	123	0.015386856588138844	low	50	\N
Container (Base)	245785.10579609039	3781.8601743849763	11923.94414289086	20.612735421326946	4.851369697227817	-2.524122320339673	15705.804317275835	119	0.015386856588138844	low	50	\N
Container (Max)	429342.85570228175	6606.236947832999	9099.567369442837	47.18277674871155	2.119417441931939	-2.524122320339673	15705.804317275835	145	0.015386856588138844	low	50	\N
Traditional Housing	521241.3762529856	15447.709030836038	402.2431483434866	100	0.07717022605439845	4.902911279763263	15849.952179179525	135	0.02963638294005743	low	51	\N
ODD Cubes Basic	301486.2850305877	5780.14593391081	10069.806245268715	29.939631179322898	3.3400545050489012	4.902911279763263	15849.952179179525	133	0.01917216875495473	low	51	\N
Container (Base)	256863.72605632708	4924.634702978366	10925.317476201159	23.51087065578264	4.25335162887319	4.902911279763263	15849.952179179525	111	0.01917216875495473	low	51	\N
Container (Max)	450379.0484105746	8634.743119823463	7215.209059356062	62.42078984898737	1.602030353059082	4.902911279763263	15849.952179179525	141	0.01917216875495473	low	51	\N
Traditional Housing	509054.57961678866	13436.202003796028	16659.665315594564	30.556110820562488	3.272667800795702	2.956489380688873	30095.867319390592	133	0.026394423195074034	middle	52	\N
ODD Cubes Basic	349349.28935974673	8172.7891452657095	21923.078174124883	15.935229833375892	6.275403683889944	2.956489380688873	30095.867319390592	42	0.023394320223876795	middle	52	\N
Container (Base)	243959.72872471236	5707.272015516035	24388.595303874557	10.003025007592589	9.99697590719778	2.956489380688873	30095.867319390592	55	0.023394320223876795	middle	52	\N
Container (Max)	505293.5435203373	11820.998964172197	18274.868355218394	27.649640681326748	3.6166835277369533	2.956489380688873	30095.867319390592	115	0.023394320223876795	middle	52	\N
Traditional Housing	507146.40202112315	12177.719909804164	18487.019133051886	27.432567596277597	3.6453022360753895	-2.8415142699588114	30664.73904285605	144	0.024012237612792822	middle	53	\N
ODD Cubes Basic	354200.0236705107	8555.3440518566	22109.394990999448	16.020339942124266	6.242064797704923	-2.8415142699588114	30664.73904285605	132	0.024153990627101374	middle	53	\N
Container (Base)	250683.8829887821	6055.01616007642	24609.722882779628	10.186375693169438	9.817034341964813	-2.8415142699588114	30664.73904285605	69	0.024153990627101374	middle	53	\N
Container (Max)	442051.911520906	10677.31772756821	19987.42131528784	22.11650540346555	4.52150998431834	-2.8415142699588114	30664.73904285605	47	0.024153990627101374	middle	53	\N
Traditional Housing	601089.3594575019	13744.631816212319	1876.6671760321387	100	0.31221101263976414	-0.5624442394412865	15621.298992244458	145	0.02286620383467974	low	54	\N
ODD Cubes Basic	316110.0357318111	3776.666327779397	11844.632664465062	26.688040455671448	3.746996718102962	-0.5624442394412865	15621.298992244458	65	0.011947315494227253	low	54	\N
Container (Base)	230558.67055602872	2754.557177062479	12866.741815181978	17.918963003048948	5.580680086397009	-0.5624442394412865	15621.298992244458	143	0.011947315494227253	low	54	\N
Container (Max)	470913.15223691205	5626.148000155456	9995.150992089002	47.11416091759215	2.1225041060353598	-0.5624442394412865	15621.298992244458	123	0.011947315494227253	low	54	\N
Traditional Housing	510310.8517780974	12057.433885459024	18117.241966515772	28.167137841469042	3.550236469279285	-0.04387024593997246	30174.675851974796	118	0.023627625874399504	middle	55	\N
ODD Cubes Basic	320848.5076366563	4333.749703891045	25840.926148083752	12.416292891284355	8.053933720442052	-0.04387024593997246	30174.675851974796	98	0.013507152443416642	middle	55	\N
Container (Base)	226644.42677438035	3061.320822892336	27113.35502908246	8.35914354867835	11.96294804816587	-0.04387024593997246	30174.675851974796	96	0.013507152443416642	middle	55	\N
Container (Max)	419275.80810954684	5663.222255972352	24511.453596002444	17.10530166917258	5.846140683985798	-0.04387024593997246	30174.675851974796	53	0.013507152443416642	middle	55	\N
Traditional Housing	553028.881108884	9778.551305170175	21178.79129989964	26.11239108397582	3.829599506165722	0.5019629189193662	30957.342605069814	138	0.017681809466375605	middle	56	\N
ODD Cubes Basic	310070.51689482003	5644.913317846874	25312.42928722294	12.249733653629823	8.163442800274122	0.5019629189193662	30957.342605069814	79	0.01820525657962412	middle	56	\N
Container (Base)	228454.75730478487	4159.077473569366	26798.265131500448	8.524983098112724	11.730228535249317	0.5019629189193662	30957.342605069814	80	0.01820525657962412	middle	56	\N
Container (Max)	480969.0149806278	8756.164324571406	22201.17828049841	21.664121106721286	4.615926928555391	0.5019629189193662	30957.342605069814	67	0.01820525657962412	middle	56	\N
Traditional Housing	591134.7519994621	17226.915086037923	-1688.6021731497385	100	0	3.4570251762184423	15538.312912888185	116	0.02914211189203371	low	57	Negative cash flow
ODD Cubes Basic	335488.564124315	6970.420190259284	8567.892722628902	39.15648514578699	2.5538553735781218	3.4570251762184423	15538.312912888185	100	0.02077692337577385	low	57	\N
Container (Base)	256826.54935872965	5336.065536890726	10202.247375997458	25.173526958673662	3.972427072462506	3.4570251762184423	15538.312912888185	67	0.02077692337577385	low	57	\N
Container (Max)	446000.6601911842	9266.521542336784	6271.7913705514	71.11216458591686	1.4062291674328269	3.4570251762184423	15538.312912888185	141	0.02077692337577385	low	57	\N
Traditional Housing	564322.6401444223	13379.127182939392	2282.6205718406745	100	0.4044885690314503	0.5406364095337857	15661.747754780066	89	0.023708294211827803	low	58	\N
ODD Cubes Basic	326400.23665386287	7925.584901762656	7736.16285301741	42.19148987104813	2.3701462144530754	0.5406364095337857	15661.747754780066	51	0.024281798882907945	low	58	\N
Container (Base)	269185.4634110731	6536.307284750052	9125.440470030015	29.498352906376223	3.390019785761817	0.5406364095337857	15661.747754780066	134	0.024281798882907945	low	58	\N
Container (Max)	424669.67272997036	10311.743584899477	5350.004169880589	79.3774470533635	1.2598036811737279	0.5406364095337857	15661.747754780066	88	0.024281798882907945	low	58	\N
Traditional Housing	593202.310502782	8331.585549253461	7246.581091098478	81.85961118015462	1.2216036523789793	-4.833606734647465	15578.16664035194	129	0.014045099625778325	low	59	\N
ODD Cubes Basic	323938.84334413044	4553.78795071073	11024.37868964121	29.383863931353496	3.403228392073273	-4.833606734647465	15578.16664035194	130	0.014057554517699803	low	59	\N
Container (Base)	231763.03289132292	3258.0214700572246	12320.145170294714	18.811712823817224	5.315837049850746	-4.833606734647465	15578.16664035194	144	0.014057554517699803	low	59	\N
Container (Max)	416430.173567603	5853.9898677417705	9724.176772610168	42.82420849655375	2.3351278052937614	-4.833606734647465	15578.16664035194	89	0.014057554517699803	low	59	\N
Traditional Housing	526400.5705382652	9751.946847158777	6242.00061709882	84.33202795531403	1.1857891055695724	-4.7856751806498385	15993.947464257597	146	0.018525714812936144	low	60	\N
ODD Cubes Basic	312233.95571919036	4233.880698865843	11760.066765391754	26.55035570359614	3.7664278820360733	-4.7856751806498385	15993.947464257597	53	0.013559962397791264	low	60	\N
Container (Base)	229935.63142906572	3117.918516090522	12876.028948167075	17.85765101606093	5.599840645898016	-4.7856751806498385	15993.947464257597	103	0.013559962397791264	low	60	\N
Container (Max)	435883.99195693136	5910.570540735139	10083.376923522457	43.22797761731024	2.3133166414881257	-4.7856751806498385	15993.947464257597	119	0.013559962397791264	low	60	\N
Traditional Housing	499843.76748577395	11707.637723428263	4144.711554454272	100	0.829201407332189	1.8243825146262527	15852.349277882535	129	0.02342259418841603	low	61	\N
ODD Cubes Basic	310517.4180697191	3900.534350821708	11951.814927060826	25.980775301888073	3.848999840768139	1.8243825146262527	15852.349277882535	80	0.012561402755016913	low	61	\N
Container (Base)	235762.52811067304	2961.5080701391607	12890.841207743375	18.289149971768584	5.467722674610989	1.8243825146262527	15852.349277882535	75	0.012561402755016913	low	61	\N
Container (Max)	461060.69148224447	5791.5690402150685	10060.780237667466	45.82752834179178	2.182094553609307	1.8243825146262527	15852.349277882535	138	0.012561402755016913	low	61	\N
Traditional Housing	577371.2692807734	7061.035417346646	8858.300869195124	65.1785571303624	1.5342469119098767	-1.282400116397465	15919.33628654177	125	0.012229627265905558	low	62	\N
ODD Cubes Basic	313974.5641246735	4502.540270678991	11416.79601586278	27.501110091520374	3.63621685332745	-1.282400116397465	15919.33628654177	149	0.014340461888151919	low	62	\N
Container (Base)	247518.92642843028	3549.535731043183	12369.800555498587	20.00993672597283	4.997517052125424	-1.282400116397465	15919.33628654177	109	0.014340461888151919	low	62	\N
Container (Max)	443504.3336299117	6360.056993649962	9559.279292891806	46.395164325797815	2.1553970430576848	-1.282400116397465	15919.33628654177	70	0.014340461888151919	low	62	\N
Traditional Housing	527854.0351348051	13888.331978129123	2040.4997163233475	100	0.3865651450030571	-0.056996428234565855	15928.83169445247	109	0.02631093267020735	low	63	\N
ODD Cubes Basic	353865.6077719367	3058.9621997059594	12869.869494746512	27.495664032676075	3.636937077830132	-0.056996428234565855	15928.83169445247	107	0.008644417916073477	low	63	\N
Container (Base)	263563.3695098809	2278.3519134119083	13650.479781040562	19.307993106289906	5.179202180646279	-0.056996428234565855	15928.83169445247	66	0.008644417916073477	low	63	\N
Container (Max)	447969.1574157708	3872.432610213229	12056.399084239241	37.15613213246894	2.691345795721693	-0.056996428234565855	15928.83169445247	135	0.008644417916073477	low	63	\N
Traditional Housing	516756.8734605064	7511.575308724581	8193.165732209482	63.07169784555922	1.5854971947142666	-4.71010111472284	15704.741040934063	92	0.014535994961078462	low	64	\N
ODD Cubes Basic	343896.124318796	6679.200755518695	9025.540285415369	38.10255269421462	2.6244960751719844	-4.71010111472284	15704.741040934063	105	0.01942214605863657	low	64	\N
Container (Base)	260557.48980257072	5060.585623617237	10644.155417316826	24.478925719054555	4.085146592938895	-4.71010111472284	15704.741040934063	51	0.01942214605863657	low	64	\N
Container (Max)	429401.1773032816	8339.892383334834	7364.848657599228	58.30414137026633	1.715144030077382	-4.71010111472284	15704.741040934063	136	0.01942214605863657	low	64	\N
Traditional Housing	547073.7606324853	12147.753885741167	18431.374009709874	29.681659128846285	3.369083903494277	2.748113121259217	30579.12789545104	127	0.02220496532624203	middle	65	\N
ODD Cubes Basic	295475.81645958335	5294.558826408113	25284.56906904293	11.686013538642749	8.557238075184904	2.748113121259217	30579.12789545104	89	0.017918755212687022	middle	65	\N
Container (Base)	243902.9840442095	4370.437866732099	26208.690028718942	9.306187519366501	10.745538899994923	2.748113121259217	30579.12789545104	129	0.017918755212687022	middle	65	\N
Container (Max)	484004.04844155407	8672.75006597372	21906.377829477322	22.094207093893726	4.526073263232761	2.748113121259217	30579.12789545104	73	0.017918755212687022	middle	65	\N
Traditional Housing	568544.304340776	9963.623101243811	20709.336138883235	27.453526299826393	3.6425193218487335	-0.59156356795667	30672.959240127046	145	0.017524796265080127	middle	66	\N
ODD Cubes Basic	334696.55129415507	5527.7245408682165	25145.23469925883	13.310535984140982	7.512845472124215	-0.59156356795667	30672.959240127046	140	0.016515630410574682	middle	66	\N
Container (Base)	231543.45862911758	3824.086186704695	26848.87305342235	8.623954464249046	11.59560853603229	-0.59156356795667	30672.959240127046	147	0.016515630410574682	middle	66	\N
Container (Max)	460114.0907655171	7599.074269780894	23073.884970346153	19.9409025119455	5.01481815780883	-0.59156356795667	30672.959240127046	69	0.016515630410574682	middle	66	\N
Traditional Housing	561530.0256869263	9228.89242576699	6590.4199330249485	85.20398265868752	1.1736540579397887	4.475931967906012	15819.312358791938	123	0.016435260811703125	low	67	\N
ODD Cubes Basic	316139.5114543928	4192.329112186042	11626.983246605896	27.19015799276042	3.6778013583674554	4.475931967906012	15819.312358791938	42	0.013261009650136185	low	67	\N
Container (Base)	255261.00700015645	3385.018677132555	12434.293681659383	20.528790258240974	4.871207642635274	4.475931967906012	15819.312358791938	69	0.013261009650136185	low	67	\N
Container (Max)	464380.13842303306	6158.149496959419	9661.16286183252	48.06669187387551	2.0804427369870755	4.475931967906012	15819.312358791938	56	0.013261009650136185	low	67	\N
Traditional Housing	535845.943494865	14985.645928627448	594.2931837688557	100	0.11090747088478253	-2.7471717571184397	15579.939112396303	126	0.02796633269422344	low	68	\N
ODD Cubes Basic	337075.97929309536	5291.052492511204	10288.8866198851	32.76117151895096	3.0523938969079354	-2.7471717571184397	15579.939112396303	71	0.015696913507771824	low	68	\N
Container (Base)	222132.0330731652	3486.7873104549844	12093.15180194132	18.368415175066787	5.444127816521678	-2.7471717571184397	15579.939112396303	57	0.015696913507771824	low	68	\N
Container (Max)	439927.59123641165	6905.505349320351	8674.433763075951	50.715424574342876	1.9717867066933787	-2.7471717571184397	15579.939112396303	78	0.015696913507771824	low	68	\N
Traditional Housing	562481.0077121974	8066.152093121789	22471.56581239969	25.030788348617136	3.9950799234625247	-4.305325993107787	30537.71790552148	119	0.014340310130522609	middle	69	\N
ODD Cubes Basic	305017.66903676605	7291.6362276459495	23246.081677875532	13.12125085265732	7.621224616687209	-4.305325993107787	30537.71790552148	73	0.02390561914223741	middle	69	\N
Container (Base)	227816.67172344337	5446.098588472763	25091.619317048717	9.079392957657834	11.013952195521727	-4.305325993107787	30537.71790552148	132	0.02390561914223741	middle	69	\N
Container (Max)	424688.4585929536	10152.440545227011	20385.27736029447	20.833096900616265	4.800054474716234	-4.305325993107787	30537.71790552148	53	0.02390561914223741	middle	69	\N
Traditional Housing	592814.8258960196	11910.433664686287	18571.883062650333	31.920017151530615	3.1328303968409625	2.0568909299378966	30482.31672733662	143	0.020091322187639402	middle	70	\N
ODD Cubes Basic	345911.4680795026	7225.430440718156	23256.886286618465	14.87350730516892	6.723363760022323	2.0568909299378966	30482.31672733662	109	0.020888091628860073	middle	70	\N
Container (Base)	276382.8784358094	5773.110889415281	24709.205837921338	11.18542134655106	8.940208589534649	2.0568909299378966	30482.31672733662	100	0.020888091628860073	middle	70	\N
Container (Max)	473130.1791683447	9882.786534847368	20599.530192489252	22.968008238403982	4.353882102532234	2.0568909299378966	30482.31672733662	47	0.020888091628860073	middle	70	\N
Traditional Housing	534253.3007384156	11884.301935782618	18707.993726840163	28.557487699599125	3.5017085904725347	1.846748056819422	30592.295662622782	113	0.02224469538954048	middle	71	\N
ODD Cubes Basic	356186.17962501914	6344.209114579514	24248.08654804327	14.689248940088513	6.807699999357314	1.846748056819422	30592.295662622782	97	0.017811497125628187	middle	71	\N
Container (Base)	275680.3171678431	4910.279176827305	25682.016485795477	10.73437194156151	9.315868738702674	1.846748056819422	30592.295662622782	79	0.017811497125628187	middle	71	\N
Container (Max)	433764.773781195	7726.000021402516	22866.295641220266	18.96961276925251	5.271588894112173	1.846748056819422	30592.295662622782	84	0.017811497125628187	middle	71	\N
Traditional Housing	559663.8759573835	12386.214257024354	3551.6956282556694	100	0.6346122701201674	2.1420768096045295	15937.909885280023	143	0.022131523561058856	low	72	\N
ODD Cubes Basic	349199.620761552	8090.569497559405	7847.340387720618	44.499104602111245	2.2472362285522376	2.1420768096045295	15937.909885280023	149	0.023168895429826315	low	72	\N
Container (Base)	267324.2704727812	6193.608068438474	9744.30181684155	27.433907066666563	3.6451242528813736	2.1420768096045295	15937.909885280023	98	0.023168895429826315	low	72	\N
Container (Max)	421665.08737258485	9769.514315743994	6168.395569536029	68.3589569798458	1.4628660883384002	2.1420768096045295	15937.909885280023	124	0.023168895429826315	low	72	\N
Traditional Housing	581480.0544978451	10201.411749526873	20427.985874273374	28.464874514630946	3.513101733457493	-0.18782446631487026	30629.397623800247	115	0.017543872176899712	middle	73	\N
ODD Cubes Basic	336649.62741205597	5203.858065147162	25425.539558653087	13.240608980409379	7.5525227085822575	-0.18782446631487026	30629.397623800247	145	0.015457786497941639	middle	73	\N
Container (Base)	263987.57625197043	4080.6635918120473	26548.7340319882	9.94350901756353	10.056811918545746	-0.18782446631487026	30629.397623800247	62	0.015457786497941639	middle	73	\N
Container (Max)	446593.53942177363	6903.347583741859	23726.050040058388	18.822919898919448	5.312672026285391	-0.18782446631487026	30629.397623800247	126	0.015457786497941639	middle	73	\N
Traditional Housing	548588.7287314398	10530.296201443603	5095.378965199883	100	0.9288158320318521	-0.574880975879072	15625.675166643487	134	0.019195247094839024	low	74	\N
ODD Cubes Basic	326287.61307428667	7872.089201310148	7753.585965333338	42.08215586093126	2.376304111663614	-0.574880975879072	15625.675166643487	137	0.024126227554700005	low	74	\N
Container (Base)	239474.47628608232	5777.6157084206325	9848.059458222855	24.31692023204915	4.1123628751391905	-0.574880975879072	15625.675166643487	56	0.024126227554700005	low	74	\N
Container (Max)	410265.4781476177	9898.158283627226	5727.51688301626	71.63060127577681	1.3960513833326822	-0.574880975879072	15625.675166643487	100	0.024126227554700005	low	74	\N
Traditional Housing	596040.9178604357	11544.944605300747	4047.0437497270595	100	0.6789875708960444	1.275185269868233	15591.988355027806	134	0.019369382636921617	low	75	\N
ODD Cubes Basic	299700.4107600932	3763.494430900685	11828.49392412712	25.337157264694582	3.9467726767967957	1.275185269868233	15591.988355027806	129	0.012557521764337254	low	75	\N
Container (Base)	233223.16834208433	2928.7050124034154	12663.28334262439	18.417274732932746	5.429684980546311	1.275185269868233	15591.988355027806	128	0.012557521764337254	low	75	\N
Container (Max)	424471.6659539598	5330.312183561343	10261.676171466464	41.36474966285161	2.4175173502816305	1.275185269868233	15591.988355027806	46	0.012557521764337254	low	75	\N
Traditional Housing	563847.1959258391	6347.751026134016	24227.963045210883	23.272579493111543	4.296902284922865	-1.5942041660661346	30575.714071344897	107	0.011257927807392898	middle	76	\N
ODD Cubes Basic	351088.31490151776	3580.0105069504943	26995.703564394404	13.005340426266224	7.689148974373257	-1.5942041660661346	30575.714071344897	106	0.010196894499193764	middle	76	\N
Container (Base)	249597.60660236294	2545.120461775564	28030.593609569332	8.90447095337835	11.230313459786183	-1.5942041660661346	30575.714071344897	43	0.010196894499193764	middle	76	\N
Container (Max)	441472.7693324887	4501.651253150291	26074.062818194605	16.931491360235082	5.906154270311814	-1.5942041660661346	30575.714071344897	40	0.010196894499193764	middle	76	\N
Traditional Housing	511713.03845523746	11963.983177871862	18222.48566624187	28.08140710480641	3.5610751137496957	-0.5739017559193282	30186.468844113733	81	0.02338025861914484	middle	77	\N
ODD Cubes Basic	307421.4622807403	5777.452653494745	24409.01619061899	12.594586356122385	7.9399193568106945	-0.5739017559193282	30186.468844113733	148	0.018793263849024043	middle	77	\N
Container (Base)	248015.10234473165	4661.013256907244	25525.45558720649	9.716382984718921	10.29189567324294	-0.5739017559193282	30186.468844113733	91	0.018793263849024043	middle	77	\N
Container (Max)	445352.9146924412	8369.634831746944	21816.834012366788	20.4132696082298	4.898774273753973	-0.5739017559193282	30186.468844113733	84	0.018793263849024043	middle	77	\N
Traditional Housing	515797.47020465817	8130.045387203069	7866.773026959924	65.56658854106861	1.5251670435371745	3.4465847643168264	15996.818414162994	97	0.015762088526679336	low	78	\N
ODD Cubes Basic	337077.96108070435	2814.2335164214383	13182.584897741555	25.569944263241776	3.910841532171644	3.4465847643168264	15996.818414162994	119	0.008348909870579301	low	78	\N
Container (Base)	268378.20792798226	2240.665469218315	13756.152944944679	19.509684793567956	5.125659438279006	3.4465847643168264	15996.818414162994	43	0.008348909870579301	low	78	\N
Container (Max)	438962.8415164698	3664.861200354392	12331.9572138086	35.595553398850996	2.8093396632858063	3.4465847643168264	15996.818414162994	97	0.008348909870579301	low	78	\N
Traditional Housing	523974.8510470595	9722.284045387216	21123.367087873594	24.805460647789463	4.031370407503862	-2.2859441913321166	30845.65113326081	81	0.018554867711607085	middle	79	\N
ODD Cubes Basic	346952.94031036313	4310.072200496379	26535.57893276443	13.075009261696112	7.6481781388067525	-2.2859441913321166	30845.65113326081	58	0.01242264209273122	middle	79	\N
Container (Base)	266828.1503882888	3314.7106125391724	27530.940520721637	9.69193733819068	10.31785457443623	-2.2859441913321166	30845.65113326081	100	0.01242264209273122	middle	79	\N
Container (Max)	442044.55405429157	5491.361284057443	25354.289849203367	17.434704607519528	5.735686508670203	-2.2859441913321166	30845.65113326081	101	0.01242264209273122	middle	79	\N
Traditional Housing	559958.355170625	10199.704023679391	5699.483255476904	98.24721471591911	1.0178405595430775	2.5029959802902804	15899.187279156295	144	0.018215111765894514	low	80	\N
ODD Cubes Basic	316607.0546518056	6749.483208204956	9149.704070951339	34.602983025098695	2.889924256745919	2.5029959802902804	15899.187279156295	135	0.021318170612552596	low	80	\N
Container (Base)	234056.20336729122	4989.650076310222	10909.537202846073	21.454274275377216	4.661075863785738	2.5029959802902804	15899.187279156295	109	0.021318170612552596	low	80	\N
Container (Max)	496539.7710640095	10585.319555460363	5313.867723695932	93.44225277754059	1.0701796781170456	2.5029959802902804	15899.187279156295	91	0.021318170612552596	low	80	\N
Traditional Housing	508323.3675562833	5601.39661890826	24601.004104220072	20.66270813186382	4.839636671138508	-0.2906075273092066	30202.400723128332	103	0.011019356922024747	middle	81	\N
ODD Cubes Basic	351303.81495025364	6674.949787565112	23527.450935563218	14.93165646853973	6.697180598193851	-0.2906075273092066	30202.400723128332	64	0.019000504701351787	middle	81	\N
Container (Base)	230721.93249008697	4383.833162982867	25818.567560145464	8.936279363779974	11.19033950587024	-0.2906075273092066	30202.400723128332	61	0.019000504701351787	middle	81	\N
Container (Max)	477184.9195371857	9066.754307080471	21135.64641604786	22.57725693096706	4.429236036324659	-0.2906075273092066	30202.400723128332	62	0.019000504701351787	middle	81	\N
Traditional Housing	579900.955453463	16101.714899636987	-365.35710274903977	100	0	0.47384927807721766	15736.357796887947	129	0.027766318969152222	low	82	Negative cash flow
ODD Cubes Basic	350910.7251276755	6796.60389191305	8939.753904974898	39.252839491744474	2.5475863987121663	0.47384927807721766	15736.357796887947	144	0.019368470112847563	low	82	\N
Container (Base)	261868.38581622188	5071.990004181128	10664.36779270682	24.555453347671413	4.072415140707755	0.47384927807721766	15736.357796887947	89	0.019368470112847563	low	82	\N
Container (Max)	425918.8992722141	8249.39747105081	7486.960325837137	56.88809353007904	1.7578370761735223	0.47384927807721766	15736.357796887947	55	0.019368470112847563	low	82	\N
Traditional Housing	512922.43382809625	11974.572101824802	3529.092410739757	100	0.6880362756608374	-4.185457925744458	15503.66451256456	82	0.023345775719839208	low	83	\N
ODD Cubes Basic	315470.60711934726	3785.9742227975344	11717.690289767024	26.922593046758156	3.714352470667433	-4.185457925744458	15503.66451256456	103	0.012001036348103402	low	83	\N
Container (Base)	231390.06722364455	2776.920607341048	12726.743905223511	18.181403581844197	5.5001254193520674	-4.185457925744458	15503.66451256456	109	0.012001036348103402	low	83	\N
Container (Max)	467928.7808166224	5615.630306903996	9888.034205660562	47.32273079605137	2.113149396026487	-4.185457925744458	15503.66451256456	126	0.012001036348103402	low	83	\N
Traditional Housing	568588.2169639246	7901.2830971882	22180.905555236048	25.634130019984827	3.9010491060955923	3.785018570804546	30082.188652424247	105	0.013896318744307563	middle	84	\N
ODD Cubes Basic	315630.84891849296	4880.334879109658	25201.85377331459	12.524112383062235	7.984597785567721	3.785018570804546	30082.188652424247	63	0.015462160608926832	middle	84	\N
Container (Base)	238206.96822061247	3683.19440079264	26398.994251631608	9.023334978221374	11.08237699712567	3.785018570804546	30082.188652424247	63	0.015462160608926832	middle	84	\N
Container (Max)	456765.4557354266	7062.580837190826	23019.607815233423	19.842451678657973	5.039699812274579	3.785018570804546	30082.188652424247	138	0.015462160608926832	middle	84	\N
Traditional Housing	546219.4494134961	9227.250266342056	21607.354018963295	25.279330774796243	3.9558009225347477	-4.284441004186252	30834.60428530535	141	0.016892936119813802	middle	85	\N
ODD Cubes Basic	299859.72819063504	4695.0165594600385	26139.58772584531	11.471478867057689	8.71727186694011	-4.284441004186252	30834.60428530535	125	0.015657376159812945	middle	85	\N
Container (Base)	260109.34940453782	4072.629926311066	26761.974358994285	9.71936322467625	10.288739878155031	-4.284441004186252	30834.60428530535	92	0.015657376159812945	middle	85	\N
Container (Max)	459443.03393090994	7193.672406261959	23640.931879043394	19.434218425974368	5.145563243559477	-4.284441004186252	30834.60428530535	129	0.015657376159812945	middle	85	\N
Traditional Housing	543434.6849992668	15386.10840535528	516.9030274323504	100	0.09511778355351902	0.1701423694389117	15903.01143278763	85	0.028312709567619963	low	86	\N
ODD Cubes Basic	320329.0334135812	6695.034239221363	9207.977193566268	34.78820881934843	2.874537189289902	0.1701423694389117	15903.01143278763	47	0.020900491497370183	low	86	\N
Container (Base)	259282.90485106173	5419.140148253058	10483.871284534573	24.731599407706053	4.043410147135138	0.1701423694389117	15903.01143278763	125	0.020900491497370183	low	86	\N
Container (Max)	422419.80875094945	8828.781621119959	7074.229811667672	59.71248036842736	1.674691779390133	0.1701423694389117	15903.01143278763	119	0.020900491497370183	low	86	\N
Traditional Housing	518920.2290234292	12024.43137592658	18254.470432632334	28.427021804795235	3.5177796916851634	3.4118425940555763	30278.901808558912	142	0.023172022795402872	middle	87	\N
ODD Cubes Basic	347507.6068254396	2815.1468292712143	27463.754979287696	12.65331732996886	7.90306584370204	3.4118425940555763	30278.901808558912	71	0.008100964623445846	middle	87	\N
Container (Base)	260577.50214203517	2110.929126518511	28167.972682040403	9.250843327754879	10.809825272899673	3.4118425940555763	30278.901808558912	71	0.008100964623445846	middle	87	\N
Container (Max)	455544.7738918919	3690.352097693853	26588.54971086506	17.133118535823694	5.836649048502738	3.4118425940555763	30278.901808558912	138	0.008100964623445846	middle	87	\N
Traditional Housing	518912.6910594944	5508.24407284979	24731.52324520771	20.98183301993117	4.766027825357655	2.437176488457	30239.7673180575	105	0.010614972745421366	middle	88	\N
ODD Cubes Basic	315909.63299726974	7241.017289780252	22998.75002827725	13.735947936685903	7.280167372571389	2.437176488457	30239.7673180575	98	0.022921166477512363	middle	88	\N
Container (Base)	239315.84270309831	5485.398271303879	24754.36904675362	9.667620380511499	10.34380706565447	2.437176488457	30239.7673180575	90	0.022921166477512363	middle	88	\N
Container (Max)	485163.2963014129	11120.508683303344	19119.25863475416	25.375633311403828	3.9407883449773813	2.437176488457	30239.7673180575	95	0.022921166477512363	middle	88	\N
Traditional Housing	562806.26724201	11458.951106083161	18802.59389217272	29.932373717665573	3.340864341172572	-0.06741187657896042	30261.544998255882	109	0.020360382911577893	middle	89	\N
ODD Cubes Basic	348449.4579196641	3551.875431626656	26709.669566629225	13.045816873564513	7.665292328503839	-0.06741187657896042	30261.544998255882	87	0.010193373388589257	middle	89	\N
Container (Base)	234644.23750374827	2391.8163263565248	27869.728671899356	8.419322637336498	11.877440063472328	-0.06741187657896042	30261.544998255882	140	0.010193373388589257	middle	89	\N
Container (Max)	478592.1461435785	4878.468446487774	25383.076551768107	18.854772988904738	5.303696844233866	-0.06741187657896042	30261.544998255882	80	0.010193373388589257	middle	89	\N
Traditional Housing	576408.0269585076	10023.438472795404	5579.48125218637	100	0.9679742458874546	-4.64331924239422	15602.919724981773	122	0.01738948453873099	low	90	\N
ODD Cubes Basic	305638.5791186143	6141.896085789908	9461.023639191866	32.30502224437113	3.0954939217670447	-4.64331924239422	15602.919724981773	139	0.02009529066488141	low	90	\N
Container (Base)	223036.08724738398	4481.975001994031	11120.944722987742	20.055498233558644	4.986163835744111	-4.64331924239422	15602.919724981773	97	0.02009529066488141	low	90	\N
Container (Max)	432215.55457546114	8685.497199076804	6917.422525904969	62.48216773760205	1.6004566362030932	-4.64331924239422	15602.919724981773	45	0.02009529066488141	low	90	\N
Traditional Housing	528115.664460052	6068.198500490245	9878.82497730555	53.459360366570195	1.870579807059067	-3.016713128993649	15947.023477795796	113	0.01149028311192852	low	91	\N
ODD Cubes Basic	355556.06197735877	7731.868957912512	8215.154519883283	43.28050812882462	2.310508917833163	-3.016713128993649	15947.023477795796	59	0.021745850471267918	low	91	\N
Container (Base)	236519.2110367269	5143.311396786923	10803.712081008873	21.89240228388614	4.567794740077694	-3.016713128993649	15947.023477795796	74	0.021745850471267918	low	91	\N
Container (Max)	439514.40190847596	9557.614463870468	6389.409013925328	68.78795847168041	1.453742809378031	-3.016713128993649	15947.023477795796	116	0.021745850471267918	low	91	\N
Traditional Housing	547077.102198755	15123.971446761407	484.76995084637747	100	0.08861090126017719	-4.160626582831549	15608.741397607784	148	0.027645045617842028	low	92	\N
ODD Cubes Basic	354763.2574245518	3062.8067403440873	12545.934657263697	28.27714850397018	3.53642447313808	-4.160626582831549	15608.741397607784	99	0.008633382054779053	low	92	\N
Container (Base)	236115.52697437757	2038.4755534352907	13570.265844172493	17.39947689202958	5.747299221725935	-4.160626582831549	15608.741397607784	109	0.008633382054779053	low	92	\N
Container (Max)	417064.9943011439	3600.681437476024	12008.05996013176	34.732087921433695	2.879181931884046	-4.160626582831549	15608.741397607784	146	0.008633382054779053	low	92	\N
Traditional Housing	505301.53944901103	13156.087139570895	17074.365966783094	29.594161237497048	3.3790449135384106	-4.070300298261955	30230.453106353987	93	0.02603611133644379	middle	93	\N
ODD Cubes Basic	301646.22998707526	3364.5494551613547	26865.90365119263	11.227846042457038	8.906427788719178	-4.070300298261955	30230.453106353987	62	0.011153958248725723	middle	93	\N
Container (Base)	243156.4020271601	2712.1563561213106	27518.296750232676	8.836171956213247	11.317117921147284	-4.070300298261955	30230.453106353987	85	0.011153958248725723	middle	93	\N
Container (Max)	426566.37076445424	4757.903489817179	25472.54961653681	16.74611992854955	5.971532535695951	-4.070300298261955	30230.453106353987	112	0.011153958248725723	middle	93	\N
Traditional Housing	591481.4878115852	6523.405871995541	24024.783413308112	24.619638713743587	4.061798028911624	-2.4604949809333188	30548.18928530365	149	0.011028926528421721	middle	94	\N
ODD Cubes Basic	320792.51187864	3432.5276652687717	27115.66162003488	11.830524970175054	8.452710277194091	-2.4604949809333188	30548.18928530365	57	0.010700148969086104	middle	94	\N
Container (Base)	264128.20815709454	2826.2111742186953	27721.978111084958	9.527754733039046	10.495652207884158	-2.4604949809333188	30548.18928530365	55	0.010700148969086104	middle	94	\N
Container (Max)	399150.4959867623	4270.969768142962	26277.21951716069	15.189982171671234	6.583286199406895	-2.4604949809333188	30548.18928530365	75	0.010700148969086104	middle	94	\N
Traditional Housing	496415.6041007248	6891.25725475193	8576.625245204692	57.8800623681532	1.7277106469571128	-1.036678377186103	15467.882499956622	114	0.013882031905978656	low	95	\N
ODD Cubes Basic	312575.4271857071	6314.318921578196	9153.563578378427	34.147949540006415	2.9284335178849865	-1.036678377186103	15467.882499956622	100	0.02020094470774485	low	95	\N
Container (Base)	263284.08012605953	5318.5871450559935	10149.295354900629	25.941119153551064	3.854883800813623	-1.036678377186103	15467.882499956622	142	0.02020094470774485	low	95	\N
Container (Max)	423555.6334549931	8556.223932078161	6911.658567878461	61.281330565639294	1.6318183544152747	-1.036678377186103	15467.882499956622	141	0.02020094470774485	low	95	\N
Traditional Housing	538683.1974340644	12515.935900841429	17995.37185054169	29.934541053557005	3.3406224542105476	-2.506531422239876	30511.30775138312	101	0.023234316497078782	middle	96	\N
ODD Cubes Basic	346727.4344709306	8338.35340022781	22172.95435115531	15.637403522317024	6.394923547076363	-2.506531422239876	30511.30775138312	57	0.024048726957390194	middle	96	\N
Container (Base)	256519.27313398512	6168.961958907406	24342.345792475713	10.537984930494083	9.489480262078095	-2.506531422239876	30511.30775138312	128	0.024048726957390194	middle	96	\N
Container (Max)	446057.4653217012	10727.114190827137	19784.193560555985	22.546153521820166	4.435346361995628	-2.506531422239876	30511.30775138312	111	0.024048726957390194	middle	96	\N
Traditional Housing	595661.2665290427	13721.720995273912	1954.7010831513435	100	0.32815648641072714	-0.813530437747195	15676.422078425256	130	0.023036114258748568	low	97	\N
ODD Cubes Basic	326600.90691269276	5793.576522292766	9882.84555613249	33.04725395713898	3.0259700285444646	-0.813530437747195	15676.422078425256	86	0.017739009291365838	low	97	\N
Container (Base)	244826.89452649167	4342.98655678168	11333.435521643576	21.602178267917374	4.629162798295934	-0.813530437747195	15676.422078425256	72	0.017739009291365838	low	97	\N
Container (Max)	447149.3598373455	7931.986648782958	7744.435429642298	57.73814810642673	1.7319571770066728	-0.813530437747195	15676.422078425256	61	0.017739009291365838	low	97	\N
Traditional Housing	549616.8680094382	6078.087501885257	24216.97953495359	22.695516887898773	4.406156532760877	3.140246111040268	30295.067036838846	121	0.01105877176568184	middle	98	\N
ODD Cubes Basic	304117.8693779794	5928.33794551026	24366.729091328583	12.480865537517147	8.012264830464096	3.140246111040268	30295.067036838846	129	0.019493553462135098	middle	98	\N
Container (Base)	270265.4548864726	5268.434093797715	25026.63294304113	10.799113708247447	9.260019173946516	3.140246111040268	30295.067036838846	44	0.019493553462135098	middle	98	\N
Container (Max)	506137.21674933995	9866.412893879518	20428.654142959327	24.77584735672754	4.036188896394955	3.140246111040268	30295.067036838846	93	0.019493553462135098	middle	98	\N
Traditional Housing	552957.2537236629	9985.84811348426	5700.798917019452	96.99644940515907	1.0309655725880744	-0.6335869688775331	15686.647030503713	86	0.018058987464652426	low	99	\N
ODD Cubes Basic	299827.5879352941	7324.102064317399	8362.544966186313	35.85362938526937	2.789117913989635	-0.6335869688775331	15686.647030503713	110	0.024427712322116324	low	99	\N
Container (Base)	267278.11231172644	6528.992837549151	9157.654192954562	29.186307615476107	3.426264168715017	-0.6335869688775331	15686.647030503713	50	0.024427712322116324	low	99	\N
Container (Max)	430986.8142663052	10528.021913522683	5158.625116981029	83.54683747954351	1.196933397083822	-0.6335869688775331	15686.647030503713	117	0.024427712322116324	low	99	\N
Traditional Housing	520986.9003497177	10544.275219436255	19795.533259942324	26.318406961229577	3.7996220723888396	-4.943764311118324	30339.80847937858	134	0.02023904096697691	middle	100	\N
ODD Cubes Basic	318681.2270213248	7259.870580781561	23079.937898597018	13.807715966198366	7.24232742365229	-4.943764311118324	30339.80847937858	109	0.022780979754090633	middle	100	\N
Container (Base)	248288.50523144848	5656.255410851054	24683.553068527523	10.058864076097127	9.94148039415603	-4.943764311118324	30339.80847937858	125	0.022780979754090633	middle	100	\N
Container (Max)	428737.7286882704	9767.06551706229	20572.74296231629	20.84008581031718	4.7984447333942155	-4.943764311118324	30339.80847937858	68	0.022780979754090633	middle	100	\N
Traditional Housing	548198.4690735078	14924.191923912033	1045.684590434088	100	0.19074927228479224	-1.2742541086769976	15969.87651434612	146	0.02722406713235613	low	101	\N
ODD Cubes Basic	341942.2925473741	5773.350890768857	10196.525623577263	33.535177095687025	2.9819433997520486	-1.2742541086769976	15969.87651434612	108	0.016883991879913463	low	101	\N
Container (Base)	225979.22501529517	3815.431400187381	12154.44511415874	18.592311116864682	5.378567482624157	-1.2742541086769976	15969.87651434612	92	0.016883991879913463	low	101	\N
Container (Max)	438672.47932914493	7406.542578934789	8563.33393541133	51.226833221478685	1.9521019300109972	-1.2742541086769976	15969.87651434612	131	0.016883991879913463	low	101	\N
Traditional Housing	583387.3212145043	9596.621918780762	21120.333700453415	27.62206930480365	3.620293573827555	-2.835843056931291	30716.955619234177	104	0.016449829418305445	middle	102	\N
ODD Cubes Basic	317880.2823637766	3718.4711445235052	26998.484474710673	11.774004672800551	8.493286929893337	-2.835843056931291	30716.955619234177	129	0.011697709329036497	middle	102	\N
Container (Base)	255171.81013563529	2984.9256639307505	27732.029955303427	9.2013390489951	10.867983395408217	-2.835843056931291	30716.955619234177	118	0.011697709329036497	middle	102	\N
Container (Max)	405080.5364561471	4738.51437031418	25978.441248919997	15.592950037869864	6.413154647269099	-2.835843056931291	30716.955619234177	67	0.011697709329036497	middle	102	\N
Traditional Housing	552489.7354795858	13162.501325770269	2549.0762709646024	100	0.46137984242402075	-0.7572814727470076	15711.57759673487	82	0.023823974420709604	low	103	\N
ODD Cubes Basic	320309.02412915265	7098.733894716581	8612.84370201829	37.1896942764784	2.6889169686788104	-0.7572814727470076	15711.57759673487	111	0.022162141432063687	low	103	\N
Container (Base)	233880.63308652872	5183.2956686842435	10528.281928050626	22.214510846579607	4.501562095633409	-0.7572814727470076	15711.57759673487	54	0.022162141432063687	low	103	\N
Container (Max)	404073.77840440074	8955.14022598669	6756.437370748181	59.805746169398034	1.6720801328479862	-0.7572814727470076	15711.57759673487	82	0.022162141432063687	low	103	\N
Traditional Housing	587139.1638267789	6164.749597116066	9310.900865109974	63.05932931011225	1.585808176110175	3.4598365628669097	15475.65046222604	132	0.010499639569154725	low	104	\N
ODD Cubes Basic	342724.8818852338	7739.040144385426	7736.610317840614	44.299101002271065	2.2573821530796607	3.4598365628669097	15475.65046222604	117	0.022580911259827793	low	104	\N
Container (Base)	240117.16663245636	5422.06443168878	10053.586030537259	23.883733217492008	4.186950134192665	3.4598365628669097	15475.65046222604	57	0.022580911259827793	low	104	\N
Container (Max)	444860.4552507566	10045.354463023927	5430.295999202113	81.92195329980558	1.2206740192587342	3.4598365628669097	15475.65046222604	140	0.022580911259827793	low	104	\N
Traditional Housing	533767.4829375051	6814.992444374511	9121.843566197844	58.51530768576746	1.7089545275401974	0.4135405304796036	15936.836010572355	106	0.012767717521624351	low	105	\N
ODD Cubes Basic	344061.6415383384	7606.168360068599	8330.667650503756	41.30060830328923	2.421271843398875	0.4135405304796036	15936.836010572355	85	0.022106993171515904	low	105	\N
Container (Base)	261498.86572122393	5780.953638858252	10155.882371714102	25.748512650121246	3.883719473774308	0.4135405304796036	15936.836010572355	92	0.022106993171515904	low	105	\N
Container (Max)	460332.558012684	10176.568716612854	5760.267293959501	79.91513839911757	1.2513273705486594	0.4135405304796036	15936.836010572355	110	0.022106993171515904	low	105	\N
Traditional Housing	562187.9175474725	9221.676639541485	21144.413864501144	26.588011431771893	3.761093613812086	2.1629371979858583	30366.09050404263	128	0.01640319251215993	middle	106	\N
ODD Cubes Basic	349084.23195581953	3375.5125306603577	26990.57797338227	12.933558973804914	7.731823870176475	2.1629371979858583	30366.09050404263	117	0.009669621889674943	middle	106	\N
Container (Base)	265065.28825088596	2563.081113463765	27803.009390578864	9.533690563033229	10.489117445005904	2.1629371979858583	30366.09050404263	78	0.009669621889674943	middle	106	\N
Container (Max)	416644.957466952	4028.7992009451245	26337.291303097503	15.819582684949488	6.321279264537015	2.1629371979858583	30366.09050404263	49	0.009669621889674943	middle	106	\N
Traditional Housing	535598.9772138351	5743.4378107319535	10076.209288863467	53.154808704280825	1.881297335793939	-4.619987742469615	15819.64709959542	106	0.01072339204344469	low	107	\N
ODD Cubes Basic	308848.22500393266	2760.4900138689954	13059.157085726425	23.649935671690617	4.228341310868839	-4.619987742469615	15819.64709959542	87	0.008938014825352631	low	107	\N
Container (Base)	239194.51781408247	2137.924146365343	13681.722953230077	17.48277747121109	5.71991493712427	-4.619987742469615	15819.64709959542	98	0.008938014825352631	low	107	\N
Container (Max)	408122.60177347506	3647.805865212808	12171.841234382613	33.530062865150086	2.9823982258004147	-4.619987742469615	15819.64709959542	103	0.008938014825352631	low	107	\N
Traditional Housing	572167.0379449468	6171.748900146651	9725.31205940208	58.83276901040891	1.6997330175349663	4.3954894184251945	15897.060959548731	133	0.01078662084819449	low	108	\N
ODD Cubes Basic	333463.8663398533	6378.352923398095	9518.708036150636	35.0324713262984	2.854494593561013	4.3954894184251945	15897.060959548731	54	0.0191275684331493	low	108	\N
Container (Base)	245959.82689522565	4704.613420743984	11192.447538804747	21.97551751236459	4.550518546092701	4.3954894184251945	15897.060959548731	43	0.0191275684331493	low	108	\N
Container (Max)	447298.55139112065	8555.73365178221	7341.327307766522	60.92883924653727	1.641258905251231	4.3954894184251945	15897.060959548731	66	0.0191275684331493	low	108	\N
Traditional Housing	542677.3486662258	12775.30496772917	17467.786967361688	31.06732121706148	3.2188163022269913	4.97688741722976	30243.091935090855	115	0.02354125337850914	middle	109	\N
ODD Cubes Basic	301665.7093505832	4794.054773029364	25449.03716206149	11.853717978780573	8.436171687145816	4.97688741722976	30243.091935090855	84	0.015891944707105955	middle	109	\N
Container (Base)	248831.8953658811	3954.422722518957	26288.6692125719	9.465366746175324	10.564830997214878	4.97688741722976	30243.091935090855	117	0.015891944707105955	middle	109	\N
Container (Max)	508952.52537716506	8088.245391835848	22154.846543255007	22.972514135157233	4.353028119240966	4.97688741722976	30243.091935090855	80	0.015891944707105955	middle	109	\N
Traditional Housing	513011.0737703724	12469.94408611582	3047.509048641041	100	0.5940435215644349	0.5998263915086968	15517.45313475686	139	0.0243073585029423	low	110	\N
ODD Cubes Basic	353206.2468454103	8561.52306314836	6955.930071608502	50.777716740866296	1.9693677939543752	0.5998263915086968	15517.45313475686	88	0.02423944406310437	low	110	\N
Container (Base)	246720.9251762176	5980.378065006285	9537.075069750575	25.869663746147918	3.8655314959356724	0.5998263915086968	15517.45313475686	127	0.02423944406310437	low	110	\N
Container (Max)	466809.53376111167	11315.203581726299	4202.249553030562	100	0.9002064544767954	0.5998263915086968	15517.45313475686	138	0.02423944406310437	low	110	\N
Traditional Housing	571963.15563767	13319.168769688504	2595.4846849484293	100	0.45378529357450953	-0.7984789946313899	15914.653454636933	125	0.02328676006208693	low	111	\N
ODD Cubes Basic	351624.3922447378	5244.249776880006	10670.403677756927	32.9532417763837	3.034602807171041	-0.7984789946313899	15914.653454636933	128	0.014914351485689592	low	111	\N
Container (Base)	248943.72585297798	3712.8342275284645	12201.819227108468	20.402181119017573	4.9014367344669125	-0.7984789946313899	15914.653454636933	96	0.014914351485689592	low	111	\N
Container (Max)	404649.7260535507	6035.088242950661	9879.565211686273	40.95825245172747	2.4415104164382475	-0.7984789946313899	15914.653454636933	143	0.014914351485689592	low	111	\N
Traditional Housing	510071.9176524616	10797.291484298741	5010.203213928489	100	0.9822542744535487	3.7826825422969605	15807.49469822723	96	0.02116817474287125	low	112	\N
ODD Cubes Basic	324294.3881602471	5271.666969892544	10535.827728334687	30.780152876655446	3.2488467617665044	3.7826825422969605	15807.49469822723	76	0.016255806953056486	low	112	\N
Container (Base)	237111.76601486866	3854.4430946360044	11953.051603591226	19.836923145519574	5.041104372206346	3.7826825422969605	15807.49469822723	57	0.016255806953056486	low	112	\N
Container (Max)	463331.8540006314	7531.833173836017	8275.661524391213	55.9872890686785	1.7861197008008725	3.7826825422969605	15807.49469822723	85	0.016255806953056486	low	112	\N
Traditional Housing	579024.6292505496	13360.344505811203	2214.325300298804	100	0.3824233354572287	-2.586601661667236	15574.669806110007	117	0.02307387947055712	low	113	\N
ODD Cubes Basic	295643.3953332287	5339.15695984323	10235.512846266778	28.884082290127687	3.4621144959893386	-2.586601661667236	15574.669806110007	60	0.018059449472312084	low	113	\N
Container (Base)	250263.1218267004	4519.6142034123795	11055.055602697626	22.637889018453407	4.417373012054456	-2.586601661667236	15574.669806110007	59	0.018059449472312084	low	113	\N
Container (Max)	415193.7454277914	7498.170466773205	8076.499339336802	51.407636896047194	1.9452362730115909	-2.586601661667236	15574.669806110007	109	0.018059449472312084	low	113	\N
Traditional Housing	515887.5044971064	10145.259767628153	5428.7614528550985	95.02858229767868	1.0523149728441519	1.450771959588896	15574.021220483251	134	0.019665643535053012	low	114	\N
ODD Cubes Basic	351977.33453676733	8452.892424096763	7121.128796386489	49.42718276846404	2.0231782270180867	1.450771959588896	15574.021220483251	92	0.024015445299117064	low	114	\N
Container (Base)	240184.3717541997	5768.134641565781	9805.88657891747	24.49389658152818	4.082649719171835	1.450771959588896	15574.021220483251	148	0.024015445299117064	low	114	\N
Container (Max)	451168.4032194377	10835.010108206397	4739.011112276854	95.20306927549579	1.0503863033094343	1.450771959588896	15574.021220483251	78	0.024015445299117064	low	114	\N
Traditional Housing	546784.8891635609	7570.026272266271	7957.996877685923	68.70885947401358	1.4554163868463144	4.2727558093951075	15528.023149952194	127	0.013844614988988537	low	115	\N
ODD Cubes Basic	335099.69822503376	3211.765726229162	12316.257423723033	27.207916065442046	3.675400929621888	4.2727558093951075	15528.023149952194	114	0.009584507963574244	low	115	\N
Container (Base)	259333.65578202222	2485.5854890656137	13042.43766088658	19.883833262224204	5.029211353827959	4.2727558093951075	15528.023149952194	55	0.009584507963574244	low	115	\N
Container (Max)	429028.0321592181	4112.022590826613	11416.000559125581	37.58129039475799	2.660898520236773	4.2727558093951075	15528.023149952194	91	0.009584507963574244	low	115	\N
Traditional Housing	507785.2884291981	6972.435152890644	23537.1023398305	21.573823366094725	4.635246998321092	-4.885514609342287	30509.537492721145	120	0.01373106963074774	middle	116	\N
ODD Cubes Basic	352473.6972424082	3611.9345957625223	26897.602896958622	13.104279165421959	7.631095059686177	-4.885514609342287	30509.537492721145	106	0.010247387603729398	middle	116	\N
Container (Base)	255200.27843323306	2615.1361696850036	27894.40132303614	9.148799268994528	10.930396116450176	-4.885514609342287	30509.537492721145	119	0.010247387603729398	middle	116	\N
Container (Max)	455373.62405800977	4666.39003023738	25843.147462483765	17.620671968036053	5.675152467590355	-4.885514609342287	30509.537492721145	80	0.010247387603729398	middle	116	\N
Traditional Housing	535927.8232407823	5852.088634351221	10120.55574657812	52.95438676102207	1.888417676353994	-2.56844917171367	15972.644380929341	122	0.010919546216061986	low	117	\N
ODD Cubes Basic	312513.4747148163	3546.3074294886806	12426.33695144066	25.149283810349658	3.9762563719149373	-2.56844917171367	15972.644380929341	107	0.011347694472133907	low	117	\N
Container (Base)	247394.83798693458	2807.361035458801	13165.28334547054	18.79145564094902	5.3215675204047	-2.56844917171367	15972.644380929341	46	0.011347694472133907	low	117	\N
Container (Max)	452406.30085499136	5133.768479370735	10838.875901558607	41.73922692388574	2.395827794854865	-2.56844917171367	15972.644380929341	146	0.011347694472133907	low	117	\N
Traditional Housing	533114.6683523789	6747.328530960161	9066.877708273547	58.79804332928308	1.7007368670412402	2.363226313236245	15814.206239233708	101	0.012656430091884663	low	118	\N
ODD Cubes Basic	323266.85525483213	3069.961489625756	12744.244749607953	25.365713041942065	3.9423295467645856	2.363226313236245	15814.206239233708	48	0.009496678795621336	low	118	\N
Container (Base)	274258.17677740095	2604.5418119277115	13209.664427305997	20.761933680198236	4.816507052778775	2.363226313236245	15814.206239233708	63	0.009496678795621336	low	118	\N
Container (Max)	415955.28218628303	3950.1937082651634	11864.012530968545	35.06025310581205	2.852232689199345	2.363226313236245	15814.206239233708	83	0.009496678795621336	low	118	\N
Traditional Housing	565350.255382227	11745.845074506264	3898.053688999491	100	0.6894935753348268	0.6192582074351094	15643.898763505755	116	0.02077622670669005	low	119	\N
ODD Cubes Basic	322710.36769824935	5080.136685981565	10563.762077524188	30.54881067274874	3.2734498593493733	0.6192582074351094	15643.898763505755	101	0.015742093203313975	low	119	\N
Container (Base)	250558.67456140404	3944.318007844437	11699.580755661318	21.416038727726292	4.669397607622688	0.6192582074351094	15643.898763505755	127	0.015742093203313975	low	119	\N
Container (Max)	460544.57472753135	7249.935619641396	8393.96314386436	54.86616593785862	1.822616876733467	0.6192582074351094	15643.898763505755	131	0.015742093203313975	low	119	\N
Traditional Housing	563819.3829384957	14759.233623332348	15483.674468540707	36.413797260078546	2.746211807732361	3.1007458195527953	30242.908091873054	127	0.02617723701943457	middle	120	\N
ODD Cubes Basic	339516.7872774329	6962.020788692983	23280.887303180072	14.583498595049525	6.857065151289947	3.1007458195527953	30242.908091873054	68	0.020505674681128606	middle	120	\N
Container (Base)	251881.79287906663	5165.006102877556	25077.901988995498	10.043973893414034	9.956218630314375	3.1007458195527953	30242.908091873054	50	0.020505674681128606	middle	120	\N
Container (Max)	455833.36206431175	9347.170631295887	20895.73746057717	21.814657794409378	4.584073742638669	3.1007458195527953	30242.908091873054	115	0.020505674681128606	middle	120	\N
Traditional Housing	596879.9982921319	6386.790591857265	9170.644532666454	65.08593765312843	1.536430196841351	-4.53192849180166	15557.43512452372	147	0.010700292538084629	low	121	\N
ODD Cubes Basic	320209.12690083164	5471.805490465788	10085.629634057932	31.74904676447019	3.1497008632053882	-4.53192849180166	15557.43512452372	102	0.017088224634397756	low	121	\N
Container (Base)	243182.43205508954	4155.556026096539	11401.87909842718	21.328276677537747	4.688611345018642	-4.53192849180166	15557.43512452372	117	0.017088224634397756	low	121	\N
Container (Max)	393175.868157641	6718.677555902124	8838.757568621595	44.483160116694634	2.248041724950871	-4.53192849180166	15557.43512452372	129	0.017088224634397756	low	121	\N
Traditional Housing	588064.3604056212	8020.206929586715	22471.332477787684	26.169536719146816	3.821236924184274	3.3349447482137453	30491.5394073744	144	0.013638314901543642	middle	122	\N
ODD Cubes Basic	305246.377322017	6738.247821502853	23753.291585871546	12.850698027197943	7.781678457337832	3.3349447482137453	30491.5394073744	140	0.022074783919202416	middle	122	\N
Container (Base)	245342.48130916405	5415.882261100754	25075.657146273647	9.78408979984092	10.220674794054517	3.3349447482137453	30491.5394073744	135	0.022074783919202416	middle	122	\N
Container (Max)	497347.60338090156	10978.840877366587	19512.698530007812	25.48840708096065	3.9233522786403583	3.3349447482137453	30491.5394073744	103	0.022074783919202416	middle	122	\N
Traditional Housing	573367.2413164567	14128.351504084218	16228.709168678964	35.330428030779075	2.8304214121856166	-4.860812365303049	30357.060672763182	126	0.024641016238816482	middle	123	\N
ODD Cubes Basic	331389.7161057584	5905.790230024752	24451.27044273843	13.553067390990105	7.378403509339786	-4.860812365303049	30357.060672763182	65	0.017821283953603443	middle	123	\N
Container (Base)	255938.04465793792	4561.144568379151	25795.916104384032	9.921649753483308	10.078968970346072	-4.860812365303049	30357.060672763182	130	0.017821283953603443	middle	123	\N
Container (Max)	407716.67414092337	7266.0346224842015	23091.026050278982	17.65693188570966	5.663498089434967	-4.860812365303049	30357.060672763182	76	0.017821283953603443	middle	123	\N
Traditional Housing	564879.4942502395	13992.870588595804	16446.31941430631	34.34686388000361	2.9114739659890456	4.663377291192134	30439.190002902113	124	0.024771425996209052	middle	124	\N
ODD Cubes Basic	296335.8218656093	2723.961911098568	27715.228091803543	10.692166085879958	9.352641849817475	4.663377291192134	30439.190002902113	71	0.009192145228847516	middle	124	\N
Container (Base)	269119.5424122079	2473.785917774004	27965.40408512811	9.6233024773393	10.391443086765419	4.663377291192134	30439.190002902113	107	0.009192145228847516	middle	124	\N
Container (Max)	476536.63428793213	4380.393949240869	26058.796053661245	18.286978159183953	5.468372036622067	4.663377291192134	30439.190002902113	56	0.009192145228847516	middle	124	\N
Traditional Housing	595701.168517036	11951.721957088392	3907.4169751006375	100	0.6559357579955616	0.7823048209521355	15859.13893218903	145	0.020063284392813126	low	125	\N
ODD Cubes Basic	318538.56529130973	4595.368594670362	11263.770337518668	28.279923661998385	3.536077437662134	0.7823048209521355	15859.13893218903	127	0.014426412043602344	low	125	\N
Container (Base)	276410.56210961594	3987.612662197057	11871.526269991973	23.283489908817163	4.294888798527204	0.7823048209521355	15859.13893218903	68	0.014426412043602344	low	125	\N
Container (Max)	484640.3575794997	6991.621491400641	8867.517440788388	54.6534428396243	1.8297108984230173	0.7823048209521355	15859.13893218903	100	0.014426412043602344	low	125	\N
Traditional Housing	551837.6200703423	7274.299481757177	23695.22170693246	23.2889831922903	4.29387574263459	0.8329902115637946	30969.52118868964	107	0.01318195646181195	middle	126	\N
ODD Cubes Basic	302442.2697708469	7234.427344719887	23735.093843969753	12.742408846539561	7.847809719836203	0.8329902115637946	30969.52118868964	136	0.023920027283888708	middle	126	\N
Container (Base)	257228.07168442276	6152.9024928734725	24816.618695816167	10.365153884875896	9.647710117059908	0.8329902115637946	30969.52118868964	109	0.023920027283888708	middle	126	\N
Container (Max)	428431.5337156246	10248.093975756025	20721.427212933617	20.67577340658331	4.836578445387649	0.8329902115637946	30969.52118868964	91	0.023920027283888708	middle	126	\N
Traditional Housing	539572.3998160678	10663.386153857142	5313.740998864234	100	0.9848059316369053	1.9632308528209546	15977.127152721376	116	0.0197626605020793	low	127	\N
ODD Cubes Basic	333294.8063888672	6504.197409159364	9472.929743562012	35.18392043553167	2.8422074277717964	1.9632308528209546	15977.127152721376	126	0.019514847769846973	low	127	\N
Container (Base)	245241.768603595	4785.855781107193	11191.271371614182	21.913664717811443	4.563362691166846	1.9632308528209546	15977.127152721376	87	0.019514847769846973	low	127	\N
Container (Max)	482954.1899207151	9424.777496112518	6552.349656608858	73.70702346960313	1.3567228100214916	1.9632308528209546	15977.127152721376	86	0.019514847769846973	low	127	\N
Traditional Housing	573303.685855019	13960.692004366718	16858.455042411246	34.00689353874624	2.9405802645885184	3.686200768045582	30819.147046777965	134	0.02435130341704657	middle	128	\N
ODD Cubes Basic	301582.6449343104	3709.0501029528623	27110.096943825105	11.124366156241363	8.989276206437584	3.686200768045582	30819.147046777965	126	0.012298619185333936	middle	128	\N
Container (Base)	274050.21495173784	3370.439231350332	27448.70781542763	9.984084380019778	10.015940991055796	3.686200768045582	30819.147046777965	50	0.012298619185333936	middle	128	\N
Container (Max)	443675.5200118457	5456.596262480696	25362.55078429727	17.493331951711212	5.716463866120023	3.686200768045582	30819.147046777965	70	0.012298619185333936	middle	128	\N
Traditional Housing	591455.4668315949	7978.287326736167	22160.9809497939	26.689047211923874	3.746855375014023	-0.6548300645500396	30139.268276530067	136	0.013489244371136778	middle	129	\N
ODD Cubes Basic	319052.20934703556	3359.2175778239693	26780.050698706098	11.913801543417199	8.393626470574674	-0.6548300645500396	30139.268276530067	133	0.010528739433269752	middle	129	\N
Container (Base)	254241.4765922955	2676.8422601700304	27462.426016360037	9.257793773967299	10.801709612629057	-0.6548300645500396	30139.268276530067	75	0.010528739433269752	middle	129	\N
Container (Max)	460833.18147298833	4851.992489933808	25287.27578659626	18.223915670554636	5.487294926500094	-0.6548300645500396	30139.268276530067	83	0.010528739433269752	middle	129	\N
Traditional Housing	569572.8443453896	16753.734362862786	14009.684849536756	40.65565003514145	2.459682723399163	-4.413997485005106	30763.41921239954	87	0.029414559575988673	middle	130	\N
ODD Cubes Basic	342343.31465872773	7624.208568739857	23139.210643659684	14.794943523820349	6.759066017318463	-4.413997485005106	30763.41921239954	149	0.022270651250602666	middle	130	\N
Container (Base)	231635.10435197497	5158.664626419791	25604.75458597975	9.046566081082851	11.053918039587266	-4.413997485005106	30763.41921239954	116	0.022270651250602666	middle	130	\N
Container (Max)	402729.2204857653	8969.042017865546	21794.377194533998	18.47858357644509	5.411670195732503	-4.413997485005106	30763.41921239954	97	0.022270651250602666	middle	130	\N
Traditional Housing	555517.3872780907	13481.080860567406	17038.030486561474	32.6045541306108	3.067056203234963	2.698213824514095	30519.11134712888	144	0.0242676128043834	middle	131	\N
ODD Cubes Basic	320932.16564822017	3740.620800206336	26778.490546922545	11.98469962621185	8.343972157740946	2.698213824514095	30519.11134712888	105	0.011655487360237058	middle	131	\N
Container (Base)	279350.93652916385	3255.971309786054	27263.140037342826	10.246469634331618	9.759458971599543	2.698213824514095	30519.11134712888	126	0.011655487360237058	middle	131	\N
Container (Max)	456735.6503650065	5323.476599798986	25195.634747329896	18.127570706009262	5.516458968594735	2.698213824514095	30519.11134712888	121	0.011655487360237058	middle	131	\N
Traditional Housing	500901.28880124015	12361.551380697136	3114.9586035262782	100	0.6218707504189129	-2.0842199914230086	15476.509984223414	126	0.024678617637979874	low	132	\N
ODD Cubes Basic	314269.88363220386	3402.581932961291	12073.928051262123	26.028802084782367	3.8418978973475153	-2.0842199914230086	15476.509984223414	66	0.010826942415339418	low	132	\N
Container (Base)	261740.33085332814	2833.847489920871	12642.662494302544	20.702943780337588	4.830230959472246	-2.0842199914230086	15476.509984223414	83	0.010826942415339418	low	132	\N
Container (Max)	476017.6631845852	5153.815827983939	10322.694156239475	46.11370403693109	2.1685527564628724	-2.0842199914230086	15476.509984223414	49	0.010826942415339418	low	132	\N
Traditional Housing	564618.2351914743	12447.223066110912	3438.551388719061	100	0.6090046644619923	0.1866384527975118	15885.774454829972	114	0.02204537914346636	low	133	\N
ODD Cubes Basic	297102.97609208885	4246.464655373319	11639.309799456652	25.525824229367814	3.917601214418323	0.1866384527975118	15885.774454829972	116	0.014292905144299536	low	133	\N
Container (Base)	264949.8235734679	3786.9026963344736	12098.8717584955	21.898721538843265	4.566476623880674	0.1866384527975118	15885.774454829972	80	0.014292905144299536	low	133	\N
Container (Max)	417830.93209756206	5972.017878824715	9913.756576005257	42.146579744438995	2.3726717709091076	0.1866384527975118	15885.774454829972	132	0.014292905144299536	low	133	\N
Traditional Housing	597409.3856018862	11305.091762588929	18949.555759458002	31.526300309373237	3.171954812923879	4.434267240674284	30254.647522046933	130	0.018923525533833252	middle	134	\N
ODD Cubes Basic	303541.16068529343	4990.725519671051	25263.922002375883	12.014807544796396	8.323062989328523	4.434267240674284	30254.647522046933	60	0.016441676339392253	middle	134	\N
Container (Base)	282866.61930936616	4650.801401902681	25603.84612014425	11.047817502965547	9.05156153902408	4.434267240674284	30254.647522046933	90	0.016441676339392253	middle	134	\N
Container (Max)	482561.6676164552	7934.12275274714	22320.524769299795	21.619638095614246	4.625424327537008	4.434267240674284	30254.647522046933	120	0.016441676339392253	middle	134	\N
Traditional Housing	513098.9000866271	10467.289334399715	5080.389004316528	100	0.9901383541182411	4.1743817659923135	15547.678338716243	94	0.020400139880698456	low	135	\N
ODD Cubes Basic	302993.87256500695	3437.9771987330073	12109.701139983235	25.020755596072984	3.9966818594277393	4.1743817659923135	15547.678338716243	83	0.011346688860829665	low	135	\N
Container (Base)	260739.99659814054	2958.535614972886	12589.142723743356	20.71149738467736	4.828236131009114	4.1743817659923135	15547.678338716243	62	0.011346688860829665	low	135	\N
Container (Max)	470581.3787784814	5339.54048869966	10208.137850016583	46.09865047793383	2.1692608994674862	4.1743817659923135	15547.678338716243	94	0.011346688860829665	low	135	\N
Traditional Housing	497470.01034322684	10785.314426119148	4726.2814370564065	100	0.9500635895208103	-2.3766656727451463	15511.595863175555	133	0.021680330877991774	low	136	\N
ODD Cubes Basic	296695.01244325103	6522.399834330608	8989.196028844946	33.005733937851886	3.0297765893736797	-2.3766656727451463	15511.595863175555	64	0.02198351694765395	low	136	\N
Container (Base)	233589.40094103938	5135.116554379672	10376.479308795882	22.51143128508255	4.442187559449679	-2.3766656727451463	15511.595863175555	42	0.02198351694765395	low	136	\N
Container (Max)	415722.86201408284	9139.050582613794	6372.545280561761	65.236548931581	1.5328830485021263	-2.3766656727451463	15511.595863175555	52	0.02198351694765395	low	136	\N
Traditional Housing	567615.1648109005	14844.136714693963	15261.383995192526	37.19290235995008	2.688685035445946	1.0094571020834326	30105.52070988649	83	0.02615176202989441	middle	137	\N
ODD Cubes Basic	340446.19890417095	6487.568793128996	23617.95191675749	14.414721484068075	6.93735221388255	1.0094571020834326	30105.52070988649	106	0.01905607644911648	middle	137	\N
Container (Base)	232397.76080861595	4428.589496572471	25676.93121331402	9.05083862545509	11.04869992033162	1.0094571020834326	30105.52070988649	87	0.01905607644911648	middle	137	\N
Container (Max)	459107.0353611251	8748.778764168821	21356.741945717666	21.497054022942045	4.6518001905413735	1.0094571020834326	30105.52070988649	72	0.01905607644911648	middle	137	\N
Traditional Housing	503402.0692760759	7208.423372054514	23626.083218248656	21.307047157408256	4.693282896557112	1.3953935530351362	30834.50659030317	124	0.014319415457351384	middle	138	\N
ODD Cubes Basic	330946.3971987981	4296.72272942002	26537.783860883148	12.470762401777455	8.018755933137419	1.3953935530351362	30834.50659030317	75	0.012983137951609115	middle	138	\N
Container (Base)	230626.77981329136	2994.259297651342	27840.247292651828	8.283934312399701	12.071558782198004	1.3953935530351362	30834.50659030317	51	0.012983137951609115	middle	138	\N
Container (Max)	467598.4673896158	6070.895408080378	24763.61118222279	18.882483008992388	5.295913675779667	1.3953935530351362	30834.50659030317	110	0.012983137951609115	middle	138	\N
Traditional Housing	588413.9720095019	12164.432771824839	18483.236603651225	31.83500728943031	3.141196076722793	-0.6346172440672113	30647.669375476064	140	0.020673256160593692	middle	139	\N
ODD Cubes Basic	294712.1366107679	4608.99219098335	26038.677184492713	11.31824533645216	8.835291781309468	-0.6346172440672113	30647.669375476064	42	0.01563896296904303	middle	139	\N
Container (Base)	251594.4144352652	3934.6757305711776	26712.993644904887	9.41842826677171	10.617482786676925	-0.6346172440672113	30647.669375476064	72	0.01563896296904303	middle	139	\N
Container (Max)	437059.50324507244	6835.15738651803	23812.511988958035	18.35419561983796	5.448345548410519	-0.6346172440672113	30647.669375476064	100	0.01563896296904303	middle	139	\N
Traditional Housing	511432.7390227737	13200.81859409834	16852.859072224826	30.346942131953462	3.2952249213506803	-2.5957781548658065	30053.67766632317	91	0.025811446133311614	middle	140	\N
ODD Cubes Basic	343990.7723982506	6238.038340920253	23815.639325402917	14.443902500292458	6.923336681203381	-2.5957781548658065	30053.67766632317	146	0.018134318829047688	middle	140	\N
Container (Base)	227627.21083878132	4127.86441551732	25925.813250805848	8.779944861776169	11.389593166507673	-2.5957781548658065	30053.67766632317	56	0.018134318829047688	middle	140	\N
Container (Max)	417767.77721424866	7575.93406850575	22477.743597817418	18.58584138555677	5.380439761942171	-2.5957781548658065	30053.67766632317	102	0.018134318829047688	middle	140	\N
Traditional Housing	553590.2453717139	16207.189808309711	-351.2912116876705	100	0	3.727628450132114	15855.89859662204	111	0.02927650901331765	low	141	Negative cash flow
ODD Cubes Basic	314520.76466461574	3393.3496672924025	12462.548929329638	25.237274208361633	3.962393053005222	3.727628450132114	15855.89859662204	65	0.010788952745014617	low	141	\N
Container (Base)	235831.68186283196	2544.3768713954146	13311.521725226627	17.716357808732567	5.644501035687426	3.727628450132114	15855.89859662204	130	0.010788952745014617	low	141	\N
Container (Max)	467008.88991336554	5038.536844777034	10817.361751845006	43.172161625611956	2.316307459126041	3.727628450132114	15855.89859662204	136	0.010788952745014617	low	141	\N
Traditional Housing	546240.2114585293	11168.139454129701	19728.930486922727	27.687269303351407	3.611768242810984	0.1691991122379486	30897.06994105243	126	0.020445472925380903	middle	142	\N
ODD Cubes Basic	320683.89531190763	2848.998037368477	28048.07190368395	11.433366842937524	8.746330050782088	0.1691991122379486	30897.06994105243	54	0.008884131941198508	middle	142	\N
Container (Base)	228700.4759745841	2031.8052035731046	28865.264737479323	7.923034070691689	12.621427486966477	0.1691991122379486	30897.06994105243	126	0.008884131941198508	middle	142	\N
Container (Max)	490131.94323544845	4354.396852299741	26542.673088752686	18.465809438128492	5.415413840105945	0.1691991122379486	30897.06994105243	66	0.008884131941198508	middle	142	\N
Traditional Housing	515429.56071247905	8378.303676028121	7573.364371488677	68.05820180168651	1.4693306222134415	1.6744983626078742	15951.668047516798	108	0.016254992562799036	low	143	\N
ODD Cubes Basic	328819.6703984528	6342.080329375024	9609.587718141775	34.21787490192527	2.9224491668935726	1.6744983626078742	15951.668047516798	146	0.019287411612845123	low	143	\N
Container (Base)	252370.0037834061	4867.564141705834	11084.103905810964	22.768642907713843	4.392005285748531	1.6744983626078742	15951.668047516798	128	0.019287411612845123	low	143	\N
Container (Max)	491707.87945498835	9483.772264327592	6467.895783189206	76.022851316342	1.3153939673202422	1.6744983626078742	15951.668047516798	144	0.019287411612845123	low	143	\N
Traditional Housing	567757.2509691862	15810.834173693826	14457.184946944706	39.27163227507666	2.5463672938153876	3.6889261648664657	30268.01912063853	142	0.02784787714591764	middle	144	\N
ODD Cubes Basic	330250.0163438197	3556.574009449368	26711.445111189165	12.363614734025797	8.08824944413634	3.6889261648664657	30268.01912063853	70	0.010769337875661625	middle	144	\N
Container (Base)	249897.38195585573	2691.229340525877	27576.789780112653	9.06187355194158	11.035245573314603	3.6889261648664657	30268.01912063853	59	0.010769337875661625	middle	144	\N
Container (Max)	476644.3150087129	5133.143674842122	25134.87544579641	18.963464371908298	5.273298066155883	3.6889261648664657	30268.01912063853	140	0.010769337875661625	middle	144	\N
Traditional Housing	535825.8879594249	9485.78822510661	21201.85904138763	25.2725898664571	3.956856045558054	2.580021212133376	30687.647266494238	101	0.01770311669940239	middle	145	\N
ODD Cubes Basic	342598.4269406035	4781.995932927042	25905.651333567195	13.224852852731876	7.561520805832093	2.580021212133376	30687.647266494238	55	0.013958020693878144	middle	145	\N
Container (Base)	270288.01938377717	3772.6857678660986	26914.961498628138	10.042296341295298	9.957881803267076	2.580021212133376	30687.647266494238	126	0.013958020693878144	middle	145	\N
Container (Max)	495780.1829646159	6920.110053434801	23767.537213059437	20.859552191726532	4.79396676788022	2.580021212133376	30687.647266494238	73	0.013958020693878144	middle	145	\N
Traditional Housing	538722.5487335608	7669.427638502131	8071.612446556417	66.7428661002419	1.4982874701516238	2.0466830219548138	15741.040085058548	104	0.014236321937018539	low	146	\N
ODD Cubes Basic	294530.3869036059	6842.9617848273765	8898.078300231173	33.100448991997965	3.021107055803835	2.0466830219548138	15741.040085058548	109	0.02323346618584026	low	146	\N
Container (Base)	266047.83478287666	6181.213373243982	9559.826711814567	27.829775873874357	3.5932736380344545	2.0466830219548138	15741.040085058548	128	0.02323346618584026	low	146	\N
Container (Max)	447436.59799273347	10395.503069771576	5345.537015286973	83.70283410500582	1.1947026772659723	2.0466830219548138	15741.040085058548	108	0.02323346618584026	low	146	\N
Traditional Housing	568293.0773538804	15200.684698742012	452.9180390631682	100	0.07969796872629027	-4.525765273597964	15653.60273780518	145	0.026747967385983888	low	147	\N
ODD Cubes Basic	318591.35956080345	5831.281736801551	9822.32100100363	32.43544570863142	3.0830468894524525	-4.525765273597964	15653.60273780518	130	0.01830332669674504	low	147	\N
Container (Base)	222017.8777465328	4063.6657489127897	11589.93698889239	19.15609014607337	5.2202719468042424	-4.525765273597964	15653.60273780518	65	0.01830332669674504	low	147	\N
Container (Max)	403788.52250831976	7390.673243865764	8262.929493939417	48.86747766690799	2.046350758711614	-4.525765273597964	15653.60273780518	118	0.01830332669674504	low	147	\N
Traditional Housing	542034.2668349942	13487.960681901579	2430.9926532854897	100	0.4484942746296022	-4.628616440198023	15918.953335187069	89	0.024883963076097505	low	148	\N
ODD Cubes Basic	312479.120187131	4267.198829844143	11651.754505342926	26.81820321942445	3.7288105836848127	-4.628616440198023	15918.953335187069	96	0.013655948683191031	low	148	\N
Container (Base)	221758.59967116782	3028.324057165771	12890.629278021297	17.203085659229167	5.812910659219537	-4.628616440198023	15918.953335187069	67	0.013655948683191031	low	148	\N
Container (Max)	392562.06558512384	5360.807422597923	10558.145912589145	37.18096613128326	2.6895481856740173	-4.628616440198023	15918.953335187069	120	0.013655948683191031	low	148	\N
Traditional Housing	540726.6160745771	9074.940076814155	21311.20410580493	25.372879607834516	3.9412160363982687	-1.5064206157756588	30386.144182619086	103	0.016782861814152936	middle	149	\N
ODD Cubes Basic	345484.84959166474	2843.4310440849345	27542.713138534153	12.543602652866744	7.9721913047959765	-1.5064206157756588	30386.144182619086	70	0.008230262622067627	middle	149	\N
Container (Base)	233669.28819637065	1923.1596085677375	28462.98457405135	8.209584893967806	12.180883843892941	-1.5064206157756588	30386.144182619086	91	0.008230262622067627	middle	149	\N
Container (Max)	430454.0245136373	3542.749668473171	26843.394514145915	16.035752269959634	6.236065406631012	-1.5064206157756588	30386.144182619086	136	0.008230262622067627	middle	149	\N
Traditional Housing	551953.0536854172	13693.766520317009	17282.247029324913	31.937574595991514	3.1311081465951704	-0.7843470712998819	30976.013549641924	105	0.024809658047696394	middle	150	\N
ODD Cubes Basic	305390.42146956123	4994.144086501428	25981.869463140494	11.75398182578075	8.507755200085786	-0.7843470712998819	30976.013549641924	141	0.01635330951923521	middle	150	\N
Container (Base)	238106.70839584697	3893.832701003567	27082.180848638356	8.792006438721442	11.373968012532787	-0.7843470712998819	30976.013549641924	64	0.01635330951923521	middle	150	\N
Container (Max)	460138.06592685485	7524.780213684114	23451.23333595781	19.62106040799673	5.096564503682184	-0.7843470712998819	30976.013549641924	115	0.01635330951923521	middle	150	\N
Traditional Housing	596171.0525258109	7329.121055266278	8331.545833174632	71.55587503965603	1.3975092882950606	0.06750165576459022	15660.66688844091	110	0.012293654688893114	low	151	\N
ODD Cubes Basic	333118.1102437502	7350.201510153381	8310.465378287528	40.08417039003334	2.494750397150899	0.06750165576459022	15660.66688844091	107	0.022064851126752216	low	151	\N
Container (Base)	259931.762108307	5735.355634034167	9925.311254406743	26.18877690036167	3.8184295654761558	0.06750165576459022	15660.66688844091	55	0.022064851126752216	low	151	\N
Container (Max)	477370.0674715904	10533.099471128304	5127.567417312606	93.09874032271298	1.074128389421434	0.06750165576459022	15660.66688844091	149	0.022064851126752216	low	151	\N
Traditional Housing	503452.1833914999	11682.744111445483	18531.730752716103	27.16703529257306	3.6809316483399295	0.739642555859108	30214.474864161584	137	0.02320527052389526	middle	152	\N
ODD Cubes Basic	344850.2884537997	7532.439663088709	22682.035201072875	15.203674864127185	6.577357178029919	0.739642555859108	30214.474864161584	139	0.021842636979837834	middle	152	\N
Container (Base)	248670.65888699447	5431.622929605705	24782.851934555878	10.033980735698197	9.966134342298165	0.739642555859108	30214.474864161584	97	0.021842636979837834	middle	152	\N
Container (Max)	475981.0038438281	10396.680276259534	19817.794587902048	24.01785939059006	4.163568383582882	0.739642555859108	30214.474864161584	65	0.021842636979837834	middle	152	\N
Traditional Housing	495961.7254400584	7499.512489791383	7963.922535163321	62.27606098002903	1.605753453675698	1.0843426805863619	15463.435024954704	88	0.015121151704069892	low	153	\N
ODD Cubes Basic	341922.01974464447	5496.026471564333	9967.40855339037	34.30400368492382	2.9151116271582245	1.0843426805863619	15463.435024954704	125	0.01607391789411193	low	153	\N
Container (Base)	258642.85695987887	4157.40404667163	11306.030978283074	22.876538854058243	4.37129063264132	1.0843426805863619	15463.435024954704	72	0.01607391789411193	low	153	\N
Container (Max)	440465.0327548905	7079.998771729432	8383.436253225273	52.53991554900116	1.9033148217898328	1.0843426805863619	15463.435024954704	45	0.01607391789411193	low	153	\N
Traditional Housing	557940.2149531061	12223.986476487264	18629.041025516424	29.950023417141473	3.3388955530086966	2.0655700997550603	30853.027502003686	82	0.02190913318107867	middle	154	\N
ODD Cubes Basic	300164.80877577205	6350.414811693556	24502.612690310132	12.250318468873974	8.163053087483677	2.0655700997550603	30853.027502003686	118	0.021156426822963842	middle	154	\N
Container (Base)	232261.1330689518	4913.8156655919465	25939.21183641174	8.954055139906721	11.168124211600707	2.0655700997550603	30853.027502003686	66	0.021156426822963842	middle	154	\N
Container (Max)	458645.9462170476	9703.309398789977	21149.71810321371	21.685676564519135	4.611338719475984	2.0655700997550603	30853.027502003686	143	0.021156426822963842	middle	154	\N
Traditional Housing	562772.1272644032	12831.062170386223	2871.9371933792954	100	0.5103197287576386	1.4350750121121045	15702.999363765519	125	0.022799747089034313	low	155	\N
ODD Cubes Basic	327119.70607633167	3313.220700216546	12389.778663548972	26.402384978734588	3.7875366214280843	1.4350750121121045	15702.999363765519	55	0.010128465630998774	low	155	\N
Container (Base)	244822.96322059925	2479.6809686591164	13223.318395106402	18.514487506494717	5.401175699026014	1.4350750121121045	15702.999363765519	93	0.010128465630998774	low	155	\N
Container (Max)	451520.9058825615	4573.213976908956	11129.785386856562	40.5686983340913	2.4649546104851603	1.4350750121121045	15702.999363765519	48	0.010128465630998774	low	155	\N
Traditional Housing	549571.6383715675	11690.137867984009	4011.5232615336354	100	0.7299363688817998	3.0258645127422508	15701.661129517644	93	0.02127136309767183	low	156	\N
ODD Cubes Basic	307778.9657543081	7439.30039192276	8262.360737594885	37.2507296073229	2.6845111774761476	3.0258645127422508	15701.661129517644	92	0.024170918807561916	low	156	\N
Container (Base)	240605.0598756203	5815.645366942192	9886.015762575453	24.337919911725805	4.108814572597095	3.0258645127422508	15701.661129517644	56	0.024170918807561916	low	156	\N
Container (Max)	434086.60386472585	10492.272057464581	5209.3890720530635	83.32773725684665	1.200080588913189	3.0258645127422508	15701.661129517644	82	0.024170918807561916	low	156	\N
Traditional Housing	556974.3224476884	15314.896697555057	238.73604247849653	100	0.04286302489302258	-4.28757985005357	15553.632740033554	83	0.027496593793142857	low	157	\N
ODD Cubes Basic	307434.0227245599	2606.0920322430306	12947.540707790524	23.744588232078474	4.211485961458028	-4.28757985005357	15553.632740033554	107	0.008476914848744353	low	157	\N
Container (Base)	241641.1514308055	2048.371464631478	13505.261275402076	17.892371461996127	5.588974061510106	-4.28757985005357	15553.632740033554	130	0.008476914848744353	low	157	\N
Container (Max)	431659.6189458181	3659.1418334451346	11894.49090658842	36.290718311173755	2.7555255077221887	-4.28757985005357	15553.632740033554	133	0.008476914848744353	low	157	\N
Traditional Housing	583792.5600099833	6368.486171797437	23740.773151416113	24.590292670193033	4.06664537674309	-3.5023263981211783	30109.25932321355	88	0.010908816946362818	middle	158	\N
ODD Cubes Basic	337385.70898771373	4473.539760887041	25635.71956232651	13.16076610088705	7.598341861972601	-3.5023263981211783	30109.25932321355	138	0.013259422796268912	middle	158	\N
Container (Base)	264603.8890263142	3508.49483813692	26600.76448507663	9.947228741292768	10.053051216655115	-3.5023263981211783	30109.25932321355	124	0.013259422796268912	middle	158	\N
Container (Max)	469470.02986222104	6224.901616120181	23884.35770709337	19.655962099529017	5.087514897192244	-3.5023263981211783	30109.25932321355	140	0.013259422796268912	middle	158	\N
Traditional Housing	563793.4988804584	15621.049762364022	196.27781373669677	100	0.034813777407233584	-4.336018397119387	15817.327576100719	145	0.02770704130747021	low	159	\N
ODD Cubes Basic	323862.89788365224	5466.95593249497	10350.37164360575	31.289977696958175	3.1959115141753967	-4.336018397119387	15817.327576100719	123	0.016880463826575695	low	159	\N
Container (Base)	234830.39448421943	3964.045979471367	11853.281596629353	19.811424589035052	5.047592592374532	-4.336018397119387	15817.327576100719	44	0.016880463826575695	low	159	\N
Container (Max)	425820.6547952672	7188.050159880285	8629.277416220433	49.34603840581751	2.0265051305154174	-4.336018397119387	15817.327576100719	40	0.016880463826575695	low	159	\N
Traditional Housing	587895.0484969483	9130.176998203731	21377.159560228225	27.50108342694486	3.6362203789405094	-3.2879038958418905	30507.336558431958	130	0.015530283885782932	middle	160	\N
ODD Cubes Basic	329648.1992199419	2937.063483709798	27570.27307472216	11.956653397175826	8.36354426930366	-3.2879038958418905	30507.336558431958	136	0.008909690666170403	middle	160	\N
Container (Base)	239361.99539790716	2132.6413362326566	28374.6952221993	8.435755645073476	11.85430259094815	-3.2879038958418905	30507.336558431958	79	0.008909690666170403	middle	160	\N
Container (Max)	461060.9987324182	4107.910876941431	26399.425681490527	17.464811708221465	5.725798919030175	-3.2879038958418905	30507.336558431958	76	0.008909690666170403	middle	160	\N
Traditional Housing	497308.6614932891	6073.219054333254	9818.632844333573	50.64948138683999	1.9743538781027383	-0.47257017699265624	15891.851898666826	137	0.012212172287723583	low	161	\N
ODD Cubes Basic	317314.1067203725	4845.216382858527	11046.635515808299	28.72495487574292	3.4812935453711025	-0.47257017699265624	15891.851898666826	86	0.015269464168916665	low	161	\N
Container (Base)	231624.0950118627	3536.775819441387	12355.076079225439	18.74728196949991	5.334106574099154	-0.47257017699265624	15891.851898666826	72	0.015269464168916665	low	161	\N
Container (Max)	454543.6496194869	6940.637971073366	8951.21392759346	50.78011242902908	1.9692748837403864	-0.47257017699265624	15891.851898666826	113	0.015269464168916665	low	161	\N
Traditional Housing	528253.7491182375	8402.283930571337	7341.363681141309	71.95580713093261	1.3897418983576608	-0.9619221728243303	15743.647611712646	147	0.015905772452342176	low	162	\N
ODD Cubes Basic	328889.92312210036	5956.097183820781	9787.550427891865	33.602884148096265	2.9759350286503725	-0.9619221728243303	15743.647611712646	42	0.018109698002542876	low	162	\N
Container (Base)	272194.31061976607	4929.356763334313	10814.290848378332	25.169871463239147	3.973003999883393	-0.9619221728243303	15743.647611712646	111	0.018109698002542876	low	162	\N
Container (Max)	471857.7310702334	8545.20100984702	7198.446601865626	65.54993836419398	1.5255544474260563	-0.9619221728243303	15743.647611712646	147	0.018109698002542876	low	162	\N
Traditional Housing	538479.2119959521	6506.434231721171	9057.184862053455	59.453265026310554	1.6819934103828582	0.770806083186808	15563.619093774625	135	0.012082981267938124	low	163	\N
ODD Cubes Basic	315171.0793026718	4843.464413594716	10720.154680179909	29.39986303419481	3.40137639021279	0.770806083186808	15563.619093774625	76	0.015367731151954259	low	163	\N
Container (Base)	274428.49858051306	4217.343386619786	11346.27570715484	24.186658747192382	4.134510725323237	0.770806083186808	15563.619093774625	133	0.015367731151954259	low	163	\N
Container (Max)	462556.122167059	7108.438128153873	8455.180965620752	54.7068269795571	1.8279254257858548	0.770806083186808	15563.619093774625	52	0.015367731151954259	low	163	\N
Traditional Housing	553641.598823225	12980.249294532347	2613.30409275929	100	0.47202090636142846	-3.1326225891353854	15593.553387291637	142	0.02344522037744652	low	164	\N
ODD Cubes Basic	324929.61601636914	5192.785029477456	10400.76835781418	31.240924212320035	3.2009296306465997	-3.1326225891353854	15593.553387291637	136	0.015981261090142848	low	164	\N
Container (Base)	221787.10116475206	3544.4375701398276	12049.11581715181	18.406919190621448	5.432739665144574	-3.1326225891353854	15593.553387291637	80	0.015981261090142848	low	164	\N
Container (Max)	445898.6959270502	7126.023479364405	8467.529907927232	52.65983123479771	1.8989806396097948	-3.1326225891353854	15593.553387291637	47	0.015981261090142848	low	164	\N
Traditional Housing	589633.7418191211	16649.66772686728	14111.209424337292	41.78477720004585	2.3932160633822948	-0.7455954874077957	30760.87715120457	94	0.028237304865729368	middle	165	\N
ODD Cubes Basic	314124.7168877865	7725.467002017653	23035.41014918692	13.636601860066042	7.333205224158074	-0.7455954874077957	30760.87715120457	84	0.024593629812255078	middle	165	\N
Container (Base)	227186.2356396593	5587.334177761532	25173.54297344304	9.024801788104702	11.080575767526192	-0.7455954874077957	30760.87715120457	84	0.024593629812255078	middle	165	\N
Container (Max)	413425.7143920701	10167.638974625668	20593.238176578903	20.07579919423587	4.981121749250801	-0.7455954874077957	30760.87715120457	43	0.024593629812255078	middle	165	\N
Traditional Housing	589481.9636912092	14431.256535205066	16079.049372487665	36.66149347733533	2.7276575642457517	-2.3329789582818607	30510.30590769273	136	0.02448125205534643	middle	166	\N
ODD Cubes Basic	302466.90765350463	2757.8243268014603	27752.48158089127	10.89873375005735	9.175377827674138	-2.3329789582818607	30510.30590769273	114	0.009117772083552116	middle	166	\N
Container (Base)	238608.52157410304	2175.5781169059997	28334.727790786732	8.421062779776856	11.874985689472538	-2.3329789582818607	30510.30590769273	75	0.009117772083552116	middle	166	\N
Container (Max)	419068.77437782794	3820.97357211056	26689.33233558217	15.701733153478935	6.368723695819758	-2.3329789582818607	30510.30590769273	73	0.009117772083552116	middle	166	\N
Traditional Housing	503493.5122728946	10588.503562017318	4902.206611934927	100	0.9736384863838962	0.8220308851656544	15490.710173952246	140	0.021030069512153568	low	167	\N
ODD Cubes Basic	333240.5387687388	6910.5124230204965	8580.19775093175	38.83832849103638	2.574776100961176	0.8220308851656544	15490.710173952246	80	0.020737310198073566	low	167	\N
Container (Base)	238465.472406341	4945.132472820445	10545.5777011318	22.61284105665902	4.422266081004096	0.8220308851656544	15490.710173952246	112	0.020737310198073566	low	167	\N
Container (Max)	476551.05659050914	9882.387085737098	5608.323088215147	84.9721118228536	1.176856710451965	0.8220308851656544	15490.710173952246	84	0.020737310198073566	low	167	\N
Traditional Housing	547080.1858097063	10656.953508063109	5313.081876458142	100	0.9711705914909918	2.9639602243078267	15970.03538452125	92	0.019479691980235546	low	168	\N
ODD Cubes Basic	327871.13660507655	3900.8460189586694	12069.18936556258	27.165961745583523	3.681077111737353	2.9639602243078267	15970.03538452125	142	0.011897497472176912	low	168	\N
Container (Base)	238044.53694271998	2832.1342765415343	13137.901107979716	18.118916787867747	5.51909372788549	2.9639602243078267	15970.03538452125	105	0.011897497472176912	low	168	\N
Container (Max)	500433.9163864722	5953.911255199645	10016.124129321604	49.962830923938114	2.0014878690968683	2.9639602243078267	15970.03538452125	91	0.011897497472176912	low	168	\N
Traditional Housing	511704.37437330803	8762.272535469461	21252.234354700304	24.077674179239214	4.153225068816	-4.125792816752223	30014.506890169767	139	0.017123700664472035	middle	169	\N
ODD Cubes Basic	314471.91298522946	5733.059264051592	24281.447626118174	12.951118805905537	7.721340642354492	-4.125792816752223	30014.506890169767	72	0.01823075138771096	middle	169	\N
Container (Base)	227692.07898546645	4150.997684935086	25863.50920523468	8.803603454529766	11.358985047031673	-4.125792816752223	30014.506890169767	142	0.01823075138771096	middle	169	\N
Container (Max)	466303.1908881778	8501.057544378697	21513.449345791072	21.674961713166937	4.61361829946176	-4.125792816752223	30014.506890169767	100	0.01823075138771096	middle	169	\N
Traditional Housing	562313.3673443231	15681.703279928242	-122.83763651749359	100	0	-1.2520732389627365	15558.865643410749	142	0.027887836552755854	low	170	Negative cash flow
ODD Cubes Basic	320307.49891405075	7381.723298739143	8177.142344671606	39.171080239635266	2.5529038103681136	-1.2520732389627365	15558.865643410749	47	0.02304573987111025	low	170	\N
Container (Base)	224952.75238616468	5184.202614781827	10374.663028628922	21.682897243544847	4.6119298024054745	-1.2520732389627365	15558.865643410749	105	0.02304573987111025	low	170	\N
Container (Max)	483743.61662124435	11148.229552963281	4410.636090447468	100	0.9117714299268683	-1.2520732389627365	15558.865643410749	132	0.02304573987111025	low	170	\N
Traditional Housing	511452.32613245375	8009.955602752591	22739.25036482107	22.49204867912884	4.446015630972447	-2.5037503638066685	30749.20596757366	117	0.015661196935642066	middle	171	\N
ODD Cubes Basic	299167.21233655704	5299.725899168665	25449.480068404995	11.755336907961706	8.506774478940843	-2.5037503638066685	30749.20596757366	119	0.017714928911416204	middle	171	\N
Container (Base)	237196.75326345346	4201.923622080808	26547.28234549285	8.93487891440324	11.192093475245377	-2.5037503638066685	30749.20596757366	126	0.017714928911416204	middle	171	\N
Container (Max)	435695.87636012834	7718.321476716857	23030.884490856803	18.917895946770884	5.286000107061013	-2.5037503638066685	30749.20596757366	89	0.017714928911416204	middle	171	\N
Traditional Housing	522515.7577505913	12300.13163898375	3365.257463576596	100	0.6440489906110947	-3.0132862685964765	15665.389102560346	115	0.02354021186257675	low	172	\N
ODD Cubes Basic	312625.05283803114	6718.5177901753505	8946.871312384996	34.94238845318696	2.8618535946382733	-3.0132862685964765	15665.389102560346	48	0.021490657032071474	low	172	\N
Container (Base)	225645.68475102965	4849.274021751298	10816.115080809048	20.861990008907274	4.793406571343568	-3.0132862685964765	15665.389102560346	64	0.021490657032071474	low	172	\N
Container (Max)	425307.8122329241	9140.144325758425	6525.244776801921	65.17882880730356	1.5342405168961026	-3.0132862685964765	15665.389102560346	48	0.021490657032071474	low	172	\N
Traditional Housing	528519.5973029012	11005.461006326066	19042.34572097871	27.75496281010369	3.6029592503578067	3.718741242532918	30047.806727304775	98	0.020823184348297115	middle	173	\N
ODD Cubes Basic	313749.69408049405	5965.590420239808	24082.216307064966	13.028273231996913	7.675614275144617	3.718741242532918	30047.806727304775	107	0.019013852548042026	middle	173	\N
Container (Base)	249642.6409990434	4746.668365659602	25301.13836164517	9.866854108725988	10.134942596502224	3.718741242532918	30047.806727304775	144	0.019013852548042026	middle	173	\N
Container (Max)	480368.5812604734	9133.657372798785	20914.14935450599	22.968592846783757	4.353771285296774	3.718741242532918	30047.806727304775	112	0.019013852548042026	middle	173	\N
Traditional Housing	530457.4149431086	12205.165503032427	3531.873695958906	100	0.6658166322998235	0.8757401027436895	15737.039198991333	142	0.023008756516941946	low	174	\N
ODD Cubes Basic	295348.40336758055	4661.501914239065	11075.537284752269	26.66673370096345	3.7499905733257113	0.8757401027436895	15737.039198991333	45	0.015783061161287262	low	174	\N
Container (Base)	243032.27027185532	3835.7931858671886	11901.246013124144	20.420741660482488	4.896981787567321	0.8757401027436895	15737.039198991333	134	0.015783061161287262	low	174	\N
Container (Max)	437559.153868058	6906.022887180663	8831.01631181067	49.54799520445489	2.018245129542778	0.8757401027436895	15737.039198991333	66	0.015783061161287262	low	174	\N
Traditional Housing	515061.60673813743	5700.879853242426	24576.774964588163	20.957249577305085	4.771618509916086	4.795698110815893	30277.65481783059	120	0.011068345570049083	middle	175	\N
ODD Cubes Basic	355899.3827764297	6827.2168926322765	23450.437925198312	15.176662538741054	6.589063948989622	4.795698110815893	30277.65481783059	105	0.019182997282467962	middle	175	\N
Container (Base)	263799.5756671488	5060.466543139117	25217.18827469147	10.461101879938926	9.55922245550139	4.795698110815893	30277.65481783059	44	0.019182997282467962	middle	175	\N
Container (Max)	516570.92447098467	9909.378640328861	20368.276177501728	25.361543606796513	3.9429776653342783	4.795698110815893	30277.65481783059	124	0.019182997282467962	middle	175	\N
Traditional Housing	580935.352337084	8513.616824888999	21750.830047999993	26.708652086153442	3.744105081657901	-3.427869913183029	30264.44687288899	108	0.014655015899168464	middle	176	\N
ODD Cubes Basic	345433.1434415533	3886.450543230974	26377.996329658017	13.095503506957677	7.636208867178702	-3.427869913183029	30264.44687288899	58	0.011250948604729223	middle	176	\N
Container (Base)	258317.12927022716	2906.3127451405207	27358.13412774847	9.442059464436372	10.590909787917687	-3.427869913183029	30264.44687288899	137	0.011250948604729223	middle	176	\N
Container (Max)	432503.47606937244	4866.074380623245	25398.372492265746	17.02878702960504	5.872408870117823	-3.427869913183029	30264.44687288899	110	0.011250948604729223	middle	176	\N
Traditional Housing	539301.5157168165	6853.340052999931	8966.80163788361	60.14424512730776	1.662669467183922	3.686699141740977	15820.14169088354	123	0.01270780788348196	low	177	\N
ODD Cubes Basic	356287.0473418876	6189.593702227884	9630.547988655657	36.99551134178215	2.703030621097581	3.686699141740977	15820.14169088354	47	0.01737249150202321	low	177	\N
Container (Base)	277423.05016279494	4819.529581418515	11000.612109465026	25.21887395012298	3.9652841041902405	3.686699141740977	15820.14169088354	84	0.01737249150202321	low	177	\N
Container (Max)	478348.4002491213	8310.103518334257	7510.0381725492825	63.69453646688269	1.5699933706558014	3.686699141740977	15820.14169088354	121	0.01737249150202321	low	177	\N
Traditional Housing	561771.4548698589	9282.723386364927	21484.165013391874	26.14816328769054	3.824360391962055	-3.770399480462979	30766.8883997568	96	0.01652402112263853	middle	178	\N
ODD Cubes Basic	355538.03901217587	5716.5896426250965	25050.298757131706	14.192966018457398	7.045743635964034	-3.770399480462979	30766.8883997568	92	0.016078700491536785	middle	178	\N
Container (Base)	232902.35329922236	3744.7671824722806	27022.12121728452	8.618951540719458	11.602339278456206	-3.770399480462979	30766.8883997568	144	0.016078700491536785	middle	178	\N
Container (Max)	413233.5702992446	6644.258809889965	24122.629589866836	17.130535821552023	5.8375290207904325	-3.770399480462979	30766.8883997568	134	0.016078700491536785	middle	178	\N
Traditional Housing	593753.3571276235	13296.108078601852	17355.685267353103	34.21088525063904	2.9230462546458678	3.276955594478215	30651.793345954953	108	0.02239331857073431	middle	179	\N
ODD Cubes Basic	306425.8631074392	7273.155373038151	23378.637972916804	13.107087909159679	7.629459777264223	3.276955594478215	30651.793345954953	41	0.023735448761673338	middle	179	\N
Container (Base)	245429.71814807085	5825.384499695465	24826.40884625949	9.885832448338533	10.115486027360959	3.276955594478215	30651.793345954953	138	0.023735448761673338	middle	179	\N
Container (Max)	505949.1192730977	12008.929396520363	18642.86394943459	27.139023309154297	3.6847309816882348	3.276955594478215	30651.793345954953	140	0.023735448761673338	middle	179	\N
Traditional Housing	590070.4004772814	12910.896806350114	2586.3429742808275	100	0.43831091547531464	2.06883226778716	15497.239780630942	106	0.02188026512752897	low	180	\N
ODD Cubes Basic	321922.59047055274	4242.255999359639	11254.983781271303	28.60267031270569	3.4961770669215686	2.06883226778716	15497.239780630942	131	0.013177876063803889	low	180	\N
Container (Base)	278339.38432309724	3667.9219102852544	11829.317870345687	23.5296225339292	4.249961930150056	2.06883226778716	15497.239780630942	122	0.013177876063803889	low	180	\N
Container (Max)	421811.77467960166	5558.583288980962	9938.656491649981	42.44152869494878	2.3561828019616455	2.06883226778716	15497.239780630942	84	0.013177876063803889	low	180	\N
Traditional Housing	574391.9376980191	17140.814433309202	13322.794524784964	43.11347267492967	2.3194605721971837	4.892037773220528	30463.608958094166	114	0.029841669613268174	middle	181	\N
ODD Cubes Basic	334909.7300010564	6029.56135362111	24434.047604473057	13.706682389361704	7.295711475565665	4.892037773220528	30463.608958094166	114	0.018003541890532986	middle	181	\N
Container (Base)	247696.2053193024	4459.40900859212	26004.199949502046	9.525238453800057	10.498424841018588	4.892037773220528	30463.608958094166	41	0.018003541890532986	middle	181	\N
Container (Max)	459987.6240771853	8281.406459200345	22182.20249889382	20.736787706275962	4.822347675852183	4.892037773220528	30463.608958094166	75	0.018003541890532986	middle	181	\N
Traditional Housing	601751.557986371	10887.277770873601	19181.684969578208	31.37115216628454	3.187641928799568	2.587832191820281	30068.96274045181	86	0.01809264575451284	middle	182	\N
ODD Cubes Basic	323767.1487777845	8026.723545397313	22042.2391950545	14.688487222769382	6.808053033874368	2.587832191820281	30068.96274045181	135	0.02479165528589932	middle	182	\N
Container (Base)	253253.74190865157	6278.5794692634045	23790.383271188406	10.64521487618727	9.393892106743117	2.587832191820281	30068.96274045181	138	0.02479165528589932	middle	182	\N
Container (Max)	451213.294545365	11186.324458783645	18882.638281668165	23.89567007611518	4.1848585823903965	2.587832191820281	30068.96274045181	91	0.02479165528589932	middle	182	\N
Traditional Housing	536524.0090479777	10844.247991321008	19258.035054043426	27.859748283889893	3.5894078791022586	1.2306624521339362	30102.283045364435	100	0.020212046075185574	middle	183	\N
ODD Cubes Basic	311303.78162783507	5940.9382933900015	24161.344751974433	12.884373151556298	7.761339944421048	1.2306624521339362	30102.283045364435	118	0.01908405436748731	middle	183	\N
Container (Base)	275355.24549638096	5254.89447542575	24847.388569938685	11.081858551104087	9.023757119696947	1.2306624521339362	30102.283045364435	96	0.01908405436748731	middle	183	\N
Container (Max)	412390.0957230699	7870.075007392363	22232.208037972072	18.549218998792995	5.391062556677293	1.2306624521339362	30102.283045364435	61	0.01908405436748731	middle	183	\N
Traditional Housing	517508.93499436334	11477.891243074328	4156.9185975185555	100	0.8032554254476462	2.4165574455146572	15634.809840592883	101	0.02217911704886669	low	184	\N
ODD Cubes Basic	329421.2014469636	2719.2055406016375	12915.604299991246	25.505674670382003	3.920696131050522	2.4165574455146572	15634.809840592883	88	0.00825449463682873	low	184	\N
Container (Base)	270697.5295539676	2234.471305906012	13400.33853468687	20.200797827104527	4.950299530537575	2.4165574455146572	15634.809840592883	41	0.00825449463682873	low	184	\N
Container (Max)	463408.52486517926	3825.2031831603354	11809.606657432549	39.23996271065695	2.5484224013505905	2.4165574455146572	15634.809840592883	108	0.00825449463682873	low	184	\N
Traditional Housing	538901.1357855123	14744.359077908572	16099.224850637496	33.473731858846165	2.9874171311906714	-4.868351006313665	30843.583928546068	126	0.027360044540297584	middle	185	\N
ODD Cubes Basic	297117.08989385935	4857.823495036211	25985.76043350986	11.433842417430775	8.745966259562142	-4.868351006313665	30843.583928546068	46	0.016349862260604385	middle	185	\N
Container (Base)	241268.9394656623	3944.7139280256756	26898.870000520394	8.969482341116732	11.148915421974023	-4.868351006313665	30843.583928546068	102	0.016349862260604385	middle	185	\N
Container (Max)	457443.6201908714	7479.140182112975	23364.44374643309	19.578622335518112	5.107611673911666	-4.868351006313665	30843.583928546068	138	0.016349862260604385	middle	185	\N
Traditional Housing	527803.6580945741	6039.823745066306	24811.689218622894	21.272379056659343	4.700931651022591	-2.1761521197636413	30851.5129636892	117	0.011443315430724174	middle	186	\N
ODD Cubes Basic	306376.2277294481	6168.664594377231	24682.84836931197	12.412515085186188	8.056384972240298	-2.1761521197636413	30851.5129636892	102	0.02013427947753374	middle	186	\N
Container (Base)	242909.60707834273	4890.809916693261	25960.703046995943	9.356819291011117	10.687392466376657	-2.1761521197636413	30851.5129636892	69	0.02013427947753374	middle	186	\N
Container (Max)	461208.21432169003	9286.095084487186	21565.417879202018	21.386472402488685	4.675852946573988	-2.1761521197636413	30851.5129636892	118	0.02013427947753374	middle	186	\N
Traditional Housing	566446.06126616	11483.434264460915	4301.339725759877	100	0.7593555714987621	-2.409885274430498	15784.773990220792	119	0.020272776261860373	low	187	\N
ODD Cubes Basic	329475.8804434096	7731.573354309978	8053.2006359108145	40.91241424859223	2.4442458807827734	-2.409885274430498	15784.773990220792	111	0.023466280274916644	low	187	\N
Container (Base)	226533.67085762016	5315.902612050631	10468.87137817016	21.638786328962965	4.62133127430315	-2.409885274430498	15784.773990220792	64	0.023466280274916644	low	187	\N
Container (Max)	407338.43786742963	9558.717949743823	6226.056040476969	65.42479464033607	1.5284725087749444	-2.409885274430498	15784.773990220792	98	0.023466280274916644	low	187	\N
Traditional Housing	592704.670870549	6057.47120319111	9419.788491993073	62.921229215959016	1.5892887225196883	-1.944448292674358	15477.259695184184	140	0.010220049715980905	low	188	\N
ODD Cubes Basic	311719.48086211045	7682.405464910456	7794.854230273728	39.99041824944608	2.5005990028970286	-1.944448292674358	15477.259695184184	144	0.024645252980864483	low	188	\N
Container (Base)	242803.66622596755	5983.957778820351	9493.301916363833	25.576313527692722	3.9098676160551875	-1.944448292674358	15477.259695184184	144	0.024645252980864483	low	188	\N
Container (Max)	465885.99230148154	11481.878140511095	3995.3815546730893	100	0.8575878263555133	-1.944448292674358	15477.259695184184	67	0.024645252980864483	low	188	\N
Traditional Housing	551319.8874878632	14688.470528919903	16243.721038523307	33.94049221729203	2.9463332281625516	0.9627103487483311	30932.19156744321	147	0.026642373805612546	middle	189	\N
ODD Cubes Basic	331527.90163848177	3037.630146261099	27894.56142118211	11.88503725270015	8.41394081261976	0.9627103487483311	30932.19156744321	77	0.009162517336394558	middle	189	\N
Container (Base)	274057.25779626175	2511.054375723001	28421.13719172021	9.642726677245747	10.37051068096467	0.9627103487483311	30932.19156744321	115	0.009162517336394558	middle	189	\N
Container (Max)	471463.74002703984	4319.794691479169	26612.39687596404	17.715944273056426	5.644632792850144	0.9627103487483311	30932.19156744321	46	0.009162517336394558	middle	189	\N
Traditional Housing	564608.755486168	8142.163134356826	7474.582389246303	75.53716396229329	1.3238516612818305	-2.8755649252808926	15616.74552360313	137	0.014420894212569993	low	190	\N
ODD Cubes Basic	303579.0583073106	4642.649577410267	10974.095946192861	27.663240762226835	3.6149054573731085	-2.8755649252808926	15616.74552360313	102	0.015293049538056575	low	190	\N
Container (Base)	244798.4336565858	3743.714572748823	11873.030950854307	20.61802371019438	4.850125376010504	-2.8755649252808926	15616.74552360313	100	0.015293049538056575	low	190	\N
Container (Max)	408489.5780155429	6247.0513523715235	9369.694171231606	43.59689553899801	2.2937413034501195	-2.8755649252808926	15616.74552360313	45	0.015293049538056575	low	190	\N
Traditional Housing	563576.9636658104	12796.403709880651	2946.91558491823	100	0.5228949681956288	3.6530228145556105	15743.319294798881	114	0.02270568979016796	low	191	\N
ODD Cubes Basic	332888.2275019378	7012.825125026003	8730.49416977288	38.129368284154964	2.6226503217876806	3.6530228145556105	15743.319294798881	130	0.021066605982589696	low	191	\N
Container (Base)	259254.2167980291	5461.606434608966	10281.712860189915	25.215080436825232	3.9658806661570485	3.6530228145556105	15743.319294798881	140	0.021066605982589696	low	191	\N
Container (Max)	431609.8232509837	9092.554084643654	6650.765210155227	64.89626525861226	1.5409207232727338	3.6530228145556105	15743.319294798881	119	0.021066605982589696	low	191	\N
Traditional Housing	587458.5607103035	14846.380123766503	16103.55585305416	36.480052360540455	2.7412241356365885	4.769688592821389	30949.935976820663	137	0.02527221682805262	middle	192	\N
ODD Cubes Basic	337282.0509997456	4095.718291127067	26854.217685693595	12.559742195708436	7.961946864973806	4.769688592821389	30949.935976820663	102	0.012143303442880678	middle	192	\N
Container (Base)	278540.542760747	3382.402331888432	27567.53364493223	10.103934082327724	9.897135035243835	4.769688592821389	30949.935976820663	118	0.012143303442880678	middle	192	\N
Container (Max)	447581.08788627037	5435.112965497626	25514.82301132304	17.542002454323967	5.700603466473166	4.769688592821389	30949.935976820663	101	0.012143303442880678	middle	192	\N
Traditional Housing	509642.31451198616	9641.348809999998	20623.465274203234	24.711769226749198	4.046654817889576	0.27023225905909865	30264.814084203234	123	0.018917873448620885	middle	193	\N
ODD Cubes Basic	355786.08364085597	3624.349593679818	26640.464490523416	13.35510061273206	7.487775861805577	0.27023225905909865	30264.814084203234	127	0.010186878465258845	middle	193	\N
Container (Base)	236615.53734696124	2410.3737219454097	27854.440362257825	8.494715178969106	11.772025064192409	0.27023225905909865	30264.814084203234	58	0.010186878465258845	middle	193	\N
Container (Max)	469216.6705028641	4779.853196286082	25484.96088791715	18.411512286264784	5.431384366758468	0.27023225905909865	30264.814084203234	81	0.010186878465258845	middle	193	\N
Traditional Housing	584841.052815601	7836.7070455103685	8044.428297857762	72.70138177144852	1.3754896752082402	3.909498239120598	15881.13534336813	139	0.013399721185409438	low	194	\N
ODD Cubes Basic	330672.38541082357	4427.518621395108	11453.616721973023	28.870564943599867	3.463735475746843	3.909498239120598	15881.13534336813	97	0.013389441685293466	low	194	\N
Container (Base)	268981.3777117576	3601.5104713014744	12279.624872066655	21.904690128085985	4.565232350481002	3.909498239120598	15881.13534336813	148	0.013389441685293466	low	194	\N
Container (Max)	496822.52246965014	6652.176192547783	9228.959150820348	53.832996153795776	1.8575967741849158	3.909498239120598	15881.13534336813	108	0.013389441685293466	low	194	\N
Traditional Housing	596665.726347433	15093.680278196536	15722.470428078263	37.94987111452069	2.635055062459413	-0.47543598841387613	30816.1507062748	133	0.02529671072376566	middle	195	\N
ODD Cubes Basic	329515.6480547315	5631.721611722605	25184.429094552193	13.084102356166222	7.642862863486574	-0.47543598841387613	30816.1507062748	47	0.017090907958298825	middle	195	\N
Container (Base)	255326.10726860014	4363.754998678378	26452.39570759642	9.652286699887727	10.36023929968462	-0.47543598841387613	30816.1507062748	91	0.017090907958298825	middle	195	\N
Container (Max)	433706.0411433611	7412.430030139347	23403.720676135454	18.53149963397089	5.396217358291161	-0.47543598841387613	30816.1507062748	137	0.017090907958298825	middle	195	\N
Traditional Housing	559088.955708457	9615.116871068894	20862.8451973507	26.798308208673944	3.731578845250854	-2.9993373874730036	30477.962068419594	128	0.01719783010001507	middle	196	\N
ODD Cubes Basic	319212.7137874914	7537.4615959995535	22940.50047242004	13.91481036655069	7.186587338652231	-2.9993373874730036	30477.962068419594	95	0.023612660995130187	middle	196	\N
Container (Base)	222464.4475887626	5252.977584382358	25224.984484037235	8.819210482747435	11.338883474390913	-2.9993373874730036	30477.962068419594	116	0.023612660995130187	middle	196	\N
Container (Max)	421134.7947090226	9944.113140717896	20533.8489277017	20.50929643983502	4.875837661879561	-2.9993373874730036	30477.962068419594	45	0.023612660995130187	middle	196	\N
Traditional Housing	597256.1930889455	10244.242501053233	5337.289993257555	100	0.8936349350608922	-3.839398672700268	15581.532494310788	104	0.01715217459373858	low	197	\N
ODD Cubes Basic	320567.7994962472	2794.0505658547677	12787.48192845602	25.068876053141217	3.9890101091097643	-3.839398672700268	15581.532494310788	112	0.008715942681222033	low	197	\N
Container (Base)	224390.12328262383	1955.7714527636947	13625.761041547094	16.468080028588712	6.072353293547228	-3.839398672700268	15581.532494310788	44	0.008715942681222033	low	197	\N
Container (Max)	442618.72955656424	3857.8394764503305	11723.693017860458	37.75420670621935	2.6487114609013025	-3.839398672700268	15581.532494310788	122	0.008715942681222033	low	197	\N
Traditional Housing	504413.61703062605	10591.761958897188	5347.326990651925	94.33004899689702	1.060107580388191	3.236072239067841	15939.088949549114	113	0.020998168172478376	low	198	\N
ODD Cubes Basic	339063.47062389797	4241.177872037412	11697.9110775117	28.984958799671542	3.4500652801042864	3.236072239067841	15939.088949549114	108	0.012508507225014183	low	198	\N
Container (Base)	262348.84752028645	3281.5924546816473	12657.496494867466	20.72675648195259	4.8246815697899	3.236072239067841	15939.088949549114	81	0.012508507225014183	low	198	\N
Container (Max)	494003.70959242556	6179.248970620663	9759.83997892845	50.615964058732764	1.975661273268725	3.236072239067841	15939.088949549114	147	0.012508507225014183	low	198	\N
Traditional Housing	591970.4533080405	11945.306656800223	3684.0994489574805	100	0.6223451573250067	-0.12475671251601295	15629.406105757704	120	0.02017888999366039	low	199	\N
ODD Cubes Basic	353949.9140723012	5092.446297401564	10536.95980835614	33.59127495120631	2.9769635164267223	-0.12475671251601295	15629.406105757704	97	0.014387477139947355	low	199	\N
Container (Base)	253187.06573386054	3642.7231203762667	11986.682985381438	21.122362712239834	4.734318852599417	-0.12475671251601295	15629.406105757704	97	0.014387477139947355	low	199	\N
Container (Max)	470710.6166025654	6772.338235899933	8857.06786985777	53.14519697929381	1.881637583147195	-0.12475671251601295	15629.406105757704	109	0.014387477139947355	low	199	\N
Traditional Housing	500098.18495371146	11382.281728499449	19243.82041434147	25.987468921764254	3.848008449805243	-3.2069555681902884	30626.10214284092	84	0.02276009405943551	middle	200	\N
ODD Cubes Basic	304845.30178444623	4933.995742263408	25692.10640057751	11.86532925839019	8.427916143101397	-3.2069555681902884	30626.10214284092	99	0.016185244494114587	middle	200	\N
Container (Base)	236608.13104088217	3829.560450192181	26796.541692648738	8.829801015173251	11.325283528831354	-3.2069555681902884	30626.10214284092	138	0.016185244494114587	middle	200	\N
Container (Max)	406413.4893133559	6577.901690242891	24048.200452598026	16.89995432774469	5.917175754482944	-3.2069555681902884	30626.10214284092	89	0.016185244494114587	middle	200	\N
Traditional Housing	581670.018161975	8165.650933950259	7410.578614097478	78.49184907848327	1.2740176358950461	3.2078476113587815	15576.229548047737	80	0.014038287480852087	low	201	\N
ODD Cubes Basic	337918.9895252272	7381.504394429443	8194.725153618294	41.236159015781354	2.4250561251771616	3.2078476113587815	15576.229548047737	110	0.021844005880818897	low	201	\N
Container (Base)	269153.7960468664	5879.3971036924795	9696.832444355257	27.756878093067066	3.6027106385922187	3.2078476113587815	15576.229548047737	57	0.021844005880818897	low	201	\N
Container (Max)	432667.793641859	9451.197828753706	6125.031719294031	70.63927396146255	1.4156430890633909	3.2078476113587815	15576.229548047737	75	0.021844005880818897	low	201	\N
Traditional Housing	561560.0457897985	10195.668697407285	20110.095256932196	27.92428571894615	3.581112190531402	0.8417683253946775	30305.763954339483	110	0.018155972409090688	middle	202	\N
ODD Cubes Basic	348470.00013461127	4251.066797282131	26054.69715705735	13.37455576758536	7.476883848535778	0.8417683253946775	30305.763954339483	108	0.012199233206990491	middle	202	\N
Container (Base)	237098.01529669727	2892.4139815190088	27413.349972820473	8.648998226476259	11.562032663376048	0.8417683253946775	30305.763954339483	115	0.012199233206990491	middle	202	\N
Container (Max)	474481.5278329449	5788.310810443244	24517.45314389624	19.352806551649095	5.167209196925434	0.8417683253946775	30305.763954339483	130	0.012199233206990491	middle	202	\N
Traditional Housing	560750.7580946992	14609.965453231765	1011.9989472584712	100	0.18047214964042285	1.704690539624477	15621.964400490237	113	0.02605429460830875	low	203	\N
ODD Cubes Basic	321429.9786058946	7124.325934525464	8497.638465964774	37.82580064959274	2.6436981711602363	1.704690539624477	15621.964400490237	125	0.02216447254056723	low	203	\N
Container (Base)	242433.28646362876	5373.405920742569	10248.558479747668	23.655354745031204	4.227372663730819	1.704690539624477	15621.964400490237	92	0.02216447254056723	low	203	\N
Container (Max)	454554.92820592446	10074.970224399722	5546.994176090515	81.94617008346884	1.2203132849057114	1.704690539624477	15621.964400490237	107	0.02216447254056723	low	203	\N
Traditional Housing	535744.9836804629	9281.812441623935	6541.837075231691	81.8951889995653	1.221072949725176	-0.46734233415052806	15823.649516855627	109	0.01732505711553229	low	204	\N
ODD Cubes Basic	327367.6223943029	5510.777602599932	10312.871914255695	31.743594327180183	3.1502418714561204	-0.46734233415052806	15823.649516855627	58	0.016833606091815615	low	204	\N
Container (Base)	256917.38777678207	4324.8461039725935	11498.803412883033	22.34296722465373	4.475681273419125	-0.46734233415052806	15823.649516855627	40	0.016833606091815615	low	204	\N
Container (Max)	409138.324962646	6887.273399486435	8936.376117369193	45.783471911776864	2.184194335298478	-0.46734233415052806	15823.649516855627	126	0.016833606091815615	low	204	\N
Traditional Housing	522246.2087417663	14626.475413629623	1119.9228278632236	100	0.21444345772493467	-0.6157542125575972	15746.398241492847	105	0.028006858008349733	low	205	\N
ODD Cubes Basic	326796.7894466332	4364.923266214186	11381.474975278661	28.713043797614816	3.4827376959703233	-0.6157542125575972	15746.398241492847	134	0.013356689561134717	low	205	\N
Container (Base)	230927.07114384885	3084.42120053046	12661.977040962387	18.237836824121818	5.483106410280933	-0.6157542125575972	15746.398241492847	70	0.013356689561134717	low	205	\N
Container (Max)	484395.08739177947	6469.91480723072	9276.483434262127	52.21753381272646	1.9150655478797813	-0.6157542125575972	15746.398241492847	60	0.013356689561134717	low	205	\N
Traditional Housing	522903.65632665163	10403.273971076478	20456.604982020806	25.56160500660929	3.912117411021087	-2.2956172685418785	30859.878953097286	114	0.019895202194910026	middle	206	\N
ODD Cubes Basic	339736.2999508075	6416.163804470549	24443.71514862674	13.8987178456747	7.194908272141099	-2.2956172685418785	30859.878953097286	103	0.018885717556232834	middle	206	\N
Container (Base)	234985.1083124896	4437.862385510459	26422.016567586827	8.893534212704918	11.244123832923961	-2.2956172685418785	30859.878953097286	115	0.018885717556232834	middle	206	\N
Container (Max)	408136.2675370679	7707.946273160143	23151.93267993714	17.628604625770535	5.672598717984412	-2.2956172685418785	30859.878953097286	67	0.018885717556232834	middle	206	\N
Traditional Housing	592307.130271024	10787.114872370745	19935.706626350042	29.710867107571765	3.3657718449595557	4.798648279782489	30722.821498720787	92	0.018212029403452984	middle	207	\N
ODD Cubes Basic	332255.14355646237	4293.060609425303	26429.760889295485	12.57125045315985	7.954658160108844	4.798648279782489	30722.821498720787	81	0.012920975619737107	middle	207	\N
Container (Base)	266981.33820941777	3449.6593619286737	27273.162136792114	9.789159646040966	10.215381464377593	4.798648279782489	30722.821498720787	147	0.012920975619737107	middle	207	\N
Container (Max)	463696.17665929504	5991.406993580062	24731.414505140725	18.749278435445337	5.333538586261055	4.798648279782489	30722.821498720787	48	0.012920975619737107	middle	207	\N
Traditional Housing	515010.7647716009	12754.88190324599	17251.733951941635	29.852695746773783	3.3497812341053694	3.1738890961857535	30006.615855187625	87	0.024766243301540654	middle	208	\N
ODD Cubes Basic	330183.91496702225	6752.086813545182	23254.529041642443	14.198692838532828	7.0429018457682995	3.1738890961857535	30006.615855187625	138	0.020449472271293286	middle	208	\N
Container (Base)	236749.4230979548	4841.400762886309	25165.215092301318	9.40780447254681	10.629472614127232	3.1738890961857535	30006.615855187625	146	0.020449472271293286	middle	208	\N
Container (Max)	475075.72345786396	9715.047833616187	20291.56802157144	23.412469797938893	4.271228147352633	3.1738890961857535	30006.615855187625	100	0.020449472271293286	middle	208	\N
Traditional Housing	581404.2614094627	6375.687856138427	23951.344266354005	24.27438956844684	4.119568062382314	0.4320872813775143	30327.03212249243	115	0.010966015007668225	middle	209	\N
ODD Cubes Basic	321254.57509457617	7824.962637675198	22502.06948481723	14.276667988752568	7.004435494247111	0.4320872813775143	30327.03212249243	96	0.024357513462248927	middle	209	\N
Container (Base)	264991.0568959529	6454.523235718744	23872.508886773685	11.100260058663899	9.008797944508398	0.4320872813775143	30327.03212249243	96	0.024357513462248927	middle	209	\N
Container (Max)	472522.6701112656	11509.47729845296	18817.55482403947	25.11073699690338	3.9823602155656306	0.4320872813775143	30327.03212249243	147	0.024357513462248927	middle	209	\N
Traditional Housing	584384.9095894002	13133.008524164565	16941.849650967903	34.493571931563785	2.899090885641035	0.9514114170543087	30074.858175132467	106	0.022473216383003564	middle	210	\N
ODD Cubes Basic	314645.95985956915	5301.422487911093	24773.435687221376	12.700941598579712	7.873431999024587	0.9514114170543087	30074.858175132467	101	0.016848849704846652	middle	210	\N
Container (Base)	247423.33133453818	4168.798523128109	25906.05965200436	9.550789840607619	10.470338230543456	0.9514114170543087	30074.858175132467	54	0.016848849704846652	middle	210	\N
Container (Max)	449528.9876226971	7574.0463504266945	22500.811824705772	19.97834527592985	5.005419548959402	0.9514114170543087	30074.858175132467	70	0.016848849704846652	middle	210	\N
Traditional Housing	553026.719986662	10248.262748091087	20481.405933094917	27.001404190376054	3.7035110950134364	-2.577889996362097	30729.668681186005	125	0.018531225305602333	middle	211	\N
ODD Cubes Basic	320812.96085377736	4230.550109970905	26499.1185712151	12.106552147823637	8.259990026803523	-2.577889996362097	30729.668681186005	148	0.013186967567370629	middle	211	\N
Container (Base)	241644.35376581876	3186.556255948087	27543.11242523792	8.773313271030277	11.39820235648062	-2.577889996362097	30729.668681186005	138	0.013186967567370629	middle	211	\N
Container (Max)	460091.2761358732	6067.208736433924	24662.45994475208	18.655530598592048	5.36034070280194	-2.577889996362097	30729.668681186005	48	0.013186967567370629	middle	211	\N
Traditional Housing	588602.7297167891	6983.25322573594	8816.92726091187	66.75826082021166	1.4979419591129326	0.1791346466743402	15800.18048664781	96	0.011864119673885964	low	212	\N
ODD Cubes Basic	330223.6837840644	6854.0029051431775	8946.177581504633	36.91226568839526	2.70912657717022	0.1791346466743402	15800.18048664781	107	0.020755636987034094	low	212	\N
Container (Base)	265997.59084125864	5520.94943492679	10279.23105172102	25.877187651767343	3.864407575727043	0.1791346466743402	15800.18048664781	91	0.020755636987034094	low	212	\N
Container (Max)	425094.10264226416	8823.098879771846	6977.081606875965	60.927208049756906	1.6413028464776172	0.1791346466743402	15800.18048664781	53	0.020755636987034094	low	212	\N
Traditional Housing	582211.4835928835	15524.627717942247	26.718855010731204	100	0.004589200962826525	-3.8674527887546706	15551.346572952978	139	0.026664928733693583	low	213	\N
ODD Cubes Basic	297705.1148029935	5203.235248300833	10348.111324652145	28.769029000854985	3.475960206965209	-3.8674527887546706	15551.346572952978	80	0.017477816099142524	low	213	\N
Container (Base)	261964.3392112665	4578.564545267906	10972.782027685073	23.87401285747887	4.188654860704475	-3.8674527887546706	15551.346572952978	75	0.017477816099142524	low	213	\N
Container (Max)	457187.4973529802	7990.6390015625975	7560.7075713903805	60.46887715681159	1.6537432924490045	-3.8674527887546706	15551.346572952978	101	0.017477816099142524	low	213	\N
Traditional Housing	539172.8006088655	15607.008409955084	14583.81265494521	36.97063404239754	2.7048494728362256	-0.14881127823696438	30190.821064900294	130	0.02894620869660105	middle	214	\N
ODD Cubes Basic	314651.041838264	4991.840166740502	25198.980898159793	12.486657421183331	8.008548375032078	-0.14881127823696438	30190.821064900294	147	0.01586468659876993	middle	214	\N
Container (Base)	238331.13386928826	3781.0487455657394	26409.772319334556	9.024353977289172	11.081125613164284	-0.14881127823696438	30190.821064900294	77	0.01586468659876993	middle	214	\N
Container (Max)	465458.02750698826	7384.345731280002	22806.475333620292	20.409029483869027	4.899792029750284	-0.14881127823696438	30190.821064900294	54	0.01586468659876993	middle	214	\N
Traditional Housing	553641.4929511006	6970.539614169588	8848.22716664362	62.57089499671065	1.598187144442428	3.285807769748274	15818.76678081321	116	0.01259034899464309	low	215	\N
ODD Cubes Basic	341086.29627301096	4819.2084968801955	10999.558283933015	31.00909031694787	3.2248608062309225	3.285807769748274	15818.76678081321	77	0.014129000635730096	low	215	\N
Container (Base)	275202.83970006765	3888.3410970769837	11930.425683736226	23.067311007622234	4.335139018455882	3.285807769748274	15818.76678081321	123	0.014129000635730096	low	215	\N
Container (Max)	438658.9925618633	6197.81318477529	9620.95359603792	45.59412829332333	2.193264872982421	3.285807769748274	15818.76678081321	87	0.014129000635730096	low	215	\N
Traditional Housing	598847.8244705778	17155.765386199622	-1436.186891273026	100	0	3.3312264553036144	15719.578494926596	139	0.028647954764411954	low	216	Negative cash flow
ODD Cubes Basic	338161.01262793405	7056.545182578402	8663.033312348194	39.03494312389668	2.561807242362326	3.3312264553036144	15719.578494926596	63	0.0208674120287854	low	216	\N
Container (Base)	240760.2414504479	5024.0431584963535	10695.535336430243	22.510349774675646	4.442400984479635	3.3312264553036144	15719.578494926596	116	0.0208674120287854	low	216	\N
Container (Max)	433253.02743780083	9040.869436263256	6678.70905866334	64.87077422182409	1.5415262296400587	3.3312264553036144	15719.578494926596	59	0.0208674120287854	low	216	\N
Traditional Housing	586254.3886002449	6389.570776033989	24256.215100405032	24.169244301863714	4.137489726655993	-4.4648940333720155	30645.785876439022	100	0.010898973040167566	middle	217	\N
ODD Cubes Basic	329181.2714448132	3260.4202103920857	27385.365666046935	12.020335074544592	8.319235643586138	-4.4648940333720155	30645.785876439022	115	0.009904634598687036	middle	217	\N
Container (Base)	224740.49992602575	2225.972531293536	28419.813345145485	7.907880927881417	12.645612764277015	-4.4648940333720155	30645.785876439022	99	0.009904634598687036	middle	217	\N
Container (Max)	414372.24894456554	4104.205713632102	26541.58016280692	15.612192130340116	6.40525040719067	-4.4648940333720155	30645.785876439022	116	0.009904634598687036	middle	217	\N
Traditional Housing	512997.6402158175	5371.413692145221	10334.646968008361	49.63862256774115	2.0145603328039847	-1.608081659726488	15706.060660153582	100	0.01047064015710769	low	218	\N
ODD Cubes Basic	319130.2299462589	3139.203233269799	12566.857426883784	25.394593023993107	3.9378461354162613	-1.608081659726488	15706.060660153582	115	0.009836746690523292	low	218	\N
Container (Base)	257033.32698122674	2528.3717285367734	13177.688931616809	19.505190046225394	5.1268405877107455	-1.608081659726488	15706.060660153582	148	0.009836746690523292	low	218	\N
Container (Max)	405286.157629943	3986.697269781243	11719.363390372338	34.58260863921095	2.8916268591322103	-1.608081659726488	15706.060660153582	95	0.009836746690523292	low	218	\N
Traditional Housing	499692.3855643016	13154.228097967301	2365.6640208766676	100	0.4734240683305846	-0.013031190797899939	15519.892118843969	95	0.026324651881801754	low	219	\N
ODD Cubes Basic	354842.25974808837	6995.912542104774	8523.979576739195	41.62870834608821	2.4021883928905727	-0.013031190797899939	15519.892118843969	140	0.019715556278644353	low	219	\N
Container (Base)	231822.12179563098	4570.502088896508	10949.39002994746	21.172149422166793	4.723186012247869	-0.013031190797899939	15519.892118843969	69	0.019715556278644353	low	219	\N
Container (Max)	407973.0858886976	8043.416335010824	7476.475783833145	54.56756601430897	1.832590443447258	-0.013031190797899939	15519.892118843969	48	0.019715556278644353	low	219	\N
Traditional Housing	496203.40619353415	5348.835611905694	10380.473693643275	47.80161492027054	2.0919795317959946	-2.624117038482031	15729.30930554897	80	0.010779522157934339	low	220	\N
ODD Cubes Basic	309555.53520620585	4582.075570725396	11147.233734823574	27.769717812515676	3.6010448746774983	-2.624117038482031	15729.30930554897	140	0.014802111574820052	low	220	\N
Container (Base)	242150.92980645818	3584.3450809416127	12144.964224607356	19.938381482905264	5.015452236468533	-2.624117038482031	15729.30930554897	74	0.014802111574820052	low	220	\N
Container (Max)	396069.9576297599	5862.6717042699565	9866.637601279013	40.14234368741965	2.4911350662203455	-2.624117038482031	15729.30930554897	109	0.014802111574820052	low	220	\N
Traditional Housing	505997.33497139165	9486.230838970554	6415.992555603374	78.8650127920553	1.2679893968149307	-2.3304908414320655	15902.223394573928	147	0.0187475905174617	low	221	\N
ODD Cubes Basic	348190.3908597998	5841.72334862943	10060.500045944498	34.60965054119346	2.8893675156002216	-2.3304908414320655	15902.223394573928	42	0.01677738243782156	low	221	\N
Container (Base)	240932.1758975608	4042.2112566098717	11860.012137964057	20.314665203953183	4.922552205317184	-2.3304908414320655	15902.223394573928	70	0.01677738243782156	low	221	\N
Container (Max)	441650.13167971023	7409.73316290475	8492.490231669177	52.00478536116079	1.9228999659459016	-2.3304908414320655	15902.223394573928	84	0.01677738243782156	low	221	\N
Traditional Housing	597761.2604915017	11472.010131432444	4299.090483174399	100	0.7191985776461202	4.547436351492246	15771.100614606843	130	0.01919162530204739	low	222	\N
ODD Cubes Basic	335227.2042313094	7171.458233603382	8599.642381003461	38.98152846120945	2.565317573411984	4.547436351492246	15771.100614606843	49	0.02139282893238885	low	222	\N
Container (Base)	263077.90988635947	5627.980722089297	10143.119892517545	25.936586836603283	3.855557426657001	4.547436351492246	15771.100614606843	58	0.02139282893238885	low	222	\N
Container (Max)	438376.95298563916	9378.123163123648	6392.977451483195	68.57164072805138	1.458328821335784	4.547436351492246	15771.100614606843	109	0.02139282893238885	low	222	\N
Traditional Housing	511359.85294686106	9489.482496602317	6186.85853030418	82.65258538596643	1.2098835085802286	1.3466074459800232	15676.341026906497	97	0.018557347515485215	low	223	\N
ODD Cubes Basic	347214.64109499607	7158.2642886788335	8518.076738227664	40.76209357644742	2.453259664213631	1.3466074459800232	15676.341026906497	109	0.0206162512793358	low	223	\N
Container (Base)	264125.6821850723	5445.281433253437	10231.059593653059	25.816063308723695	3.873557281144731	1.3466074459800232	15676.341026906497	102	0.0206162512793358	low	223	\N
Container (Max)	498769.3989758306	10282.755259729016	5393.585767177481	92.47454671270421	1.0813786447710365	1.3466074459800232	15676.341026906497	140	0.0206162512793358	low	223	\N
Traditional Housing	597873.8870735728	16634.378080418097	13696.547595866214	43.65142988690219	2.290875700042198	-3.282540515202965	30330.92567628431	85	0.027822553284336887	middle	224	\N
ODD Cubes Basic	310131.9195148322	4048.7892822145063	26282.136394069803	11.800103114327081	8.474502216729372	-3.282540515202965	30330.92567628431	64	0.013055055050600398	middle	224	\N
Container (Base)	231887.81465176365	3027.308185842196	27303.617490442113	8.492933756229853	11.774494287871565	-3.282540515202965	30330.92567628431	58	0.013055055050600398	middle	224	\N
Container (Max)	460280.21032286005	6008.983484466868	24321.94219181744	18.9244841835744	5.284159876166955	-3.282540515202965	30330.92567628431	117	0.013055055050600398	middle	224	\N
Traditional Housing	514952.1797886103	6419.8452470316915	9344.674713488002	55.10648530604644	1.814668445004743	3.197890785019979	15764.519960519694	139	0.012466876535345594	low	225	\N
ODD Cubes Basic	332131.284049688	7106.89777932099	8657.622181198705	38.36287575253166	2.606686752189081	3.197890785019979	15764.519960519694	129	0.021397857174627888	low	225	\N
Container (Base)	264966.9780776757	5669.725552898863	10094.794407620831	26.247882559910778	3.8098311272061682	3.197890785019979	15764.519960519694	135	0.021397857174627888	low	225	\N
Container (Max)	449124.2232901191	9610.295983627651	6154.223976892043	72.97820569685086	1.3702721113122018	3.197890785019979	15764.519960519694	75	0.021397857174627888	low	225	\N
Traditional Housing	517885.3481821661	12004.229655027542	18374.855308061473	28.18445857121704	3.54805467514368	-0.8666161241597834	30379.084963089015	126	0.02317931893065462	middle	226	\N
ODD Cubes Basic	305486.89389279136	3300.517275451016	27078.567687638	11.281501201123474	8.864068550561468	-0.8666161241597834	30379.084963089015	58	0.01080412070512364	middle	226	\N
Container (Base)	267629.61576087	2891.5026729462998	27487.582290142716	9.736382521239209	10.270755055263828	-0.8666161241597834	30379.084963089015	112	0.01080412070512364	middle	226	\N
Container (Max)	406348.0890661628	4390.233802567155	25988.85116052186	15.635477172743302	6.395711425700903	-0.8666161241597834	30379.084963089015	102	0.01080412070512364	middle	226	\N
Traditional Housing	547643.2264639147	11560.82428996496	3926.6868744733983	100	0.7170155102305708	-3.6913764733827756	15487.511164438358	140	0.021110138373503146	low	227	\N
ODD Cubes Basic	355980.2335512012	4604.3963865266505	10883.114777911707	32.709407262128316	3.057224461409982	-3.6913764733827756	15487.511164438358	144	0.012934415882011024	low	227	\N
Container (Base)	249212.3298891279	3223.415917710907	12264.095246727451	20.3204822594335	4.921143047851455	-3.6913764733827756	15487.511164438358	98	0.012934415882011024	low	227	\N
Container (Max)	461138.41157952644	5964.5559945395635	9522.955169898794	48.423877184379016	2.0650969276838254	-3.6913764733827756	15487.511164438358	85	0.012934415882011024	low	227	\N
Traditional Housing	555881.8274283345	14300.90739901685	1164.3589275345403	100	0.20946159238937379	-4.9366998576399705	15465.266326551391	118	0.0257265244038951	low	228	\N
ODD Cubes Basic	322620.0384699149	3251.3164887819953	12213.949837769396	26.414062834307025	3.785862123039941	-4.9366998576399705	15465.266326551391	63	0.01007785041562193	low	228	\N
Container (Base)	232907.99865026242	2347.211970999219	13118.054355552173	17.754767005648585	5.632290188217369	-4.9366998576399705	15465.266326551391	143	0.01007785041562193	low	228	\N
Container (Max)	451676.2854585494	4551.9260411350115	10913.34028541638	41.38753797149801	2.41618624593872	-4.9366998576399705	15465.266326551391	87	0.01007785041562193	low	228	\N
Traditional Housing	570597.6850218808	8988.96119900848	21696.26830466918	26.299346828186316	3.802375802460045	4.552561785397733	30685.22950367766	113	0.015753588622890714	middle	229	\N
ODD Cubes Basic	333083.70568401593	7008.907700266807	23676.32180341085	14.068220074455626	7.108219765596006	4.552561785397733	30685.22950367766	126	0.02104248145634568	middle	229	\N
Container (Base)	281793.06221262447	5929.625286136014	24755.604217541644	11.383000783836572	8.785029703414954	4.552561785397733	30685.22950367766	90	0.02104248145634568	middle	229	\N
Container (Max)	491555.2784991312	10343.542832586803	20341.686671090858	24.164922331525162	4.138229729360298	4.552561785397733	30685.22950367766	129	0.02104248145634568	middle	229	\N
Traditional Housing	588689.9918353836	12516.46993099242	18228.451566093398	32.29511786565576	3.0964432585751602	2.4145939461866828	30744.92149708582	124	0.02126156398883102	middle	230	\N
ODD Cubes Basic	308797.1588204764	6499.623247033183	24245.298250052634	12.73637286849239	7.851528926840931	2.4145939461866828	30744.92149708582	126	0.021048196401353005	middle	230	\N
Container (Base)	274299.11230613064	5773.501588536223	24971.419908549597	10.98452203802065	9.103718819432533	2.4145939461866828	30744.92149708582	66	0.021048196401353005	middle	230	\N
Container (Max)	437659.78827902884	9211.949180671572	21532.97231641425	20.325098729886335	4.920025301178906	2.4145939461866828	30744.92149708582	45	0.021048196401353005	middle	230	\N
Traditional Housing	558602.7558924833	6765.268681005192	24016.683999749937	23.25894598514514	4.299420965329526	-2.0077988572243752	30781.95268075513	135	0.012111054966415763	middle	231	\N
ODD Cubes Basic	307072.67372178135	4377.72277175435	26404.22990900078	11.629677319886735	8.59869085352868	-2.0077988572243752	30781.95268075513	99	0.014256308510605931	middle	231	\N
Container (Base)	242297.60309419228	3454.2693810911514	27327.68329966398	8.866379211046096	11.278561137495217	-2.0077988572243752	30781.95268075513	130	0.014256308510605931	middle	231	\N
Container (Max)	479501.9548292949	6835.927799485057	23946.024881270074	20.024281992805754	4.99393686305095	-2.0077988572243752	30781.95268075513	96	0.014256308510605931	middle	231	\N
Traditional Housing	541563.9626110173	9835.740653801775	6050.207996937319	89.51162718457991	1.1171733007801574	3.6430838402210934	15885.948650739094	137	0.01816173403854491	low	232	\N
ODD Cubes Basic	298070.6062491381	4780.93942085368	11105.009229885414	26.841094867979113	3.7256304369050905	3.6430838402210934	15885.948650739094	120	0.016039620548352895	low	232	\N
Container (Base)	269952.40521895944	4329.934145827309	11556.014504911785	23.360338039054767	4.28075997157301	3.6430838402210934	15885.948650739094	85	0.016039620548352895	low	232	\N
Container (Max)	483785.1908063202	7759.73088744588	8126.2177632932135	59.53386986398731	1.6797161049409808	3.6430838402210934	15885.948650739094	103	0.016039620548352895	low	232	\N
Traditional Housing	557801.594660333	6883.3246095737395	8936.571833967047	62.41784937487807	1.6021058239191432	-1.5797388850186103	15819.896443540787	89	0.012340094892997325	low	233	\N
ODD Cubes Basic	351160.381969745	3199.337722302312	12620.558721238474	27.8244719371097	3.593958592494591	-1.5797388850186103	15819.896443540787	110	0.009110759318452838	low	233	\N
Container (Base)	261110.95903327042	2378.919103162526	13440.97734037826	19.426486067264076	5.147611341225103	-1.5797388850186103	15819.896443540787	100	0.009110759318452838	low	233	\N
Container (Max)	401126.8187606547	3654.5699019049775	12165.32654163581	32.97295945059911	3.032788129006813	-1.5797388850186103	15819.896443540787	93	0.009110759318452838	low	233	\N
Traditional Housing	590609.6662680143	10359.45664109318	5143.899944082725	100	0.8709474696860888	1.579335123059085	15503.356585175905	138	0.017540276146432277	low	234	\N
ODD Cubes Basic	329695.12933480996	4025.9621531201033	11477.394432055802	28.725607653073904	3.4812144344420535	1.579335123059085	15503.356585175905	48	0.012211166604865683	low	234	\N
Container (Base)	243505.10354064708	2973.4813884699097	12529.875196705994	19.433960811091133	5.145631452695383	1.579335123059085	15503.356585175905	129	0.012211166604865683	low	234	\N
Container (Max)	461372.7187592611	5633.899135709175	9869.457449466729	46.74752600348768	2.139150636389599	1.579335123059085	15503.356585175905	93	0.012211166604865683	low	234	\N
Traditional Housing	546789.9319831762	16122.760739793222	14665.770369292364	37.28341015948685	2.682158085116974	4.485299607776218	30788.531109085587	88	0.029486206304708065	middle	235	\N
ODD Cubes Basic	305532.5569191685	7262.086991867981	23526.444117217605	12.986771625873006	7.700143105679485	4.485299607776218	30788.531109085587	75	0.023768619177920322	middle	235	\N
Container (Base)	242270.3256213572	5758.431107804791	25030.100001280796	9.679159316541291	10.331475774874793	4.485299607776218	30788.531109085587	65	0.023768619177920322	middle	235	\N
Container (Max)	493022.99010241224	11718.475697703816	19070.05541138177	25.853254197056838	3.867985021838531	4.485299607776218	30788.531109085587	40	0.023768619177920322	middle	235	\N
Traditional Housing	549413.1399038153	7767.283074025431	22991.265184882934	23.896603144095867	4.184695180189532	-3.9083792179122234	30758.548258908366	123	0.014137417746115854	middle	236	\N
ODD Cubes Basic	351579.6375603473	5221.268010985882	25537.280247922485	13.767309366820655	7.263583416015982	-3.9083792179122234	30758.548258908366	124	0.014850882853218913	middle	236	\N
Container (Base)	223841.66623942423	3324.246362991016	27434.30189591735	8.15918943695576	12.25611940655107	-3.9083792179122234	30758.548258908366	133	0.014850882853218913	middle	236	\N
Container (Max)	429079.59097794985	6372.21074032062	24386.337518587745	17.59508128889371	5.683406536071053	-3.9083792179122234	30758.548258908366	55	0.014850882853218913	middle	236	\N
Traditional Housing	502170.6846752988	8778.081602063015	6824.777067356241	73.58052574013645	1.3590552526516178	-4.025898486683847	15602.858669419256	87	0.017480274874545655	low	237	\N
ODD Cubes Basic	312736.4891063868	7717.149845031675	7885.708824387581	39.65864021496818	2.521518626406597	-4.025898486683847	15602.858669419256	79	0.024676205412047243	low	237	\N
Container (Base)	227579.19241146286	5615.790899453081	9987.067769966176	22.78738841603291	4.388392306054752	-4.025898486683847	15602.858669419256	55	0.024676205412047243	low	237	\N
Container (Max)	442885.5154120919	10928.733952329196	4674.124717090061	94.75260978654765	1.05537990167525	-4.025898486683847	15602.858669419256	48	0.024676205412047243	low	237	\N
Traditional Housing	498018.97501838417	8942.928772878899	6800.1600521158925	73.23636079174693	1.3654419596893608	-0.29330938335730394	15743.088824994791	139	0.01795700409316487	low	238	\N
ODD Cubes Basic	321920.79458613583	6916.174397529906	8826.914427464886	36.4703654070194	2.7419522366713975	-0.29330938335730394	15743.088824994791	119	0.021484087122801122	low	238	\N
Container (Base)	226561.7733577155	4867.472877513482	10875.61594748131	20.832086610247124	4.8002872621896095	-0.29330938335730394	15743.088824994791	138	0.021484087122801122	low	238	\N
Container (Max)	440146.55634073855	9456.14696322532	6286.941861769472	70.00964316486592	1.4283746563956867	-0.29330938335730394	15743.088824994791	111	0.021484087122801122	low	238	\N
Traditional Housing	567753.7220091983	7787.192933298979	8002.806867400047	70.94432383742507	1.4095560376212544	2.877589293596589	15789.999800699026	97	0.013715793717285076	low	239	\N
ODD Cubes Basic	335104.5792235837	5343.589424918372	10446.410375780655	32.07844294538749	3.117358288563031	2.877589293596589	15789.999800699026	81	0.015946035226672026	low	239	\N
Container (Base)	237640.77461251087	3789.4281632647253	12000.571637434301	19.802454565682506	5.049879027284788	2.877589293596589	15789.999800699026	49	0.015946035226672026	low	239	\N
Container (Max)	462229.50426548475	7370.727957824567	8419.27184287446	54.90136354923457	1.821448385527288	2.877589293596589	15789.999800699026	112	0.015946035226672026	low	239	\N
Traditional Housing	529273.1222863604	9847.343717416006	5866.261696036763	90.22323750812829	1.1083619116526484	-1.0315668357845276	15713.60541345277	107	0.018605410520143802	low	240	\N
ODD Cubes Basic	337982.89192952274	4593.65541420403	11119.94999924874	30.394281624679675	3.2900925652673294	-1.0315668357845276	15713.60541345277	98	0.01359138442771214	low	240	\N
Container (Base)	268686.37437046494	3651.819804557171	12061.785608895598	22.27583734967964	4.489169068270206	-1.0315668357845276	15713.60541345277	98	0.01359138442771214	low	240	\N
Container (Max)	477751.6823306574	6493.306775542173	9220.298637910597	51.81520697890543	1.9299353574079354	-1.0315668357845276	15713.60541345277	74	0.01359138442771214	low	240	\N
Traditional Housing	501452.97856769187	12573.950275615862	3291.250905740999	100	0.6563428768818667	1.9073651195031598	15865.20118135686	84	0.02507503357848434	low	241	\N
ODD Cubes Basic	318954.2799384122	3958.199685785229	11907.001495571632	26.78712017102168	3.733137394447502	1.9073651195031598	15865.20118135686	113	0.01240992811430381	low	241	\N
Container (Base)	262873.342210493	3262.2392799990034	12602.961901357858	20.858060531165354	4.794309607577542	1.9073651195031598	15865.20118135686	89	0.01240992811430381	low	241	\N
Container (Max)	429073.70136315335	5324.773789654993	10540.427391701867	40.707429159936055	2.456554050787841	1.9073651195031598	15865.20118135686	88	0.01240992811430381	low	241	\N
Traditional Housing	499852.513028088	7580.552212204945	23038.963512025326	21.695963569159133	4.60915228223144	2.7964940457717287	30619.51572423027	111	0.015165577874725968	middle	242	\N
ODD Cubes Basic	344728.04015771486	7617.438065457644	23002.077658772625	14.986821854600647	6.672528770287747	2.7964940457717287	30619.51572423027	44	0.022096949415465673	middle	242	\N
Container (Base)	249847.4470267292	5520.866398532875	25098.649325697395	9.954617229976654	10.045589668567752	2.7964940457717287	30619.51572423027	116	0.022096949415465673	middle	242	\N
Container (Max)	463133.78351390944	10233.843786900086	20385.671937330182	22.71859298715684	4.401681039689892	2.7964940457717287	30619.51572423027	106	0.022096949415465673	middle	242	\N
Traditional Housing	564518.9217907581	12166.423805577177	3566.7236023109817	100	0.6318164838472866	1.1923235459820614	15733.147407888158	81	0.021551844120624046	low	243	\N
ODD Cubes Basic	317333.98097635363	7779.007997870233	7954.139410017925	39.895451238468866	2.506551421169936	1.1923235459820614	15733.147407888158	111	0.024513630635887972	low	243	\N
Container (Base)	242777.8274514921	5951.365988729221	9781.781419158939	24.819387905763154	4.029108226991353	1.1923235459820614	15733.147407888158	84	0.024513630635887972	low	243	\N
Container (Max)	445881.4894927334	10930.17414080443	4802.9732670837275	92.83447246073555	1.0771860640700588	1.1923235459820614	15733.147407888158	80	0.024513630635887972	low	243	\N
Traditional Housing	497746.4075691307	13949.755380289049	1865.694493516312	100	0.37482831922944426	-0.3981450372355466	15815.44987380536	95	0.028025828349854245	low	244	\N
ODD Cubes Basic	298819.9128305341	6773.957676141221	9041.49219766414	33.04984468246668	3.025732827514653	-0.3981450372355466	15815.44987380536	142	0.022669030360044473	low	244	\N
Container (Base)	226207.7361032114	5127.9100374006275	10687.539836404732	21.16555723448019	4.724657087557937	-0.3981450372355466	15815.44987380536	80	0.022669030360044473	low	244	\N
Container (Max)	471544.9513360881	10689.466817963475	5125.983055841885	91.99112564343858	1.0870613801118616	-0.3981450372355466	15815.44987380536	61	0.022669030360044473	low	244	\N
Traditional Housing	560836.2435178588	16669.698473951255	13406.913276847255	41.83186927048908	2.3905219093459564	-3.604056614843608	30076.61175079851	145	0.02972293368451042	middle	245	\N
ODD Cubes Basic	355000.33246509166	5612.631057326063	24463.980693472447	14.511143419918326	6.891255713366992	-3.604056614843608	30076.61175079851	140	0.015810213523892884	middle	245	\N
Container (Base)	246786.930856934	3901.754071754316	26174.857679044195	9.42839628329722	10.606257628050063	-3.604056614843608	30076.61175079851	142	0.015810213523892884	middle	245	\N
Container (Max)	461950.9298464061	7303.542838432542	22773.06891236597	20.28496605459982	4.9297592971482445	-3.604056614843608	30076.61175079851	123	0.015810213523892884	middle	245	\N
Traditional Housing	597218.7236057401	11009.25663757615	19608.04237086871	30.4578454243355	3.2832263282845684	-0.7140801897756388	30617.29900844486	117	0.018434212127689455	middle	246	\N
ODD Cubes Basic	313251.9925599298	6738.205453429654	23879.093555015206	13.118253079340152	7.622966213198717	-0.7140801897756388	30617.29900844486	114	0.021510495107674485	middle	246	\N
Container (Base)	238815.28575521315	5137.035035875397	25480.263972569464	9.372559327183874	10.66944433309301	-0.7140801897756388	30617.29900844486	115	0.021510495107674485	middle	246	\N
Container (Max)	416081.78024330584	8950.12509831612	21667.17391012874	19.20332489918311	5.207431552868947	-0.7140801897756388	30617.29900844486	137	0.021510495107674485	middle	246	\N
Traditional Housing	547722.7195511379	11503.18318537464	19304.427778172714	28.372906249541437	3.524489141876899	-3.0740971630697578	30807.610963547355	89	0.021001836832332917	middle	247	\N
ODD Cubes Basic	355357.6922053257	3436.393885614539	27371.217077932815	12.982897004306823	7.702441139818558	-3.0740971630697578	30807.610963547355	65	0.009670239201207414	middle	247	\N
Container (Base)	253683.75808608087	2453.1826221536376	28354.428341393716	8.94688318281967	11.177076749143867	-3.0740971630697578	30807.610963547355	79	0.009670239201207414	middle	247	\N
Container (Max)	455031.56424942636	4400.264070391533	26407.346893155824	17.231248791879207	5.80340990997288	-3.0740971630697578	30807.610963547355	83	0.009670239201207414	middle	247	\N
Traditional Housing	545852.3148138097	10163.65288143036	5408.860726621944	100	0.9909018574862887	2.2082450647564844	15572.513608052304	120	0.01861978525253151	low	248	\N
ODD Cubes Basic	355131.7637992407	5851.0346513493205	9721.478956702984	36.530631335099116	2.7374287370697226	2.2082450647564844	15572.513608052304	139	0.01647567254687183	low	248	\N
Container (Base)	252197.86124317977	4155.129378864048	11417.384229188257	22.088935274547584	4.527153471051499	2.2082450647564844	15572.513608052304	131	0.01647567254687183	low	248	\N
Container (Max)	450537.9485668828	7422.915710527343	8149.597897524961	55.28345744563809	1.8088593698817237	2.2082450647564844	15572.513608052304	91	0.01647567254687183	low	248	\N
Traditional Housing	598092.1607992165	8263.178984640901	22629.96167507734	26.42921669009731	3.783691403819347	1.946369259378593	30893.14065971824	121	0.013815895820468552	middle	249	\N
ODD Cubes Basic	330230.24405410246	7842.718968191771	23050.42169152647	14.326429619094469	6.980106185474054	1.946369259378593	30893.14065971824	74	0.023749244987103235	middle	249	\N
Container (Base)	260945.94775819746	6197.269241701274	24695.871418016966	10.566379430037985	9.463979659458483	1.946369259378593	30893.14065971824	133	0.023749244987103235	middle	249	\N
Container (Max)	429975.9945056439	10211.605232087892	20681.535427630348	20.790332323740326	4.809927924327153	1.946369259378593	30893.14065971824	82	0.023749244987103235	middle	249	\N
Traditional Housing	511408.9158728981	11950.563736394224	3647.016703521962	100	0.7131312322345911	-4.18697215261623	15597.580439916186	110	0.023367922156766488	low	250	\N
ODD Cubes Basic	317487.64068123413	6371.243531857063	9226.336908059122	34.411017486681146	2.9060460080468467	-4.18697215261623	15597.580439916186	147	0.02006768993648467	low	250	\N
Container (Base)	219158.47200278434	4398.004263105633	11199.576176810553	19.568461211645324	5.110263853577272	-4.18697215261623	15597.580439916186	55	0.02006768993648467	low	250	\N
Container (Max)	451323.7235127646	9057.024544433896	6540.55589548229	69.0038783743908	1.4491939055575274	-4.18697215261623	15597.580439916186	109	0.02006768993648467	low	250	\N
Traditional Housing	591746.5369698153	6240.4737317875515	23911.1495037011	24.747724356715743	4.0407755702541275	-2.309084804899327	30151.623235488652	100	0.0105458559398479	middle	251	\N
ODD Cubes Basic	352311.41122299404	3111.9277352243153	27039.695500264337	13.029414891878123	7.6749417245386	-2.309084804899327	30151.623235488652	147	0.008832889415706814	middle	251	\N
Container (Base)	243484.60916243008	2150.672627158339	28000.950608330313	8.695583681005214	11.500090582584095	-2.309084804899327	30151.623235488652	84	0.008832889415706814	middle	251	\N
Container (Max)	469988.49333448434	4151.356388278159	26000.266847210492	18.076294989445785	5.532107108142849	-2.309084804899327	30151.623235488652	116	0.008832889415706814	middle	251	\N
Traditional Housing	522457.0010800431	7659.265457145188	23217.668728260338	22.502560752110014	4.443938674429453	-0.5097838777056918	30876.934185405527	141	0.014660087703507966	middle	252	\N
ODD Cubes Basic	331661.04223389144	6430.710291683957	24446.22389372157	13.566964111748591	7.370845767433183	-0.5097838777056918	30876.934185405527	131	0.019389405063585795	middle	252	\N
Container (Base)	270657.252203732	5247.883096375258	25629.05108903027	10.560564699158078	9.469190601897672	-0.5097838777056918	30876.934185405527	103	0.019389405063585795	middle	252	\N
Container (Max)	470246.97167041263	9117.809013642185	21759.125171763342	21.611483364259914	4.627169653952373	-0.5097838777056918	30876.934185405527	89	0.019389405063585795	middle	252	\N
Traditional Housing	547511.3427758676	15961.379038467307	14673.466299089896	37.313020087818394	2.68002964554046	-2.4600534129092444	30634.845337557203	118	0.029152599757191422	middle	253	\N
ODD Cubes Basic	352244.76168444863	7650.384475081287	22984.460862475917	15.32534366553353	6.525139153968763	-2.4600534129092444	30634.845337557203	121	0.02171894462957189	middle	253	\N
Container (Base)	232170.76204013993	5042.5039253553105	25592.34141220189	9.071884369651531	11.023068187964702	-2.4600534129092444	30634.845337557203	92	0.02171894462957189	middle	253	\N
Container (Max)	418261.6987821289	9084.202676519735	21550.64266103747	19.40831674306985	5.152430338180003	-2.4600534129092444	30634.845337557203	89	0.02171894462957189	middle	253	\N
Traditional Housing	580684.3831989531	8593.47918091163	22348.54071988135	25.983100663139677	3.848655373985549	-0.9240974578428176	30942.01990079298	92	0.014798881164274996	middle	254	\N
ODD Cubes Basic	294850.79613883485	6849.469264036086	24092.550636756896	12.238255740718236	8.171099061714102	-0.9240974578428176	30942.01990079298	124	0.023230289196203874	middle	254	\N
Container (Base)	225717.44159424654	5243.481444861604	25698.538455931375	8.783279328562346	11.385269243892768	-0.9240974578428176	30942.01990079298	117	0.023230289196203874	middle	254	\N
Container (Max)	415826.87434095796	9659.77854649398	21282.241354299	19.538678629681137	5.118053369693607	-0.9240974578428176	30942.01990079298	126	0.023230289196203874	middle	254	\N
Traditional Housing	513377.0594920023	9467.320586780756	6136.519091104627	83.65932735973774	1.1953239782815472	-1.688670157725518	15603.839677885382	97	0.018441261469978563	low	255	\N
ODD Cubes Basic	346488.1053667777	4063.1611027977333	11540.678575087648	30.023200378765093	3.3307575054766088	-1.688670157725518	15603.839677885382	95	0.01172669722239568	low	255	\N
Container (Base)	225372.71314572275	2642.877569249725	12960.962108635656	17.388578969423957	5.750901219463638	-1.688670157725518	15603.839677885382	113	0.01172669722239568	low	255	\N
Container (Max)	447725.10058972123	5250.33669348231	10353.502984403072	43.243827839156666	2.3124687382427194	-1.688670157725518	15603.839677885382	56	0.01172669722239568	low	255	\N
Traditional Housing	511814.7825544179	13202.219721928184	2790.928495646398	100	0.5453004857962767	-3.871088227189483	15993.148217574582	129	0.02579491677836499	low	256	\N
ODD Cubes Basic	351202.66819759656	4876.706707879311	11116.441509695273	31.593083802158542	3.1652497308024006	-3.871088227189483	15993.148217574582	111	0.013885733650336442	low	256	\N
Container (Base)	252608.4447138362	3507.653581122068	12485.494636452515	20.232153556521766	4.942627571535278	-3.871088227189483	15993.148217574582	41	0.013885733650336442	low	256	\N
Container (Max)	472393.5140599938	6559.530514383537	9433.617703191045	50.07554142248106	1.996982901419129	-3.871088227189483	15993.148217574582	86	0.013885733650336442	low	256	\N
Traditional Housing	568974.0227584112	9486.622635860736	6377.855961683523	89.21086116975002	1.120939745326754	-2.744194617869251	15864.47859754426	148	0.01667320871675155	low	257	\N
ODD Cubes Basic	303023.11824547814	4599.309389296347	11265.169208247913	26.899118215074527	3.7175939820941424	-2.744194617869251	15864.47859754426	66	0.01517808085378641	low	257	\N
Container (Base)	255409.13861507844	3876.6205566956014	11987.858040848658	21.305652581534677	4.693590098557632	-2.744194617869251	15864.47859754426	60	0.01517808085378641	low	257	\N
Container (Max)	399356.62318088906	6061.467116134646	9803.011481409612	40.73815724262153	2.4547011148402382	-2.744194617869251	15864.47859754426	129	0.01517808085378641	low	257	\N
Traditional Housing	539560.5257864124	13545.44601686518	17001.46780261243	31.736114319700327	3.150984364142039	4.776691581666995	30546.91381947761	82	0.025104590438899545	middle	258	\N
ODD Cubes Basic	316208.4690431508	6792.507104829537	23754.406714648074	13.311570894682118	7.51226138456351	4.776691581666995	30546.91381947761	123	0.021481104302436032	middle	258	\N
Container (Base)	254203.50666632535	5460.572040744328	25086.34177873328	10.133143720533381	9.868605711904012	4.776691581666995	30546.91381947761	138	0.021481104302436032	middle	258	\N
Container (Max)	500858.5147165512	10758.993995389428	19787.91982408818	25.311327272857014	3.9508003243763716	4.776691581666995	30546.91381947761	51	0.021481104302436032	middle	258	\N
Traditional Housing	552430.5516545965	15241.218650255529	14825.757264071677	37.261540291998514	2.6837323206811674	-0.1695258930777115	30066.975914327206	114	0.02758938404946329	middle	259	\N
ODD Cubes Basic	334436.1814548133	6822.005218985886	23244.97069534132	14.38746410301304	6.95049518692164	-0.1695258930777115	30066.975914327206	133	0.020398526227963253	middle	259	\N
Container (Base)	234719.2003571272	4787.925764691421	25279.050149635783	9.28512736703871	10.769911499005406	-0.1695258930777115	30066.975914327206	66	0.020398526227963253	middle	259	\N
Container (Max)	477901.5215158962	9748.486721025552	20318.489193301655	23.5205244331574	4.251605880820744	-0.1695258930777115	30066.975914327206	69	0.020398526227963253	middle	259	\N
Traditional Housing	562516.5783532215	12185.008205152506	3465.1311359418287	100	0.6160051577654954	-0.6046892024072639	15650.139341094335	105	0.021661598384930023	low	260	\N
ODD Cubes Basic	345194.6037752629	7244.306830147605	8405.83251094673	41.06608159581143	2.435099627576827	-0.6046892024072639	15650.139341094335	103	0.02098615317539544	low	260	\N
Container (Base)	229125.34019175312	4808.45948562872	10841.679855465614	21.133748943549943	4.7317681433194165	-0.6046892024072639	15650.139341094335	102	0.02098615317539544	low	260	\N
Container (Max)	443595.6880248379	9309.367056834177	6340.772284260158	69.9592523021187	1.4294034985987338	-0.6046892024072639	15650.139341094335	149	0.02098615317539544	low	260	\N
Traditional Housing	573256.5099642467	12382.743087034089	3467.3115912586927	100	0.6048446953485003	3.1858204355454856	15850.054678292781	109	0.021600702079783422	low	261	\N
ODD Cubes Basic	319153.71012168063	7758.614756266011	8091.439922026771	39.44337635788043	2.535279918551417	3.1858204355454856	15850.054678292781	71	0.024309962598611054	low	261	\N
Container (Base)	282061.82328678516	6856.912374597788	8993.142303694993	31.36410097401606	3.1883585658280507	3.1858204355454856	15850.054678292781	107	0.024309962598611054	low	261	\N
Container (Max)	466898.67824758904	11350.289405539826	4499.765272752955	100	0.9637562671288609	3.1858204355454856	15850.054678292781	54	0.024309962598611054	low	261	\N
Traditional Housing	594090.6184362873	17393.842267586144	12629.931246318083	47.03830977777321	2.1259267280741563	-2.349898019302603	30023.773513904227	143	0.02927809618231083	middle	262	\N
ODD Cubes Basic	312491.250996694	5044.273497844658	24979.50001605957	12.509908156519957	7.993663802230366	-2.349898019302603	30023.773513904227	105	0.01614212712117826	middle	262	\N
Container (Base)	241748.47946391383	3902.3346868580493	26121.43882704618	9.254791861373542	10.805213288195828	-2.349898019302603	30023.773513904227	101	0.01614212712117826	middle	262	\N
Container (Max)	435838.6577466532	7035.36301767018	22988.410496234046	18.959060167211305	5.274523057474374	-2.349898019302603	30023.773513904227	123	0.01614212712117826	middle	262	\N
Traditional Housing	503018.5093604158	14108.684504558776	1424.1233543189392	100	0.28311549730639163	3.6714230524220586	15532.807858877715	134	0.028048042451753637	low	263	\N
ODD Cubes Basic	322503.32493905304	4166.336003603263	11366.471855274453	28.373212817959857	3.5244510602867423	3.6714230524220586	15532.807858877715	99	0.012918738138252128	low	263	\N
Container (Base)	276807.73415795504	3576.00663222953	11956.801226648186	23.15065115752131	4.319532928883145	3.6714230524220586	15532.807858877715	115	0.012918738138252128	low	263	\N
Container (Max)	495848.5944082431	6405.738147380481	9127.069711497235	54.32724960823186	1.8406969011154881	3.6714230524220586	15532.807858877715	66	0.012918738138252128	low	263	\N
Traditional Housing	586121.700126448	7036.454944692039	23417.4224133008	25.029300397875485	3.995317424393057	-4.076074085198561	30453.87735799284	143	0.012005109080885451	middle	264	\N
ODD Cubes Basic	322847.9108473202	4755.932440538984	25697.944917453853	12.563180125273142	7.959768068502945	-4.076074085198561	30453.87735799284	71	0.014731185430492497	middle	264	\N
Container (Base)	260653.4581311697	3839.734424829373	26614.142933163464	9.793794930227625	10.210546648404842	-4.076074085198561	30453.87735799284	127	0.014731185430492497	middle	264	\N
Container (Max)	456139.85578705656	6719.480797837236	23734.3965601556	19.218514978080663	5.203315662737378	-4.076074085198561	30453.87735799284	138	0.014731185430492497	middle	264	\N
Traditional Housing	559761.9082535781	8703.690030093578	6814.486032513059	82.14293867253669	1.217390096045268	-2.003720736966862	15518.176062606637	141	0.015548914461236817	low	265	\N
ODD Cubes Basic	296214.73134532565	3168.794240960711	12349.381821645926	23.986199116956783	4.169064031879318	-2.003720736966862	15518.176062606637	142	0.010697625423856947	low	265	\N
Container (Base)	266054.9035957159	2846.155700847339	12672.020361759298	20.995460550126406	4.762934338175208	-2.003720736966862	15518.176062606637	91	0.010697625423856947	low	265	\N
Container (Max)	444890.61389678216	4759.273142057541	10758.902920549095	41.350927430254806	2.4183254455094527	-2.003720736966862	15518.176062606637	100	0.010697625423856947	low	265	\N
Traditional Housing	518612.9803313487	12050.34686793829	18390.76100184026	28.199647653485034	3.546143598274412	-4.959799598388491	30441.10786977855	84	0.023235721674839612	middle	266	\N
ODD Cubes Basic	345596.32709401584	8383.196506343422	22057.911363435127	15.667681377435517	6.3825653324823985	-4.959799598388491	30441.10786977855	54	0.02425719213174063	middle	266	\N
Container (Base)	233862.5418607402	5672.848610333211	24768.259259445338	9.442025756071537	10.59094759783902	-4.959799598388491	30441.10786977855	90	0.02425719213174063	middle	266	\N
Container (Max)	390251.3364150179	9466.401647087638	20974.70622269091	18.605807026409515	5.374666084521767	-4.959799598388491	30441.10786977855	89	0.02425719213174063	middle	266	\N
Traditional Housing	520228.9579861123	12357.13664094521	3168.5720038269683	100	0.6090725929777163	1.813681963222983	15525.708644772178	89	0.023753265655917385	low	267	\N
ODD Cubes Basic	327760.4200537301	6357.569780939241	9168.138863832937	35.749940628266486	2.7972074426588773	1.813681963222983	15525.708644772178	107	0.019397002786050367	low	267	\N
Container (Base)	276971.01389405364	5372.407528158154	10153.301116614024	27.278912613045733	3.665835270581001	1.813681963222983	15525.708644772178	139	0.019397002786050367	low	267	\N
Container (Max)	423600.45301526977	8216.579167309385	7309.129477462793	57.95498004535467	1.7254772570319505	1.813681963222983	15525.708644772178	73	0.019397002786050367	low	267	\N
Traditional Housing	496421.39063616557	11687.445231869355	4286.752633847522	100	0.8635310070651941	1.7870531938321879	15974.197865716877	105	0.023543395696329395	low	268	\N
ODD Cubes Basic	352058.1561059346	5843.272660705094	10130.925205011783	34.75083953159292	2.877628320578768	1.7870531938321879	15974.197865716877	148	0.016597464252317586	low	268	\N
Container (Base)	238358.7229713771	3956.150383745502	12018.047481971375	19.833398339368024	5.042000280985958	1.7870531938321879	15974.197865716877	117	0.016597464252317586	low	268	\N
Container (Max)	493273.6784909253	8187.092245362331	7787.105620354546	63.34493232011236	1.5786582499552133	1.7870531938321879	15974.197865716877	128	0.016597464252317586	low	268	\N
Traditional Housing	532379.4692408645	5612.5011257393	24914.313720856175	21.36841797874613	4.679803628863116	1.8990915656827925	30526.814846595473	86	0.010542294453507626	middle	269	\N
ODD Cubes Basic	323230.16784228146	5294.261669060776	25232.553177534697	12.81004603727787	7.806373194053718	1.8990915656827925	30526.814846595473	97	0.016379231259268115	middle	269	\N
Container (Base)	242097.94133811956	3965.3781685697863	26561.436678025686	9.114640306275584	10.971359992247672	1.8990915656827925	30526.814846595473	79	0.016379231259268115	middle	269	\N
Container (Max)	487269.4174464216	7981.098473923793	22545.71637267168	21.612505426399096	4.626950833652663	1.8990915656827925	30526.814846595473	117	0.016379231259268115	middle	269	\N
Traditional Housing	551649.2148816976	14081.678177454578	1801.0284386450166	100	0.3264807399447222	0.6616876672789385	15882.706616099595	97	0.025526508146076897	low	270	\N
ODD Cubes Basic	303602.1308957318	4534.025176074488	11348.681440025106	26.752194296772874	3.7380111287567552	0.6616876672789385	15882.706616099595	116	0.014934101953426801	low	270	\N
Container (Base)	259901.77641819467	3881.3996269060567	12001.306989193537	21.656122674990378	4.617631766349626	0.6616876672789385	15882.706616099595	118	0.014934101953426801	low	270	\N
Container (Max)	409044.5346297552	6108.712783652783	9773.993832446811	41.850295963135004	2.389469362130385	0.6616876672789385	15882.706616099595	137	0.014934101953426801	low	270	\N
Traditional Housing	548526.4792676779	9238.806519849133	6621.429826765107	82.84109227442497	1.2071303896951684	1.892488607794725	15860.23634661424	124	0.016842954477208832	low	271	\N
ODD Cubes Basic	354044.88909970823	3198.815725139948	12661.420621474292	27.962493284460788	3.576219008180205	1.892488607794725	15860.23634661424	110	0.00903505691968647	low	271	\N
Container (Base)	233550.60328788278	2110.142994333135	13750.093352281105	16.98538310280907	5.887415043553645	1.892488607794725	15860.23634661424	90	0.00903505691968647	low	271	\N
Container (Max)	437886.4782260905	3956.329255133778	11903.907091480462	36.78510550031784	2.7184915916344443	1.892488607794725	15860.23634661424	125	0.00903505691968647	low	271	\N
Traditional Housing	526433.9202167183	14243.770034080377	1317.4918135301432	100	0.2502672724789026	1.9563363117300092	15561.26184761052	89	0.02705709014384295	low	272	\N
ODD Cubes Basic	344328.1362745967	3083.5943717698356	12477.667475840684	27.595553170597498	3.6237722571384428	1.9563363117300092	15561.26184761052	91	0.008955394714856279	low	272	\N
Container (Base)	251751.29396763703	2254.532207456006	13306.729640154514	18.919095884232135	5.285664844235165	1.9563363117300092	15561.26184761052	73	0.008955394714856279	low	272	\N
Container (Max)	453827.2898798214	4064.202513247301	11497.059334363219	39.47333632726331	2.533355659904844	1.9563363117300092	15561.26184761052	141	0.008955394714856279	low	272	\N
Traditional Housing	580030.2908530881	14908.089501229793	15996.36655871009	36.2601274935938	2.7578502038545603	-0.24524930839525982	30904.456059939883	129	0.025702260272137685	middle	273	\N
ODD Cubes Basic	337427.8020169448	6374.463359487645	24529.99270045224	13.755723702711249	7.269701119417659	-0.24524930839525982	30904.456059939883	81	0.01889134007744725	middle	273	\N
Container (Base)	238864.57274149393	4512.471876113698	26391.984183826185	9.050648525618527	11.048931987242975	-0.24524930839525982	30904.456059939883	55	0.01889134007744725	middle	273	\N
Container (Max)	432748.17962314107	8175.193029156986	22729.263030782895	19.039252572204287	5.252307023122936	-0.24524930839525982	30904.456059939883	42	0.01889134007744725	middle	273	\N
Traditional Housing	583824.5171256717	8591.34003558227	7349.233303460414	79.44019369350755	1.2588086124993014	4.003948401433924	15940.573339042685	132	0.01471562050507881	low	274	\N
ODD Cubes Basic	351697.0372611164	7709.8371918240455	8230.736147218639	42.72971833509244	2.340291579171807	4.003948401433924	15940.573339042685	83	0.021921814445368504	low	274	\N
Container (Base)	272636.8284275215	5976.693963761895	9963.87937528079	27.36251796703815	3.6546344207233963	4.003948401433924	15940.573339042685	125	0.021921814445368504	low	274	\N
Container (Max)	475609.70594815264	10426.227722211679	5514.345616831006	86.24952786718451	1.159426636560722	4.003948401433924	15940.573339042685	138	0.021921814445368504	low	274	\N
Traditional Housing	530468.9849469637	9376.714634082391	6440.8807592261255	82.35969656589323	1.2141861149281112	1.6280092334734189	15817.595393308517	129	0.01767627307187408	low	275	\N
ODD Cubes Basic	347368.16877234564	6758.532333404403	9059.063059904114	38.34482291108175	2.6079139870300394	1.6280092334734189	15817.595393308517	104	0.01945639509022986	low	275	\N
Container (Base)	231954.86722778995	4513.005539885691	11304.589853422825	20.518645102153634	4.87361614288577	1.6280092334734189	15817.595393308517	110	0.01945639509022986	low	275	\N
Container (Max)	461842.5469029004	8985.791062020844	6831.8043312876725	67.60184052517373	1.4792496657359762	1.6280092334734189	15817.595393308517	44	0.01945639509022986	low	275	\N
Traditional Housing	597097.0597390265	9649.412424009472	6273.513464656	95.17745727381929	1.0506689594817245	-3.5582539504003496	15922.925888665472	113	0.01616054252256232	low	276	\N
ODD Cubes Basic	337824.3409055642	3694.656535540874	12228.269353124597	27.626504712152297	3.6197123393612722	-3.5582539504003496	15922.925888665472	43	0.010936620273237453	low	276	\N
Container (Base)	249215.68616489577	2725.5773257197816	13197.34856294569	18.883769340200715	5.295552926878586	-3.5582539504003496	15922.925888665472	85	0.010936620273237453	low	276	\N
Container (Max)	422487.7739886554	4620.588354199292	11302.33753446618	37.38056598471689	2.6751868883121026	-3.5582539504003496	15922.925888665472	45	0.010936620273237453	low	276	\N
Traditional Housing	545851.2452564592	10793.09040497063	19319.653895089716	28.25367619008914	3.539362429412925	-1.2170159810712242	30112.744300060345	118	0.0197729518779419	middle	277	\N
ODD Cubes Basic	310581.8671583553	6889.626576140167	23223.11772392018	13.373823052124093	7.477293486705548	-1.2170159810712242	30112.744300060345	81	0.022182964637234848	middle	277	\N
Container (Base)	229774.30731664354	5097.075333750236	25015.66896631011	9.185215379452472	10.887060985385514	-1.2170159810712242	30112.744300060345	98	0.022182964637234848	middle	277	\N
Container (Max)	402640.64149485173	8931.76311179385	21180.981188266494	19.009536806439364	5.260517445439575	-1.2170159810712242	30112.744300060345	69	0.022182964637234848	middle	277	\N
Traditional Housing	574463.7247976767	14717.27424218296	15529.479692480196	36.991820471348305	2.703300316821502	1.1249460944579148	30246.753934663157	95	0.025619153319674473	middle	278	\N
ODD Cubes Basic	339154.9707738394	7234.668181811452	23012.085752851704	14.738123889174654	6.785124127871615	1.1249460944579148	30246.753934663157	120	0.02133145259615194	middle	278	\N
Container (Base)	254120.02976198678	5420.749368600541	24826.004566062617	10.236042174477454	9.769400935973085	1.1249460944579148	30246.753934663157	79	0.02133145259615194	middle	278	\N
Container (Max)	426215.4059204	9091.79372714067	21154.960207522487	20.147303598748543	4.963443346642751	1.1249460944579148	30246.753934663157	141	0.02133145259615194	middle	278	\N
Traditional Housing	581280.2056043826	15256.562008783369	704.0277376380254	100	0.12111675760677536	-3.3010589590635133	15960.589746421394	102	0.026246484675872372	low	279	\N
ODD Cubes Basic	307213.78839133837	7039.858797013468	8920.730949407927	34.43818563003834	2.903753440273464	-3.3010589590635133	15960.589746421394	115	0.022915178494677065	low	279	\N
Container (Base)	259164.34515715216	5938.797228732237	10021.792517689157	25.86007889304325	3.8669642275105933	-3.3010589590635133	15960.589746421394	52	0.022915178494677065	low	279	\N
Container (Max)	465161.8873638815	10659.267677864213	5301.322068557181	87.74450624737858	1.1396724909257503	-3.3010589590635133	15960.589746421394	134	0.022915178494677065	low	279	\N
Traditional Housing	553174.7376982614	12186.415913230252	3808.8119308608457	100	0.6885368530582514	-2.9387109788329124	15995.227844091098	86	0.02202995741262057	low	280	\N
ODD Cubes Basic	295742.5846977225	4967.559288217238	11027.66855587386	26.818232992702338	3.7288064440044044	-2.9387109788329124	15995.227844091098	43	0.016796902256381384	low	280	\N
Container (Base)	262072.57222651027	4402.007379767144	11593.220464323953	22.60567484531079	4.423667980907171	-2.9387109788329124	15995.227844091098	119	0.016796902256381384	low	280	\N
Container (Max)	468330.01835182	7866.493541984821	8128.734302106277	57.614137816076564	1.7356850903372565	-2.9387109788329124	15995.227844091098	139	0.016796902256381384	low	280	\N
Traditional Housing	499690.0164072033	14337.155020895709	1265.2286648316203	100	0.253202710338037	3.1546393703102193	15602.383685727329	94	0.02869209820116196	low	281	\N
ODD Cubes Basic	333814.8022752735	3777.2985923968463	11825.085093330483	28.229378447648536	3.542408848478556	3.1546393703102193	15602.383685727329	88	0.011315551517340969	low	281	\N
Container (Base)	260808.2177058241	2951.1888235961314	12651.194862131197	20.615303182666246	4.850765429638793	3.1546393703102193	15602.383685727329	81	0.011315551517340969	low	281	\N
Container (Max)	440781.6084619947	4987.686998448116	10614.696687279213	41.52559620382116	2.4081532630902496	3.1546393703102193	15602.383685727329	61	0.011315551517340969	low	281	\N
Traditional Housing	524653.0090288485	14156.356948948964	16673.249235310355	31.46675261818472	3.177957421072098	3.8973406752564195	30829.60618425932	125	0.026982322993158635	middle	282	\N
ODD Cubes Basic	319682.72004890186	4708.56542668104	26121.04075757828	12.238513886785118	8.170926709326844	3.8973406752564195	30829.60618425932	129	0.014728870631358401	middle	282	\N
Container (Base)	246994.68422389516	3637.9527505669716	27191.653433692347	9.08347426632952	11.009003501080906	3.8973406752564195	30829.60618425932	47	0.014728870631358401	middle	282	\N
Container (Max)	473644.9540923901	6976.255254022502	23853.35093023682	19.85653736775371	5.036124785905338	3.8973406752564195	30829.60618425932	62	0.014728870631358401	middle	282	\N
Traditional Housing	528039.7936835139	10776.280822383818	20050.47646613649	26.335523476228964	3.7971525453163006	4.526306964273038	30826.757288520308	98	0.020408084677123205	middle	283	\N
ODD Cubes Basic	314500.90323053545	3616.5692774237796	27210.18801109653	11.558203975006696	8.65186323205912	4.526306964273038	30826.757288520308	43	0.011499392339654942	middle	283	\N
Container (Base)	283782.33286570903	3263.3243846853434	27563.432903834964	10.29560918104021	9.712878397147605	4.526306964273038	30826.757288520308	141	0.011499392339654942	middle	283	\N
Container (Max)	467454.2133991124	5375.43940070118	25451.31788781913	18.366601504075103	5.444665414982321	4.526306964273038	30826.757288520308	122	0.011499392339654942	middle	283	\N
Traditional Housing	522614.59843975096	7305.692153818376	23318.0022288561	22.412494574385697	4.461796952949888	-2.0741619997244873	30623.69438267448	109	0.013979119939682674	middle	284	\N
ODD Cubes Basic	318975.8987734959	5882.459943976311	24741.234438698168	12.892481155854558	7.756458884144994	-2.0741619997244873	30623.69438267448	148	0.018441706619826574	middle	284	\N
Container (Base)	227310.68084515995	4191.996887699472	26431.697494975007	8.599927450303731	11.628005070725127	-2.0741619997244873	30623.69438267448	74	0.018441706619826574	middle	284	\N
Container (Max)	446986.7937602519	8243.199313463492	22380.495069210985	19.972158452168244	5.006970089862453	-2.0741619997244873	30623.69438267448	110	0.018441706619826574	middle	284	\N
Traditional Housing	514423.4224747229	6453.324476469129	24060.375750140833	21.380523222781	4.677154013398968	-0.7755445559433571	30513.700226609963	108	0.012544771864049842	middle	285	\N
ODD Cubes Basic	348208.60387032863	3183.0207933214256	27330.679433288537	12.740576198270926	7.84893857575856	-0.7755445559433571	30513.700226609963	70	0.0091411319477527	middle	285	\N
Container (Base)	258477.52097647486	2362.777124773973	28150.92310183599	9.181848852395788	10.891052728874682	-0.7755445559433571	30513.700226609963	82	0.0091411319477527	middle	285	\N
Container (Max)	436607.3123749038	3991.085051772676	26522.615174837287	16.461699176223195	6.074707047522598	-0.7755445559433571	30513.700226609963	43	0.0091411319477527	middle	285	\N
Traditional Housing	505266.53245820355	7248.530447839861	23576.827265526914	21.430641484021216	4.6662158981363415	-0.26330922628959463	30825.357713366775	109	0.014345954030587749	middle	286	\N
ODD Cubes Basic	305908.2862620465	6739.395736698708	24085.961976668066	12.700687917650045	7.873589261336845	-0.26330922628959463	30825.357713366775	84	0.022030772095286172	middle	286	\N
Container (Base)	271145.77793703607	5973.550838329915	24851.806875036862	10.910505594238966	9.165478092307898	-0.26330922628959463	30825.357713366775	147	0.022030772095286172	middle	286	\N
Container (Max)	446414.74780931964	9834.861568961773	20990.496144405002	21.267470036829554	4.70201673385818	-0.26330922628959463	30825.357713366775	64	0.022030772095286172	middle	286	\N
Traditional Housing	519826.0393730456	8658.900674560176	7190.366849851314	72.29478693201791	1.3832255995724085	-0.8939573768235807	15849.26752441149	121	0.016657304595598072	low	287	\N
ODD Cubes Basic	321515.6475122837	3328.8571755232088	12520.410348888283	25.679321887467676	3.8941838276813363	-0.8939573768235807	15849.26752441149	91	0.010353639710166914	low	287	\N
Container (Base)	228416.23800671782	2364.939432273291	13484.3280921382	16.939385963168004	5.90340170638027	-0.8939573768235807	15849.26752441149	54	0.010353639710166914	low	287	\N
Container (Max)	418245.57876374206	4330.364032890024	11518.903491521467	36.30949587099096	2.754100479811228	-0.8939573768235807	15849.26752441149	135	0.010353639710166914	low	287	\N
Traditional Housing	555878.7910969426	10174.153854968	19973.80212138775	27.830394419583893	3.5931937755661587	-1.4135868616850567	30147.95597635575	120	0.01830282791486045	middle	288	\N
ODD Cubes Basic	325841.3633602056	3655.627121326172	26492.32885502958	12.299460917281513	8.130437640522418	-1.4135868616850567	30147.95597635575	50	0.011219039484821364	middle	288	\N
Container (Base)	223549.35260906548	2508.009013727359	27639.946962628394	8.087908161015056	12.364136437900616	-1.4135868616850567	30147.95597635575	62	0.011219039484821364	middle	288	\N
Container (Max)	431431.681932995	4840.249074609163	25307.70690174659	17.04744264693614	5.865982486116328	-1.4135868616850567	30147.95597635575	148	0.011219039484821364	middle	288	\N
Traditional Housing	572698.9959856158	11864.200521737135	3977.6823176814505	100	0.6945502516266602	3.0845525831724103	15841.882839418586	106	0.02071629355892065	low	289	\N
ODD Cubes Basic	320841.9255301744	3154.1024859042377	12687.780353514348	25.28747476632549	3.954526931774412	3.0845525831724103	15841.882839418586	117	0.009830705512355499	low	289	\N
Container (Base)	280273.24982539535	2755.283782024304	13086.599057394282	21.41681338262086	4.669228713602519	3.0845525831724103	15841.882839418586	117	0.009830705512355499	low	289	\N
Container (Max)	436942.0925041866	4295.449037361053	11546.433802057532	37.842168412754866	2.642554700070902	3.0845525831724103	15841.882839418586	63	0.009830705512355499	low	289	\N
Traditional Housing	564461.7271925206	8040.944337606845	7469.549579734565	75.56837546455903	1.3233048796569569	-0.1672543305152452	15510.49391734141	113	0.014245331348859237	low	290	\N
ODD Cubes Basic	306336.59716644336	5561.070856674063	9949.423060667346	30.789382992213035	3.2478728146416924	-0.1672543305152452	15510.49391734141	136	0.01815346552815738	low	290	\N
Container (Base)	266623.83421428414	4840.146583394156	10670.347333947255	24.987362254463058	4.002023061963603	-0.1672543305152452	15510.49391734141	63	0.01815346552815738	low	290	\N
Container (Max)	408396.05038923526	7413.803622576606	8096.690294764803	50.43987549496588	1.9825584226507547	-0.1672543305152452	15510.49391734141	78	0.01815346552815738	low	290	\N
Traditional Housing	560035.9389541553	14099.346524788809	16441.185186456576	34.06299075175461	2.935737520195549	4.230402208984499	30540.531711245385	100	0.025175788809408864	middle	291	\N
ODD Cubes Basic	351583.64410704625	8687.07112519569	21853.460586049696	16.08823658489503	6.215721621963734	4.230402208984499	30540.531711245385	79	0.024708405157069104	middle	291	\N
Container (Base)	253013.44805752335	6251.558784792345	24288.97292645304	10.416803082767128	9.59987428056823	4.230402208984499	30540.531711245385	63	0.024708405157069104	middle	291	\N
Container (Max)	457929.96708885895	11314.719160394847	19225.81255085054	23.81849744335515	4.198417647369182	4.230402208984499	30540.531711245385	148	0.024708405157069104	middle	291	\N
Traditional Housing	561346.8578438772	15421.46169193521	15128.897724744593	37.10428003791359	2.6951068690140008	-4.696316383399656	30550.359416679803	109	0.027472250848911417	middle	292	\N
ODD Cubes Basic	333781.2132550225	7914.816403310111	22635.543013369694	14.745889376626593	6.781550942495739	-4.696316383399656	30550.359416679803	129	0.02371258803371557	middle	292	\N
Container (Base)	231239.7300247055	5483.292455103451	25067.06696157635	9.224841916254405	10.840294165236312	-4.696316383399656	30550.359416679803	75	0.02371258803371557	middle	292	\N
Container (Max)	412704.4904534151	9786.291561786333	20764.06785489347	19.875897793126935	5.031219270738044	-4.696316383399656	30550.359416679803	52	0.02371258803371557	middle	292	\N
Traditional Housing	595433.0525319105	13498.001254867968	2179.786708868054	100	0.366084264150122	-4.480256218068882	15677.787963736022	80	0.02266921729902554	low	293	\N
ODD Cubes Basic	304748.2092472382	7054.730372073493	8623.05759166253	35.34108476115171	2.8295679285408886	-4.480256218068882	15677.787963736022	53	0.023149374329383125	low	293	\N
Container (Base)	256022.6536626248	5926.764246438113	9751.023717297909	26.255976919474755	3.808656608234118	-4.480256218068882	15677.787963736022	81	0.023149374329383125	low	293	\N
Container (Max)	427408.49732142256	9894.239296052756	5783.548667683266	73.90073497775734	1.353166514921645	-4.480256218068882	15677.787963736022	78	0.023149374329383125	low	293	\N
Traditional Housing	513565.17042886274	14114.570622602056	16315.26591320787	31.47758505199176	3.176863785288143	-3.040413690446689	30429.836535809925	146	0.027483504402791577	middle	294	\N
ODD Cubes Basic	335813.5990829313	7743.6986461064125	22686.137889703514	14.802590053697326	6.755574506707522	-3.040413690446689	30429.836535809925	115	0.023059514764302493	middle	294	\N
Container (Base)	259417.1927962005	5982.034587397892	24447.801948412034	10.61106406799285	9.424125550390313	-3.040413690446689	30429.836535809925	65	0.023059514764302493	middle	294	\N
Container (Max)	403632.5044462771	9307.569695631319	21122.266840178607	19.10933648837778	5.233044070411319	-3.040413690446689	30429.836535809925	109	0.023059514764302493	middle	294	\N
Traditional Housing	496887.18700594606	10517.122196230184	5446.214844788932	91.23532603224045	1.0960666701038841	2.151348903424597	15963.337041019116	90	0.02116601609230936	low	295	\N
ODD Cubes Basic	349329.6166332426	6943.833317117294	9019.503723901822	38.73046980484234	2.5819464753174084	2.151348903424597	15963.337041019116	50	0.01987759693564016	low	295	\N
Container (Base)	239341.11872687607	4757.526288178039	11205.810752841076	21.358661502131337	4.681941328112775	2.151348903424597	15963.337041019116	142	0.01987759693564016	low	295	\N
Container (Max)	440724.6450211316	8760.546853333142	7202.790187685974	61.188044290753155	1.6343061975444144	2.151348903424597	15963.337041019116	83	0.01987759693564016	low	295	\N
Traditional Housing	572177.8922017828	13526.671753986233	17062.860566960902	33.53352680556391	2.9820901505477178	-3.790063193141957	30589.532320947135	127	0.023640675283581127	middle	296	\N
ODD Cubes Basic	306896.4535711274	3026.202830478828	27563.329490468306	11.13423012547361	8.98131248169674	-3.790063193141957	30589.532320947135	58	0.009860664061982929	middle	296	\N
Container (Base)	254643.30419724892	2510.9520783223993	28078.580242624736	9.06895227596612	11.026632069176586	-3.790063193141957	30589.532320947135	124	0.009860664061982929	middle	296	\N
Container (Max)	451068.2799534962	4447.832777637895	26141.69954330924	17.254741957622397	5.795508286684307	-3.790063193141957	30589.532320947135	99	0.009860664061982929	middle	296	\N
Traditional Housing	550522.6469624832	9076.387970962567	21455.016159120452	25.659390926557656	3.8972086393718444	2.963938511184403	30531.40413008302	141	0.016486856664374612	middle	297	\N
ODD Cubes Basic	325807.93712397333	6269.086951733441	24262.317178349578	13.428558151680058	7.446815873339978	2.963938511184403	30531.40413008302	87	0.01924166429790809	middle	297	\N
Container (Base)	251915.83215508334	4847.279873656274	25684.12425642675	9.80823132764779	10.195518096939297	2.963938511184403	30531.40413008302	144	0.01924166429790809	middle	297	\N
Container (Max)	484598.874958473	9324.488871094876	21206.915258988145	22.850983702265943	4.376179218493943	2.963938511184403	30531.40413008302	70	0.01924166429790809	middle	297	\N
Traditional Housing	496554.20590577525	13861.638995876225	1810.030696170239	100	0.36451824889259027	4.70722070398349	15671.669692046464	116	0.027915661232978402	low	298	\N
ODD Cubes Basic	318039.98680446396	7027.186608237684	8644.48308380878	36.791093662981034	2.718049126672724	4.70722070398349	15671.669692046464	55	0.022095292729835604	low	298	\N
Container (Base)	267784.4780423265	5916.776430851439	9754.893261195026	27.451297607486225	3.6428150475746204	4.70722070398349	15671.669692046464	98	0.022095292729835604	low	298	\N
Container (Max)	486272.40429247747	10744.331119283257	4927.338572763207	98.68865252743944	1.0132877229446005	4.70722070398349	15671.669692046464	88	0.022095292729835604	low	298	\N
Traditional Housing	577289.4137431219	17071.172622455353	13649.843968397901	42.2927481866944	2.3644715533397447	1.185067167499037	30721.016590853254	114	0.029571255276909618	middle	299	\N
ODD Cubes Basic	311574.82696735905	7665.308680223798	23055.707910629455	13.513999577679964	7.3997338408358635	1.185067167499037	30721.016590853254	137	0.024601822794326142	middle	299	\N
Container (Base)	248866.59137953914	6122.571780547396	24598.44481030586	10.117167703027837	9.884189225218861	1.185067167499037	30721.016590853254	127	0.024601822794326142	middle	299	\N
Container (Max)	452278.3404573792	11126.87158564435	19594.145005208906	23.082320781904265	4.332320001305784	1.185067167499037	30721.016590853254	139	0.024601822794326142	middle	299	\N
Traditional Housing	564511.2006148642	16826.737700307396	13893.90136453629	40.63014309686694	2.4612268719208914	1.8158035464434867	30720.639064843686	115	0.029807624156933915	middle	300	\N
ODD Cubes Basic	337373.0817676449	6556.198229836536	24164.44083500715	13.961551358510675	7.162527818876091	1.8158035464434867	30720.639064843686	131	0.019433080420897097	middle	300	\N
Container (Base)	260618.6499109059	5064.62318290426	25656.015881939427	10.158188672402897	9.844274725047535	1.8158035464434867	30720.639064843686	95	0.019433080420897097	middle	300	\N
Container (Max)	490640.16285387013	9534.649742461306	21185.989322382382	23.15870905945955	4.318029979272674	1.8158035464434867	30720.639064843686	143	0.019433080420897097	middle	300	\N
Traditional Housing	552353.8014195283	7757.33849062738	7981.389513326452	69.20521802591745	1.444977746657049	-3.074550348656179	15738.728003953833	114	0.01404414791876387	low	301	\N
ODD Cubes Basic	339797.50829599914	7636.518986501204	8102.209017452628	41.93887217227494	2.384422728136887	-3.074550348656179	15738.728003953833	57	0.02247373450381219	low	301	\N
Container (Base)	230133.52597110593	5171.959763100802	10566.76824085303	21.778988686566272	4.591581429200248	-3.074550348656179	15738.728003953833	46	0.02247373450381219	low	301	\N
Container (Max)	427254.371928874	9602.00132032254	6136.726683631292	69.6225192933074	1.4363168844654648	-3.074550348656179	15738.728003953833	91	0.02247373450381219	low	301	\N
Traditional Housing	570648.2871150171	8511.195848017578	21995.97631634709	25.94330339821832	3.8545592465633196	3.46679602428382	30507.172164364667	128	0.014914959074085687	middle	302	\N
ODD Cubes Basic	334115.8369890694	2932.062554853583	27575.109609511084	12.116573305435844	8.253158502754001	3.46679602428382	30507.172164364667	83	0.008775586878120672	middle	302	\N
Container (Base)	253880.36668223026	2227.9492144690444	28279.222949895622	8.977628810100219	11.138798686741836	3.46679602428382	30507.172164364667	65	0.008775586878120672	middle	302	\N
Container (Max)	501979.97272020066	4405.168861682766	26102.0033026819	19.23147303673139	5.199809697832493	3.46679602428382	30507.172164364667	94	0.008775586878120672	middle	302	\N
Traditional Housing	556912.7737358719	6826.023003949316	24150.16168685005	23.06041594906237	4.336435223930381	-1.7044294244859328	30976.184690799368	110	0.012256897894726164	middle	303	\N
ODD Cubes Basic	349117.1876553595	3427.1679746889645	27549.016716110404	12.672582519113979	7.89105139770608	-1.7044294244859328	30976.184690799368	96	0.009816669290061383	middle	303	\N
Container (Base)	227181.70386692602	2230.167655614272	28746.017035185097	7.903067182798084	12.653315185990227	-1.7044294244859328	30976.184690799368	43	0.009816669290061383	middle	303	\N
Container (Max)	418277.2052924056	4106.088995926659	26870.09569487271	15.56664367861631	6.423992355999557	-1.7044294244859328	30976.184690799368	125	0.009816669290061383	middle	303	\N
Traditional Housing	529519.0596856644	11039.475031296872	4531.508510605379	100	0.8557781684563716	1.22814484149192	15570.983541902251	101	0.020848116473560323	low	304	\N
ODD Cubes Basic	324173.07424629637	3794.142594781405	11776.840947120847	27.526318450072033	3.6328868381502835	1.22814484149192	15570.983541902251	123	0.011704064576007126	low	304	\N
Container (Base)	269496.0269443523	3154.1989023340557	12416.784639568195	21.70417179384407	4.607409163079095	1.22814484149192	15570.983541902251	99	0.011704064576007126	low	304	\N
Container (Max)	452570.6344861376	5296.915931230272	10274.06761067198	44.04980107548047	2.270157811351916	1.22814484149192	15570.983541902251	42	0.011704064576007126	low	304	\N
Traditional Housing	521215.3461273603	10055.544562048872	20268.244199601006	25.715860781745505	3.888650698831958	0.9973293853433995	30323.788761649877	84	0.019292495197545036	middle	305	\N
ODD Cubes Basic	303651.5815163811	4823.464757512419	25500.32400413746	11.907753857053475	8.397889408905248	0.9973293853433995	30323.788761649877	147	0.015884866245138286	middle	305	\N
Container (Base)	260831.92705003344	4143.280273651448	26180.508487998428	9.962828917918193	10.037309766521188	0.9973293853433995	30323.788761649877	41	0.015884866245138286	middle	305	\N
Container (Max)	447529.241202921	7108.94213729663	23214.846624353246	19.277716904381613	5.187336264766451	0.9973293853433995	30323.788761649877	91	0.015884866245138286	middle	305	\N
Traditional Housing	500460.1987157275	6252.470809795981	23817.260143020394	21.01250083806917	4.759071791151393	0.5025242840098443	30069.730952816375	124	0.012493442687032787	middle	306	\N
ODD Cubes Basic	321144.09411022044	2786.2746971125002	27283.456255703873	11.770652922431047	8.495705434439618	0.5025242840098443	30069.730952816375	84	0.008676088859215383	middle	306	\N
Container (Base)	245562.45804829584	2130.5217065143643	27939.20924630201	8.789169939761202	11.377638694595198	0.5025242840098443	30069.730952816375	147	0.008676088859215383	middle	306	\N
Container (Max)	434327.35756838525	3768.2627482515236	26301.46820456485	16.513426330055747	6.055678452265964	0.5025242840098443	30069.730952816375	66	0.008676088859215383	middle	306	\N
Traditional Housing	541990.6976240028	12014.840494389711	18381.53327648059	29.485608706945406	3.3914850120236704	3.7810030693003718	30396.3737708703	135	0.022167982858489595	middle	307	\N
ODD Cubes Basic	297751.9852758502	3576.8446368996915	26819.52913397061	11.102058644971008	9.007338476391299	3.7810030693003718	30396.3737708703	117	0.012012832201894301	middle	307	\N
Container (Base)	241891.78435094017	2905.805416424646	27490.568354445655	8.799082697459854	11.364821020362532	3.7810030693003718	30396.3737708703	125	0.012012832201894301	middle	307	\N
Container (Max)	501101.24665095744	6019.645192178	24376.728578692302	20.55654207386015	4.86463139766881	3.7810030693003718	30396.3737708703	108	0.012012832201894301	middle	307	\N
Traditional Housing	509792.07250895415	9776.647704930547	5906.025717954961	86.3172794793512	1.15851658675042	0.7204547292090782	15682.673422885508	96	0.019177716234021716	low	308	\N
ODD Cubes Basic	351314.69749957405	2923.5217449232396	12759.151677962269	27.534330366678546	3.6318297437521068	0.7204547292090782	15682.673422885508	146	0.008321660795096067	low	308	\N
Container (Base)	275352.7042178421	2291.3918035132997	13391.281619372208	20.56208748679507	4.863319449653145	0.7204547292090782	15682.673422885508	127	0.008321660795096067	low	308	\N
Container (Max)	441543.1481632162	3674.37230541313	12008.301117472378	36.769826459528055	2.7196212119757583	0.7204547292090782	15682.673422885508	126	0.008321660795096067	low	308	\N
Traditional Housing	553555.5968175926	6624.285408271999	9272.708560591536	59.69729267348822	1.675117840719272	0.28115493288695426	15896.993968863535	98	0.011966793301983053	low	309	\N
ODD Cubes Basic	333914.6872676878	2949.7045718363242	12947.28939702721	25.790316183428864	3.877424351402614	0.28115493288695426	15896.993968863535	139	0.008833707184229512	low	309	\N
Container (Base)	237606.62475372775	2098.9473481075306	13798.046620756004	17.220308880265918	5.807096765528853	0.28115493288695426	15896.993968863535	74	0.008833707184229512	low	309	\N
Container (Max)	490818.43455748475	4335.746331502735	11561.2476373608	42.45376017821626	2.355503954896125	0.28115493288695426	15896.993968863535	146	0.008833707184229512	low	309	\N
Traditional Housing	551542.5659590696	9531.117933043211	20621.555647920286	26.745924283102934	3.73888742604331	-0.24546530041891046	30152.673580963496	149	0.017280838363707585	middle	310	\N
ODD Cubes Basic	353901.2774453502	2849.8465751854724	27302.827005778025	12.96207449032494	7.714814482407217	-0.24546530041891046	30152.673580963496	110	0.008052659757990133	middle	310	\N
Container (Base)	235522.4354412094	1896.582037981256	28256.091542982238	8.335280025651828	11.997197417753206	-0.24546530041891046	30152.673580963496	58	0.008052659757990133	middle	310	\N
Container (Max)	422192.0510372407	3399.7689395309044	26752.904641432593	15.781166818925001	6.336667063178025	-0.24546530041891046	30152.673580963496	49	0.008052659757990133	middle	310	\N
Traditional Housing	575785.5686159243	11788.966437592015	3993.0931054875855	100	0.6935035060163454	-3.8994017002091486	15782.0595430796	97	0.020474577829260952	low	311	\N
ODD Cubes Basic	310166.29673067917	5530.524133140686	10251.535409938915	30.255594340528873	3.305173875432519	-3.8994017002091486	15782.0595430796	44	0.017830835237211157	low	311	\N
Container (Base)	255572.8062148561	4557.076598728795	11224.982944350806	22.76821332218399	4.392088153116782	-3.8994017002091486	15782.0595430796	84	0.017830835237211157	low	311	\N
Container (Max)	457304.40472049237	8154.119493822027	7627.940049257573	59.951232150153274	1.6680224311243674	-3.8994017002091486	15782.0595430796	42	0.017830835237211157	low	311	\N
Traditional Housing	516923.0538878257	9999.922193081056	5622.853378500775	91.93251523582377	1.08775442228989	-1.4261119496618635	15622.775571581831	80	0.019345088437961365	low	312	\N
ODD Cubes Basic	312860.8610274835	5461.335048983447	10161.440522598383	30.789026450698724	3.2479104254928663	-1.4261119496618635	15622.775571581831	40	0.017456114616087093	low	312	\N
Container (Base)	256616.8546208395	4479.533226681133	11143.242344900698	23.028921626053563	4.342365727054536	-1.4261119496618635	15622.775571581831	112	0.017456114616087093	low	312	\N
Container (Max)	463010.6619875217	8082.367184124538	7540.408387457293	61.403923792468994	1.6285604212847502	-1.4261119496618635	15622.775571581831	138	0.017456114616087093	low	312	\N
Traditional Housing	503788.3475181423	10361.244210803783	5205.476157950761	96.78045431994997	1.0332664865304975	-2.3336672867886152	15566.720368754544	84	0.02056666110251916	low	313	\N
ODD Cubes Basic	302938.2955938947	6486.796071772617	9079.924296981928	33.36352657638217	2.9972850673042872	-2.3336672867886152	15566.720368754544	54	0.021412928527426985	low	313	\N
Container (Base)	231529.5104091856	4957.724858382054	10608.99551037249	21.823886171204197	4.582135336278754	-2.3336672867886152	15566.720368754544	71	0.021412928527426985	low	313	\N
Container (Max)	460388.6697369266	9858.269679913998	5708.450688840547	80.65037167386602	1.239919890318423	-2.3336672867886152	15566.720368754544	82	0.021412928527426985	low	313	\N
Traditional Housing	600916.6616630651	7413.717171299293	23293.12110213507	25.79803105939223	3.876264811441617	-2.200120200803074	30706.83827343436	124	0.012337346664313622	middle	314	\N
ODD Cubes Basic	305473.82169860555	4780.374319293197	25926.463954141163	11.782317181352957	8.487294855570767	-2.200120200803074	30706.83827343436	74	0.01564904741333198	middle	314	\N
Container (Base)	242574.39977281485	3796.058283305326	26910.779990129035	9.014023371369836	11.093825240970423	-2.200120200803074	30706.83827343436	112	0.01564904741333198	middle	314	\N
Container (Max)	434048.4427648576	6792.444660510168	23914.393612924192	18.150091940039086	5.509613963960154	-2.200120200803074	30706.83827343436	65	0.01564904741333198	middle	314	\N
Traditional Housing	536380.3771118475	11591.949143095946	4242.961215662139	100	0.7910358761646838	4.456696421574129	15834.910358758085	114	0.02161143404520699	low	315	\N
ODD Cubes Basic	332812.0844389157	6804.6924995736645	9030.21785918442	36.85537709374535	2.71330828458599	4.456696421574129	15834.910358758085	60	0.02044604994150264	low	315	\N
Container (Base)	285957.1098376537	5846.6933488684235	9988.21700988966	28.629445030531297	3.492907385852468	4.456696421574129	15834.910358758085	91	0.02044604994150264	low	315	\N
Container (Max)	475730.23485682835	9726.804140565493	6108.106218192592	77.88506254850272	1.2839432456990745	4.456696421574129	15834.910358758085	126	0.02044604994150264	low	315	\N
Traditional Housing	546238.3844264763	12136.150217237313	3863.565891197499	100	0.7073039905926887	-1.5282417868566665	15999.716108434812	91	0.0222176810770625	low	316	\N
ODD Cubes Basic	296547.5795164709	7133.2069035052755	8866.509204929536	33.44580969380809	2.989911170202983	-1.5282417868566665	15999.716108434812	63	0.02405417341505929	low	316	\N
Container (Base)	231957.64838562455	5579.549499217161	10420.166609217651	22.260454854957448	4.492271189046696	-1.5282417868566665	15999.716108434812	48	0.02405417341505929	low	316	\N
Container (Max)	475696.5268962337	11442.486750903423	4557.229357531389	100	0.9580119046203341	-1.5282417868566665	15999.716108434812	46	0.02405417341505929	low	316	\N
Traditional Housing	528084.1228146803	6763.662483034061	23288.297644051934	22.675943552686356	4.4099598222960505	3.551364415860851	30051.960127085993	102	0.012807926220132965	middle	317	\N
ODD Cubes Basic	297816.1728202614	7150.38904140848	22901.57108567751	13.004180879385766	7.689834594543364	3.551364415860851	30051.960127085993	135	0.024009404773742415	middle	317	\N
Container (Base)	254005.61982050238	6098.523741075771	23953.436386010224	10.604141123102151	9.430278118624836	3.551364415860851	30051.960127085993	75	0.024009404773742415	middle	317	\N
Container (Max)	473823.492219	11376.22001599416	18675.740111091833	25.371069066097593	3.941497291244469	3.551364415860851	30051.960127085993	43	0.024009404773742415	middle	317	\N
Traditional Housing	555700.2139415973	7834.13013371646	22259.116364877915	24.965061722684656	4.005597947676388	4.74619609999748	30093.246498594373	82	0.014097763393230954	middle	318	\N
ODD Cubes Basic	327713.3408653712	5021.598674136219	25071.647824458152	13.071073076643847	7.650481288998821	4.74619609999748	30093.246498594373	60	0.015323143882015947	middle	318	\N
Container (Base)	258331.12629494342	3958.4450174206513	26134.801481173723	9.88456432244312	10.116783779022793	4.74619609999748	30093.246498594373	58	0.015323143882015947	middle	318	\N
Container (Max)	481555.12441004603	7378.938458457225	22714.308040137148	21.200519230395116	4.716865606604121	4.74619609999748	30093.246498594373	126	0.015323143882015947	middle	318	\N
Traditional Housing	510792.03232507716	14873.95463593582	16039.17832415414	31.846521187176517	3.1400603981908866	4.765469342523417	30913.13296008996	135	0.02911939438097924	middle	319	\N
ODD Cubes Basic	307759.2381632961	7578.412781219461	23334.7201788705	13.18889773711411	7.582134761618161	4.765469342523417	30913.13296008996	96	0.024624485121705363	middle	319	\N
Container (Base)	264723.75670513266	6518.68620834749	24394.44675174247	10.851804076525069	9.215057634179265	4.765469342523417	30913.13296008996	126	0.024624485121705363	middle	319	\N
Container (Max)	433053.89239186316	10663.72913010003	20249.40382998993	21.386007016685515	4.675954698882278	4.765469342523417	30913.13296008996	65	0.024624485121705363	middle	319	\N
Traditional Housing	572846.4768552339	14386.574750233689	1296.0112833226522	100	0.22624059598609905	0.9722484706570942	15682.586033556341	120	0.025114189109116877	low	320	\N
ODD Cubes Basic	334583.3069190191	7186.261860344585	8496.324173211757	39.379771781064335	2.539374797699685	0.9722484706570942	15682.586033556341	49	0.021478243868526033	low	320	\N
Container (Base)	246401.59944052142	5292.273642378387	10390.312391177955	23.714551609606296	4.2168201889801695	0.9722484706570942	15682.586033556341	105	0.021478243868526033	low	320	\N
Container (Max)	485270.5872838008	10422.760015904323	5259.826017652018	92.25981727441723	1.0838954916045453	0.9722484706570942	15682.586033556341	105	0.021478243868526033	low	320	\N
Traditional Housing	536810.5382562986	13986.144224608708	16339.442175889913	32.85366369779767	3.0438005611746566	3.6046028544902917	30325.58640049862	105	0.02605415361263095	middle	321	\N
ODD Cubes Basic	300955.0972108075	6728.113779230918	23597.472621267705	12.753700450935815	7.840861590305141	3.6046028544902917	30325.58640049862	110	0.022355872492560352	middle	321	\N
Container (Base)	272060.9096513138	6082.1590063747535	24243.427394123868	11.222048154678658	8.911029307810297	3.6046028544902917	30325.58640049862	43	0.022355872492560352	middle	321	\N
Container (Max)	446657.92247716256	9985.427562691353	20340.15883780727	21.959411725287865	4.553856052748567	3.6046028544902917	30325.58640049862	63	0.022355872492560352	middle	321	\N
Traditional Housing	565269.3733056589	16476.175230875084	14195.170748782122	39.82124507760192	2.5112223338352258	1.7526552665205122	30671.345979657206	117	0.029147475538119944	middle	322	\N
ODD Cubes Basic	298843.00712173874	2773.136367153153	27898.20961250405	10.711906293362873	9.3354065337521	1.7526552665205122	30671.345979657206	44	0.009279575901280732	middle	322	\N
Container (Base)	253664.97075200686	2353.9033495894046	28317.442630067802	8.957905347097352	11.163324027798888	1.7526552665205122	30671.345979657206	94	0.009279575901280732	middle	322	\N
Container (Max)	473894.4745343668	4397.539745639206	26273.806234018	18.036765222116625	5.544231394517478	1.7526552665205122	30671.345979657206	80	0.009279575901280732	middle	322	\N
Traditional Housing	517685.47103343555	9443.884995894308	21555.5867466041	24.016301533290086	4.163838460363493	1.270326392426079	30999.47174249841	86	0.018242515048842	middle	323	\N
ODD Cubes Basic	339031.0639694589	5056.371606447869	25943.10013605054	13.068255612918875	7.652130702214233	1.270326392426079	30999.47174249841	56	0.014914183813266636	middle	323	\N
Container (Base)	256700.66221739777	3828.48086129754	27170.99088120087	9.447600322703153	10.584698397930104	1.270326392426079	30999.47174249841	84	0.014914183813266636	middle	323	\N
Container (Max)	475168.10164770554	7086.744410174845	23912.727332323564	19.87092877546453	5.0324774010299	1.270326392426079	30999.47174249841	63	0.014914183813266636	middle	323	\N
Traditional Housing	501755.4033032762	8599.80659236393	7372.578237612914	68.05697913702087	1.4693570191922185	2.075976535240284	15972.384829976843	128	0.01713943992580374	low	324	\N
ODD Cubes Basic	307759.09818992816	6540.745173462884	9431.639656513958	32.630497919561044	3.064617654518011	2.075976535240284	15972.384829976843	144	0.021252808485377018	low	324	\N
Container (Base)	235498.38255270192	5005.002023008627	10967.382806968217	21.472614451195785	4.657094748629043	2.075976535240284	15972.384829976843	51	0.021252808485377018	low	324	\N
Container (Max)	492705.2528333961	10471.37037820743	5501.014451769413	89.56625312535152	1.1164919432327491	2.075976535240284	15972.384829976843	110	0.021252808485377018	low	324	\N
Traditional Housing	506495.76027850644	11114.189602048986	19175.26589943224	26.41401495733643	3.785868985139847	2.3954400686000987	30289.455501481225	98	0.02194330234065066	middle	325	\N
ODD Cubes Basic	305527.48252607574	4753.407593555956	25536.04790792527	11.964556286380297	8.358019938761435	2.3954400686000987	30289.455501481225	102	0.015558036070127564	middle	325	\N
Container (Base)	278109.61507114535	4326.8394227261715	25962.616078755054	10.711925725340121	9.335389598850567	2.3954400686000987	30289.455501481225	114	0.015558036070127564	middle	325	\N
Container (Max)	494757.1245981901	7697.449190451239	22592.006311029985	21.89965414256445	4.566282159024544	2.3954400686000987	30289.455501481225	117	0.015558036070127564	middle	325	\N
Traditional Housing	551806.9283211424	14922.916184508647	16002.104401169987	34.48339758868198	2.899946263787581	2.4070490592717695	30925.020585678634	106	0.027043727468067887	middle	326	\N
ODD Cubes Basic	324141.60653760936	6262.203768832236	24662.816816846396	13.142927222984456	7.60865508142807	2.4070490592717695	30925.020585678634	123	0.01931934575052971	middle	326	\N
Container (Base)	264082.60184512124	5101.903091745372	25823.117493933263	10.22659645595321	9.778424369310768	2.4070490592717695	30925.020585678634	75	0.01931934575052971	middle	326	\N
Container (Max)	491026.2314387289	9486.305537744425	21438.71504793421	22.903715560417563	4.366103819976748	2.4070490592717695	30925.020585678634	136	0.01931934575052971	middle	326	\N
Traditional Housing	525100.746444149	13316.576512020509	2234.139692628458	100	0.4254687710420322	2.918629894458279	15550.716204648967	111	0.02536004110105925	low	327	\N
ODD Cubes Basic	324294.5252609228	6680.587530465592	8870.128674183376	36.56029547855221	2.735207653304229	2.918629894458279	15550.716204648967	122	0.020600370990199374	low	327	\N
Container (Base)	241205.39829320443	4968.920689678814	10581.795514970152	22.794373407799196	4.387047549452908	2.918629894458279	15550.716204648967	108	0.020600370990199374	low	327	\N
Container (Max)	435549.30181042466	8972.477201817064	6578.239002831902	66.21062287687064	1.5103316606153392	2.918629894458279	15550.716204648967	43	0.020600370990199374	low	327	\N
Traditional Housing	532482.2905280684	12763.67986066089	17299.344564934276	30.780489314456954	3.2488112511269303	-3.558582297513019	30063.024425595166	139	0.02397014903162885	middle	328	\N
ODD Cubes Basic	301924.0147060431	7464.670104024195	22598.354321570972	13.360442553015703	7.484782005026331	-3.558582297513019	30063.024425595166	48	0.024723671322706437	middle	328	\N
Container (Base)	247618.0476960717	6122.027224807923	23940.997200787242	10.342846023470125	9.668518681712815	-3.558582297513019	30063.024425595166	123	0.024723671322706437	middle	328	\N
Container (Max)	410305.1740895197	10144.250266195131	19918.774159400033	20.598916921596263	4.854624171776637	-3.558582297513019	30063.024425595166	75	0.024723671322706437	middle	328	\N
Traditional Housing	561507.4384326978	8881.073767753594	6961.9847626321425	80.65335641734536	1.2398740045305037	-1.3457347296957	15843.058530385737	147	0.01581648462670914	low	329	\N
ODD Cubes Basic	341287.5968636874	2937.284052148916	12905.77447823682	26.444565371819042	3.781495312702933	-1.3457347296957	15843.058530385737	112	0.008606477584129983	low	329	\N
Container (Base)	267285.2795711793	2300.3847671972703	13542.673763188466	19.736522066839633	5.066748825418195	-1.3457347296957	15843.058530385737	85	0.008606477584129983	low	329	\N
Container (Max)	449630.1551199726	3869.7318511889316	11973.326679196805	37.552650751706935	2.6629278625678525	-1.3457347296957	15843.058530385737	62	0.008606477584129983	low	329	\N
Traditional Housing	594253.2425299683	16151.22818460174	-429.39366683586013	100	0	-4.917756988805021	15721.83451776588	132	0.027179032487630442	low	330	Negative cash flow
ODD Cubes Basic	301747.58922570327	6953.169754784785	8768.664762981094	34.41203391645204	2.905960172037115	-4.917756988805021	15721.83451776588	140	0.023043000186436964	low	330	\N
Container (Base)	259097.3328958695	5970.379890224841	9751.45462754104	26.570121360571246	3.7636260159652517	-4.917756988805021	15721.83451776588	70	0.023043000186436964	low	330	\N
Container (Max)	430950.6816958788	9930.396638663271	5791.437879102608	74.4116902731339	1.3438748620403893	-4.917756988805021	15721.83451776588	99	0.023043000186436964	low	330	\N
Traditional Housing	581223.0954949177	10423.11613423824	19750.84836908239	29.427753412595358	3.398152709720582	-1.8870181121395504	30173.96450332063	96	0.017933072885486158	middle	331	\N
ODD Cubes Basic	337006.29533431533	2826.301789159592	27347.662714161037	12.323038310685627	8.114881856148042	-1.8870181121395504	30173.96450332063	125	0.00838649552927745	middle	331	\N
Container (Base)	225874.48947766633	1894.2953961822752	28279.669107138354	7.9871687544127274	12.52008102930745	-1.8870181121395504	30173.96450332063	119	0.00838649552927745	middle	331	\N
Container (Max)	462755.7980603927	3880.8994315807026	26293.065071739926	17.599918335795994	5.681844545642734	-1.8870181121395504	30173.96450332063	120	0.00838649552927745	middle	331	\N
Traditional Housing	506640.22504121816	6141.894248956468	24432.102857772803	20.73666061372348	4.822377231453564	-0.7488593573051139	30573.99710672927	101	0.012122792359127799	middle	332	\N
ODD Cubes Basic	306984.60330812016	6734.234956220974	23839.762150508297	12.876999416773746	7.765784307618956	-0.7488593573051139	30573.99710672927	144	0.021936718922224995	middle	332	\N
Container (Base)	264504.9739746649	5802.371267612662	24771.62583911661	10.677739753237672	9.365277887549029	-0.7488593573051139	30573.99710672927	101	0.021936718922224995	middle	332	\N
Container (Max)	423950.5274342864	9300.083557254979	21273.913549474295	19.92818699993085	5.018017946155714	-0.7488593573051139	30573.99710672927	94	0.021936718922224995	middle	332	\N
Traditional Housing	595192.3715388945	17508.190303445183	-1558.3778394840538	100	0	1.289076975441386	15949.812463961129	101	0.02941601932527635	low	333	Negative cash flow
ODD Cubes Basic	314408.71899748605	3027.556169362764	12922.256294598365	24.330791142790762	4.11001842945128	1.289076975441386	15949.812463961129	134	0.009629364538669081	low	333	\N
Container (Base)	263375.38045559835	2536.1375489176166	13413.674915043512	19.63484146765935	5.092987390028615	1.289076975441386	15949.812463961129	147	0.009629364538669081	low	333	\N
Container (Max)	436277.8746991685	4201.078695634086	11748.733768327042	37.134033616057685	2.6929474194464427	1.289076975441386	15949.812463961129	59	0.009629364538669081	low	333	\N
Traditional Housing	499485.2595927116	14205.490198441734	1490.203810089768	100	0.2983479054626966	-4.2029866278199925	15695.694008531502	83	0.02844025909798644	low	334	\N
ODD Cubes Basic	300615.97515144857	3519.4280037516087	12176.266004779893	24.68868329859411	4.050438769478422	-4.2029866278199925	15695.694008531502	65	0.01170738847786962	low	334	\N
Container (Base)	257405.17181469125	3013.5423426473662	12682.151665884136	20.29664828146859	4.926921854940099	-4.2029866278199925	15695.694008531502	143	0.01170738847786962	low	334	\N
Container (Max)	392209.49601328786	4591.748934537017	11103.945073994484	35.32163509452557	2.8311260147608173	-4.2029866278199925	15695.694008531502	75	0.01170738847786962	low	334	\N
Traditional Housing	501645.43821843487	13093.2993156271	2525.6479121502052	100	0.5034727159325718	-4.26102448648932	15618.947227777306	94	0.026100704438033376	low	335	\N
ODD Cubes Basic	317463.1963668148	7487.603853335238	8131.343374442067	39.04191247963348	2.5613499352052944	-4.26102448648932	15618.947227777306	99	0.023585738249430468	low	335	\N
Container (Base)	232682.95406732458	5487.99924973617	10130.947978041135	22.967540112896216	4.353970843566754	-4.26102448648932	15618.947227777306	103	0.023585738249430468	low	335	\N
Container (Max)	408251.7789049629	9628.919597116814	5990.027630660492	68.15524135736698	1.467238586621055	-4.26102448648932	15618.947227777306	95	0.023585738249430468	low	335	\N
Traditional Housing	565315.1044492831	13452.594031182009	16584.47501986128	34.08700629789436	2.933669185439064	-2.142588771452427	30037.069051043287	91	0.023796629393596717	middle	336	\N
ODD Cubes Basic	311373.7609334795	6489.274040808002	23547.795010235284	13.223053827253796	7.562549567323988	-2.142588771452427	30037.069051043287	117	0.020840786395595938	middle	336	\N
Container (Base)	225890.71071580908	4707.740050777531	25329.329000265756	8.918148234935044	11.21309013549138	-2.142588771452427	30037.069051043287	114	0.020840786395595938	middle	336	\N
Container (Max)	480134.00408744684	10006.370220448667	20030.69883059462	23.969907797430242	4.17189756611082	-2.142588771452427	30037.069051043287	113	0.020840786395595938	middle	336	\N
Traditional Housing	547502.5493685709	14082.011634287517	16498.578649673786	33.18483131147763	3.0134249911167403	1.7044503611199975	30580.590283961305	83	0.025720449430834902	middle	337	\N
ODD Cubes Basic	329887.76551487786	4129.340802165711	26451.249481795596	12.471538092819198	8.01825719135457	1.7044503611199975	30580.590283961305	132	0.012517411173829901	middle	337	\N
Container (Base)	267891.36283425486	3353.306338514022	27227.28394544728	9.839077719650748	10.163554232352343	1.7044503611199975	30580.590283961305	123	0.012517411173829901	middle	337	\N
Container (Max)	434489.54826912	5438.684326416189	25141.905957545117	17.281488086177855	5.786538722899817	1.7044503611199975	30580.590283961305	138	0.012517411173829901	middle	337	\N
Traditional Housing	568237.7096795123	6482.927650612548	9034.17472006093	62.89868496982975	1.5898583578967735	-3.709185827460634	15517.102370673478	147	0.011408830389431454	low	338	\N
ODD Cubes Basic	314119.5770795716	3807.6458173875703	11709.456553285907	26.826144804425052	3.7277067103397092	-3.709185827460634	15517.102370673478	97	0.012121644415760281	low	338	\N
Container (Base)	222919.7976866657	2702.154520790983	12814.947849882494	17.39529495539147	5.748680908052449	-3.709185827460634	15517.102370673478	74	0.012121644415760281	low	338	\N
Container (Max)	434426.68077538203	5265.965749078184	10251.136621595295	42.37839147126458	2.3596931485190225	-3.709185827460634	15517.102370673478	129	0.012121644415760281	low	338	\N
Traditional Housing	589990.8741931586	10124.778547348062	5826.890418066208	100	0.9876238214760129	4.901696055467605	15951.66896541427	88	0.01716090704147618	low	339	\N
ODD Cubes Basic	305778.3838251357	5572.97901189741	10378.68995351686	29.46213685875851	3.394186934892062	4.901696055467605	15951.66896541427	96	0.018225549308562006	low	339	\N
Container (Base)	261021.14254148916	4757.253703967102	11194.415261447168	23.31708592591065	4.288700582814982	4.901696055467605	15951.66896541427	90	0.018225549308562006	low	339	\N
Container (Max)	466170.9155041819	8496.221006738959	7455.447958675311	62.527552749092145	1.5992949604356925	4.901696055467605	15951.66896541427	137	0.018225549308562006	low	339	\N
Traditional Housing	550460.0061187458	11422.54022188866	18825.668349592386	29.239865267820058	3.419988398854048	2.6365394054316074	30248.208571481046	92	0.020750899420337865	middle	340	\N
ODD Cubes Basic	351846.4077992461	4644.660462145557	25603.54810933549	13.742095677393904	7.276910476216705	2.6365394054316074	30248.208571481046	111	0.013200818195636298	middle	340	\N
Container (Base)	240148.93474117047	3170.162427393917	27078.04614408713	8.868768945266398	11.275522072696893	2.6365394054316074	30248.208571481046	129	0.013200818195636298	middle	340	\N
Container (Max)	451040.9548184574	5954.109643344662	24294.098928136384	18.565864745700903	5.386229048294446	2.6365394054316074	30248.208571481046	136	0.013200818195636298	middle	340	\N
Traditional Housing	571364.7281493642	13888.62061238451	1974.1788898508512	100	0.34551990919095865	0.07488159292289609	15862.79950223536	85	0.02430780187879185	low	341	\N
ODD Cubes Basic	315006.120354614	7825.240958998091	8037.55854323727	39.19176683567143	2.5515563107755157	0.07488159292289609	15862.79950223536	93	0.024841552126634647	low	341	\N
Container (Base)	248001.80353319406	6160.749729969245	9702.049772266117	25.561794605725677	3.912088393731191	0.07488159292289609	15862.79950223536	67	0.024841552126634647	low	341	\N
Container (Max)	454977.61552830134	11302.350152598234	4560.449349637127	99.7659617828019	1.002345872409947	0.07488159292289609	15862.79950223536	86	0.024841552126634647	low	341	\N
Traditional Housing	577796.2197995525	15327.474099456122	14818.765514210387	38.990847061145374	2.5647044764936804	3.4147023236235245	30146.23961366651	119	0.02652747382939523	middle	342	\N
ODD Cubes Basic	352674.6369877409	4084.4808794065566	26061.75873425995	13.532265438560987	7.389745675180455	3.4147023236235245	30146.23961366651	73	0.011581442074465181	middle	342	\N
Container (Base)	272885.25871615065	3160.4048167965434	26985.834796869964	10.112166652254245	9.889077527980376	3.4147023236235245	30146.23961366651	122	0.011581442074465181	middle	342	\N
Container (Max)	437520.1208607419	5067.113936161687	25079.12567750482	17.445589072237215	5.73210796069588	3.4147023236235245	30146.23961366651	94	0.011581442074465181	middle	342	\N
Traditional Housing	542575.8866609146	10845.157043785272	4943.280246124219	100	0.9110762876960556	3.6617645639021106	15788.43728990949	109	0.01998827686672151	low	343	\N
ODD Cubes Basic	307592.92656178266	5812.225990751327	9976.211299158163	30.832639499901	3.243316226634476	3.6617645639021106	15788.43728990949	61	0.018895837611479963	low	343	\N
Container (Base)	265209.60939926514	5011.357712212544	10777.079577696946	24.608671346188597	4.063608253904697	3.6617645639021106	15788.43728990949	90	0.018895837611479963	low	343	\N
Container (Max)	444483.50181539584	8398.888071285679	7389.549218623812	60.15028639300057	1.6625024749946422	3.6617645639021106	15788.43728990949	61	0.018895837611479963	low	343	\N
Traditional Housing	541343.7848144117	7188.473218060406	8326.539367112568	65.01425873905835	1.5381241275296338	1.9332799550713675	15515.012585172974	126	0.013278942918915793	low	344	\N
ODD Cubes Basic	306132.9685390591	7261.540389087981	8253.472196084993	37.09141574188283	2.69604160423249	1.9332799550713675	15515.012585172974	143	0.02372021681866483	low	344	\N
Container (Base)	257363.25330199342	6104.712169480241	9410.300415692733	27.349100659189507	3.656427362864644	1.9332799550713675	15515.012585172974	118	0.02372021681866483	low	344	\N
Container (Max)	441061.99703438306	10462.08620012887	5052.926385044104	87.28842722503532	1.145627240392285	1.9332799550713675	15515.012585172974	137	0.02372021681866483	low	344	\N
Traditional Housing	499917.20436136355	11628.298896496355	3901.7667264156935	100	0.7804825863915085	-1.5266558311222491	15530.065622912049	140	0.023260449520538757	low	345	\N
ODD Cubes Basic	329787.2795958411	5372.671244063683	10157.394378848367	32.46770454070249	3.079983676537311	-1.5266558311222491	15530.065622912049	139	0.016291323457496502	low	345	\N
Container (Base)	257843.68716112574	4200.614909015438	11329.450713896611	22.75871034461157	4.393922084591069	-1.5266558311222491	15530.065622912049	42	0.016291323457496502	low	345	\N
Container (Max)	426770.6362244741	6952.658476894482	8577.407146017566	49.75520328688384	2.009840044736816	-1.5266558311222491	15530.065622912049	63	0.016291323457496502	low	345	\N
Traditional Housing	523493.7868903961	5859.887724785338	24470.413816593853	21.392927427136726	4.674442071595632	-4.411880724891622	30330.30154137919	133	0.011193805679325517	middle	346	\N
ODD Cubes Basic	330809.3038967425	4955.509768512834	25374.791772866356	13.036926838961566	7.670519382002248	-4.411880724891622	30330.30154137919	88	0.014979958877032148	middle	346	\N
Container (Base)	230288.40670281433	3449.710862265413	26880.59067911378	8.567088776131264	11.67257660252216	-4.411880724891622	30330.30154137919	145	0.014979958877032148	middle	346	\N
Container (Max)	418200.7541202661	6264.630099065419	24065.67144231377	17.377481244298856	5.754573899068811	-4.411880724891622	30330.30154137919	127	0.014979958877032148	middle	346	\N
Traditional Housing	584489.4120330757	10545.67078140908	20027.782051927847	29.183931127152125	3.426543174197738	-0.45807519920041884	30573.452833336927	111	0.018042535184217008	middle	347	\N
ODD Cubes Basic	320008.1011804237	2703.5384078907573	27869.91442544617	11.482206091319947	8.709127776028659	-0.45807519920041884	30573.452833336927	87	0.008448343644795655	middle	347	\N
Container (Base)	236107.3835847796	1994.7163135978026	28578.736519739126	8.261645276784785	12.104126557091467	-0.45807519920041884	30573.452833336927	87	0.008448343644795655	middle	347	\N
Container (Max)	428944.3291877465	3623.8690974644337	26949.583735872493	15.916547483320874	6.282769558209223	-0.45807519920041884	30573.452833336927	85	0.008448343644795655	middle	347	\N
Traditional Housing	584191.069559111	9508.12352211568	6072.46258993656	96.20332128966054	1.039465152132409	0.7664927516403512	15580.58611205224	93	0.016275708441232183	low	348	\N
ODD Cubes Basic	316972.6524162077	6316.779554526814	9263.806557525426	34.21624258320851	2.92258858513806	0.7664927516403512	15580.58611205224	129	0.019928468611962243	low	348	\N
Container (Base)	266644.10481662984	5313.8086734029785	10266.777438649262	25.97154817176115	3.850367307280124	0.7664927516403512	15580.58611205224	105	0.019928468611962243	low	348	\N
Container (Max)	492264.81434334285	9810.08390141473	5770.502210637511	85.30710090291407	1.1722353583883662	0.7664927516403512	15580.58611205224	99	0.019928468611962243	low	348	\N
Traditional Housing	551214.213798566	12506.909940674426	17498.434483986435	31.500773072185726	3.17452526548617	-0.34392475133632505	30005.344424660863	85	0.022689744980424094	middle	349	\N
ODD Cubes Basic	327618.96892082854	4925.899354843393	25079.44506981747	13.063246336144429	7.655065014223306	-0.34392475133632505	30005.344424660863	73	0.015035452223872214	middle	349	\N
Container (Base)	262964.85977125895	3953.7955856480203	26051.548839012845	10.094020182687277	9.906855563010925	-0.34392475133632505	30005.344424660863	44	0.015035452223872214	middle	349	\N
Container (Max)	449001.7362057444	6750.944153157145	23254.40027150372	19.308248372930848	5.179133708482576	-0.34392475133632505	30005.344424660863	146	0.015035452223872214	middle	349	\N
Traditional Housing	554556.2356243839	14242.739244361948	1537.8658758694855	100	0.27731468462129494	-1.1571066031967892	15780.605120231434	81	0.02568312883241826	low	350	\N
ODD Cubes Basic	356217.8984408043	7278.691654733654	8501.913465497779	41.89855611756077	2.3867170916204294	-1.1571066031967892	15780.605120231434	112	0.020433256404557718	low	350	\N
Container (Base)	238481.3575246706	4872.950726008595	10907.654394222838	21.863670126088756	4.573797510815685	-1.1571066031967892	15780.605120231434	140	0.020433256404557718	low	350	\N
Container (Max)	484704.2175078474	9904.08555670836	5876.519563523074	82.4815117636159	1.2123929091720629	-1.1571066031967892	15780.605120231434	130	0.020433256404557718	low	350	\N
Traditional Housing	496201.8538212404	8927.191626255888	6729.883965530695	73.73111577594811	1.3562794886202045	3.006124721543028	15657.075591786583	148	0.017991048516864186	low	351	\N
ODD Cubes Basic	323518.2460917992	4716.001253463664	10941.074338322918	29.569147972847894	3.3819033301813697	3.006124721543028	15657.075591786583	120	0.014577234237742143	low	351	\N
Container (Base)	259170.38246724033	3777.9873727101817	11879.0882190764	21.817363225827684	4.583505301026417	3.006124721543028	15657.075591786583	88	0.014577234237742143	low	351	\N
Container (Max)	447252.8456855965	6519.709495055681	9137.3660967309	48.94767714797061	2.0429978668384274	3.006124721543028	15657.075591786583	131	0.014577234237742143	low	351	\N
Traditional Housing	533938.7741181266	5828.534080949489	24775.735500959665	21.55087481045497	4.640182864014737	-4.382414597446312	30604.269581909153	94	0.010916109418305715	middle	352	\N
ODD Cubes Basic	313336.6953866624	2613.1123525556404	27991.157229353514	11.194131518723895	8.933252198505505	-4.382414597446312	30604.269581909153	60	0.00833963079023036	middle	352	\N
Container (Base)	224600.848790648	1873.088154086361	28731.18142782279	7.817320333828957	12.792107234912246	-4.382414597446312	30604.269581909153	101	0.00833963079023036	middle	352	\N
Container (Max)	450349.0931865255	3755.7451638906696	26848.52441801848	16.773699968564713	5.961713884677096	-4.382414597446312	30604.269581909153	88	0.00833963079023036	middle	352	\N
Traditional Housing	542118.5251954958	14512.076504826284	16233.483490627783	33.39508279344244	2.9944528246426834	3.5257197664276045	30745.559995454067	145	0.02676919498294772	middle	353	\N
ODD Cubes Basic	346927.80886405887	3654.470015416687	27091.08998003738	12.80597455176959	7.808855124281151	3.5257197664276045	30745.559995454067	132	0.010533805368276673	middle	353	\N
Container (Base)	241692.41195792644	2545.940826554143	28199.619168899924	8.570768651531223	11.667564960131592	3.5257197664276045	30745.559995454067	142	0.010533805368276673	middle	353	\N
Container (Max)	435764.18249975896	4590.255084918657	26155.304910535408	16.660642419971648	6.002169512991095	3.5257197664276045	30745.559995454067	124	0.010533805368276673	middle	353	\N
Traditional Housing	545107.1053178855	14863.853404184561	701.8100209841723	100	0.12874717906582847	-4.245515168004123	15565.663425168734	138	0.027267766754785802	low	354	\N
ODD Cubes Basic	340806.85861369036	7830.525741090158	7735.137684078576	44.05957237389342	2.2696543477860196	-4.245515168004123	15565.663425168734	119	0.022976432378569514	low	354	\N
Container (Base)	230929.9242523218	5305.945788771652	10259.717636397083	22.508409337999844	4.442783961244872	-4.245515168004123	15565.663425168734	126	0.022976432378569514	low	354	\N
Container (Max)	396709.39258748136	9114.966532729652	6450.696892439082	61.498687537538444	1.6260509614771954	-4.245515168004123	15565.663425168734	98	0.022976432378569514	low	354	\N
Traditional Housing	505629.52038932964	12307.750124357128	17883.08921486408	28.274170883689383	3.5367969024226045	-1.384894610154077	30190.83933922121	95	0.024341438994464334	middle	355	\N
ODD Cubes Basic	339920.7861641476	7364.591898520149	22826.24744070106	14.89166307546641	6.715166700537776	-1.384894610154077	30190.83933922121	147	0.021665612102237816	middle	355	\N
Container (Base)	259069.86352193853	5612.907170446011	24577.932168775198	10.540751017739051	9.486990047645543	-1.384894610154077	30190.83933922121	127	0.021665612102237816	middle	355	\N
Container (Max)	430530.9029025624	9327.715540313131	20863.123798908076	20.635975084665667	4.845906219101259	-1.384894610154077	30190.83933922121	108	0.021665612102237816	middle	355	\N
Traditional Housing	515041.3987553463	6785.737601022904	23383.881548603567	22.025487842334005	4.5401945562265995	-1.8881980946367447	30169.619149626473	97	0.01317513042140181	middle	356	\N
ODD Cubes Basic	300197.7952568206	6986.948908975144	23182.67024065133	12.949232859742667	7.72246519026512	-1.8881980946367447	30169.619149626473	134	0.023274484421172303	middle	356	\N
Container (Base)	249910.7186728104	5816.5431284343	24353.076021192173	10.261977520019927	9.744710491219807	-1.8881980946367447	30169.619149626473	109	0.023274484421172303	middle	356	\N
Container (Max)	463284.6175357129	10782.710613403719	19386.908536222756	23.896776356586496	4.184664848003138	-1.8881980946367447	30169.619149626473	122	0.023274484421172303	middle	356	\N
Traditional Housing	579189.7427980473	16020.021942027772	14686.79268844314	39.43609439342088	2.535748063750527	1.4504501950584023	30706.81463047091	129	0.027659367489202336	middle	357	\N
ODD Cubes Basic	302684.14040072006	2803.6675610938037	27903.147069377108	10.847670323642708	9.218569242655546	1.4504501950584023	30706.81463047091	58	0.009262684055339207	middle	357	\N
Container (Base)	231190.48147227854	2141.444386479469	28565.37024399144	8.093382984276499	12.355772634790176	1.4504501950584023	30706.81463047091	69	0.009262684055339207	middle	357	\N
Container (Max)	457466.5926554332	4237.368513639837	26469.446116831074	17.28281697456997	5.786093791720444	1.4504501950584023	30706.81463047091	54	0.009262684055339207	middle	357	\N
Traditional Housing	591232.1776274507	12758.735146345976	17242.06507722887	34.290102431423655	2.9162934173203108	4.93554516138488	30000.800223574846	145	0.021579906556414723	middle	358	\N
ODD Cubes Basic	302065.7157065716	4834.165341014512	25166.634882560335	12.002626378781112	8.331509858274465	4.93554516138488	30000.800223574846	101	0.01600368757409877	middle	358	\N
Container (Base)	277096.53211842093	4434.566327889434	25566.23389568541	10.838378982568257	9.22647198080391	4.93554516138488	30000.800223574846	83	0.01600368757409877	middle	358	\N
Container (Max)	435914.6130279724	6976.241275883836	23024.55894769101	18.932593411162284	5.281896559456137	4.93554516138488	30000.800223574846	88	0.01600368757409877	middle	358	\N
Traditional Housing	511577.4508367782	6380.81216284017	24002.943600428815	21.313113064500925	4.691947145279297	-0.47753801464997636	30383.755763268986	84	0.012472817463715783	middle	359	\N
ODD Cubes Basic	320029.07060560444	6105.004422111708	24278.75134115728	13.181446858969718	7.586420600857785	-0.47753801464997636	30383.755763268986	41	0.019076405810756352	middle	359	\N
Container (Base)	236062.71010616576	4503.228054772153	25880.527708496833	9.12124794227685	10.963412093700628	-0.47753801464997636	30383.755763268986	129	0.019076405810756352	middle	359	\N
Container (Max)	465274.11993278767	8875.75792508038	21507.997838188607	21.632609573108123	4.622650802347571	-0.47753801464997636	30383.755763268986	78	0.019076405810756352	middle	359	\N
Traditional Housing	578702.15660146	6634.498885270546	23709.49223539505	24.40803669922278	4.097011211196035	3.3664070752765376	30343.991120665596	98	0.011464444722710075	middle	360	\N
ODD Cubes Basic	350413.3741415303	7351.965852632642	22992.025268032954	15.240648444690464	6.5614006098827105	3.3664070752765376	30343.991120665596	64	0.020980836906251236	middle	360	\N
Container (Base)	250600.48120787836	5257.8078248505735	25086.183295815023	9.98958184482709	10.010429020288077	3.3664070752765376	30343.991120665596	147	0.020980836906251236	middle	360	\N
Container (Max)	427577.07771454006	8970.924932380276	21373.06618828532	20.005415879397646	4.9986463966982	3.3664070752765376	30343.991120665596	63	0.020980836906251236	middle	360	\N
Traditional Housing	571743.2820605744	16807.860695094147	-863.2280118804501	100	0	1.7231814089865969	15944.632683213697	99	0.029397565695076074	low	361	Negative cash flow
ODD Cubes Basic	331278.7536928156	3831.775992658732	12112.856690554965	27.349349716250764	3.656394065581048	1.7231814089865969	15944.632683213697	134	0.011566621613808102	low	361	\N
Container (Base)	268017.0001048785	3100.051226281096	12844.5814569326	20.866152860140243	4.7924502743879485	1.7231814089865969	15944.632683213697	120	0.011566621613808102	low	361	\N
Container (Max)	466636.85255320906	5397.411904541333	10547.220778672363	44.24263626839024	2.2602631405906153	1.7231814089865969	15944.632683213697	68	0.011566621613808102	low	361	\N
Traditional Housing	558579.7696072579	10810.40174999524	4768.8009008265235	100	0.8537367732060019	3.480509388841508	15579.202650821764	95	0.019353371421947707	low	362	\N
ODD Cubes Basic	301868.2154264504	6550.299750031022	9028.902900790741	33.43354322705289	2.991008141759998	3.480509388841508	15579.202650821764	55	0.021699203212823807	low	362	\N
Container (Base)	278187.2654434618	6036.442004077435	9542.76064674433	29.15165492895077	3.4303369823676495	3.480509388841508	15579.202650821764	93	0.021699203212823807	low	362	\N
Container (Max)	443886.25537483447	9631.978058757937	5947.224592063827	74.63754706139245	1.339808232413451	3.480509388841508	15579.202650821764	140	0.021699203212823807	low	362	\N
Traditional Housing	599577.8867472579	9160.305546220092	20953.138649670364	28.61518251618549	3.494648337239764	4.272971888547797	30113.444195890457	113	0.015277924267546355	middle	363	\N
ODD Cubes Basic	345065.35255477077	7159.435360167123	22954.008835723333	15.032901443243562	6.652075807025552	4.272971888547797	30113.444195890457	112	0.020748056294729665	middle	363	\N
Container (Base)	255218.7887907747	5295.293797303714	24818.150398586742	10.283553959174492	9.724264626509282	4.272971888547797	30113.444195890457	93	0.020748056294729665	middle	363	\N
Container (Max)	455362.92988606944	9447.895703809207	20665.548492081252	22.034882357976517	4.538258855909003	4.272971888547797	30113.444195890457	54	0.020748056294729665	middle	363	\N
Traditional Housing	499925.65982709476	6040.535865909621	9622.730389733635	51.952578902185486	1.9248322626731686	2.147713172626222	15663.266255643255	100	0.012082868216844105	low	364	\N
ODD Cubes Basic	304617.02012808714	4102.746673273834	11560.519582369421	26.349768966496004	3.795099688621596	2.147713172626222	15663.266255643255	78	0.013468540502263095	low	364	\N
Container (Base)	269951.7519012263	3635.8561041385447	12027.410151504711	22.444711579695607	4.4553925161802495	2.147713172626222	15663.266255643255	41	0.013468540502263095	low	364	\N
Container (Max)	420800.7813614291	5667.572367150365	9995.69388849289	42.098206093111536	2.375398129289002	2.147713172626222	15663.266255643255	135	0.013468540502263095	low	364	\N
Traditional Housing	552226.3674111612	11135.189883342638	4816.26389583592	100	0.8721539173173819	-0.5010056844119992	15951.453779178559	101	0.02016417639661873	low	365	\N
ODD Cubes Basic	345140.5097868185	3913.1799843911103	12038.273794787448	28.670265826339968	3.487934175626929	-0.5010056844119992	15951.453779178559	110	0.011337933025619472	low	365	\N
Container (Base)	261135.09534944737	2960.732221710789	12990.72155746777	20.101662112781778	4.9747130082548905	-0.5010056844119992	15951.453779178559	64	0.011337933025619472	low	365	\N
Container (Max)	425162.8339737321	4820.467736576745	11130.986042601813	38.19633160498981	2.6180524620572836	-0.5010056844119992	15951.453779178559	93	0.011337933025619472	low	365	\N
Traditional Housing	528979.4990218888	12334.6109173689	18040.505452348913	29.321767087906874	3.4104356569029166	2.130924026052721	30375.116369717813	138	0.023317748495312672	middle	366	\N
ODD Cubes Basic	295340.93519368867	5632.160373917082	24742.95599580073	11.936364242163009	8.37776042781674	2.130924026052721	30375.116369717813	68	0.019070029592150622	middle	366	\N
Container (Base)	245873.99899448993	4688.824436765335	25686.291932952478	9.572187361113912	10.446932997387865	2.130924026052721	30375.116369717813	100	0.019070029592150622	middle	366	\N
Container (Max)	448139.14122673566	8546.026684594815	21829.089685123	20.529447067696655	4.871051795513346	2.130924026052721	30375.116369717813	106	0.019070029592150622	middle	366	\N
Traditional Housing	577805.9117612463	8183.096993985312	22302.382534546698	25.907811009259525	3.8598397975135654	-1.2904510412497618	30485.47952853201	130	0.014162362875523207	middle	367	\N
ODD Cubes Basic	297898.98740915547	3807.8114365226884	26677.66809200932	11.166605206336765	8.955273169615824	-1.2904510412497618	30485.47952853201	88	0.012782223496761242	middle	367	\N
Container (Base)	235406.9821522503	3009.024658568148	27476.45486996386	8.56758935118619	11.671894613641225	-1.2904510412497618	30485.47952853201	79	0.012782223496761242	middle	367	\N
Container (Max)	413056.4313133095	5279.779621821331	25205.69990671068	16.38742160868696	6.102241242575347	-1.2904510412497618	30485.47952853201	54	0.012782223496761242	middle	367	\N
Traditional Housing	586945.4539411435	14821.505995888114	16153.162512915951	36.336256350533596	2.752072173734857	4.795336873037607	30974.668508804065	96	0.025251930816341844	middle	368	\N
ODD Cubes Basic	300921.43270306033	6826.841671246478	24147.826837557586	12.461636184794541	8.024628428971322	4.795336873037607	30974.668508804065	149	0.022686458754112696	middle	368	\N
Container (Base)	249449.36654866074	5659.122765445731	25315.545743358336	9.853604148119345	10.148570867755629	4.795336873037607	30974.668508804065	70	0.022686458754112696	middle	368	\N
Container (Max)	476293.04226443655	10805.402458202994	20169.266050601072	23.614792976080672	4.234633778127532	4.795336873037607	30974.668508804065	80	0.022686458754112696	middle	368	\N
Traditional Housing	534830.1637940404	7727.094689148012	23227.221806944675	23.02600665027155	4.34291544855524	2.314492700106956	30954.316496092688	124	0.014447754095118061	middle	369	\N
ODD Cubes Basic	330885.6739305118	4295.999995506741	26658.31650058595	12.41209938831805	8.05665479073729	2.314492700106956	30954.316496092688	130	0.012983336342355302	middle	369	\N
Container (Base)	280401.08981884574	3640.541659881053	27313.774836211636	10.265922286475757	9.740966004753338	2.314492700106956	30954.316496092688	46	0.012983336342355302	middle	369	\N
Container (Max)	435756.2663867637	5657.570169788328	25296.74632630436	17.225783140879685	5.8052513016190925	2.314492700106956	30954.316496092688	73	0.012983336342355302	middle	369	\N
Traditional Housing	594171.7096701926	7321.553689476914	22742.225528117586	26.126366082140123	3.8275510526647483	-2.382226673911406	30063.7792175945	98	0.012322285915532558	middle	370	\N
ODD Cubes Basic	319512.90071497636	7541.471510325927	22522.307707268574	14.186508099783252	7.048950967823283	-2.382226673911406	30063.7792175945	96	0.02360302664915977	middle	370	\N
Container (Base)	238289.70874913014	5624.358345826238	24439.420871768263	9.750219123416127	10.256179757010795	-2.382226673911406	30063.7792175945	41	0.02360302664915977	middle	370	\N
Container (Max)	432688.34066490346	10212.754435494437	19851.024782100063	21.79677600599564	4.587834456457827	-2.382226673911406	30063.7792175945	106	0.02360302664915977	middle	370	\N
Traditional Housing	580558.0254628198	9693.924148750317	20714.156450627303	28.027114058281548	3.5679734913859837	-4.132235312088955	30408.08059937762	120	0.016697597352172227	middle	371	\N
ODD Cubes Basic	302374.0858772649	5288.552542928604	25119.528056449017	12.037411100947633	8.307434145214797	-4.132235312088955	30408.08059937762	139	0.017490098490368824	middle	371	\N
Container (Base)	229923.66439035986	4021.3875354539014	26386.693063923718	8.71362181813965	11.47628415452048	-4.132235312088955	30408.08059937762	56	0.017490098490368824	middle	371	\N
Container (Max)	432281.1609268512	7560.640080141603	22847.440519236017	18.920332041696284	5.285319506001365	-4.132235312088955	30408.08059937762	55	0.017490098490368824	middle	371	\N
Traditional Housing	578437.0698788832	8948.622401659848	6620.465112762324	87.37106230857185	1.144543712274277	4.567080392881207	15569.087514422172	93	0.015470347368182275	low	372	\N
ODD Cubes Basic	319861.0645234841	6014.371928870206	9554.715585551967	33.47677507085168	2.98714555952166	4.567080392881207	15569.087514422172	63	0.018803076072513455	low	372	\N
Container (Base)	239138.14016527453	4496.532641367043	11072.554873055129	21.597376839126177	4.6301919323294065	4.567080392881207	15569.087514422172	123	0.018803076072513455	low	372	\N
Container (Max)	496174.32970676123	9329.603666704605	6239.483847717567	79.52169471329975	1.2575184716640013	4.567080392881207	15569.087514422172	100	0.018803076072513455	low	372	\N
Traditional Housing	517160.1984524141	7251.6461134142755	8228.175771338998	62.85235182430417	1.5910303607975942	0.4229197883166229	15479.821884753273	134	0.01402204990854788	low	373	\N
ODD Cubes Basic	301135.339574333	3567.5984006883914	11912.223484064882	25.27952400970022	3.955770684670651	0.4229197883166229	15479.821884753273	44	0.011847159505527768	low	373	\N
Container (Base)	248052.20468169785	2938.7140345618964	12541.107850191376	19.779130172930664	5.055834059723115	0.4229197883166229	15479.821884753273	100	0.011847159505527768	low	373	\N
Container (Max)	492609.4464789001	5836.022686365273	9643.799198388	51.080433794312285	1.9576967651189923	0.4229197883166229	15479.821884753273	123	0.011847159505527768	low	373	\N
Traditional Housing	586116.4475772458	16955.61856399632	-1258.3132277333425	100	0	-4.841266541710528	15697.305336262976	121	0.0289287540625819	low	374	Negative cash flow
ODD Cubes Basic	307784.9599598832	4441.629518401395	11255.675817861582	27.344867153286398	3.656993447414926	-4.841266541710528	15697.305336262976	136	0.014430950488874827	low	374	\N
Container (Base)	229638.45263349824	3313.9011402958404	12383.404195967136	18.54404887375669	5.392565597770763	-4.841266541710528	15697.305336262976	46	0.014430950488874827	low	374	\N
Container (Max)	404404.5273027911	5835.941710983407	9861.36362527957	41.00898645153917	2.4384899177689077	-4.841266541710528	15697.305336262976	64	0.014430950488874827	low	374	\N
Traditional Housing	590592.1635974639	7019.137988275231	8827.488488914649	66.90375913139003	1.4946843241440795	3.0243820040588965	15846.626477189879	105	0.011884915549030784	low	375	\N
ODD Cubes Basic	322840.54569859756	7641.19531065134	8205.43116653854	39.34473876462824	2.5416358867758486	3.0243820040588965	15846.626477189879	85	0.023668635840385192	low	375	\N
Container (Base)	243816.96887671947	5770.815048049603	10075.811429140274	24.198246522515888	4.132530838833814	3.0243820040588965	15846.626477189879	134	0.023668635840385192	low	375	\N
Container (Max)	446850.90978144173	10576.351458561761	5270.275018628117	84.78701931151964	1.179425822631949	3.0243820040588965	15846.626477189879	127	0.023668635840385192	low	375	\N
Traditional Housing	544916.0135586703	9635.526449942668	20381.898975565127	26.73529165324309	3.7403743821836937	2.5725979328014983	30017.425425507798	106	0.0176825899958714	middle	376	\N
ODD Cubes Basic	316769.82240763085	3779.390629498306	26238.03479600949	12.072924853953161	8.282996971297802	2.5725979328014983	30017.425425507798	93	0.011931031184639961	middle	376	\N
Container (Base)	264634.9466543551	3157.3678010786434	26860.057624429155	9.852359602299225	10.14985283085518	2.5725979328014983	30017.425425507798	123	0.011931031184639961	middle	376	\N
Container (Max)	479545.0596060201	5721.467060599455	24295.958364908343	19.73764740635409	5.066459945363461	2.5725979328014983	30017.425425507798	92	0.011931031184639961	middle	376	\N
Traditional Housing	553736.1777852571	5870.089042153233	9904.12863527687	55.90963104143663	1.788600606680563	4.613932482328353	15774.217677430102	145	0.010600876875394795	low	377	\N
ODD Cubes Basic	340053.02530025074	5372.4496575777175	10401.768019852385	32.69184860220297	3.0588664843278828	4.613932482328353	15774.217677430102	71	0.01579885858340504	low	377	\N
Container (Base)	238623.87712077296	3769.984889254913	12004.23278817519	19.878311369955288	5.03060839217677	4.613932482328353	15774.217677430102	99	0.01579885858340504	low	377	\N
Container (Max)	482311.2008323598	7619.966455142719	8154.251222287384	59.14843529888997	1.690661798485085	4.613932482328353	15774.217677430102	141	0.01579885858340504	low	377	\N
Traditional Housing	550416.3596641589	6468.389616833013	24059.493538685398	22.877304494341963	4.371144337600266	-4.5501723081322805	30527.88315551841	84	0.011751812066014453	middle	378	\N
ODD Cubes Basic	323583.65055872744	6978.006755627892	23549.87639989052	13.740354516690022	7.277832597298187	-4.5501723081322805	30527.88315551841	88	0.021564769244611287	middle	378	\N
Container (Base)	247466.72490399992	5336.5628182744595	25191.320337243953	9.823491646769076	10.1796798527222	-4.5501723081322805	30527.88315551841	66	0.021564769244611287	middle	378	\N
Container (Max)	441614.8098213162	9523.321468799582	21004.56168671883	21.024709603940412	4.756308262220096	-4.5501723081322805	30527.88315551841	147	0.021564769244611287	middle	378	\N
Traditional Housing	591568.6587963518	14932.191076086325	872.0652183181683	100	0.1474157234922714	2.6216009385959165	15804.256294404493	109	0.0252416872565028	low	379	\N
ODD Cubes Basic	307833.8889609116	3447.099761858818	12357.156532545676	24.911385410563806	4.014228769372035	2.6216009385959165	15804.256294404493	121	0.011197921624205992	low	379	\N
Container (Base)	243678.1871721994	2728.6892414828867	13075.567052921606	18.636146806172505	5.365916089847439	2.6216009385959165	15804.256294404493	71	0.011197921624205992	low	379	\N
Container (Max)	474302.86014162976	5311.206254002706	10493.050040401788	45.20161995944015	2.212310091756246	2.6216009385959165	15804.256294404493	72	0.011197921624205992	low	379	\N
Traditional Housing	580342.2474131446	16238.75386574214	-282.3431291251145	100	0	-3.500242293842053	15956.410736617025	100	0.027981340214547228	low	380	Negative cash flow
ODD Cubes Basic	296118.0571725957	3846.754803121576	12109.655933495449	24.453052902480053	4.089468926387425	-3.500242293842053	15956.410736617025	53	0.012990612054703076	low	380	\N
Container (Base)	230092.88454509428	2989.0473996729047	12967.36333694412	17.743999189839762	5.63570810222197	-3.500242293842053	15956.410736617025	114	0.012990612054703076	low	380	\N
Container (Max)	440179.85667939973	5718.205752416882	10238.204984200143	42.993850714915006	2.3259140164737317	-3.500242293842053	15956.410736617025	82	0.012990612054703076	low	380	\N
Traditional Housing	529994.8203709045	9883.089590764246	5640.654704869099	93.95980574974833	1.0642848737505808	-0.8669350477154172	15523.744295633345	116	0.018647521090579332	low	381	\N
ODD Cubes Basic	324307.5562884401	4824.453751166617	10699.290544466729	30.31112716685311	3.2991184870668717	-0.8669350477154172	15523.744295633345	54	0.014876168185473094	low	381	\N
Container (Base)	271902.340767842	4044.8649512862353	11478.87934434711	23.687185186918363	4.221691991297752	-0.8669350477154172	15523.744295633345	140	0.014876168185473094	low	381	\N
Container (Max)	417044.975259716	6204.03119287	9319.713102763344	44.748692439476486	2.2347021677840537	-0.8669350477154172	15523.744295633345	77	0.014876168185473094	low	381	\N
Traditional Housing	560254.7163985809	8654.90380421978	6987.837478711535	80.17569356834619	1.2472608037341701	-4.3348082405534685	15642.741282931316	126	0.015448158758671546	low	382	\N
ODD Cubes Basic	342426.4952409495	6903.595229292227	8739.14605363909	39.183061266994024	2.5521232074900517	-4.3348082405534685	15642.741282931316	139	0.020160809181644923	low	382	\N
Container (Base)	218279.50046171408	4400.691357073392	11242.049925857924	19.41634327380523	5.150300372723166	-4.3348082405534685	15642.741282931316	95	0.020160809181644923	low	382	\N
Container (Max)	393549.8791257028	7934.284016512718	7708.457266418598	51.05429861305422	1.9586989287211694	-4.3348082405534685	15642.741282931316	80	0.020160809181644923	low	382	\N
Traditional Housing	504182.40515500423	14902.381232092224	638.7376221971317	100	0.12668780498215923	0.10437164746208705	15541.118854289356	148	0.029557519420993446	low	383	\N
ODD Cubes Basic	351933.13631322136	4404.75799548763	11136.360858801727	31.602167061160532	3.1643399582841036	0.10437164746208705	15541.118854289356	43	0.01251589447254374	low	383	\N
Container (Base)	236073.86819130942	2954.675622007629	12586.443232281727	18.75620171915024	5.331569872054594	0.10437164746208705	15541.118854289356	118	0.01251589447254374	low	383	\N
Container (Max)	465897.45980495453	5831.123441944999	9709.995412344357	47.98122347335583	2.084148605663013	0.10437164746208705	15541.118854289356	112	0.01251589447254374	low	383	\N
Traditional Housing	583884.9110955144	17213.865596987052	-1737.0191973610054	100	0	-3.681721485187083	15476.846399626047	112	0.02948160719668115	low	384	Negative cash flow
ODD Cubes Basic	298890.15024354815	4290.715369950243	11186.131029675804	26.719707596006103	3.7425559258345844	-3.681721485187083	15476.846399626047	61	0.014355492700090618	low	384	\N
Container (Base)	229995.01249235435	3301.6917228912434	12175.154676734805	18.890520785895724	5.293660303672689	-3.681721485187083	15476.846399626047	141	0.014355492700090618	low	384	\N
Container (Max)	445909.93334283045	6401.256793000897	9075.58960662515	49.13288862437298	2.035296576281366	-3.681721485187083	15476.846399626047	56	0.014355492700090618	low	384	\N
Traditional Housing	569317.0956007185	13859.24641164846	2096.9743174805353	100	0.3683315209897043	-4.100785574707629	15956.220729128996	132	0.02434363295735005	low	385	\N
ODD Cubes Basic	305874.05064398417	6774.016688502988	9182.20404062601	33.31161552179261	3.001955877359942	-4.100785574707629	15956.220729128996	73	0.022146424890379032	low	385	\N
Container (Base)	250255.24428222908	5542.258970919843	10413.961758209152	24.030743543393275	4.16133607432604	-4.100785574707629	15956.220729128996	111	0.022146424890379032	low	385	\N
Container (Max)	400210.65786988183	8863.235274844517	7092.985454284479	56.4234426320636	1.7723129843759882	-4.100785574707629	15956.220729128996	51	0.022146424890379032	low	385	\N
Traditional Housing	532623.7112783764	10770.953665451929	4739.57865014124	100	0.8898549857582465	2.184860257699861	15510.53231559317	106	0.02022244492195068	low	386	\N
ODD Cubes Basic	309418.5704580908	6317.60791762204	9192.924397971128	33.65833950797847	2.971031888732827	2.184860257699861	15510.53231559317	119	0.02041767534595254	low	386	\N
Container (Base)	234205.06755628597	4781.923033741129	10728.609281852041	21.82995590607024	4.5808612912586355	2.184860257699861	15510.53231559317	96	0.02041767534595254	low	386	\N
Container (Max)	433322.915697238	8847.446612667767	6663.085702925402	65.03336967540268	1.537672128925877	2.184860257699861	15510.53231559317	96	0.02041767534595254	low	386	\N
Traditional Housing	501329.6145965117	12241.298208329808	18525.47825102182	27.06162873656768	3.69526908278335	3.030639013492454	30766.77645935163	131	0.02441766425105776	middle	387	\N
ODD Cubes Basic	348170.2322054613	5799.740555925169	24967.035903426462	13.945196920940006	7.170927780147782	3.030639013492454	30766.77645935163	69	0.016657772605047527	middle	387	\N
Container (Base)	278561.44544197177	4640.213214705718	26126.563244645913	10.662001076588481	9.379102410670265	3.030639013492454	30766.77645935163	109	0.016657772605047527	middle	387	\N
Container (Max)	473241.89221528696	7883.1558277046615	22883.62063164697	20.680376581702973	4.835501887740057	3.030639013492454	30766.77645935163	98	0.016657772605047527	middle	387	\N
Traditional Housing	571675.9458994688	7439.852212725034	23451.709474203395	24.376728124161083	4.102273262049661	-0.6548979739757019	30891.56168692843	89	0.013014107495845834	middle	388	\N
ODD Cubes Basic	318267.51623899647	4210.984304602067	26680.577382326366	11.928809173740815	8.383066452276937	-0.6548979739757019	30891.56168692843	55	0.013230958516796652	middle	388	\N
Container (Base)	238195.08948201704	3151.5493478412336	27740.012339087196	8.58669731542935	11.645921164626476	-0.6548979739757019	30891.56168692843	112	0.013230958516796652	middle	388	\N
Container (Max)	481948.18504265323	6376.636443544781	24514.925243383652	19.659378124056346	5.086630887761107	-0.6548979739757019	30891.56168692843	131	0.013230958516796652	middle	388	\N
Traditional Housing	502414.6749980622	13504.393392914402	2256.080102088077	100	0.4490474132939646	2.8004409361422535	15760.47349500248	130	0.026878978789714868	low	389	\N
ODD Cubes Basic	337205.39723801584	6454.526233824783	9305.947261177696	36.23547262563591	2.7597266643419442	2.8004409361422535	15760.47349500248	138	0.019141230498362596	low	389	\N
Container (Base)	251389.07008465627	4811.896135259435	10948.577359743045	22.96088905659942	4.355232053667277	2.8004409361422535	15760.47349500248	128	0.019141230498362596	low	389	\N
Container (Max)	486754.8610936356	9317.086992391747	6443.386502610732	75.54332817011864	1.3237436372250706	2.8004409361422535	15760.47349500248	62	0.019141230498362596	low	389	\N
Traditional Housing	529936.7745742628	8231.858860528833	22666.510803942117	23.379724350079375	4.2772103940421555	0.3168443928033584	30898.369664470953	99	0.015533662231956052	middle	390	\N
ODD Cubes Basic	313386.0426327453	5517.314447324844	25381.05521714611	12.34724245905419	8.098974352501708	0.3168443928033584	30898.369664470953	50	0.01760548874791639	middle	390	\N
Container (Base)	232745.57943778663	4097.599679919233	26800.76998455172	8.68428703995982	11.515050059937066	0.3168443928033584	30898.369664470953	60	0.01760548874791639	middle	390	\N
Container (Max)	467718.5861362971	8234.414305413942	22663.95535905701	20.637112045377663	4.845639243519937	0.3168443928033584	30898.369664470953	54	0.01760548874791639	middle	390	\N
Traditional Housing	527916.4876126401	12903.061229093728	2564.0157250776065	100	0.48568585851006013	-3.6127878043354276	15467.076954171334	146	0.024441481809830076	low	391	\N
ODD Cubes Basic	322982.1977539031	4802.79252571299	10664.284428458344	30.286345035209663	3.3018180266963246	-3.6127878043354276	15467.076954171334	105	0.014870146277760135	low	391	\N
Container (Base)	251422.382224551	3738.6876011819927	11728.389352989341	21.437076708275228	4.664815140648239	-3.6127878043354276	15467.076954171334	98	0.014870146277760135	low	391	\N
Container (Max)	437637.3902813903	6507.732010101476	8959.344944069859	48.84702989040065	2.0472073783067795	-3.6127878043354276	15467.076954171334	59	0.014870146277760135	low	391	\N
Traditional Housing	536940.8266193144	6007.0348820490335	24742.25101425736	21.70137334351309	4.608003300855229	2.7374978283898797	30749.28589630639	118	0.01118751747724328	middle	392	\N
ODD Cubes Basic	339975.84020208946	4772.06505864126	25977.220837665132	13.08746006074478	7.640902018868069	2.7374978283898797	30749.28589630639	135	0.014036482874208459	middle	392	\N
Container (Base)	253568.23837736866	3559.2062354271434	27190.079660879248	9.32576298193784	10.722983223322343	2.7374978283898797	30749.28589630639	145	0.014036482874208459	middle	392	\N
Container (Max)	467892.52257686533	6567.565380120364	24181.720516186026	19.349017050448566	5.1682211938348415	2.7374978283898797	30749.28589630639	49	0.014036482874208459	middle	392	\N
Traditional Housing	548010.4111515234	11194.197873267043	4390.679300484862	100	0.80120362882501	-0.154023427488176	15584.877173751906	107	0.02042698030087585	low	393	\N
ODD Cubes Basic	333768.31414878194	4210.509007959601	11374.368165792304	29.343899307969398	3.407863384156358	-0.154023427488176	15584.877173751906	106	0.012615065089979473	low	393	\N
Container (Base)	253957.64328980361	3203.6922001986613	12381.184973553245	20.511578159301255	4.875295270961569	-0.154023427488176	15584.877173751906	91	0.012615065089979473	low	393	\N
Container (Max)	420498.15967031894	5304.611654457655	10280.265519294251	40.903433756756364	2.444782523508364	-0.154023427488176	15584.877173751906	134	0.012615065089979473	low	393	\N
Traditional Housing	545800.0966965547	9836.640156968057	21064.013959273296	25.911495204657786	3.8592909907423727	4.197295165083336	30900.654116241352	125	0.018022422891648692	middle	394	\N
ODD Cubes Basic	350913.1862447191	6400.919839062772	24499.73427717858	14.323142540023118	6.981708079813509	4.197295165083336	30900.654116241352	84	0.018240750390607754	middle	394	\N
Container (Base)	262169.6812203403	4782.171715125433	26118.482401115918	10.037707290724482	9.962434359129674	4.197295165083336	30900.654116241352	123	0.018240750390607754	middle	394	\N
Container (Max)	491814.077553654	8971.057827243207	21929.596288998146	22.42695538359692	4.458920004502262	4.197295165083336	30900.654116241352	107	0.018240750390607754	middle	394	\N
Traditional Housing	516414.0176547955	14718.49830313357	769.83961321879	100	0.14907411241756813	-0.4591376909157594	15488.33791635236	120	0.02850135317777599	low	395	\N
ODD Cubes Basic	319846.7492154116	7596.502648158165	7891.835268194195	40.528817232724464	2.467380171145392	-0.4591376909157594	15488.33791635236	75	0.02375044507031098	low	395	\N
Container (Base)	256122.83850125558	6083.0314070762015	9405.306509276159	27.231737556734558	3.67218580127912	-0.4591376909157594	15488.33791635236	115	0.02375044507031098	low	395	\N
Container (Max)	462812.7713871768	10992.009304669537	4496.328611682824	100	0.9715221553212747	-0.4591376909157594	15488.33791635236	126	0.02375044507031098	low	395	\N
Traditional Housing	519241.30295095214	6849.50426097452	23155.920990152634	22.423694707360873	4.459568385363974	2.6958995160520978	30005.425251127155	94	0.01319137022044937	middle	396	\N
ODD Cubes Basic	342641.3097347524	7408.591333325725	22596.83391780143	15.163244150979265	6.5948947998401675	2.6958995160520978	30005.425251127155	139	0.021622002726585737	middle	396	\N
Container (Base)	256642.12030412682	5549.116624972575	24456.30862615458	10.493902584696007	9.529343272715051	2.6958995160520978	30005.425251127155	60	0.021622002726585737	middle	396	\N
Container (Max)	443550.7544559499	9590.455622225709	20414.969628901446	21.72674084354334	4.602623132485035	2.6958995160520978	30005.425251127155	140	0.021622002726585737	middle	396	\N
Traditional Housing	579279.5796806517	14354.044322958547	16530.992978545095	35.042031681489135	2.853715815022927	-4.646451554915439	30885.037301503642	135	0.02477913053809306	middle	397	\N
ODD Cubes Basic	356329.51038722886	5906.890303320556	24978.146998183085	14.26565030677209	7.009845177021387	-4.646451554915439	30885.037301503642	51	0.016577044929288753	middle	397	\N
Container (Base)	256427.41119633798	4250.8087165028965	26634.228585000747	9.6277393722132	10.386654242906895	-4.646451554915439	30885.037301503642	96	0.016577044929288753	middle	397	\N
Container (Max)	429253.8084332686	7115.759668466601	23769.27763303704	18.059186108232694	5.537348106425057	-4.646451554915439	30885.037301503642	65	0.016577044929288753	middle	397	\N
Traditional Housing	517353.64350160526	11943.269194748409	3962.119252473316	100	0.7658435003291945	-0.6393008268922422	15905.388447221725	82	0.02308530991279537	low	398	\N
ODD Cubes Basic	310510.8565383711	2870.366545901486	13035.021901320239	23.82127616578238	4.197927907138875	-0.6393008268922422	15905.388447221725	145	0.009244013487646873	low	398	\N
Container (Base)	248679.21130368082	2298.793983388612	13606.594463833113	18.276374148188246	5.4715448036454815	-0.6393008268922422	15905.388447221725	48	0.009244013487646873	low	398	\N
Container (Max)	434021.9940271196	4012.105166722084	11893.283280499641	36.49303424385315	2.74024898373157	-0.6393008268922422	15905.388447221725	115	0.009244013487646873	low	398	\N
Traditional Housing	565149.8761132042	12609.593470903246	17807.449937716607	31.736710089871046	3.1509252130048466	-4.704862513575194	30417.04340861985	99	0.02231194591711711	middle	399	\N
ODD Cubes Basic	350550.12762400345	7398.74712232852	23018.29628629133	15.229195213408364	6.566335160767799	-4.704862513575194	30417.04340861985	140	0.02110610306285309	middle	399	\N
Container (Base)	256524.04451066547	5414.222921542018	25002.82048707783	10.259804274611513	9.746774628776873	-4.704862513575194	30417.04340861985	82	0.02110610306285309	middle	399	\N
Container (Max)	425071.2443631827	8971.597492584544	21445.445916035307	19.821049467912722	5.045141538135247	-4.704862513575194	30417.04340861985	89	0.02110610306285309	middle	399	\N
Traditional Housing	555249.7400165492	16226.16088766608	14054.47978989784	39.50695780399178	2.531199706546273	2.3289080607602646	30280.64067756392	109	0.029223176020185905	middle	400	\N
ODD Cubes Basic	349401.9218447836	3474.556077455041	26806.08460010888	13.034425842383726	7.6719911723946	2.3289080607602646	30280.64067756392	129	0.009944295838757746	middle	400	\N
Container (Base)	258085.63545657633	2566.4799107139806	27714.16076684994	9.312410273858385	10.738358497876542	2.3289080607602646	30280.64067756392	113	0.009944295838757746	middle	400	\N
Container (Max)	481742.9785374876	4790.5946968211	25490.04598074282	18.89925890684678	5.291212766219751	2.3289080607602646	30280.64067756392	79	0.009944295838757746	middle	400	\N
Traditional Housing	550337.773259302	8696.331025252248	6881.709156945095	79.97108867989506	1.2504519026904315	-2.071212803945123	15578.040182197343	141	0.01580180654100733	low	401	\N
ODD Cubes Basic	299193.55726277496	4541.492598762811	11036.54758343453	27.10934329788547	3.6887651206143386	-2.071212803945123	15578.040182197343	95	0.015179112278725041	low	401	\N
Container (Base)	261452.03656013616	3968.609818447631	11609.430363749712	22.52066021917118	4.440367157392345	-2.071212803945123	15578.040182197343	113	0.015179112278725041	low	401	\N
Container (Max)	446751.86836739036	6781.296770678809	8796.743411518535	50.78605200447355	1.969044571355761	-2.071212803945123	15578.040182197343	53	0.015179112278725041	low	401	\N
Traditional Housing	579703.3321621643	13179.667712814151	2458.191193414519	100	0.4240429642255141	-4.293054995429442	15637.85890622867	120	0.022735193989064935	low	402	\N
ODD Cubes Basic	311181.0127543464	6588.064320986462	9049.794585242209	34.38542276548457	2.908209117625801	-4.293054995429442	15637.85890622867	121	0.021171164212988904	low	402	\N
Container (Base)	224540.26105149186	4753.778739148531	10884.08016708014	20.63015501582152	4.847273320210574	-4.293054995429442	15637.85890622867	85	0.021171164212988904	low	402	\N
Container (Max)	409798.4282748058	8675.909819230668	6961.949086998002	58.86260056686384	1.6988715931163614	-4.293054995429442	15637.85890622867	89	0.021171164212988904	low	402	\N
Traditional Housing	585335.4611089156	16235.553889049668	14037.849089905507	41.69694782727257	2.3982570718184166	-2.5971701028961567	30273.402978955175	83	0.027737178024873937	middle	403	\N
ODD Cubes Basic	296146.8814993422	6471.446533889523	23801.95644506565	12.442123494463246	8.037213265444606	-2.5971701028961567	30273.402978955175	53	0.021852151544279885	middle	403	\N
Container (Base)	228788.4242131694	4999.519317483171	25273.883661472006	9.052365171797435	11.04683672191541	-2.5971701028961567	30273.402978955175	98	0.021852151544279885	middle	403	\N
Container (Max)	480100.8665863867	10491.236893185822	19782.166085769353	24.269378009709243	4.120418741674956	-2.5971701028961567	30273.402978955175	124	0.021852151544279885	middle	403	\N
Traditional Housing	569656.0931679211	11451.790124952278	19530.863738890315	29.16696879276304	3.428535913708393	3.022006161597025	30982.653863842595	121	0.02010298891260444	middle	404	\N
ODD Cubes Basic	327431.40255623194	6549.348987360589	24433.304876482005	13.401027990748695	7.462114105651767	3.022006161597025	30982.653863842595	108	0.020002201793201023	middle	404	\N
Container (Base)	268979.29470969335	5380.1781309761745	25602.47573286642	10.505987683230147	9.518381613907835	3.022006161597025	30982.653863842595	110	0.020002201793201023	middle	404	\N
Container (Max)	420376.77342180925	8408.461051157774	22574.19281268482	18.62200686022281	5.369990503741201	3.022006161597025	30982.653863842595	41	0.020002201793201023	middle	404	\N
Traditional Housing	510827.36279849015	7987.533527431825	22666.872686778297	22.536296464772505	4.437286319707166	-0.18497815500666182	30654.40621421012	129	0.01563646372362149	middle	405	\N
ODD Cubes Basic	337590.1830656832	6508.990059874587	24145.416154335533	13.981543366568388	7.152286223215704	-0.18497815500666182	30654.40621421012	97	0.0192807444836397	middle	405	\N
Container (Base)	244758.7341794199	4719.130613852486	25935.275600357636	9.437290659677616	10.59626153375423	-0.18497815500666182	30654.40621421012	60	0.0192807444836397	middle	405	\N
Container (Max)	426544.92559893464	8224.103721266165	22430.302492943956	19.016458905675286	5.25860258715969	-0.18497815500666182	30654.40621421012	108	0.0192807444836397	middle	405	\N
Traditional Housing	584241.9046746864	12182.608599045525	18433.623557605337	31.6943601917942	3.155135468735236	0.3383765432255341	30616.23215665086	96	0.020851993842908208	middle	406	\N
ODD Cubes Basic	315604.64435968257	3070.60986626356	27545.622290387302	11.457524576230767	8.727888762940575	0.3383765432255341	30616.23215665086	130	0.009729292395216159	middle	406	\N
Container (Base)	233882.14545715958	2275.5077791731824	28340.72437747768	8.252511204089945	12.117523687873334	0.3383765432255341	30616.23215665086	89	0.009729292395216159	middle	406	\N
Container (Max)	448575.9980935577	4364.32704692815	26251.905109722713	17.087369324956995	5.852275917858507	0.3383765432255341	30616.23215665086	138	0.009729292395216159	middle	406	\N
Traditional Housing	502495.41673040483	13134.20294807008	17827.659043821543	28.18628152441319	3.547825204022967	-2.8637023984760446	30961.861991891623	134	0.026137955712174678	middle	407	\N
ODD Cubes Basic	320959.32617288525	7262.5959404947325	23699.26605139689	13.54300700607423	7.383884535771752	-2.8637023984760446	30961.861991891623	62	0.022627776631680502	middle	407	\N
Container (Base)	256715.88118312467	5808.9096172167765	25152.952374674845	10.206192790377884	9.797972863522354	-2.8637023984760446	30961.861991891623	132	0.022627776631680502	middle	407	\N
Container (Max)	431131.50153760985	9755.547315674054	21206.314676217567	20.330335945694266	4.918757873313887	-2.8637023984760446	30961.861991891623	65	0.022627776631680502	middle	407	\N
Traditional Housing	564665.5025149161	12704.373809623841	17836.811455250747	31.657311842509362	3.158827903565717	-1.1834236066407664	30541.185264874588	113	0.02249893742940006	middle	408	\N
ODD Cubes Basic	295295.755378689	3558.563926889293	26982.621337985296	10.943923930881422	9.137490413088608	-1.1834236066407664	30541.185264874588	60	0.012050846861397551	middle	408	\N
Container (Base)	234526.93197471972	2826.248142100748	27714.93712277384	8.462113081324832	11.817379304548831	-1.1834236066407664	30541.185264874588	123	0.012050846861397551	middle	408	\N
Container (Max)	479491.22979842604	5778.275381684014	24762.909883190572	19.363282912236084	5.164413516718686	-1.1834236066407664	30541.185264874588	121	0.012050846861397551	middle	408	\N
Traditional Housing	568917.893587612	8199.285572449753	22696.072260507703	25.066799535070103	3.9893405562243163	-3.6917683676535007	30895.357832957456	143	0.014412071873403088	middle	409	\N
ODD Cubes Basic	294181.6840880414	6620.652518854721	24274.705314102735	12.118857068766655	8.251603219063055	-3.6917683676535007	30895.357832957456	135	0.02250531857337971	middle	409	\N
Container (Base)	258473.0168002138	5817.017585711338	25078.340247246117	10.306623733944955	9.70249837205652	-3.6917683676535007	30895.357832957456	140	0.02250531857337971	middle	409	\N
Container (Max)	398025.1647017162	8957.683131834052	21937.674701123404	18.143452764450636	5.51163007936036	-3.6917683676535007	30895.357832957456	140	0.02250531857337971	middle	409	\N
Traditional Housing	536115.8611186551	12652.883153517627	18305.883726391316	29.286532632442373	3.414538732018561	4.156021753606714	30958.76687990894	121	0.023601023717366283	middle	410	\N
ODD Cubes Basic	351926.75896046957	5313.712940314519	25645.05393959442	13.722987668086587	7.287042910674213	4.156021753606714	30958.76687990894	109	0.01509891704742857	middle	410	\N
Container (Base)	265522.92833507067	4009.108669121553	26949.658210787387	9.852552721013263	10.14965388479705	4.156021753606714	30958.76687990894	114	0.01509891704742857	middle	410	\N
Container (Max)	463252.84977802716	6994.616350783321	23964.150529125618	19.33107744482733	5.1730174008877245	4.156021753606714	30958.76687990894	100	0.01509891704742857	middle	410	\N
Traditional Housing	546156.9973919191	10383.567031912127	19982.090951875536	27.332324665485338	3.6586715994295873	-4.175114131445094	30365.657983787663	81	0.019012055290872597	middle	411	\N
ODD Cubes Basic	356262.2618291024	3935.9157249335985	26429.742258854065	13.479596521973392	7.418619677301748	-4.175114131445094	30365.657983787663	128	0.011047804234796111	middle	411	\N
Container (Base)	258222.92274779044	2852.796299454468	27512.861684333195	9.385534871308272	10.654693778369689	-4.175114131445094	30365.657983787663	86	0.011047804234796111	middle	411	\N
Container (Max)	420849.68218456226	4649.464901051204	25716.19308273646	16.3651626362645	6.1105411673944685	-4.175114131445094	30365.657983787663	44	0.011047804234796111	middle	411	\N
Traditional Housing	566446.4529508228	13276.689866471046	17452.238176794406	32.456951779629364	3.08100405358343	-3.2998979540817794	30728.928043265452	136	0.023438561221997254	middle	412	\N
ODD Cubes Basic	308300.07054054673	6064.980115194406	24663.947928071047	12.500029250777724	7.999981279546063	-3.2998979540817794	30728.928043265452	81	0.019672328016534648	middle	412	\N
Container (Base)	259686.45263175084	5108.63707762209	25620.290965643362	10.135968126981409	9.86585580649226	-3.2998979540817794	30728.928043265452	50	0.019672328016534648	middle	412	\N
Container (Max)	420549.3755802402	8273.185263563311	22455.74277970214	18.727920946813523	5.339621001391219	-3.2998979540817794	30728.928043265452	122	0.019672328016534648	middle	412	\N
Traditional Housing	503448.52800968033	8291.449621981257	22207.460198094457	22.670243401038693	4.411068652020659	-4.19931008483518	30498.909820075714	112	0.0164693094937837	middle	413	\N
ODD Cubes Basic	355442.64479923784	7006.330435437064	23492.57938463865	15.129996539743736	6.60938683874238	-4.19931008483518	30498.909820075714	68	0.019711563983534953	middle	413	\N
Container (Base)	248174.8395117646	4891.914228139666	25606.995591936047	9.691681268142128	10.318127189006265	-4.19931008483518	30498.909820075714	75	0.019711563983534953	middle	413	\N
Container (Max)	440302.0781575033	8679.042585685032	21819.86723439068	20.178953126879495	4.955658471042999	-4.19931008483518	30498.909820075714	73	0.019711563983534953	middle	413	\N
Traditional Housing	539236.6552321964	5985.71288617795	24903.76846520267	21.652813548505986	4.618337463442476	2.851960286917402	30889.48135138062	142	0.011100344956335524	middle	414	\N
ODD Cubes Basic	310912.4914105682	3708.8671732988014	27180.614178081818	11.43875886591573	8.742207189800263	2.851960286917402	30889.48135138062	96	0.011928974472759745	middle	414	\N
Container (Base)	267730.822990423	3193.754153023714	27695.727198356904	9.666863811624582	10.344616614930292	2.851960286917402	30889.48135138062	115	0.011928974472759745	middle	414	\N
Container (Max)	447609.95733950846	5339.527754856074	25549.953596524545	17.51901253552159	5.70808427685292	2.851960286917402	30889.48135138062	96	0.011928974472759745	middle	414	\N
Traditional Housing	598715.390603124	6816.371073524804	23328.669065194626	25.66436125995639	3.8964538796462502	4.328661287680827	30145.04013871943	129	0.011384993906133331	middle	415	\N
ODD Cubes Basic	348042.0099645823	8411.45143384058	21733.58870487885	16.0140147442126	6.244530281585985	4.328661287680827	30145.04013871943	47	0.02416791994361989	middle	415	\N
Container (Base)	277100.9334306376	6696.953175453994	23448.086963265436	11.817635010683526	8.461929980879994	4.328661287680827	30145.04013871943	142	0.02416791994361989	middle	415	\N
Container (Max)	503317.75277373573	12164.143155238313	17980.896983481114	27.99180448206389	3.572474224163587	4.328661287680827	30145.04013871943	52	0.02416791994361989	middle	415	\N
Traditional Housing	594710.6931247219	14000.240529919649	1571.5166922911321	100	0.26424893825838036	-0.20866849127215836	15571.757222210781	85	0.023541262485730248	low	416	\N
ODD Cubes Basic	342825.8914083643	5591.830158130853	9979.927064079928	34.35154277251927	2.9110774052337045	-0.20866849127215836	15571.757222210781	88	0.01631099137570688	low	416	\N
Container (Base)	254925.4732254845	4158.087195228873	11413.670026981908	22.33510103435975	4.477257561815483	-0.20866849127215836	15571.757222210781	66	0.01631099137570688	low	416	\N
Container (Max)	407187.0505874662	6641.624470431682	8930.1327517791	45.59697620467564	2.193127885303625	-0.20866849127215836	15571.757222210781	88	0.01631099137570688	low	416	\N
Traditional Housing	591273.8343130678	13991.178636510833	16612.437264548695	35.59223880862197	2.809601288013827	-2.0285218362738746	30603.61590105953	81	0.023662773193347128	middle	417	\N
ODD Cubes Basic	332745.5406430342	4471.152655356253	26132.46324570328	12.733033909374942	7.853587818247548	-2.0285218362738746	30603.61590105953	105	0.013437152746557334	middle	417	\N
Container (Base)	263018.89267188124	3534.2250360624375	27069.39086499709	9.716468833141935	10.291804740721204	-2.0285218362738746	30603.61590105953	74	0.013437152746557334	middle	417	\N
Container (Max)	405192.0501426014	5444.627469456854	25158.988431602676	16.105260004556943	6.209151542521217	-2.0285218362738746	30603.61590105953	133	0.013437152746557334	middle	417	\N
Traditional Housing	568020.6778666724	6898.037482611326	23981.807174504294	23.68548265497483	4.2219954499849	4.095000807967796	30879.84465711562	93	0.01214399008944258	middle	418	\N
ODD Cubes Basic	312866.570380404	7636.476765065419	23243.3678920502	13.460466307355228	7.429163129761471	4.095000807967796	30879.84465711562	144	0.024408094338044754	middle	418	\N
Container (Base)	280347.6918063659	6842.752909062875	24037.091748052746	11.663128582478244	8.574028768767244	4.095000807967796	30879.84465711562	55	0.024408094338044754	middle	418	\N
Container (Max)	465515.3350922916	11362.342214739168	19517.50244237645	23.851173400217615	4.192665841718614	4.095000807967796	30879.84465711562	149	0.024408094338044754	middle	418	\N
Traditional Housing	597640.2141419357	14515.787235947118	1368.3933148846536	100	0.22896607063989655	1.9810977048170608	15884.180550831772	113	0.024288504843651155	low	419	\N
ODD Cubes Basic	343234.54197637667	3610.552252067235	12273.628298764537	27.96520585611401	3.575872121754365	1.9810977048170608	15884.180550831772	141	0.01051919842122339	low	419	\N
Container (Base)	254508.36504365478	2677.2239917553597	13206.956559076412	19.270780812006624	5.189203332004855	1.9810977048170608	15884.180550831772	100	0.01051919842122339	low	419	\N
Container (Max)	414083.66505301924	4355.828235680115	11528.352315151657	35.918720536393664	2.784063533072614	1.9810977048170608	15884.180550831772	91	0.01051919842122339	low	419	\N
Traditional Housing	582272.0274284959	9377.867110827712	6333.069944238767	91.9415121821278	1.0876479799669716	1.195034227379404	15710.937055066479	122	0.016105645933642814	low	420	\N
ODD Cubes Basic	351279.9756008783	6162.659144694955	9548.277910371524	36.78987759869361	2.7181389699309837	1.195034227379404	15710.937055066479	85	0.017543439913287065	low	420	\N
Container (Base)	234839.90180252373	4119.89970651481	11591.037348551668	20.260473220877646	4.935718870423708	1.195034227379404	15710.937055066479	92	0.017543439913287065	low	420	\N
Container (Max)	447816.5376130641	7856.242519791047	7854.694535275432	57.01259744754174	1.7539983175124008	1.195034227379404	15710.937055066479	132	0.017543439913287065	low	420	\N
Traditional Housing	537308.6804785263	9403.600520000833	20921.229104482398	25.68246243063259	3.8937076329848206	1.4576159230955739	30324.82962448323	126	0.017501300205360542	middle	421	\N
ODD Cubes Basic	350173.3317794794	4534.799365652502	25790.030258830728	13.57785656957797	7.3649327114013134	1.4576159230955739	30324.82962448323	132	0.012950156262922612	middle	421	\N
Container (Base)	274790.52400589205	3558.580225446689	26766.24939903654	10.266306642714882	9.740601316536889	1.4576159230955739	30324.82962448323	61	0.012950156262922612	middle	421	\N
Container (Max)	414718.80693775037	5370.673355016701	24954.15626946653	16.61922777349892	6.017126749984157	1.4576159230955739	30324.82962448323	77	0.012950156262922612	middle	421	\N
Traditional Housing	601319.4401249414	17533.585431795036	13187.107970721307	45.59903820155425	2.1930287116580343	-4.1280222683079595	30720.693402516343	93	0.029158520849004867	middle	422	\N
ODD Cubes Basic	333964.91497827426	7999.426001438125	22721.267401078218	14.698340065414936	6.803489343351029	-4.1280222683079595	30720.693402516343	145	0.023952893380906552	middle	422	\N
Container (Base)	249156.4726729173	5968.018425097145	24752.6749774192	10.065840273837557	9.934590384859689	-4.1280222683079595	30720.693402516343	139	0.023952893380906552	middle	422	\N
Container (Max)	465335.48140156094	11146.131172364414	19574.56223015193	23.772459170748423	4.206548396265548	-4.1280222683079595	30720.693402516343	121	0.023952893380906552	middle	422	\N
Traditional Housing	526256.4476285772	8707.069229141489	6784.045081626549	77.57266369792482	1.28911391246547	-0.49115639795984745	15491.114310768038	87	0.016545297009428354	low	423	\N
ODD Cubes Basic	346931.8952820875	3546.267935475893	11944.846375292145	29.044483652775508	3.4429945870442062	-0.49115639795984745	15491.114310768038	118	0.010221798525017284	low	423	\N
Container (Base)	233780.00203391633	2389.6520799688237	13101.462230799214	17.843809943926793	5.604184325782699	-0.49115639795984745	15491.114310768038	76	0.010221798525017284	low	423	\N
Container (Max)	489327.32266723795	5001.805305090629	10489.309005677409	46.65010082193081	2.1436180895238004	-0.49115639795984745	15491.114310768038	103	0.010221798525017284	low	423	\N
Traditional Housing	593417.3385055168	10578.25545732485	5378.078727223756	100	0.906289448968259	-2.3977974712684325	15956.334184548607	91	0.01782599659788422	low	424	\N
ODD Cubes Basic	301067.61529691785	4490.842926266728	11465.49125828188	26.258588360044964	3.808277833859488	-2.3977974712684325	15956.334184548607	98	0.014916393189077424	low	424	\N
Container (Base)	228930.00376948022	3414.809949002544	12541.524235546063	18.253762419134894	5.4783226440579105	-2.3977974712684325	15956.334184548607	74	0.014916393189077424	low	424	\N
Container (Max)	400573.26551943866	5975.108329520657	9981.22585502795	40.13267221256732	2.491735398787763	-2.3977974712684325	15956.334184548607	116	0.014916393189077424	low	424	\N
Traditional Housing	549638.63470326	9157.635742475428	21428.630263372866	25.649732528295857	3.8986761319902112	2.2280013490696415	30586.266005848294	110	0.016661193672128725	middle	425	\N
ODD Cubes Basic	301856.721344123	6896.956958925547	23689.309046922746	12.742318517868902	7.847865351958301	2.2280013490696415	30586.266005848294	114	0.022848445872645888	middle	425	\N
Container (Base)	234104.18816676817	5348.916871888111	25237.349133960182	9.27610054939368	10.780391983411215	2.2280013490696415	30586.266005848294	130	0.022848445872645888	middle	425	\N
Container (Max)	481772.22790181526	11007.746672158644	19578.51933368965	24.607184010734045	4.063853871145045	2.2280013490696415	30586.266005848294	63	0.022848445872645888	middle	425	\N
Traditional Housing	533340.3445868881	14727.459334678144	1202.1688834563356	100	0.22540370246835634	-2.825516354460502	15929.62821813448	124	0.027613623241057567	low	426	\N
ODD Cubes Basic	336131.6138375468	7411.044615003524	8518.583603130955	39.45862710251544	2.534300033809973	-2.825516354460502	15929.62821813448	136	0.022048044009883878	low	426	\N
Container (Base)	248185.9604113311	5472.014977784325	10457.613240350154	23.732562555834303	4.213619990034177	-2.825516354460502	15929.62821813448	115	0.022048044009883878	low	426	\N
Container (Max)	401431.7908136668	8850.785790826225	7078.842427308255	56.708677292356704	1.763398562171687	-2.825516354460502	15929.62821813448	62	0.022048044009883878	low	426	\N
Traditional Housing	532644.5634453685	11254.547225374194	4718.177936669079	100	0.88580232681808	-1.976442858330877	15972.725162043273	115	0.021129563686100652	low	427	\N
ODD Cubes Basic	354142.88311939326	8167.219775621994	7805.505386421279	45.3709100932109	2.20405541335975	-1.976442858330877	15972.725162043273	117	0.023061933939439224	low	427	\N
Container (Base)	252891.48687375305	5832.166764129054	10140.558397914217	24.93861550324187	4.009845694401143	-1.976442858330877	15972.725162043273	96	0.023061933939439224	low	427	\N
Container (Max)	420817.2147039687	9704.85880608174	6267.8663559615325	67.13883015449403	1.489451034072067	-1.976442858330877	15972.725162043273	143	0.023061933939439224	low	427	\N
Traditional Housing	566504.0511380857	8732.738863080329	7063.559670680639	80.20092949586392	1.2468683421575202	-0.41048989729310925	15796.298533760968	89	0.015415139301363475	low	428	\N
ODD Cubes Basic	298326.7368869335	2470.7437868925103	13325.554746868458	22.387566037882294	4.466765160213875	-0.41048989729310925	15796.298533760968	125	0.008282005872738547	low	428	\N
Container (Base)	260337.83471383635	2156.11947599603	13640.179057764937	19.08610096768737	5.239414806056998	-0.41048989729310925	15796.298533760968	98	0.008282005872738547	low	428	\N
Container (Max)	430517.2695894428	3565.5465550551294	12230.751978705839	35.19957483717994	2.840943405213346	-0.41048989729310925	15796.298533760968	140	0.008282005872738547	low	428	\N
Traditional Housing	567402.7515019742	6851.642396555095	8990.91065873309	63.10848511778305	1.5845729748284112	2.287960974122976	15842.553055288185	116	0.012075447957236873	low	429	\N
ODD Cubes Basic	331249.60614595964	8189.092850504444	7653.460204783741	43.28102548163959	2.310481299534397	2.287960974122976	15842.553055288185	87	0.024721819131449944	low	429	\N
Container (Base)	235629.3878286362	5825.187107953817	10017.365947334369	23.522090444478312	4.251322825071208	2.287960974122976	15842.553055288185	50	0.024721819131449944	low	429	\N
Container (Max)	423812.46972239594	10477.415222130177	5365.137833158007	78.99377106457916	1.265922599368598	2.287960974122976	15842.553055288185	78	0.024721819131449944	low	429	\N
Traditional Housing	512097.03374342475	14316.038050500767	1249.9098498516942	100	0.24407676035825954	-0.8198158707898395	15565.947900352461	137	0.02795571367764163	low	430	\N
ODD Cubes Basic	354227.6679163506	7653.863662588247	7912.084237764214	44.77046215276997	2.233615540057876	-0.8198158707898395	15565.947900352461	109	0.021607187568407772	low	430	\N
Container (Base)	258484.6660090866	5585.126662015571	9980.82123833689	25.898136018730863	3.8612817512300825	-0.8198158707898395	15565.947900352461	137	0.021607187568407772	low	430	\N
Container (Max)	425792.2384194991	9200.172760702319	6365.775139650143	66.88772837221207	1.4950425501599802	-0.8198158707898395	15565.947900352461	79	0.021607187568407772	low	430	\N
Traditional Housing	595538.7967938356	7987.556092781217	7881.000781008221	75.56639230755766	1.3233396083406594	0.0759724583148822	15868.556873789437	109	0.013412318619346573	low	431	\N
ODD Cubes Basic	344647.14972700353	4141.5726082434485	11726.984265545989	29.389239545548016	3.4026059042806485	0.0759724583148822	15868.556873789437	43	0.012016848569686434	low	431	\N
Container (Base)	268892.8012339712	3231.2440739074254	12637.312799882013	21.27768818355764	4.699758692641954	0.0759724583148822	15868.556873789437	64	0.012016848569686434	low	431	\N
Container (Max)	421707.38153917925	5067.593744675297	10800.963129114141	39.043497926815554	2.5612459259527247	0.0759724583148822	15868.556873789437	143	0.012016848569686434	low	431	\N
Traditional Housing	564458.5917379266	16286.015105191656	-479.7215204790864	100	0	-2.9301423193934353	15806.29358471257	115	0.028852453206617355	low	432	Negative cash flow
ODD Cubes Basic	322026.0786791072	6740.187073677802	9066.106511034768	35.51977668552147	2.8153330153328886	-2.9301423193934353	15806.29358471257	82	0.020930562833062563	low	432	\N
Container (Base)	220743.1376895738	4620.278113379006	11186.015471333565	19.733848773521984	5.067435204741998	-2.9301423193934353	15806.29358471257	47	0.020930562833062563	low	432	\N
Container (Max)	450436.08037846483	9427.880682639878	6378.412902072692	70.61883375911486	1.4160528385544582	-2.9301423193934353	15806.29358471257	107	0.020930562833062563	low	432	\N
Traditional Housing	573311.345872193	6305.259199050015	24059.58837705695	23.828809408015417	4.196600773782785	3.941362213409885	30364.847576106964	118	0.010997966889103974	middle	433	\N
ODD Cubes Basic	348733.5599463622	8212.39164278879	22152.455933318175	15.742433299318884	6.352258135616597	3.941362213409885	30364.847576106964	85	0.023549186502302553	middle	433	\N
Container (Base)	260091.69005453662	6124.947716793353	24239.899859313613	10.72989952780694	9.319751759170366	3.941362213409885	30364.847576106964	101	0.023549186502302553	middle	433	\N
Container (Max)	502751.62529778737	11839.391788473326	18525.45578763364	27.138421373329493	3.684812709787012	3.941362213409885	30364.847576106964	110	0.023549186502302553	middle	433	\N
Traditional Housing	582807.7129433381	14242.91548215137	16022.855568580722	36.37352346145889	2.7492524914711454	2.5245570804810704	30265.77105073209	133	0.024438447134168415	middle	434	\N
ODD Cubes Basic	345500.791967057	6707.067828436196	23558.703222295895	14.66552673578722	6.818711785917464	2.5245570804810704	30265.77105073209	75	0.019412597552238623	middle	434	\N
Container (Base)	256640.1039965699	4982.051054650078	25283.719996082014	10.15040919755238	9.851819572368917	2.5245570804810704	30265.77105073209	142	0.019412597552238623	middle	434	\N
Container (Max)	420713.21400361106	8167.136308360944	22098.63474237115	19.037973110481357	5.252660008482993	2.5245570804810704	30265.77105073209	93	0.019412597552238623	middle	434	\N
Traditional Housing	580902.3630305037	13611.841661652386	1959.9160134649846	100	0.337391640695059	-1.5937873210111975	15571.757675117371	147	0.023432236685423186	low	435	\N
ODD Cubes Basic	352711.05074564385	7827.344984148556	7744.412690968815	45.54393790983784	2.1956818972915215	-1.5937873210111975	15571.757675117371	132	0.022191947112519633	low	435	\N
Container (Base)	231447.79749807107	5136.277281386347	10435.480393731024	22.178930798155708	4.508783624876791	-1.5937873210111975	15571.757675117371	112	0.022191947112519633	low	435	\N
Container (Max)	414108.11917008413	9189.865479487484	6381.892195629887	64.88798407683099	1.5411173797847444	-1.5937873210111975	15571.757675117371	97	0.022191947112519633	low	435	\N
Traditional Housing	548787.191753633	12361.796819009534	18298.795422628507	29.990345215565185	3.3344064325107983	4.4606892472745585	30660.59224163804	103	0.022525665694761908	middle	436	\N
ODD Cubes Basic	305811.5511444624	6113.637419732854	24546.954821905187	12.45822764425193	8.026823947637427	4.4606892472745585	30660.59224163804	96	0.019991518949671168	middle	436	\N
Container (Base)	259699.5248812167	5191.787972883442	25468.8042687546	10.196769433727159	9.80702767184642	4.4606892472745585	30660.59224163804	114	0.019991518949671168	middle	436	\N
Container (Max)	486113.5689915436	9718.148626186727	20942.443615451317	23.211883862153	4.308138046608534	4.4606892472745585	30660.59224163804	109	0.019991518949671168	middle	436	\N
Traditional Housing	500522.0129955143	11347.910831653106	18827.133049982607	26.58514239351895	3.7614995067462367	4.057057157596111	30175.043881635713	124	0.02267215134802634	middle	437	\N
ODD Cubes Basic	318360.4773029044	4142.944191717596	26032.099689918115	12.22953511607061	8.17692570084629	4.057057157596111	30175.043881635713	98	0.013013374734250658	middle	437	\N
Container (Base)	263209.2392474508	3425.2404638441126	26749.8034177916	9.839670039309047	10.16294241580301	4.057057157596111	30175.043881635713	145	0.013013374734250658	middle	437	\N
Container (Max)	452889.49302166555	5893.620685895732	24281.423195739982	18.65168649180012	5.36144546735563	4.057057157596111	30175.043881635713	86	0.013013374734250658	middle	437	\N
Traditional Housing	520745.7500222986	5285.782600341171	10680.43652254112	48.756972519172024	2.050988706500971	-4.386993469811546	15966.219122882292	91	0.010150409485079486	low	438	\N
ODD Cubes Basic	340623.4146577349	4304.846772932863	11661.37234994943	29.209547936200842	3.423538091668479	-4.386993469811546	15966.219122882292	109	0.012638141089796946	low	438	\N
Container (Base)	223311.90113721677	2822.2473136029325	13143.97180927936	16.98968199091567	5.885925354781196	-4.386993469811546	15966.219122882292	140	0.012638141089796946	low	438	\N
Container (Max)	406598.75851887086	5138.652477097768	10827.566645784525	37.55218248203267	2.662961068849895	-4.386993469811546	15966.219122882292	144	0.012638141089796946	low	438	\N
Traditional Housing	576905.420348773	14914.099026708183	15566.576507706523	37.06052002270154	2.6982891750775404	-3.4721138115882244	30480.675534414706	100	0.025851896169898594	middle	439	\N
ODD Cubes Basic	326023.95101735945	7801.049046269456	22679.62648814525	14.375190490362517	6.956429555979969	-3.4721138115882244	30480.675534414706	112	0.023927840337883893	middle	439	\N
Container (Base)	253058.59146867518	6055.145572792247	24425.52996162246	10.360413545429	9.65212436371518	-3.4721138115882244	30480.675534414706	81	0.023927840337883893	middle	439	\N
Container (Max)	435337.626610083	10416.68922259938	20063.986311815326	21.697464294706002	4.608833485874161	-3.4721138115882244	30480.675534414706	111	0.023927840337883893	middle	439	\N
Traditional Housing	576452.7628922216	16901.25570654184	-1146.078355922471	100	0	0.2883827495877611	15755.17735061937	82	0.029319411397637524	low	440	Negative cash flow
ODD Cubes Basic	345251.62827171903	5305.223470710865	10449.953879908506	33.03857914009682	3.0267645462584785	0.2883827495877611	15755.17735061937	125	0.015366251847291974	low	440	\N
Container (Base)	265925.3171284245	4086.2753955663566	11668.901955053014	22.789232281900368	4.388037243335391	0.2883827495877611	15755.17735061937	127	0.015366251847291974	low	440	\N
Container (Max)	443541.8483518153	6815.5757465873785	8939.601604031992	49.615393168277926	2.015503528528641	0.2883827495877611	15755.17735061937	87	0.015366251847291974	low	440	\N
Traditional Housing	543465.0395937039	7605.5443440969775	22421.329882524136	24.23875133371536	4.12562506307423	-0.7469327948122748	30026.874226621116	123	0.013994542040428038	middle	441	\N
ODD Cubes Basic	345032.418820002	3832.296498009125	26194.577728611992	13.171902307214047	7.591917831430586	-0.7469327948122748	30026.874226621116	121	0.011107062087427715	middle	441	\N
Container (Base)	224727.2153041547	2496.059133117982	27530.815093503134	8.162751975955372	12.25077036452476	-0.7469327948122748	30026.874226621116	47	0.011107062087427715	middle	441	\N
Container (Max)	465558.937774978	5170.992027223577	24855.88219939754	18.73033248388433	5.338933523259158	-0.7469327948122748	30026.874226621116	49	0.011107062087427715	middle	441	\N
Traditional Housing	544087.8111421225	5568.207896146842	9929.20025146125	54.796740660160495	1.824926059383385	3.5288332415608057	15497.408147608092	98	0.010234024328643447	low	442	\N
ODD Cubes Basic	328757.80946702056	4589.615833383015	10907.792314225077	30.139720302364093	3.3178808229403582	3.5288332415608057	15497.408147608092	110	0.013960476987067358	low	442	\N
Container (Base)	246169.9532724528	3436.649967567524	12060.758180040568	20.410819087629264	4.89936242003187	3.5288332415608057	15497.408147608092	109	0.013960476987067358	low	442	\N
Container (Max)	433931.34649723925	6057.888576741861	9439.519570866232	45.96964318359042	2.1753486230168644	3.5288332415608057	15497.408147608092	134	0.013960476987067358	low	442	\N
Traditional Housing	539853.983575032	12771.088502313867	2940.992825984473	100	0.5447756088615983	-2.670014723072173	15712.08132829834	133	0.023656560645789637	low	443	\N
ODD Cubes Basic	352810.056338451	7482.632815341332	8229.448512957008	42.87165243004591	2.3325436350551443	-2.670014723072173	15712.08132829834	133	0.0212086721478348	low	443	\N
Container (Base)	243085.4735956679	5155.5201133916735	10556.561214906666	23.026956283113552	4.342736346502442	-2.670014723072173	15712.08132829834	48	0.0212086721478348	low	443	\N
Container (Max)	402376.16621002794	8533.864189251166	7178.217139047174	56.05516779664299	1.7839568398542685	-2.670014723072173	15712.08132829834	107	0.0212086721478348	low	443	\N
Traditional Housing	559473.7134974427	6949.176941613464	23705.534062986717	23.600974861435088	4.237113110247149	-3.5421898628074544	30654.71100460018	142	0.012420917683821133	middle	444	\N
ODD Cubes Basic	331416.1952273283	5027.132948874593	25627.578055725586	12.932013883898206	7.732747652282612	-3.5421898628074544	30654.71100460018	121	0.015168639979788352	middle	444	\N
Container (Base)	231068.88843492456	3505.000779199251	27149.71022540093	8.510915457901993	11.749617358395284	-3.5421898628074544	30654.71100460018	111	0.015168639979788352	middle	444	\N
Container (Max)	396300.0311792936	6011.3324969376035	24643.378507662575	16.081400164188878	6.218364009291094	-3.5421898628074544	30654.71100460018	122	0.015168639979788352	middle	444	\N
Traditional Housing	552918.8200647113	16266.815207785696	14343.125742605878	38.54939501940504	2.594074432287767	1.9546227587190943	30609.940950391574	129	0.029419897853869212	middle	445	\N
ODD Cubes Basic	322203.4087781349	3653.126472238477	26956.814478153097	11.952577298748029	8.366396426524219	1.9546227587190943	30609.940950391574	92	0.011337951035626605	middle	445	\N
Container (Base)	263960.6783509949	2992.7732464743635	27617.16770391721	9.557847538201928	10.46260673235352	1.9546227587190943	30609.940950391574	55	0.011337951035626605	middle	445	\N
Container (Max)	492123.49490987504	5579.672088769602	25030.26886162197	19.661134989421974	5.086176360306855	1.9546227587190943	30609.940950391574	68	0.011337951035626605	middle	445	\N
Traditional Housing	549825.0759501972	7209.113460368246	8327.840089625035	66.02253045602768	1.5146344635578908	-0.9845508497879409	15536.95354999328	104	0.01311164909659603	low	446	\N
ODD Cubes Basic	338237.48922292225	6488.5848123065925	9048.368737686687	37.38104613422245	2.6751525262544678	-0.9845508497879409	15536.95354999328	145	0.0191835175551169	low	446	\N
Container (Base)	256201.4254965799	4914.844543659616	10622.109006333665	24.11963813813379	4.1459991823798275	-0.9845508497879409	15536.95354999328	143	0.0191835175551169	low	446	\N
Container (Max)	450982.81496119057	8651.436747864036	6885.516802129245	65.49730803383281	1.5267803059683724	-0.9845508497879409	15536.95354999328	70	0.0191835175551169	low	446	\N
Traditional Housing	507922.521620041	9888.486939020893	20611.45955590324	24.642724608727143	4.057992839175962	-2.552835358046485	30499.94649492413	121	0.019468494737112922	middle	447	\N
ODD Cubes Basic	298890.2622908024	7202.03383326411	23297.91266166002	12.829057548261318	7.794804850146821	-2.552835358046485	30499.94649492413	118	0.024095913256140012	middle	447	\N
Container (Base)	263860.58486244484	6357.961764559841	24141.98473036429	10.929531594416817	9.149522935738934	-2.552835358046485	30499.94649492413	111	0.024095913256140012	middle	447	\N
Container (Max)	437276.92454293004	10536.586842698123	19963.359652226005	21.9039746896596	4.565381462352031	-2.552835358046485	30499.94649492413	123	0.024095913256140012	middle	447	\N
Traditional Housing	580118.1152839148	14710.974531035057	765.0683864685761	100	0.13188148522032364	-0.09467531166723475	15476.042917503633	129	0.02535858499063657	low	448	\N
ODD Cubes Basic	306096.1466015315	5028.648168489125	10447.394749014507	29.298801658701105	3.4131088760861377	-0.09467531166723475	15476.042917503633	118	0.016428328890514578	low	448	\N
Container (Base)	244383.19756198136	4014.80754486383	11461.235372639803	21.322587802827222	4.689862268347218	-0.09467531166723475	15476.042917503633	138	0.016428328890514578	low	448	\N
Container (Max)	463597.2173722026	7616.127559717923	7859.9153577857105	58.982469437534355	1.6954190109979277	-0.09467531166723475	15476.042917503633	70	0.016428328890514578	low	448	\N
Traditional Housing	525409.0045416201	14111.951690950522	1615.9985483115815	100	0.30756963324627806	0.9797947890366334	15727.950239262103	108	0.026858983323405618	low	449	\N
ODD Cubes Basic	296689.07755961915	3656.2285657346183	12071.721673527485	24.57719665706337	4.068812297649108	0.9797947890366334	15727.950239262103	52	0.012323435010848708	low	449	\N
Container (Base)	252225.13376444866	3108.2800440488054	12619.670195213297	19.98666604299365	5.003335713164383	0.9797947890366334	15727.950239262103	105	0.012323435010848708	low	449	\N
Container (Max)	420319.3511587725	5179.77820780723	10548.172031454873	39.84760107299836	2.5095613614683137	0.9797947890366334	15727.950239262103	109	0.012323435010848708	low	449	\N
Traditional Housing	540541.9109613115	11094.337133210316	4842.100503786782	100	0.8957863221328175	-4.387703402843939	15936.437636997098	143	0.02052447166118887	low	450	\N
ODD Cubes Basic	338942.13311079284	5298.6231622492405	10637.814474747858	31.862008302116642	3.138534114102181	-4.387703402843939	15936.437636997098	48	0.0156328253251337	low	450	\N
Container (Base)	247742.38065226923	3872.913362369708	12063.52427462739	20.536484613649215	4.869382558957376	-4.387703402843939	15936.437636997098	48	0.0156328253251337	low	450	\N
Container (Max)	402547.8155821729	6292.959686010243	9643.477950986855	41.74301197432391	2.3956105530072893	-4.387703402843939	15936.437636997098	70	0.0156328253251337	low	450	\N
Traditional Housing	595232.7306107583	17038.284486090335	-1455.1046067738607	100	0	4.77838061511582	15583.179879316474	135	0.028624575917738322	low	451	Negative cash flow
ODD Cubes Basic	306278.7122331399	2633.2176540519968	12949.962225264477	23.65093479852871	4.228162685824192	4.77838061511582	15583.179879316474	144	0.008597455679673835	low	451	\N
Container (Base)	258678.6879083794	2223.9785545684717	13359.201324748003	19.363334799751502	5.164399677749895	4.77838061511582	15583.179879316474	76	0.008597455679673835	low	451	\N
Container (Max)	469902.6573058542	4039.967269948044	11543.212609368431	40.7081350060626	2.456511456128048	4.77838061511582	15583.179879316474	87	0.008597455679673835	low	451	\N
Traditional Housing	548979.040350496	9380.636177042708	6188.318645301873	88.7121481320741	1.1272413317184091	-3.3825665521475914	15568.954822344582	145	0.017087421354107867	low	452	\N
ODD Cubes Basic	336229.1237024047	3415.2475996051216	12153.70722273946	27.664737807187215	3.614709840988274	-3.3825665521475914	15568.954822344582	114	0.010157500819673034	low	452	\N
Container (Base)	222078.23406577946	2255.7598445546946	13313.194977789888	16.681062242103998	5.9948220652036195	-3.3825665521475914	15568.954822344582	97	0.010157500819673034	low	452	\N
Container (Max)	450424.85556225287	4575.190839574691	10993.763982769891	40.97094100511769	2.4407542894245213	-3.3825665521475914	15568.954822344582	107	0.010157500819673034	low	452	\N
Traditional Housing	576546.8758798855	9491.387621871361	6347.732614191733	90.8272151525239	1.1009915897131985	1.6319535842323862	15839.120236063094	96	0.016462473424014776	low	453	\N
ODD Cubes Basic	311900.72065680375	3927.6824659913614	11911.437770071732	26.18497671544528	3.8189837282159864	1.6319535842323862	15839.120236063094	71	0.012592732898213275	low	453	\N
Container (Base)	244373.17029793415	3077.3260610514703	12761.794175011624	19.148809873178475	5.222256665677635	1.6319535842323862	15839.120236063094	96	0.012592732898213275	low	453	\N
Container (Max)	452105.97644012823	5693.249802996439	10145.870433066655	44.56059038233512	2.244135437658887	1.6319535842323862	15839.120236063094	40	0.012592732898213275	low	453	\N
Traditional Housing	544121.1534676854	6500.520036008754	23622.776996344906	23.033750585372584	4.341455362614905	-1.123789518430435	30123.29703235366	148	0.011946824699942142	middle	454	\N
ODD Cubes Basic	344800.98501990683	4648.254901430347	25475.042130923313	13.534854358547431	7.388332179344712	-1.123789518430435	30123.29703235366	66	0.013480979183287377	middle	454	\N
Container (Base)	244306.4338999285	3293.4899497481097	26829.807082605552	9.105784217819389	10.98203049928494	-1.123789518430435	30123.29703235366	146	0.013480979183287377	middle	454	\N
Container (Max)	463061.914059076	6242.528024003612	23880.76900835005	19.390577995924826	5.1571438469248445	-1.123789518430435	30123.29703235366	60	0.013480979183287377	middle	454	\N
Traditional Housing	509542.04317813925	14160.190073468802	1519.8784802847986	100	0.29828323307826415	0.5089572060112681	15680.068553753601	98	0.02779003276186634	low	455	\N
ODD Cubes Basic	296956.2726758156	3162.8290632174526	12517.239490536149	23.72378293954781	4.215179352079591	0.5089572060112681	15680.068553753601	82	0.010650824226468802	low	455	\N
Container (Base)	239013.80964509593	2545.69407422859	13134.374479525011	18.19757842428592	5.495236655583972	0.5089572060112681	15680.068553753601	46	0.010650824226468802	low	455	\N
Container (Max)	410478.2968566847	4371.93218860083	11308.136365152772	36.29937627225803	2.754868272390274	0.5089572060112681	15680.068553753601	53	0.010650824226468802	low	455	\N
Traditional Housing	548716.2027850781	11499.622870136516	18858.1124078484	29.097090467904547	3.4367697385518556	-2.4812267546120514	30357.735277984917	126	0.02095732331534723	middle	456	\N
ODD Cubes Basic	322883.1351871174	4979.722843331032	25378.012434653887	12.722948103934955	7.859813557603995	-2.4812267546120514	30357.735277984917	68	0.015422678674267644	middle	456	\N
Container (Base)	261818.25842407136	4037.9388707308203	26319.796407254096	9.947579167136364	10.052697075321419	-2.4812267546120514	30357.735277984917	83	0.015422678674267644	middle	456	\N
Container (Max)	407906.48753849283	6291.010686455334	24066.724591529583	16.948982234252924	5.900059284852262	-2.4812267546120514	30357.735277984917	50	0.015422678674267644	middle	456	\N
Traditional Housing	537916.1052895022	7385.055609417449	23537.47036679548	22.853607329373222	4.3756768268032795	-1.4808922002015934	30922.525976212928	114	0.013729010038550288	middle	457	\N
ODD Cubes Basic	317816.9774168302	4098.825930352406	26823.70004586052	11.848364575858588	8.439983371523958	-1.4808922002015934	30922.525976212928	118	0.012896812384495828	middle	457	\N
Container (Base)	266882.06065112	3441.9278650051306	27480.598111207797	9.711654002984517	10.296907197195113	-1.4808922002015934	30922.525976212928	52	0.012896812384495828	middle	457	\N
Container (Max)	480178.4912162709	6192.771912286524	24729.754063926404	19.417034636697547	5.150116991139489	-1.4808922002015934	30922.525976212928	142	0.012896812384495828	middle	457	\N
Traditional Housing	536802.656503659	10125.92103035646	5690.957692024038	94.32553983945373	1.0601582579882867	-4.232096700481219	15816.878722380497	112	0.01886339590103619	low	458	\N
ODD Cubes Basic	354220.87175500527	5731.801141878444	10085.077580502053	35.12326691862409	2.8471155667747707	-4.232096700481219	15816.878722380497	64	0.016181432543711904	low	458	\N
Container (Base)	244814.7146558482	3961.4527909116855	11855.425931468812	20.650014269501426	4.842611665779463	-4.232096700481219	15816.878722380497	44	0.016181432543711904	low	458	\N
Container (Max)	455013.1637089813	7362.7648150578225	8454.113907322675	53.82150852200653	1.8579932585708188	-4.232096700481219	15816.878722380497	64	0.016181432543711904	low	458	\N
Traditional Housing	588875.3287543812	14319.597691803023	1316.2218064159642	100	0.22351451014259727	2.9384924705543565	15635.819498218987	120	0.024316857902830738	low	459	\N
ODD Cubes Basic	322237.82496841555	3465.9149341786915	12169.904564040295	26.478254062941936	3.7766840578796543	2.9384924705543565	15635.819498218987	148	0.010755766907619882	low	459	\N
Container (Base)	255650.09970850623	2749.7128823744747	12886.106615844512	19.839204138988244	5.040524776065931	2.9384924705543565	15635.819498218987	111	0.010755766907619882	low	459	\N
Container (Max)	424156.72367236525	4562.130852119697	11073.68864609929	38.303110844801886	2.6107540039028185	2.9384924705543565	15635.819498218987	116	0.010755766907619882	low	459	\N
Traditional Housing	544252.0395538921	9160.248799469153	6523.879452135816	83.42460089076485	1.1986871849820269	3.3757862278496216	15684.128251604969	92	0.016830894757835998	low	460	\N
ODD Cubes Basic	316913.0467066305	3709.8833788034426	11974.244872801526	26.46622397262573	3.7784007308118817	3.3757862278496216	15684.128251604969	140	0.011706313190184682	low	460	\N
Container (Base)	273606.28233357804	3202.9208317989587	12481.20741980601	21.921459449460105	4.561740071665843	3.3757862278496216	15684.128251604969	128	0.011706313190184682	low	460	\N
Container (Max)	462634.1462718754	5415.740208732284	10268.388042872684	45.05421341112942	2.2195482381964684	3.3757862278496216	15684.128251604969	51	0.011706313190184682	low	460	\N
Traditional Housing	495755.1139356502	11620.690444768288	4289.355287761711	100	0.8652165488944359	-0.33592868226458794	15910.04573253	103	0.023440384411801896	low	461	\N
ODD Cubes Basic	301929.86502457183	5587.239171607849	10322.80656092215	29.248815546689855	3.418941865880692	-0.33592868226458794	15910.04573253	130	0.01850508948875642	low	461	\N
Container (Base)	233355.75011297435	4318.269038556471	11591.776693973528	20.131146093790274	4.967427067197448	-0.33592868226458794	15910.04573253	143	0.01850508948875642	low	461	\N
Container (Max)	460408.93203718215	8519.908488770829	7390.137243759171	62.30045760327234	1.6051246467048017	-0.33592868226458794	15910.04573253	106	0.01850508948875642	low	461	\N
Traditional Housing	557752.3056429994	6259.166332869545	9714.210518581254	57.416122965024876	1.7416710644310687	3.603736660027659	15973.3768514508	129	0.011222125430129286	low	462	\N
ODD Cubes Basic	350911.209459147	7192.323124576895	8781.053726873904	39.96231208393631	2.5023577161892265	3.603736660027659	15973.3768514508	52	0.020496133867203302	low	462	\N
Container (Base)	245540.6712290462	5032.634467353485	10940.742384097313	22.4427797135546	4.455776034713015	3.603736660027659	15973.3768514508	73	0.020496133867203302	low	462	\N
Container (Max)	455721.1026586979	9340.520726202172	6632.856125248627	68.70661658466406	1.4554638981061527	3.603736660027659	15973.3768514508	49	0.020496133867203302	low	462	\N
Traditional Housing	501102.799169644	9850.132634384678	20871.324592007124	24.00915174121465	4.16507842833688	-0.8085715799958981	30721.4572263918	144	0.019656910020672227	middle	463	\N
ODD Cubes Basic	351479.0419711494	3745.374204414239	26976.083021977563	13.029283817253878	7.675018934469456	-0.8085715799958981	30721.4572263918	58	0.010656038503489697	middle	463	\N
Container (Base)	254758.20546666547	2714.7132465327268	28006.743979859075	9.096316431852046	10.993461006901187	-0.8085715799958981	30721.4572263918	117	0.010656038503489697	middle	463	\N
Container (Max)	437877.5281919989	4666.039800226836	26055.417426164968	16.805623223379268	5.950389263808095	-0.8085715799958981	30721.4572263918	139	0.010656038503489697	middle	463	\N
Traditional Housing	522737.23796200415	7103.319107089181	23779.887374319762	21.982326061246006	4.549109121636411	-2.42293697177157	30883.206481408943	83	0.013588699237848242	middle	464	\N
ODD Cubes Basic	308213.83674178086	3703.5661705462353	27179.640310862706	11.339879160159418	8.818436121553361	-2.42293697177157	30883.206481408943	65	0.012016222923985902	middle	464	\N
Container (Base)	258314.4286051962	3103.963758602078	27779.242722806863	9.298829027946075	10.754042223968925	-2.42293697177157	30883.206481408943	70	0.012016222923985902	middle	464	\N
Container (Max)	434119.76177283	5216.4798331699785	25666.726648238964	16.913717425771377	5.912360806479498	-2.42293697177157	30883.206481408943	135	0.012016222923985902	middle	464	\N
Traditional Housing	575697.102051565	7663.425277155424	7906.445807870761	72.8136404196265	1.3733690476632943	-0.7745327535411395	15569.871085026185	80	0.013311557848469097	low	465	\N
ODD Cubes Basic	302172.4386203654	3780.372763263769	11789.498321762416	25.630644355967263	3.9015796330035784	-0.7745327535411395	15569.871085026185	71	0.012510647167305829	low	465	\N
Container (Base)	246142.47789042507	3079.401693773484	12490.4693912527	19.706423368108414	5.074487548148055	-0.7745327535411395	15569.871085026185	129	0.012510647167305829	low	465	\N
Container (Max)	425242.65487943747	5320.060815685045	10249.81026934114	41.487856233925406	2.4103438711356726	-0.7745327535411395	15569.871085026185	144	0.012510647167305829	low	465	\N
Traditional Housing	591496.5509033935	16782.2548963166	-1321.6675135526639	100	0	4.571093552478022	15460.587382763937	124	0.028372532131734393	low	466	Negative cash flow
ODD Cubes Basic	295614.10673242155	5929.103552002437	9531.4838307615	31.014489661973656	3.2242993868317082	4.571093552478022	15460.587382763937	59	0.020056903297139442	low	466	\N
Container (Base)	247240.0744513462	4958.870264448207	10501.71711831573	23.542823679771587	4.24757885291057	4.571093552478022	15460.587382763937	128	0.020056903297139442	low	466	\N
Container (Max)	433343.38108466176	8691.526288870506	6769.0610938934315	64.01824050245219	1.5620548021179925	4.571093552478022	15460.587382763937	127	0.020056903297139442	low	466	\N
Traditional Housing	599510.3921639121	11341.152518675166	19542.372368293407	30.677462329834114	3.2597220371369855	-0.2717119922168463	30883.524886968575	81	0.018917357675385188	middle	467	\N
ODD Cubes Basic	294820.92960439133	6781.485680196564	24102.03920677201	12.23219857353625	8.175145244645146	-0.2717119922168463	30883.524886968575	140	0.023002049716403697	middle	467	\N
Container (Base)	265136.04510426975	6098.672491099066	24784.852395869508	10.697503494047668	9.347975446387306	-0.2717119922168463	30883.524886968575	84	0.023002049716403697	middle	467	\N
Container (Max)	473337.22337994457	10887.726344809967	19995.798542158605	23.671833979621923	4.224429762648967	-0.2717119922168463	30883.524886968575	42	0.023002049716403697	middle	467	\N
Traditional Housing	549657.6874956687	9510.811465902878	6273.521064436303	87.61550042632354	1.1413505545641511	4.002195567607696	15784.332530339181	113	0.017303153730525826	low	468	\N
ODD Cubes Basic	324826.8247123414	2927.7267751258487	12856.605755213332	25.265364039075763	3.9579876959357727	4.002195567607696	15784.332530339181	86	0.009013192730368162	low	468	\N
Container (Base)	240406.8327201833	2166.8331170043907	13617.49941333479	17.654256881022334	5.664356232829956	4.002195567607696	15784.332530339181	74	0.009013192730368162	low	468	\N
Container (Max)	457341.3060805365	4122.105335262172	11662.227195077008	39.215605941341515	2.550005223674969	4.002195567607696	15784.332530339181	60	0.009013192730368162	low	468	\N
Traditional Housing	569521.5459973103	15086.142094388762	824.692650093315	100	0.14480446892472962	3.5085219703133035	15910.834744482077	100	0.026489150762454228	low	469	\N
ODD Cubes Basic	336155.36110204173	5568.538544425489	10342.29620005659	32.5029717385393	3.076641754619267	3.5085219703133035	15910.834744482077	103	0.016565371815489595	low	469	\N
Container (Base)	269611.43456141325	4466.213659217352	11444.621085264725	23.557917081985845	4.244857457133488	3.5085219703133035	15910.834744482077	121	0.016565371815489595	low	469	\N
Container (Max)	470636.0771296079	7796.261607435394	8114.573137046684	57.99887057286379	1.7241715056221714	3.5085219703133035	15910.834744482077	104	0.016565371815489595	low	469	\N
Traditional Housing	571463.9062507143	11724.89929717374	3738.8684333556303	100	0.6542615189620222	-4.592744020909274	15463.767730529371	103	0.02051730506323484	low	470	\N
ODD Cubes Basic	332150.838550594	5714.463661421941	9749.304069107431	34.06918444600355	2.9352038103081273	-4.592744020909274	15463.767730529371	55	0.01720442340702235	low	470	\N
Container (Base)	233081.1693014335	4010.0271248657214	11453.74060566365	20.349785919385972	4.914056609545766	-4.592744020909274	15463.767730529371	41	0.01720442340702235	low	470	\N
Container (Max)	390372.70662080747	6716.137331249689	8747.630399279682	44.62610887777706	2.2408406763377497	-4.592744020909274	15463.767730529371	74	0.01720442340702235	low	470	\N
Traditional Housing	586588.5379514683	11237.366321731888	4334.796102597851	100	0.7389841127370431	4.323307986111917	15572.16242432974	124	0.01915715291842545	low	471	\N
ODD Cubes Basic	296723.18995542696	6311.582648988487	9260.579775341252	32.041534888078075	3.12094911649216	4.323307986111917	15572.16242432974	141	0.02127094498389761	low	471	\N
Container (Base)	271595.1995862922	5777.086548290712	9795.075876039027	27.727727995520233	3.606498160114535	4.323307986111917	15572.16242432974	131	0.02127094498389761	low	471	\N
Container (Max)	472501.93226309045	10050.562605953512	5521.599818376228	85.57337507339352	1.1685877752774532	4.323307986111917	15572.16242432974	41	0.02127094498389761	low	471	\N
Traditional Housing	522069.7698899784	14858.275117903038	16096.51735553038	32.43370962543072	3.083211916085963	1.6552747856289418	30954.79247343342	116	0.028460324605721357	middle	472	\N
ODD Cubes Basic	340252.8165697158	8207.494917005008	22747.297556428413	14.957944596524607	6.685410509090563	1.6552747856289418	30954.79247343342	130	0.02412175452285592	middle	472	\N
Container (Base)	232579.93872287587	5610.236188814084	25344.556284619335	9.17672166405296	10.897137742743123	1.6552747856289418	30954.79247343342	76	0.02412175452285592	middle	472	\N
Container (Max)	457383.5257885001	11032.893131868539	19921.89934156488	22.958831281424008	4.355622408398027	1.6552747856289418	30954.79247343342	96	0.02412175452285592	middle	472	\N
Traditional Housing	584705.9213631599	8663.500836416308	6924.5694565261565	84.43931785709734	1.1842824236126246	2.74022634093774	15588.070292942464	114	0.014816851548584576	low	473	\N
ODD Cubes Basic	309235.2520187464	2933.493728369422	12654.576564573043	24.436633690649277	4.092216680330449	2.74022634093774	15588.070292942464	90	0.009486284986006668	low	473	\N
Container (Base)	240542.95213786443	2281.858995355144	13306.21129758732	18.077493792803338	5.531740248186951	2.74022634093774	15588.070292942464	97	0.009486284986006668	low	473	\N
Container (Max)	499690.4007644587	4740.205546423539	10847.864746518924	46.06347999727865	2.170917177901188	2.74022634093774	15588.070292942464	91	0.009486284986006668	low	473	\N
Traditional Housing	598626.8382122751	13555.43968556213	2012.0271687161912	100	0.3361070771108194	4.310926884249891	15567.466854278322	91	0.022644223112421376	low	474	\N
ODD Cubes Basic	342046.65190124867	6649.424787933892	8918.042066344431	38.3544559844688	2.6072589855138046	4.310926884249891	15567.466854278322	132	0.01944011073043226	low	474	\N
Container (Base)	282836.1832989301	5498.366721904037	10069.100132374286	28.08951937915008	3.560046672575918	4.310926884249891	15567.466854278322	128	0.01944011073043226	low	474	\N
Container (Max)	438739.1479217838	8529.137617374976	7038.329236903346	62.33569546894567	1.604217282693475	4.310926884249891	15567.466854278322	46	0.01944011073043226	low	474	\N
Traditional Housing	539137.128289952	8534.824404272042	21850.14002440982	24.67430999012622	4.052798235898651	-3.4867326702123314	30384.96442868186	103	0.015830526143400664	middle	475	\N
ODD Cubes Basic	312835.6584963513	5710.565099241329	24674.39932944053	12.678552143033851	7.887335941189811	-3.4867326702123314	30384.96442868186	142	0.018254201348686515	middle	475	\N
Container (Base)	241598.39025992702	4410.185661323251	25974.778767358606	9.301268450591516	10.751221785630804	-3.4867326702123314	30384.96442868186	43	0.018254201348686515	middle	475	\N
Container (Max)	439534.86448333313	8023.357916046404	22361.606512635455	19.655782076076395	5.087561492743289	-3.4867326702123314	30384.96442868186	53	0.018254201348686515	middle	475	\N
Traditional Housing	524962.9510538582	12258.643886093661	3625.387952636578	100	0.6905988213756126	4.9686409136373	15884.03183873024	144	0.023351445776286783	low	476	\N
ODD Cubes Basic	328820.68553406064	4341.426450393172	11542.605388337068	28.487561904031576	3.5103039121732613	4.9686409136373	15884.03183873024	112	0.013203021103559705	low	476	\N
Container (Base)	274585.9225260497	3625.3637298518447	12258.668108878395	22.399327568643418	4.464419732848987	4.9686409136373	15884.03183873024	133	0.013203021103559705	low	476	\N
Container (Max)	463321.48741376295	6117.243376056585	9766.788462673656	47.438468559492975	2.1079938504884317	4.9686409136373	15884.03183873024	117	0.013203021103559705	low	476	\N
Traditional Housing	588034.4021275067	16458.084913110408	14168.058606743747	41.504232756886864	2.4093928102647997	4.5322381530684055	30626.143519854155	139	0.027988302816238486	middle	477	\N
ODD Cubes Basic	326145.29245100584	7425.093403734446	23201.05011611971	14.057350456926319	7.113716080879817	4.5322381530684055	30626.143519854155	49	0.022766213634219042	middle	477	\N
Container (Base)	242115.41034281178	5512.05115600106	25114.092363853095	9.640619570679382	10.37277731652603	4.5322381530684055	30626.143519854155	124	0.022766213634219042	middle	477	\N
Container (Max)	459907.0050627532	10470.3411291325	20155.802390721656	22.81759843381193	4.382582167447405	4.5322381530684055	30626.143519854155	117	0.022766213634219042	middle	477	\N
Traditional Housing	583137.2189868987	7011.356475802097	8949.384980871322	65.15947411283717	1.534696241207061	-3.0828843382456994	15960.741456673419	80	0.01202351050063848	low	478	\N
ODD Cubes Basic	354290.2943572594	4435.805058980821	11524.936397692598	30.741193021090485	3.2529641881950844	-3.0828843382456994	15960.741456673419	145	0.012520255648064246	low	478	\N
Container (Base)	264835.2181788734	3315.804636210367	12644.936820463052	20.94397322336129	4.774643231899197	-3.0828843382456994	15960.741456673419	126	0.012520255648064246	low	478	\N
Container (Max)	423201.84613600763	5298.5953043555655	10662.146152317853	39.69199447186413	2.519399726080419	-3.0828843382456994	15960.741456673419	40	0.012520255648064246	low	478	\N
Traditional Housing	594786.2950213919	7346.442186019844	8385.923779176568	70.92674709235138	1.4099053474113692	2.0166962498421253	15732.365965196412	111	0.012351397884437844	low	479	\N
ODD Cubes Basic	333498.6443857213	5804.411047925144	9927.954917271269	33.59187739718146	2.9769101267436318	2.0166962498421253	15732.365965196412	93	0.017404601624742493	low	479	\N
Container (Base)	238687.43203374476	4154.259667380127	11578.106297816284	20.615412045298196	4.85073981447813	2.0166962498421253	15732.365965196412	55	0.017404601624742493	low	479	\N
Container (Max)	465080.976580747	8094.549120634094	7637.816844562318	60.89187343001785	1.6422552693329193	2.0166962498421253	15732.365965196412	109	0.017404601624742493	low	479	\N
Traditional Housing	512122.3179173247	12073.868915758281	3489.5072916080717	100	0.6813816093387685	-0.868335836181596	15563.376207366353	95	0.0235761428341177	low	480	\N
ODD Cubes Basic	341730.4811596065	4879.379259053199	10683.996948313154	31.985265702791192	3.1264395590521388	-0.868335836181596	15563.376207366353	68	0.014278443182755673	low	480	\N
Container (Base)	248459.34185273162	3547.6125958690973	12015.763611497256	20.677782110742747	4.836108605092947	-0.868335836181596	15563.376207366353	91	0.014278443182755673	low	480	\N
Container (Max)	471361.83159852715	6730.313130999218	8833.063076367136	53.36334944325892	1.8739453397004189	-0.868335836181596	15563.376207366353	99	0.014278443182755673	low	480	\N
Traditional Housing	533066.7318449597	15232.532885695211	722.5141535258663	100	0.13553915680035472	4.50529771888052	15955.047039221077	105	0.028575283310168252	low	481	\N
ODD Cubes Basic	356682.27723679895	4820.969298185227	11134.07774103585	32.03518832298142	3.121567414924855	4.50529771888052	15955.047039221077	105	0.013516144776054062	low	481	\N
Container (Base)	266545.2005641717	3602.6635201877116	12352.383519033367	21.578442747787204	4.634254712854785	4.50529771888052	15955.047039221077	116	0.013516144776054062	low	481	\N
Container (Max)	436532.548358011	5900.237123066698	10054.80991615438	43.41529596264807	2.3033356742755835	4.50529771888052	15955.047039221077	136	0.013516144776054062	low	481	\N
Traditional Housing	546687.2812217443	8346.482462377462	21891.43154918769	24.972660193254	4.0043791580927985	-4.231584795233212	30237.914011565153	119	0.01526737999780172	middle	482	\N
ODD Cubes Basic	347551.49949640397	4730.485531937047	25507.428479628106	13.625501283831149	7.3391795220529685	-4.231584795233212	30237.914011565153	68	0.013610890871687903	middle	482	\N
Container (Base)	260120.26221301893	3540.468502496243	26697.44550906891	9.74326409336272	10.263500921433684	-4.231584795233212	30237.914011565153	110	0.013610890871687903	middle	482	\N
Container (Max)	471531.9679919389	6417.970158850513	23819.94385271464	19.795679238689754	5.0516074136296645	-4.231584795233212	30237.914011565153	83	0.013610890871687903	middle	482	\N
Traditional Housing	535741.3954546326	12466.847018668028	3328.972702675528	100	0.6213767931541946	-2.741775491692219	15795.819721343556	125	0.023270270179679888	low	483	\N
ODD Cubes Basic	297109.28242513275	5229.469444361772	10566.350276981784	28.118439634957877	3.556385108783786	-2.741775491692219	15795.819721343556	106	0.017601164802649755	low	483	\N
Container (Base)	242333.95775910708	4265.359927796408	11530.459793547148	21.01685120091444	4.758086691675725	-2.741775491692219	15795.819721343556	55	0.017601164802649755	low	483	\N
Container (Max)	406788.7890467701	7159.956515882525	8635.863205461032	47.104589242396806	2.12293539989081	-2.741775491692219	15795.819721343556	48	0.017601164802649755	low	483	\N
Traditional Housing	549786.4974753308	6267.376136539373	24278.288039797004	22.64519213933536	4.4159484002035505	-1.5123928807725906	30545.664176336377	96	0.01139965453011256	middle	484	\N
ODD Cubes Basic	323441.5246113495	3282.1992029069047	27263.464973429473	11.863551640503887	8.42917897019856	-1.5123928807725906	30545.664176336377	54	0.01014773599911399	middle	484	\N
Container (Base)	224313.5927791082	2276.275120535152	28269.389055801224	7.934858172432853	12.602619710005436	-1.5123928807725906	30545.664176336377	110	0.01014773599911399	middle	484	\N
Container (Max)	419895.1098500896	4260.984722077677	26284.6794542587	15.9748993926596	6.25982033075899	-1.5123928807725906	30545.664176336377	40	0.01014773599911399	middle	484	\N
Traditional Housing	507361.18359126634	6152.1946621082925	24630.23748945546	20.599118616232367	4.854576638109105	-3.551543563161985	30782.432151563753	143	0.012125867845389889	middle	485	\N
ODD Cubes Basic	330563.01168180845	6348.500353914226	24433.931797649526	13.528850551740005	7.391610958932395	-3.551543563161985	30782.432151563753	68	0.019205114091909142	middle	485	\N
Container (Base)	242604.8103443093	4659.25306190844	26123.179089655314	9.28695582998089	10.76779106423356	-3.551543563161985	30782.432151563753	60	0.019205114091909142	middle	485	\N
Container (Max)	410121.5530501383	7876.431217878874	22906.000933684878	17.904546246962987	5.5851736548175435	-3.551543563161985	30782.432151563753	143	0.019205114091909142	middle	485	\N
Traditional Housing	545916.5762825606	9732.406968719883	6035.310138552519	90.45377350127208	1.1055370730176741	-3.1813464763031463	15767.717107272401	147	0.017827645086348307	low	486	\N
ODD Cubes Basic	318471.34456368606	2836.48212418187	12931.234983090531	24.628068779210462	4.060407695645791	-3.1813464763031463	15767.717107272401	66	0.008906553674610579	low	486	\N
Container (Base)	259459.53834113	2310.8903046249557	13456.826802647445	19.280885616368707	5.18648375337614	-3.1813464763031463	15767.717107272401	135	0.008906553674610579	low	486	\N
Container (Max)	432892.5649422701	3855.5808649981745	11912.136242274228	36.340464559665214	2.751753485039137	-3.1813464763031463	15767.717107272401	91	0.008906553674610579	low	486	\N
Traditional Housing	519827.2990895006	5210.461994232301	10636.223205302254	48.87329732139901	2.046107086705921	-0.37918632391912066	15846.685199534555	118	0.01002344817857516	low	487	\N
ODD Cubes Basic	297736.6050141325	2753.131360330888	13093.553839203667	22.739174457180106	4.3976970310997405	-0.37918632391912066	15846.685199534555	90	0.009246868923625319	low	487	\N
Container (Base)	238314.36487496397	2203.6616946158097	13643.023504918745	17.467855625187777	5.7248011516539545	-0.37918632391912066	15846.685199534555	121	0.009246868923625319	low	487	\N
Container (Max)	475143.76718484546	4393.592135035811	11453.093064498744	41.48606533702698	2.4104479223954844	-0.37918632391912066	15846.685199534555	111	0.009246868923625319	low	487	\N
Traditional Housing	584556.6212365073	14664.716823970211	15757.942245675786	37.09599972654541	2.6957084520474943	3.584691091831502	30422.659069645997	106	0.025086905684089368	middle	488	\N
ODD Cubes Basic	354559.872163357	4993.21868436379	25429.440385282207	13.942889296477226	7.172114607928913	3.584691091831502	30422.659069645997	72	0.014082864634109684	middle	488	\N
Container (Base)	258400.27893738373	3639.016149691359	26783.64291995464	9.647689812384243	10.365175699537431	3.584691091831502	30422.659069645997	86	0.014082864634109684	middle	488	\N
Container (Max)	420743.2919785296	5925.270826643319	24497.38824300268	17.17502648874044	5.822407322955674	3.584691091831502	30422.659069645997	116	0.014082864634109684	middle	488	\N
Traditional Housing	598767.6769734899	11947.779662520792	3539.8419468516295	100	0.5911878818749853	-3.6728171720617753	15487.621609372422	103	0.01995394895548073	low	489	\N
ODD Cubes Basic	334183.22776163695	8175.797782399113	7311.823826973308	45.704496671382515	2.1879685213252587	-3.6728171720617753	15487.621609372422	85	0.024465015306605	low	489	\N
Container (Base)	222328.7701297013	5439.276764321807	10048.344845050615	22.12590964562795	4.519588193281801	-3.6728171720617753	15487.621609372422	43	0.024465015306605	low	489	\N
Container (Max)	404979.0229709275	9907.817995837679	5579.803613534743	72.57944024922014	1.3778006506611837	-3.6728171720617753	15487.621609372422	102	0.024465015306605	low	489	\N
Traditional Housing	501338.701767825	8445.313275230206	7291.256298187554	68.75889164566149	1.4543573581048224	3.5695883282996395	15736.56957341776	99	0.016845524284182064	low	490	\N
ODD Cubes Basic	302214.1623468069	4895.790752114783	10840.778821302978	27.877532355233782	3.5871180679026566	3.5695883282996395	15736.56957341776	81	0.016199739661758805	low	490	\N
Container (Base)	235873.69778855646	3821.092497230988	11915.477076186773	19.795573125641184	5.051634492485095	3.5695883282996395	15736.56957341776	102	0.016199739661758805	low	490	\N
Container (Max)	457966.7466582173	7418.94206960577	8317.627503811991	55.059780742565096	1.8162077409562394	3.5695883282996395	15736.56957341776	75	0.016199739661758805	low	490	\N
Traditional Housing	507535.5558956381	5862.883879148936	9603.889936551132	52.846873428237146	1.8922595323599216	-3.6510403023061455	15466.773815700068	83	0.011551671229817227	low	491	\N
ODD Cubes Basic	297554.91807492723	6183.871303762682	9282.902511937385	32.05408197406849	3.119727468124005	-3.6510403023061455	15466.773815700068	46	0.02078228564921761	low	491	\N
Container (Base)	259803.7393116299	5399.31552310916	10067.458292590909	25.806289111009384	3.875024400828648	-3.6510403023061455	15466.773815700068	53	0.02078228564921761	low	491	\N
Container (Max)	458351.8885159487	9525.599874996791	5941.1739407032765	77.14837052249173	1.2962036569631257	-3.6510403023061455	15466.773815700068	103	0.02078228564921761	low	491	\N
Traditional Housing	557196.5447450469	14580.524200241634	16037.934487550068	34.74241306931311	2.878326263650549	2.673466131928782	30618.458687791703	148	0.02616765006486743	middle	492	\N
ODD Cubes Basic	300245.2057462757	7391.053127187515	23227.405560604187	12.926334151392231	7.736145362544995	2.673466131928782	30618.458687791703	76	0.02461672321733382	middle	492	\N
Container (Base)	272483.8866869065	6707.6604197549295	23910.79826803677	11.3958506793625	8.775123754569426	2.673466131928782	30618.458687791703	129	0.02461672321733382	middle	492	\N
Container (Max)	485167.6583472466	11943.237959536149	18675.220728255554	25.97921949126895	3.849230344799536	2.673466131928782	30618.458687791703	64	0.02461672321733382	middle	492	\N
Traditional Housing	591393.6272558289	7651.497205736408	7850.487575063229	75.33208881628805	1.327455558067286	-0.07014261697193724	15501.984780799638	108	0.01293807855394166	low	493	\N
ODD Cubes Basic	312101.4520779224	3778.0631058322806	11723.921674967358	26.620909003879998	3.75644573163993	-0.07014261697193724	15501.984780799638	100	0.012105240397564734	low	493	\N
Container (Base)	270244.0098509955	3271.3687052481528	12230.616075551485	22.09569887417221	4.525767687615012	-0.07014261697193724	15501.984780799638	69	0.012105240397564734	low	493	\N
Container (Max)	468497.1366520555	5671.270464743868	9830.71431605577	47.65646946803186	2.098350992347018	-0.07014261697193724	15501.984780799638	125	0.012105240397564734	low	493	\N
Traditional Housing	572581.6904392367	12335.280957101299	3528.8808743400223	100	0.6163104642121826	-1.638768354922461	15864.16183144132	88	0.02154326825861076	low	494	\N
ODD Cubes Basic	300290.4826514435	5296.362043851953	10567.799787589367	28.415610504288626	3.51919238141681	-1.638768354922461	15864.16183144132	88	0.017637462223535086	low	494	\N
Container (Base)	250940.752774762	4425.958047410322	11438.203784030999	21.938825143603676	4.558129222756273	-1.638768354922461	15864.16183144132	147	0.017637462223535086	low	494	\N
Container (Max)	437771.95103501575	7721.186248903342	8142.975582537979	53.76068570975283	1.8600953220702467	-1.638768354922461	15864.16183144132	131	0.017637462223535086	low	494	\N
Traditional Housing	586391.964794892	16485.744445374192	-633.7863716209486	100	0	-1.843582037643856	15851.958073753243	112	0.028113864846597225	low	495	Negative cash flow
ODD Cubes Basic	320349.06422449317	4449.883818730102	11402.07425502314	28.095683036212872	3.559265666227398	-1.843582037643856	15851.958073753243	136	0.013890734563256683	low	495	\N
Container (Base)	247477.7716826364	3437.6480367497434	12414.310037003499	19.93487925990056	5.016333367072464	-1.843582037643856	15851.958073753243	61	0.013890734563256683	low	495	\N
Container (Max)	450406.3326215399	6256.47481205571	9595.483261697533	46.939411005950596	2.130405939420987	-1.843582037643856	15851.958073753243	63	0.013890734563256683	low	495	\N
Traditional Housing	590576.4426340358	16256.18506518678	-713.2017385963991	100	0	-1.262711477726116	15542.983326590382	85	0.027525962587810662	low	496	Negative cash flow
ODD Cubes Basic	339235.6208037314	2803.892767544321	12739.09055904606	26.629500687773923	3.7552337602000843	-1.262711477726116	15542.983326590382	74	0.00826532532433127	low	496	\N
Container (Base)	240670.65099201264	1989.221226467575	13553.762100122807	17.75674157581916	5.631663871043681	-1.262711477726116	15542.983326590382	77	0.00826532532433127	low	496	\N
Container (Max)	402548.2002800241	3327.1918340384595	12215.791492551922	32.95310013481004	3.03461585073645	-1.262711477726116	15542.983326590382	51	0.00826532532433127	low	496	\N
Traditional Housing	548457.2714538772	7806.00202376766	7748.378331327171	70.78349146123011	1.4127587935496584	0.17388044287495852	15554.38035509483	129	0.014232652988764522	low	497	\N
ODD Cubes Basic	301361.76996148075	7268.199523250257	8286.180831844573	36.36920024763629	2.749579295643137	0.17388044287495852	15554.38035509483	131	0.024117855175124762	low	497	\N
Container (Base)	268325.33826111496	6471.431647997933	9082.948707096897	29.541655129182978	3.38505068733316	0.17388044287495852	15554.38035509483	56	0.024117855175124762	low	497	\N
Container (Max)	491928.06829332706	11864.249907677346	3690.130447417485	100	0.7501361856053175	0.17388044287495852	15554.38035509483	134	0.024117855175124762	low	497	\N
Traditional Housing	568709.4187080706	11868.896655300237	3767.9241183985305	100	0.6625394260144437	-1.2491172100345462	15636.820773698768	135	0.020869878825398473	low	498	\N
ODD Cubes Basic	335449.882364116	7283.150414984977	8353.67035871379	40.1559874832989	2.4902886535062936	-1.2491172100345462	15636.820773698768	93	0.02171159030868116	low	498	\N
Container (Base)	232339.08426098808	5044.451010168724	10592.369763530045	21.934570775742827	4.559013304723007	-1.2491172100345462	15636.820773698768	112	0.02171159030868116	low	498	\N
Container (Max)	460537.475531698	9999.000990538501	5637.8197831602665	81.68715802290949	1.2241826306645973	-1.2491172100345462	15636.820773698768	67	0.02171159030868116	low	498	\N
Traditional Housing	572171.5405649251	17027.51151639881	-1097.0124139311538	100	0	-2.4464826253744976	15930.499102467655	95	0.029759452033540412	low	499	Negative cash flow
ODD Cubes Basic	316918.09172945085	3218.349776613403	12712.149325854252	24.930331103403244	4.011178174298253	-2.4464826253744976	15930.499102467655	96	0.010155146899473538	low	499	\N
Container (Base)	234700.03696508106	2383.4133526922674	13547.085749775388	17.324762041088608	5.77208505160608	-2.4464826253744976	15930.499102467655	117	0.010155146899473538	low	499	\N
Container (Max)	425274.9217569731	4318.729303104176	11611.76979936348	36.624470610869786	2.730414892886424	-2.4464826253744976	15930.499102467655	81	0.010155146899473538	low	499	\N
\.


--
-- Data for Name: sensitivity_analysis_viable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_analysis_viable (model_name, adjusted_investment, annual_maintenance, annual_net_income, payback_years, annual_roi_percentage, container_price_increase, rental_income, expected_lifespan, maintenance_pct, income_segment, iteration) FROM stdin;
Traditional Housing	517649.01041189744	9172.831876971128	21002.77452629232	24.646696547824128	4.057338873222271	0.7703804702650334	30175.606403263446	83	0.017720176591610272	middle	0
ODD Cubes Basic	296317.56031330064	2812.055973055085	27363.55043020836	10.828914949069507	9.234535543987505	0.7703804702650334	30175.606403263446	124	0.00949000784861302	middle	0
Container (Base)	231645.27719749612	2198.315498698377	27977.29090456507	8.279760824151078	12.077643560465164	0.7703804702650334	30175.606403263446	53	0.00949000784861302	middle	0
Container (Max)	451812.12149269413	4287.700579064167	25887.90582419928	17.452633077425403	5.729794441696468	0.7703804702650334	30175.606403263446	140	0.00949000784861302	middle	0
Traditional Housing	495732.15514430945	10900.489017538046	5043.041579499752	98.30023158236264	1.0172916013551117	-4.840352258163661	15943.530597037798	137	0.02198866646922444	low	1
ODD Cubes Basic	349213.0578026544	6773.10140179286	9170.429195244938	38.08033957491638	2.626027002812503	-4.840352258163661	15943.530597037798	118	0.019395326865527585	low	1
Container (Base)	218772.22496454028	4243.158812285993	11700.371784751806	18.697886613282606	5.348198011264118	-4.840352258163661	15943.530597037798	107	0.019395326865527585	low	1
Container (Max)	448547.2224262026	8699.719993580704	7243.810603457094	61.92144535255165	1.6149493835398532	-4.840352258163661	15943.530597037798	49	0.019395326865527585	low	1
Traditional Housing	503437.0383992262	14674.013700182128	15917.020788914058	31.628848455727454	3.161670591326624	-3.0261476342201954	30591.034489096186	88	0.0291476641187167	middle	2
ODD Cubes Basic	328963.3077274993	3254.6249219107704	27336.409567185416	12.033888609950676	8.309865849789503	-3.0261476342201954	30591.034489096186	90	0.009893580364308527	middle	2
Container (Base)	228693.80811136958	2262.6005693695884	28328.433919726598	8.072942145669334	12.387057679292823	-3.0261476342201954	30591.034489096186	90	0.009893580364308527	middle	2
Container (Max)	430499.66802182194	4259.183062382037	26331.85142671415	16.349008698456807	6.11657879963322	-3.0261476342201954	30591.034489096186	136	0.009893580364308527	middle	2
Traditional Housing	548188.4716893081	7920.630817828205	22114.67367401829	24.788449505061173	4.034136946709093	0.6175415805011255	30035.304491846495	136	0.014448736569413504	middle	3
ODD Cubes Basic	304737.39699500706	5916.688894236539	24118.615597609954	12.634945640296417	7.914557200869286	0.6175415805011255	30035.304491846495	137	0.019415696769023334	middle	3
Container (Base)	241562.1149276532	4690.09677431928	25345.207717527213	9.53087927389932	10.492211382202045	0.6175415805011255	30035.304491846495	47	0.019415696769023334	middle	3
Container (Max)	436521.02058409154	8475.359768965314	21559.94472288118	20.246852494052067	4.939039291631975	0.6175415805011255	30035.304491846495	65	0.019415696769023334	middle	3
Traditional Housing	550109.932322854	8262.83762883622	22468.992126310157	24.483071124436442	4.084454907300843	1.7165564757741567	30731.829755146377	100	0.01502033892379686	middle	4
ODD Cubes Basic	345067.26446911815	8390.564321831576	22341.265433314802	15.445287353981367	6.474466787710671	1.7165564757741567	30731.829755146377	59	0.024315735468968227	middle	4
Container (Base)	250884.6823694555	6100.445569711796	24631.38418543458	10.185569778811399	9.81781109663847	1.7165564757741567	30731.829755146377	131	0.024315735468968227	middle	4
Container (Max)	425742.3231065597	10352.237706603104	20379.592048543273	20.89062048408332	4.786837235217142	1.7165564757741567	30731.829755146377	99	0.024315735468968227	middle	4
Traditional Housing	534893.6386266353	10225.972816259393	5469.376381177379	97.79792088682149	1.0225166250285311	2.5504202293387586	15695.349197436772	82	0.01911776861380341	low	5
ODD Cubes Basic	316589.56356190424	4427.276086784267	11268.073110652505	28.09615809668556	3.5592054848166863	2.5504202293387586	15695.349197436772	98	0.013984276793503905	low	5
Container (Base)	280851.1389154173	3927.500064364012	11767.84913307276	23.865970385879933	4.190066374135955	2.5504202293387586	15695.349197436772	41	0.013984276793503905	low	5
Container (Max)	416637.79320278665	5826.378222782409	9868.970974654363	42.216943820465374	2.368717177284712	2.5504202293387586	15695.349197436772	117	0.013984276793503905	low	5
Traditional Housing	506742.4832243047	10044.241395331901	5696.19076226658	88.96164197679819	1.1240799717487306	-4.630705080392298	15740.432157598481	99	0.019821194645892586	low	6
ODD Cubes Basic	334660.34908505995	5835.723950667222	9904.70820693126	33.78800688453058	2.9596300350519864	-4.630705080392298	15740.432157598481	80	0.017437751339893476	low	6
Container (Base)	219146.10393637407	3821.4152675489418	11919.01689004954	18.386256681901827	5.438844987867115	-4.630705080392298	15740.432157598481	60	0.017437751339893476	low	6
Container (Max)	416692.2147942313	7266.175226851286	8474.256930747195	49.17153423592156	2.033696966220477	-4.630705080392298	15740.432157598481	77	0.017437751339893476	low	6
Traditional Housing	587211.294877589	17105.13770378095	13019.585826469935	45.10214861702728	2.2171892707179652	-3.6024523364870653	30124.723530250885	90	0.029129442592460204	middle	7
ODD Cubes Basic	302975.2856478367	6481.420165875131	23643.303364375755	12.814422797803322	7.80370693068924	-3.6024523364870653	30124.723530250885	138	0.021392570526062013	middle	7
Container (Base)	233143.45758450468	4987.537859066464	25137.185671184423	9.274843279363793	10.781853341122922	-3.6024523364870653	30124.723530250885	62	0.021392570526062013	middle	7
Container (Max)	418858.72617453034	8960.464840145138	21164.258690105748	19.79085269687929	5.052839386539845	-3.6024523364870653	30124.723530250885	128	0.021392570526062013	middle	7
Traditional Housing	580020.8311786394	9677.997190155229	6147.985648140622	94.34323116125996	1.059959456222895	-0.9383515991140134	15825.982838295851	148	0.016685602774798483	low	8
ODD Cubes Basic	318893.39006097766	7915.543165757523	7910.4396725383285	40.31297920999757	2.480590667315407	-0.9383515991140134	15825.982838295851	102	0.024821910432963005	low	8
Container (Base)	260066.5567392118	6455.348777989807	9370.634060306045	27.753357463915098	3.603167657463424	-0.9383515991140134	15825.982838295851	144	0.024821910432963005	low	8
Container (Max)	439730.25115442974	10914.944908819582	4911.03792947627	89.53916818991543	1.1168296737791534	-0.9383515991140134	15825.982838295851	89	0.024821910432963005	low	8
Traditional Housing	534490.530359727	9074.092311923418	21069.350777912463	25.368153769600106	3.9419502462900895	-4.005383522945508	30143.44308983588	119	0.01697708714468019	middle	9
ODD Cubes Basic	324738.18381558324	5388.65343686842	24754.78965296746	13.11819604884647	7.622999353542468	-4.005383522945508	30143.44308983588	144	0.01659383991606174	middle	9
Container (Base)	252952.77786123136	4197.4579021524	25945.98518768348	9.749206901625291	10.257244615798337	-4.005383522945508	30143.44308983588	115	0.01659383991606174	middle	9
Container (Max)	451216.5320851143	7487.414900900922	22656.028188934957	19.915959157637577	5.021098868926479	-4.005383522945508	30143.44308983588	101	0.01659383991606174	middle	9
Traditional Housing	558050.1181461299	6351.37083003797	23841.39388704153	23.406773982684204	4.272267509994231	-3.597336392017482	30192.7647170795	113	0.011381362754903698	middle	10
ODD Cubes Basic	307509.57970219775	6428.78075709356	23763.98395998594	12.940152636863658	7.727884114374503	-3.597336392017482	30192.7647170795	124	0.02090595279444432	middle	10
Container (Base)	255754.73906808492	5346.796501912808	24845.968215166693	10.293611295532644	9.714763568292044	-3.597336392017482	30192.7647170795	72	0.02090595279444432	middle	10
Container (Max)	460428.8201998245	9625.703180299224	20567.061536780275	22.38670893148422	4.466936176552597	-3.597336392017482	30192.7647170795	143	0.02090595279444432	middle	10
Traditional Housing	534893.3448299464	15732.481047867715	15234.13776204012	35.11149453845524	2.848070163760098	2.98508452175943	30966.618809907835	83	0.029412370148051467	middle	11
ODD Cubes Basic	308153.18477182876	5774.8786939379515	25191.740115969886	12.23231040623828	8.175070504178967	2.98508452175943	30966.618809907835	83	0.01874028560897057	middle	11
Container (Base)	264596.73640429304	4958.618411417952	26008.000398489883	10.173667038995296	9.829297500763849	2.98508452175943	30966.618809907835	49	0.01874028560897057	middle	11
Container (Max)	432169.8982254792	8098.987324345224	22867.63148556261	18.898760831366726	5.291352215750972	2.98508452175943	30966.618809907835	102	0.01874028560897057	middle	11
Traditional Housing	538758.7313028405	14033.374328467222	1552.8932270204023	100	0.2882353708245535	-1.545113032750145	15586.267555487624	139	0.02604760445279717	low	12
ODD Cubes Basic	307074.4362670338	3581.4429614532487	12004.824594034375	25.579252229943453	3.909418426350185	-1.545113032750145	15586.267555487624	63	0.011663110107735585	low	12
Container (Base)	255251.4943054113	2977.026283248055	12609.24127223957	20.243208040389508	4.939928483690862	-1.545113032750145	15586.267555487624	98	0.011663110107735585	low	12
Container (Max)	444868.55167710275	5188.550901678907	10397.716653808717	42.7852158785406	2.3372559410213496	-1.545113032750145	15586.267555487624	55	0.011663110107735585	low	12
Traditional Housing	572212.7041182733	12753.043111232755	17525.416287812324	32.650448623934054	3.0627450529637166	0.4630598243594761	30278.459399045078	122	0.02228724217314261	middle	13
ODD Cubes Basic	316255.8025691777	6793.453456758787	23485.00594228629	13.466285822808263	7.425952583794629	0.4630598243594761	30278.459399045078	98	0.02148088162041798	middle	13
Container (Base)	258907.34498071086	5561.558028187369	24716.901370857708	10.474911118348102	9.546620383712625	0.4630598243594761	30278.459399045078	126	0.02148088162041798	middle	13
Container (Max)	492903.52128746524	10588.002191063215	19690.45720798186	25.032609252346788	3.9947893162845207	0.4630598243594761	30278.459399045078	123	0.02148088162041798	middle	13
Traditional Housing	597378.5371539098	14901.185978514553	704.066583195814	100	0.11785937046720794	-2.4030417521358824	15605.252561710367	113	0.02494429419829555	low	14
ODD Cubes Basic	347675.6319001927	3280.303746730271	12324.948814980096	28.209093369833532	3.5449561844812356	-2.4030417521358824	15605.252561710367	84	0.009434954439579327	low	14
Container (Base)	248282.19885097552	2342.5312343175287	13262.72132739284	18.72030578959487	5.34179308414834	-2.4030417521358824	15605.252561710367	110	0.009434954439579327	low	14
Container (Max)	448300.312583678	4229.6930244761725	11375.559537234196	39.40907795491841	2.5374864165660997	-2.4030417521358824	15605.252561710367	82	0.009434954439579327	low	14
Traditional Housing	590313.2131821362	16782.34258444059	13464.856235664447	43.84103349121322	2.2809681259006442	-2.707748116580664	30247.198820105037	120	0.028429556055460575	middle	15
ODD Cubes Basic	309431.3317024648	6420.644310847338	23826.5545092577	12.986826592247596	7.700110515042556	-2.707748116580664	30247.198820105037	111	0.020749819598169003	middle	15
Container (Base)	266682.24414488295	5533.608456041183	24713.590364063853	10.790914643170053	9.267055046468514	-2.707748116580664	30247.198820105037	99	0.020749819598169003	middle	15
Container (Max)	435959.1073042967	9046.07282874296	21201.125991362078	20.563016675714223	4.863099688972394	-2.707748116580664	30247.198820105037	54	0.020749819598169003	middle	15
Traditional Housing	503079.13947024866	9782.442610894475	20306.341427599116	24.774484427140322	4.0364109410265065	0.14387375309400596	30088.78403849359	113	0.01944513664628504	middle	16
ODD Cubes Basic	327460.2697344112	4717.110803391175	25371.67323510242	12.906530314341301	7.7480157381169565	0.14387375309400596	30088.78403849359	85	0.014405139308096882	middle	16
Container (Base)	259897.44114111445	3743.8588454556634	26344.92519303793	9.865180456454533	10.136662014588143	0.14387375309400596	30088.78403849359	72	0.014405139308096882	middle	16
Container (Max)	425922.8692552474	6135.478266126173	23953.305772367417	17.781381547201427	5.623859975927393	0.14387375309400596	30088.78403849359	58	0.014405139308096882	middle	16
Traditional Housing	601117.0171990747	8904.526125616687	6667.636584086518	90.15443622613532	1.1092077571110195	-2.5966675663693684	15572.162709703205	138	0.014813299026381968	low	17
ODD Cubes Basic	329664.5569595979	2655.811924422522	12916.350785280683	25.523041487482644	3.9180283450561078	-2.5966675663693684	15572.162709703205	69	0.008056103904272626	low	17
Container (Base)	259960.18845513114	2094.2662891688296	13477.896420534376	19.287890360922074	5.18460018844795	-2.5966675663693684	15572.162709703205	131	0.008056103904272626	low	17
Container (Max)	447202.1133017486	3602.7066909691857	11969.45601873402	37.36194131143548	2.676520450755933	-2.5966675663693684	15572.162709703205	99	0.008056103904272626	low	17
Traditional Housing	495968.9006739617	9371.763313545967	20741.34995920893	23.912083912057856	4.18198599368306	4.127169113187204	30113.113272754897	99	0.018895868875671188	middle	18
ODD Cubes Basic	320220.52152859815	5964.941557156659	24148.17171559824	13.260652827052546	7.541106859836784	4.127169113187204	30113.113272754897	121	0.018627605528473114	middle	18
Container (Base)	258461.243194314	4814.514082622438	25298.59919013246	10.216425077603704	9.788159678204709	4.127169113187204	30113.113272754897	75	0.018627605528473114	middle	18
Container (Max)	494703.4826877472	9215.141329069183	20897.971943685712	23.672320166800734	4.2243430004062335	4.127169113187204	30113.113272754897	105	0.018627605528473114	middle	18
Traditional Housing	509635.5524860908	8641.478660865983	21559.292116697216	23.638788775044652	4.23033518982874	3.3595403254472664	30200.7707775632	84	0.016956192751293248	middle	19
ODD Cubes Basic	335898.98512398975	7473.5553907521025	22727.215386811098	14.77959263407678	6.766086351354067	3.3595403254472664	30200.7707775632	101	0.022249413430032852	middle	19
Container (Base)	238318.8325795497	5302.454234225183	24898.316543338016	9.571684582157667	10.44748175116504	3.3595403254472664	30200.7707775632	106	0.022249413430032852	middle	19
Container (Max)	501864.44288514875	11166.189475584784	19034.58130197842	26.365930246807473	3.7927734414797873	3.3595403254472664	30200.7707775632	52	0.022249413430032852	middle	19
Traditional Housing	517573.35253230965	6679.690677939935	9182.599615582163	56.36457802799412	1.7741639075224487	1.8454179749420039	15862.2902935221	84	0.012905785518629368	low	20
ODD Cubes Basic	320412.3403587035	7370.141469047161	8492.148824474938	37.73041982439754	2.650381322694353	1.8454179749420039	15862.2902935221	45	0.023002052482735978	low	20
Container (Base)	240289.36546528453	5527.148595475801	10335.141698046298	23.249740785915648	4.3011232220093625	1.8454179749420039	15862.2902935221	48	0.023002052482735978	low	20
Container (Max)	445405.4419336295	10245.239351453558	5617.050942068541	79.29524701259056	1.2611096347820432	1.8454179749420039	15862.2902935221	66	0.023002052482735978	low	20
Traditional Housing	498238.6160149148	10184.426716983131	20034.138848097813	24.86948003069377	4.0209927942434085	2.204667047720621	30218.565565080942	140	0.020440861847364836	middle	21
ODD Cubes Basic	312917.5220636433	5482.744085525597	24735.821479555343	12.65037922117428	7.904901367116285	2.204667047720621	30218.565565080942	50	0.017521371284572804	middle	21
Container (Base)	268829.64987064	4710.264107685193	25508.301457395748	10.538908296957455	9.488648841253285	2.204667047720621	30218.565565080942	104	0.017521371284572804	middle	21
Container (Max)	472973.7465454238	8287.148621077804	21931.41694400314	21.56603687545835	4.636920569944758	2.204667047720621	30218.565565080942	114	0.017521371284572804	middle	21
Traditional Housing	519751.28516189626	9207.944092001448	6625.641754152448	78.4454252806765	1.2747715962046424	2.814927422170671	15833.585846153896	92	0.017716058343431096	low	22
ODD Cubes Basic	346011.53249800095	6673.159153254739	9160.426692899156	37.77242524807464	2.6474339241719003	2.814927422170671	15833.585846153896	85	0.019285944329885285	low	22
Container (Base)	272658.6353961233	5258.479263312123	10575.106582841772	25.783062634897217	3.8785151871232943	2.814927422170671	15833.585846153896	102	0.019285944329885285	low	22
Container (Max)	430195.48961645464	8296.726263710687	7536.859582443209	57.078878133616364	1.7519615533772275	2.814927422170671	15833.585846153896	80	0.019285944329885285	low	22
Traditional Housing	518211.0969715355	12582.851598192974	17982.756983789575	28.817110604267913	3.470160536677457	3.0314927865949066	30565.60858198255	142	0.024281324100792326	middle	23
ODD Cubes Basic	318629.7011286422	5966.561648775494	24599.046933207057	12.952928704669185	7.720261747750736	3.0314927865949066	30565.60858198255	57	0.018725692010634565	middle	23
Container (Base)	243628.75202432706	4562.11697534281	26003.491606639738	9.369078418765842	10.673408368501274	3.0314927865949066	30565.60858198255	126	0.018725692010634565	middle	23
Container (Max)	507480.3103330713	9502.919992758343	21062.688589224206	24.093804937737204	4.15044449220114	3.0314927865949066	30565.60858198255	51	0.018725692010634565	middle	23
Traditional Housing	561795.6350610123	6213.986503449943	9565.590638185404	58.73088827556028	1.702681552010734	2.0286320198048893	15779.577141635347	81	0.011060937671356397	low	24
ODD Cubes Basic	317196.4492983958	5085.704054839206	10693.873086796142	29.661512412190692	3.3713722554113805	2.0286320198048893	15779.577141635347	137	0.016033294401902144	low	24
Container (Base)	245647.88467003507	3938.5448541191768	11841.032287516171	20.7454788320287	4.820327398064739	2.0286320198048893	15779.577141635347	84	0.016033294401902144	low	24
Container (Max)	435626.83795194613	6984.53334225327	8795.043799382078	49.53094582457366	2.018939843268393	2.0286320198048893	15779.577141635347	134	0.016033294401902144	low	24
Traditional Housing	583740.670137931	14172.159579222796	16448.458513617195	35.48908061230597	2.8177681211985144	-0.0635923545710888	30620.61809283999	110	0.024278177458277976	middle	25
ODD Cubes Basic	335493.80610604835	5787.732557592181	24832.88553524781	13.510061310831086	7.4018909092462435	-0.0635923545710888	30620.61809283999	129	0.01725138423498257	middle	25
Container (Base)	243018.25057961568	4192.401216862226	26428.216875977767	9.195408518102102	10.874992644768286	-0.0635923545710888	30620.61809283999	112	0.01725138423498257	middle	25
Container (Max)	482955.2287448956	8331.646219372093	22288.971873467897	21.667900676916847	4.615121764266326	-0.0635923545710888	30620.61809283999	136	0.01725138423498257	middle	25
Traditional Housing	541711.7056512954	6955.493969582517	23826.359356132274	22.735815302469746	4.398346778843563	-2.215975716343388	30781.85332571479	105	0.012839844324980915	middle	26
ODD Cubes Basic	330020.10920920264	5989.821380354248	24792.03194536054	13.311539366218064	7.512279177401476	-2.215975716343388	30781.85332571479	59	0.018149867881406122	middle	26
Container (Base)	259074.8658802993	4702.174587120443	26079.678738594346	9.933974589069766	10.066464243831346	-2.215975716343388	30781.85332571479	99	0.018149867881406122	middle	26
Container (Max)	402994.08541266096	7314.2894072278905	23467.5639184869	17.17238682346559	5.82330231830981	-2.215975716343388	30781.85332571479	145	0.018149867881406122	middle	26
Traditional Housing	582530.4316677522	17213.09754342119	13757.104697347339	42.3439702236239	2.361611333842511	0.23064797156548522	30970.20224076853	146	0.02954883832273114	middle	27
ODD Cubes Basic	306548.24363817443	3703.704490289755	27266.497750478775	11.24267027043441	8.894684055884532	0.23064797156548522	30970.20224076853	75	0.012081962846478802	middle	27
Container (Base)	256133.38676687217	3094.5940626601346	27875.608178108396	9.18844120387737	10.88323881942039	0.23064797156548522	30970.20224076853	99	0.012081962846478802	middle	27
Container (Max)	461583.5313196784	5576.835075950839	25393.36716481769	18.177326713851432	5.501359004775894	0.23064797156548522	30970.20224076853	43	0.012081962846478802	middle	27
Traditional Housing	504532.1791465531	5217.307054304506	10670.876833575301	47.28122974478269	2.1150042107573275	-3.296532991771264	15888.183887879808	93	0.010340880661229375	low	28
ODD Cubes Basic	315489.88032067224	6877.904875008138	9010.27901287167	35.01444071487441	2.8559645094522157	-3.296532991771264	15888.183887879808	44	0.02180071471077695	low	28
Container (Base)	237847.15340081102	5185.237936061482	10702.945951818325	22.222587544731375	4.499926023408035	-3.296532991771264	15888.183887879808	49	0.02180071471077695	low	28
Container (Max)	393505.6856807379	8578.705190594434	7309.478697285374	53.83498632082747	1.8575281027110133	-3.296532991771264	15888.183887879808	76	0.02180071471077695	low	28
Traditional Housing	538378.4378028224	6826.983486007292	8725.155205067942	61.704167450237364	1.620636079088939	-3.875041924924151	15552.138691075234	119	0.012680640617534595	low	29
ODD Cubes Basic	319843.04461229354	2742.8886106488426	12809.250080426391	24.96969319859252	4.004854973774238	-3.875041924924151	15552.138691075234	95	0.008575733181797683	low	29
Container (Base)	252772.07765798288	2167.7058938035048	13384.43279727173	18.885527798347027	5.295059850471989	-3.875041924924151	15552.138691075234	80	0.008575733181797683	low	29
Container (Max)	400655.26987672254	3435.9126923439153	12116.22599873132	33.06766231652289	3.0241024915158	-3.875041924924151	15552.138691075234	93	0.008575733181797683	low	29
Traditional Housing	555913.3188853199	6657.273985558344	24143.048378998486	23.025813068779534	4.342951960102074	4.75248191808347	30800.32236455683	117	0.011975381339858997	middle	30
ODD Cubes Basic	326115.4540009571	6608.694365691933	24191.627998864897	13.480508794871467	7.418117633515736	4.75248191808347	30800.32236455683	54	0.020264891726574044	middle	30
Container (Base)	286189.76798931434	5799.604661556801	25000.717703000028	11.447262090198803	8.735713327086346	4.75248191808347	30800.32236455683	89	0.020264891726574044	middle	30
Container (Max)	485201.93267625343	9832.564631208745	20967.757733348084	23.140382431287158	4.321449755505947	4.75248191808347	30800.32236455683	117	0.020264891726574044	middle	30
Traditional Housing	571681.573600836	8336.93277968641	21950.981975165734	26.043553506973332	3.839721794233047	-0.2800474402003381	30287.914754852147	97	0.014583175608013369	middle	31
ODD Cubes Basic	322092.5759656739	7021.898425461952	23266.016329390193	13.84390741438614	7.22339416226399	-0.2800474402003381	30287.914754852147	129	0.02180087015172399	middle	31
Container (Base)	237821.08478077507	5184.706588647819	25103.208166204327	9.473732727952527	10.555501497835913	-0.2800474402003381	30287.914754852147	88	0.02180087015172399	middle	31
Container (Max)	460076.90198183316	10030.076799913391	20257.837954938754	22.71105648121096	4.403141706892007	-0.2800474402003381	30287.914754852147	45	0.02180087015172399	middle	31
Traditional Housing	497233.8177145429	6513.312568703581	9438.854272053846	52.67946759033365	1.8982727915486635	3.7271174187297493	15952.166840757427	147	0.013099094101525512	low	32
ODD Cubes Basic	298958.42989025783	5705.527966840355	10246.638873917072	29.176243407119546	3.427446042474342	3.7271174187297493	15952.166840757427	109	0.019084686686823817	low	32
Container (Base)	265569.2482344539	5068.305896209892	10883.860944547534	24.40027942175204	4.09831372303275	3.7271174187297493	15952.166840757427	65	0.019084686686823817	low	32
Container (Max)	472322.09014745767	9014.119105729984	6938.047735027443	68.07708856814163	1.468922982802139	3.7271174187297493	15952.166840757427	52	0.019084686686823817	low	32
Traditional Housing	590242.0273513797	15865.353434626802	14887.09831199425	39.6478893993622	2.522202354650653	3.3946765211958994	30752.451746621053	145	0.02687940319299209	middle	33
ODD Cubes Basic	339595.4805813377	4967.137674269433	25785.31407235162	13.170112244064926	7.592949714233812	3.3946765211958994	30752.451746621053	70	0.014626630677671035	middle	33
Container (Base)	273453.9471207438	3999.7098918865045	26752.741854734548	10.221529763400662	9.783271419710703	3.3946765211958994	30752.451746621053	131	0.014626630677671035	middle	33
Container (Max)	479009.70922152844	7006.29810780189	23746.153638819163	20.17209677437884	4.957342864179239	3.3946765211958994	30752.451746621053	45	0.014626630677671035	middle	33
Traditional Housing	526845.0329605674	6058.5019846298665	9445.377731031047	55.77807981460764	1.7928189771389573	4.064408737972716	15503.879715660914	85	0.011499590212675166	low	34
ODD Cubes Basic	347094.7196792189	7669.316554543329	7834.563161117585	44.30300867339061	2.2571830445470913	4.064408737972716	15503.879715660914	119	0.022095745396620344	low	34
Container (Base)	264953.02953049616	5854.334682569075	9649.54503309184	27.4575670274479	3.6419832791461526	4.064408737972716	15503.879715660914	87	0.022095745396620344	low	34
Container (Max)	451843.6953818083	9983.823252224516	5520.056463436398	81.85490463271861	1.2216738929536122	4.064408737972716	15503.879715660914	104	0.022095745396620344	low	34
Traditional Housing	558859.6009679814	5962.281303952827	9855.641164274919	56.70454023770221	1.7635272163534998	-3.5081453473096715	15817.922468227745	81	0.010668656839080453	low	35
ODD Cubes Basic	316578.29941767664	7044.518273926135	8773.40419430161	36.08386122496175	2.7713220427425584	-3.5081453473096715	15817.922468227745	40	0.02225205671672388	low	35
Container (Base)	257575.0475366449	5731.574566598272	10086.347901629473	25.53699813339108	3.915887038784104	-3.5081453473096715	15817.922468227745	72	0.02225205671672388	low	35
Container (Max)	406152.28278047766	9037.723632058065	6780.19883616968	59.902709727894084	1.6693735634706082	-3.5081453473096715	15817.922468227745	56	0.02225205671672388	low	35
Traditional Housing	501397.6268640795	11619.38439292764	19234.931196218968	26.067035111757498	3.836262911039512	-1.1334558452181631	30854.31558914661	144	0.02317399159944062	middle	36
ODD Cubes Basic	295575.7668193162	6399.131295858348	24455.18429328826	12.08642565414799	8.273744683622043	-1.1334558452181631	30854.31558914661	102	0.021649715620191898	middle	36
Container (Base)	262764.68386715173	5688.780680753461	25165.534908393147	10.441450373443686	9.577213550172637	-1.1334558452181631	30854.31558914661	108	0.021649715620191898	middle	36
Container (Max)	476502.12526958133	10316.13550450349	20538.180084643118	23.200795947147878	4.31019695306157	-1.1334558452181631	30854.31558914661	106	0.021649715620191898	middle	36
Traditional Housing	594255.4806887214	10908.019332146352	19131.78322419108	31.061165272734133	3.2194542323813335	3.423822957982365	30039.802556337432	105	0.018355774051093877	middle	37
ODD Cubes Basic	324159.2839424088	7792.631392377343	22247.17116396009	14.57080909538465	6.863036866749926	3.423822957982365	30039.802556337432	148	0.02403951322203009	middle	37
Container (Base)	240673.5328350133	5785.674574779995	24254.127981557438	9.922992614618785	10.077605001204743	3.423822957982365	30039.802556337432	71	0.02403951322203009	middle	37
Container (Max)	467713.27188598976	11243.599383622206	18796.203172715228	24.883390948068033	4.01874488122223	3.423822957982365	30039.802556337432	112	0.02403951322203009	middle	37
Traditional Housing	522355.86426314927	11942.631526453048	3663.531612758552	100	0.701347847970739	3.055960316833941	15606.1631392116	99	0.02286301799884965	low	38
ODD Cubes Basic	329012.4923233508	6438.971064624097	9167.192074587503	35.89021476220737	2.786274773292821	3.055960316833941	15606.1631392116	95	0.01957059751486861	low	38
Container (Base)	268064.88391798653	5246.18995102889	10359.97318818271	25.875055760159647	3.8647259711019464	3.055960316833941	15606.1631392116	74	0.01957059751486861	low	38
Container (Max)	506523.34368223103	9912.96449109041	5693.19864812119	88.96990514275988	1.1239755717345252	3.055960316833941	15606.1631392116	135	0.01957059751486861	low	38
Traditional Housing	541041.4024417275	10658.167425868452	20065.412260415535	26.963881699509276	3.7086648396703183	3.514567450636573	30723.579686283985	115	0.019699356422203537	middle	39
ODD Cubes Basic	331849.9562488769	5267.599428792449	25455.980257491537	13.036227750499432	7.670930725812833	3.514567450636573	30723.579686283985	122	0.015873437165204618	middle	39
Container (Base)	243085.88423659277	3858.608509177759	26864.971177106225	9.048432720588421	11.051637680022115	3.514567450636573	30723.579686283985	108	0.015873437165204618	middle	39
Container (Max)	424276.09284855844	6734.719900530113	23988.859785753873	17.686380121347863	5.654068232950491	3.514567450636573	30723.579686283985	80	0.015873437165204618	middle	39
Traditional Housing	528636.1046272902	14024.526079988143	16408.35381942813	32.21749789435699	3.1039033610836477	-3.1132830161656146	30432.87989941627	147	0.026529641008678363	middle	40
ODD Cubes Basic	295080.74564342335	3243.669656180165	27189.210243236106	10.852861962654137	9.214159393541605	-3.1132830161656146	30432.87989941627	147	0.010992481563333947	middle	40
Container (Base)	229128.46011587355	2518.6903734588377	27914.189525957434	8.208314982701065	12.182768352670301	-3.1132830161656146	30432.87989941627	41	0.010992481563333947	middle	40
Container (Max)	404894.81132071273	4450.798748532512	25982.081150883758	15.583617377276207	6.416995334203884	-3.1132830161656146	30432.87989941627	126	0.010992481563333947	middle	40
Traditional Housing	546568.8422040304	9444.821964804363	20662.508730339174	26.452201392248774	3.780403699379922	-1.398476773148781	30107.330695143537	100	0.01728020559444674	middle	41
ODD Cubes Basic	347942.26614512596	5528.262303632777	24579.06839151076	14.156039627006368	7.064122638454876	-1.398476773148781	30107.330695143537	116	0.015888447140615422	middle	41
Container (Base)	224492.70694884722	3566.8405078104274	26540.49018733311	8.458498895999671	11.822428687351795	-1.398476773148781	30107.330695143537	66	0.015888447140615422	middle	41
Container (Max)	440448.0961983402	6998.036294632025	23109.294400511513	19.059348527257114	5.246769051785176	-1.398476773148781	30107.330695143537	59	0.015888447140615422	middle	41
Traditional Housing	530158.9257367243	14682.074561047419	1189.9581339914894	100	0.22445309816068623	1.4442109349716041	15872.032695038908	116	0.02769372323713079	low	42
ODD Cubes Basic	348524.05010359397	6793.502789121524	9078.529905917385	38.38992146475456	2.604850340519949	1.4442109349716041	15872.032695038908	127	0.01949220659837463	low	42
Container (Base)	252030.86923241985	4912.637772246268	10959.39492279264	22.99678686715289	4.34843356933631	1.4442109349716041	15872.032695038908	59	0.01949220659837463	low	42
Container (Max)	429594.9358921149	8373.753244024607	7498.279451014301	57.29246805198799	1.745430130698133	1.4442109349716041	15872.032695038908	122	0.01949220659837463	low	42
Traditional Housing	589979.4519620815	14360.565682901857	1453.6034970243782	100	0.2463820548648197	-0.06199242535041005	15814.169179926235	119	0.024340789556557003	low	43
ODD Cubes Basic	299665.0988263299	4096.456991017462	11717.712188908772	25.5736865691217	3.910269242164814	-0.06199242535041005	15814.169179926235	74	0.013670117097592176	low	43
Container (Base)	237240.81756702557	3243.1097564697425	12571.059423456492	18.871982827823967	5.298860268808887	-0.06199242535041005	15814.169179926235	99	0.013670117097592176	low	43
Container (Max)	412273.34490844357	5635.824901114431	10178.344278811805	40.504951848275596	2.4688339434294937	-0.06199242535041005	15814.169179926235	140	0.013670117097592176	low	43
Traditional Housing	573764.5880243147	11590.759203982017	18473.530925681785	31.058739681793632	3.219705661740652	-2.353096012872926	30064.290129663805	132	0.020201245329366388	middle	44
ODD Cubes Basic	320245.22710132494	6186.971486598014	23877.31864306579	13.412110123777541	7.455948324098224	-2.353096012872926	30064.290129663805	83	0.01931948070732829	middle	44
Container (Base)	249323.56529514687	4816.801809601895	25247.488320061908	9.875182914612218	10.126394707284959	-2.353096012872926	30064.290129663805	123	0.01931948070732829	middle	44
Container (Max)	404345.54535064567	7811.745962495935	22252.54416716787	18.1707557712538	5.503348416481408	-2.353096012872926	30064.290129663805	86	0.01931948070732829	middle	44
Traditional Housing	546305.2373621521	5604.235731831557	10069.506700190785	54.25342607416919	1.8432015678289373	2.7626376270426976	15673.742432022342	149	0.010258433103976347	low	45
ODD Cubes Basic	329891.83035050635	8166.641664217183	7507.100767805159	43.943972587297026	2.275624940402116	2.7626376270426976	15673.742432022342	131	0.024755513513445356	low	45
Container (Base)	258822.62774644908	6407.287058762658	9266.455373259683	27.931136267416395	3.5802338666993982	2.7626376270426976	15673.742432022342	145	0.024755513513445356	low	45
Container (Max)	458438.38964151795	11348.877749852725	4324.864682169617	100	0.9433906016360242	2.7626376270426976	15673.742432022342	108	0.024755513513445356	low	45
Traditional Housing	515960.249491754	11601.93560270868	3862.4054740447737	100	0.7485858606063998	-3.2942424439039444	15464.341076753453	149	0.02248610355960009	low	46
ODD Cubes Basic	336224.98105041427	4380.023743376242	11084.31733337721	30.33339545755968	3.2966965448992633	-3.2942424439039444	15464.341076753453	44	0.013027062206063424	low	46
Container (Base)	240376.3396335402	3131.397529271957	12332.943547481496	19.49058946942373	5.130681150350895	-3.2942424439039444	15464.341076753453	99	0.013027062206063424	low	46
Container (Max)	468017.90997845004	6096.89842684106	9367.442649912393	49.96218578213843	2.0015137135123138	-3.2942424439039444	15464.341076753453	120	0.013027062206063424	low	46
Traditional Housing	583273.6038102169	6416.349909470337	9341.438557927968	62.439376996726004	1.6015534556862006	4.190032119713871	15757.788467398304	124	0.011000583375547476	low	47
ODD Cubes Basic	339612.3396021584	5179.53577576501	10578.252691633294	32.104767157885114	3.1148022195027636	4.190032119713871	15757.788467398304	123	0.015251317963983931	low	47
Container (Base)	264766.73673731816	4038.041688267265	11719.74677913104	22.591506602239857	4.4264422803074766	4.190032119713871	15757.788467398304	108	0.015251317963983931	low	47
Container (Max)	503234.2677353234	7674.985827604037	8082.802639794268	62.25987323477841	1.6061709541698828	4.190032119713871	15757.788467398304	98	0.015251317963983931	low	47
Traditional Housing	495671.7046127075	12569.271288719157	17761.097608301796	27.907718066986092	3.5832381479550883	-3.5913191947114975	30330.36889702095	86	0.025358056898850304	middle	48
ODD Cubes Basic	302925.2408941967	4601.679161763349	25728.6897352576	11.773830848411983	8.493412321571418	-3.5913191947114975	30330.36889702095	135	0.015190807963640729	middle	48
Container (Base)	246583.4082504908	3745.8012017532283	26584.567695267724	9.27543419464311	10.781166455555637	-3.5913191947114975	30330.36889702095	134	0.015190807963640729	middle	48
Container (Max)	424372.82654429576	6446.566113021814	23883.802783999137	17.7682268766933	5.628023589183828	-3.5913191947114975	30330.36889702095	143	0.015190807963640729	middle	48
Traditional Housing	561341.5871853097	7106.404713049487	8769.543388584687	64.01035519318006	1.5622472285648936	-0.9260363253910997	15875.948101634174	97	0.01265967973027362	low	49
ODD Cubes Basic	343493.7826875886	7529.43490356006	8346.513198074113	41.154165162866676	2.429887706487357	-0.9260363253910997	15875.948101634174	46	0.02192014901884895	low	49
Container (Base)	233970.85642984198	5128.676039009849	10747.272062624324	21.77025528585249	4.59342339751916	-0.9260363253910997	15875.948101634174	99	0.02192014901884895	low	49
Container (Max)	481575.91034178674	10556.215718579806	5319.732383054368	90.52634148962319	1.104650849183635	-0.9260363253910997	15875.948101634174	142	0.02192014901884895	low	49
Traditional Housing	527172.2641022946	9592.15081121057	6113.653506065266	86.22867874001932	1.1597069729144454	-2.524122320339673	15705.804317275835	98	0.018195477008914246	low	50
ODD Cubes Basic	302097.3612590788	4648.328773348617	11057.47554392722	27.32064475828672	3.66023572594013	-2.524122320339673	15705.804317275835	123	0.015386856588138844	low	50
Container (Base)	245785.10579609039	3781.8601743849763	11923.94414289086	20.612735421326946	4.851369697227817	-2.524122320339673	15705.804317275835	119	0.015386856588138844	low	50
Container (Max)	429342.85570228175	6606.236947832999	9099.567369442837	47.18277674871155	2.119417441931939	-2.524122320339673	15705.804317275835	145	0.015386856588138844	low	50
Traditional Housing	521241.3762529856	15447.709030836038	402.2431483434866	100	0.07717022605439845	4.902911279763263	15849.952179179525	135	0.02963638294005743	low	51
ODD Cubes Basic	301486.2850305877	5780.14593391081	10069.806245268715	29.939631179322898	3.3400545050489012	4.902911279763263	15849.952179179525	133	0.01917216875495473	low	51
Container (Base)	256863.72605632708	4924.634702978366	10925.317476201159	23.51087065578264	4.25335162887319	4.902911279763263	15849.952179179525	111	0.01917216875495473	low	51
Container (Max)	450379.0484105746	8634.743119823463	7215.209059356062	62.42078984898737	1.602030353059082	4.902911279763263	15849.952179179525	141	0.01917216875495473	low	51
Traditional Housing	509054.57961678866	13436.202003796028	16659.665315594564	30.556110820562488	3.272667800795702	2.956489380688873	30095.867319390592	133	0.026394423195074034	middle	52
ODD Cubes Basic	349349.28935974673	8172.7891452657095	21923.078174124883	15.935229833375892	6.275403683889944	2.956489380688873	30095.867319390592	42	0.023394320223876795	middle	52
Container (Base)	243959.72872471236	5707.272015516035	24388.595303874557	10.003025007592589	9.99697590719778	2.956489380688873	30095.867319390592	55	0.023394320223876795	middle	52
Container (Max)	505293.5435203373	11820.998964172197	18274.868355218394	27.649640681326748	3.6166835277369533	2.956489380688873	30095.867319390592	115	0.023394320223876795	middle	52
Traditional Housing	507146.40202112315	12177.719909804164	18487.019133051886	27.432567596277597	3.6453022360753895	-2.8415142699588114	30664.73904285605	144	0.024012237612792822	middle	53
ODD Cubes Basic	354200.0236705107	8555.3440518566	22109.394990999448	16.020339942124266	6.242064797704923	-2.8415142699588114	30664.73904285605	132	0.024153990627101374	middle	53
Container (Base)	250683.8829887821	6055.01616007642	24609.722882779628	10.186375693169438	9.817034341964813	-2.8415142699588114	30664.73904285605	69	0.024153990627101374	middle	53
Container (Max)	442051.911520906	10677.31772756821	19987.42131528784	22.11650540346555	4.52150998431834	-2.8415142699588114	30664.73904285605	47	0.024153990627101374	middle	53
Traditional Housing	601089.3594575019	13744.631816212319	1876.6671760321387	100	0.31221101263976414	-0.5624442394412865	15621.298992244458	145	0.02286620383467974	low	54
ODD Cubes Basic	316110.0357318111	3776.666327779397	11844.632664465062	26.688040455671448	3.746996718102962	-0.5624442394412865	15621.298992244458	65	0.011947315494227253	low	54
Container (Base)	230558.67055602872	2754.557177062479	12866.741815181978	17.918963003048948	5.580680086397009	-0.5624442394412865	15621.298992244458	143	0.011947315494227253	low	54
Container (Max)	470913.15223691205	5626.148000155456	9995.150992089002	47.11416091759215	2.1225041060353598	-0.5624442394412865	15621.298992244458	123	0.011947315494227253	low	54
Traditional Housing	510310.8517780974	12057.433885459024	18117.241966515772	28.167137841469042	3.550236469279285	-0.04387024593997246	30174.675851974796	118	0.023627625874399504	middle	55
ODD Cubes Basic	320848.5076366563	4333.749703891045	25840.926148083752	12.416292891284355	8.053933720442052	-0.04387024593997246	30174.675851974796	98	0.013507152443416642	middle	55
Container (Base)	226644.42677438035	3061.320822892336	27113.35502908246	8.35914354867835	11.96294804816587	-0.04387024593997246	30174.675851974796	96	0.013507152443416642	middle	55
Container (Max)	419275.80810954684	5663.222255972352	24511.453596002444	17.10530166917258	5.846140683985798	-0.04387024593997246	30174.675851974796	53	0.013507152443416642	middle	55
Traditional Housing	553028.881108884	9778.551305170175	21178.79129989964	26.11239108397582	3.829599506165722	0.5019629189193662	30957.342605069814	138	0.017681809466375605	middle	56
ODD Cubes Basic	310070.51689482003	5644.913317846874	25312.42928722294	12.249733653629823	8.163442800274122	0.5019629189193662	30957.342605069814	79	0.01820525657962412	middle	56
Container (Base)	228454.75730478487	4159.077473569366	26798.265131500448	8.524983098112724	11.730228535249317	0.5019629189193662	30957.342605069814	80	0.01820525657962412	middle	56
Container (Max)	480969.0149806278	8756.164324571406	22201.17828049841	21.664121106721286	4.615926928555391	0.5019629189193662	30957.342605069814	67	0.01820525657962412	middle	56
ODD Cubes Basic	335488.564124315	6970.420190259284	8567.892722628902	39.15648514578699	2.5538553735781218	3.4570251762184423	15538.312912888185	100	0.02077692337577385	low	57
Container (Base)	256826.54935872965	5336.065536890726	10202.247375997458	25.173526958673662	3.972427072462506	3.4570251762184423	15538.312912888185	67	0.02077692337577385	low	57
Container (Max)	446000.6601911842	9266.521542336784	6271.7913705514	71.11216458591686	1.4062291674328269	3.4570251762184423	15538.312912888185	141	0.02077692337577385	low	57
Traditional Housing	564322.6401444223	13379.127182939392	2282.6205718406745	100	0.4044885690314503	0.5406364095337857	15661.747754780066	89	0.023708294211827803	low	58
ODD Cubes Basic	326400.23665386287	7925.584901762656	7736.16285301741	42.19148987104813	2.3701462144530754	0.5406364095337857	15661.747754780066	51	0.024281798882907945	low	58
Container (Base)	269185.4634110731	6536.307284750052	9125.440470030015	29.498352906376223	3.390019785761817	0.5406364095337857	15661.747754780066	134	0.024281798882907945	low	58
Container (Max)	424669.67272997036	10311.743584899477	5350.004169880589	79.3774470533635	1.2598036811737279	0.5406364095337857	15661.747754780066	88	0.024281798882907945	low	58
Traditional Housing	593202.310502782	8331.585549253461	7246.581091098478	81.85961118015462	1.2216036523789793	-4.833606734647465	15578.16664035194	129	0.014045099625778325	low	59
ODD Cubes Basic	323938.84334413044	4553.78795071073	11024.37868964121	29.383863931353496	3.403228392073273	-4.833606734647465	15578.16664035194	130	0.014057554517699803	low	59
Container (Base)	231763.03289132292	3258.0214700572246	12320.145170294714	18.811712823817224	5.315837049850746	-4.833606734647465	15578.16664035194	144	0.014057554517699803	low	59
Container (Max)	416430.173567603	5853.9898677417705	9724.176772610168	42.82420849655375	2.3351278052937614	-4.833606734647465	15578.16664035194	89	0.014057554517699803	low	59
Traditional Housing	526400.5705382652	9751.946847158777	6242.00061709882	84.33202795531403	1.1857891055695724	-4.7856751806498385	15993.947464257597	146	0.018525714812936144	low	60
ODD Cubes Basic	312233.95571919036	4233.880698865843	11760.066765391754	26.55035570359614	3.7664278820360733	-4.7856751806498385	15993.947464257597	53	0.013559962397791264	low	60
Container (Base)	229935.63142906572	3117.918516090522	12876.028948167075	17.85765101606093	5.599840645898016	-4.7856751806498385	15993.947464257597	103	0.013559962397791264	low	60
Container (Max)	435883.99195693136	5910.570540735139	10083.376923522457	43.22797761731024	2.3133166414881257	-4.7856751806498385	15993.947464257597	119	0.013559962397791264	low	60
Traditional Housing	499843.76748577395	11707.637723428263	4144.711554454272	100	0.829201407332189	1.8243825146262527	15852.349277882535	129	0.02342259418841603	low	61
ODD Cubes Basic	310517.4180697191	3900.534350821708	11951.814927060826	25.980775301888073	3.848999840768139	1.8243825146262527	15852.349277882535	80	0.012561402755016913	low	61
Container (Base)	235762.52811067304	2961.5080701391607	12890.841207743375	18.289149971768584	5.467722674610989	1.8243825146262527	15852.349277882535	75	0.012561402755016913	low	61
Container (Max)	461060.69148224447	5791.5690402150685	10060.780237667466	45.82752834179178	2.182094553609307	1.8243825146262527	15852.349277882535	138	0.012561402755016913	low	61
Traditional Housing	577371.2692807734	7061.035417346646	8858.300869195124	65.1785571303624	1.5342469119098767	-1.282400116397465	15919.33628654177	125	0.012229627265905558	low	62
ODD Cubes Basic	313974.5641246735	4502.540270678991	11416.79601586278	27.501110091520374	3.63621685332745	-1.282400116397465	15919.33628654177	149	0.014340461888151919	low	62
Container (Base)	247518.92642843028	3549.535731043183	12369.800555498587	20.00993672597283	4.997517052125424	-1.282400116397465	15919.33628654177	109	0.014340461888151919	low	62
Container (Max)	443504.3336299117	6360.056993649962	9559.279292891806	46.395164325797815	2.1553970430576848	-1.282400116397465	15919.33628654177	70	0.014340461888151919	low	62
Traditional Housing	527854.0351348051	13888.331978129123	2040.4997163233475	100	0.3865651450030571	-0.056996428234565855	15928.83169445247	109	0.02631093267020735	low	63
ODD Cubes Basic	353865.6077719367	3058.9621997059594	12869.869494746512	27.495664032676075	3.636937077830132	-0.056996428234565855	15928.83169445247	107	0.008644417916073477	low	63
Container (Base)	263563.3695098809	2278.3519134119083	13650.479781040562	19.307993106289906	5.179202180646279	-0.056996428234565855	15928.83169445247	66	0.008644417916073477	low	63
Container (Max)	447969.1574157708	3872.432610213229	12056.399084239241	37.15613213246894	2.691345795721693	-0.056996428234565855	15928.83169445247	135	0.008644417916073477	low	63
Traditional Housing	516756.8734605064	7511.575308724581	8193.165732209482	63.07169784555922	1.5854971947142666	-4.71010111472284	15704.741040934063	92	0.014535994961078462	low	64
ODD Cubes Basic	343896.124318796	6679.200755518695	9025.540285415369	38.10255269421462	2.6244960751719844	-4.71010111472284	15704.741040934063	105	0.01942214605863657	low	64
Container (Base)	260557.48980257072	5060.585623617237	10644.155417316826	24.478925719054555	4.085146592938895	-4.71010111472284	15704.741040934063	51	0.01942214605863657	low	64
Container (Max)	429401.1773032816	8339.892383334834	7364.848657599228	58.30414137026633	1.715144030077382	-4.71010111472284	15704.741040934063	136	0.01942214605863657	low	64
Traditional Housing	547073.7606324853	12147.753885741167	18431.374009709874	29.681659128846285	3.369083903494277	2.748113121259217	30579.12789545104	127	0.02220496532624203	middle	65
ODD Cubes Basic	295475.81645958335	5294.558826408113	25284.56906904293	11.686013538642749	8.557238075184904	2.748113121259217	30579.12789545104	89	0.017918755212687022	middle	65
Container (Base)	243902.9840442095	4370.437866732099	26208.690028718942	9.306187519366501	10.745538899994923	2.748113121259217	30579.12789545104	129	0.017918755212687022	middle	65
Container (Max)	484004.04844155407	8672.75006597372	21906.377829477322	22.094207093893726	4.526073263232761	2.748113121259217	30579.12789545104	73	0.017918755212687022	middle	65
Traditional Housing	568544.304340776	9963.623101243811	20709.336138883235	27.453526299826393	3.6425193218487335	-0.59156356795667	30672.959240127046	145	0.017524796265080127	middle	66
ODD Cubes Basic	334696.55129415507	5527.7245408682165	25145.23469925883	13.310535984140982	7.512845472124215	-0.59156356795667	30672.959240127046	140	0.016515630410574682	middle	66
Container (Base)	231543.45862911758	3824.086186704695	26848.87305342235	8.623954464249046	11.59560853603229	-0.59156356795667	30672.959240127046	147	0.016515630410574682	middle	66
Container (Max)	460114.0907655171	7599.074269780894	23073.884970346153	19.9409025119455	5.01481815780883	-0.59156356795667	30672.959240127046	69	0.016515630410574682	middle	66
Traditional Housing	561530.0256869263	9228.89242576699	6590.4199330249485	85.20398265868752	1.1736540579397887	4.475931967906012	15819.312358791938	123	0.016435260811703125	low	67
ODD Cubes Basic	316139.5114543928	4192.329112186042	11626.983246605896	27.19015799276042	3.6778013583674554	4.475931967906012	15819.312358791938	42	0.013261009650136185	low	67
Container (Base)	255261.00700015645	3385.018677132555	12434.293681659383	20.528790258240974	4.871207642635274	4.475931967906012	15819.312358791938	69	0.013261009650136185	low	67
Container (Max)	464380.13842303306	6158.149496959419	9661.16286183252	48.06669187387551	2.0804427369870755	4.475931967906012	15819.312358791938	56	0.013261009650136185	low	67
Traditional Housing	535845.943494865	14985.645928627448	594.2931837688557	100	0.11090747088478253	-2.7471717571184397	15579.939112396303	126	0.02796633269422344	low	68
ODD Cubes Basic	337075.97929309536	5291.052492511204	10288.8866198851	32.76117151895096	3.0523938969079354	-2.7471717571184397	15579.939112396303	71	0.015696913507771824	low	68
Container (Base)	222132.0330731652	3486.7873104549844	12093.15180194132	18.368415175066787	5.444127816521678	-2.7471717571184397	15579.939112396303	57	0.015696913507771824	low	68
Container (Max)	439927.59123641165	6905.505349320351	8674.433763075951	50.715424574342876	1.9717867066933787	-2.7471717571184397	15579.939112396303	78	0.015696913507771824	low	68
Traditional Housing	562481.0077121974	8066.152093121789	22471.56581239969	25.030788348617136	3.9950799234625247	-4.305325993107787	30537.71790552148	119	0.014340310130522609	middle	69
ODD Cubes Basic	305017.66903676605	7291.6362276459495	23246.081677875532	13.12125085265732	7.621224616687209	-4.305325993107787	30537.71790552148	73	0.02390561914223741	middle	69
Container (Base)	227816.67172344337	5446.098588472763	25091.619317048717	9.079392957657834	11.013952195521727	-4.305325993107787	30537.71790552148	132	0.02390561914223741	middle	69
Container (Max)	424688.4585929536	10152.440545227011	20385.27736029447	20.833096900616265	4.800054474716234	-4.305325993107787	30537.71790552148	53	0.02390561914223741	middle	69
Traditional Housing	592814.8258960196	11910.433664686287	18571.883062650333	31.920017151530615	3.1328303968409625	2.0568909299378966	30482.31672733662	143	0.020091322187639402	middle	70
ODD Cubes Basic	345911.4680795026	7225.430440718156	23256.886286618465	14.87350730516892	6.723363760022323	2.0568909299378966	30482.31672733662	109	0.020888091628860073	middle	70
Container (Base)	276382.8784358094	5773.110889415281	24709.205837921338	11.18542134655106	8.940208589534649	2.0568909299378966	30482.31672733662	100	0.020888091628860073	middle	70
Container (Max)	473130.1791683447	9882.786534847368	20599.530192489252	22.968008238403982	4.353882102532234	2.0568909299378966	30482.31672733662	47	0.020888091628860073	middle	70
Traditional Housing	534253.3007384156	11884.301935782618	18707.993726840163	28.557487699599125	3.5017085904725347	1.846748056819422	30592.295662622782	113	0.02224469538954048	middle	71
ODD Cubes Basic	356186.17962501914	6344.209114579514	24248.08654804327	14.689248940088513	6.807699999357314	1.846748056819422	30592.295662622782	97	0.017811497125628187	middle	71
Container (Base)	275680.3171678431	4910.279176827305	25682.016485795477	10.73437194156151	9.315868738702674	1.846748056819422	30592.295662622782	79	0.017811497125628187	middle	71
Container (Max)	433764.773781195	7726.000021402516	22866.295641220266	18.96961276925251	5.271588894112173	1.846748056819422	30592.295662622782	84	0.017811497125628187	middle	71
Traditional Housing	559663.8759573835	12386.214257024354	3551.6956282556694	100	0.6346122701201674	2.1420768096045295	15937.909885280023	143	0.022131523561058856	low	72
ODD Cubes Basic	349199.620761552	8090.569497559405	7847.340387720618	44.499104602111245	2.2472362285522376	2.1420768096045295	15937.909885280023	149	0.023168895429826315	low	72
Container (Base)	267324.2704727812	6193.608068438474	9744.30181684155	27.433907066666563	3.6451242528813736	2.1420768096045295	15937.909885280023	98	0.023168895429826315	low	72
Container (Max)	421665.08737258485	9769.514315743994	6168.395569536029	68.3589569798458	1.4628660883384002	2.1420768096045295	15937.909885280023	124	0.023168895429826315	low	72
Traditional Housing	581480.0544978451	10201.411749526873	20427.985874273374	28.464874514630946	3.513101733457493	-0.18782446631487026	30629.397623800247	115	0.017543872176899712	middle	73
ODD Cubes Basic	336649.62741205597	5203.858065147162	25425.539558653087	13.240608980409379	7.5525227085822575	-0.18782446631487026	30629.397623800247	145	0.015457786497941639	middle	73
Container (Base)	263987.57625197043	4080.6635918120473	26548.7340319882	9.94350901756353	10.056811918545746	-0.18782446631487026	30629.397623800247	62	0.015457786497941639	middle	73
Container (Max)	446593.53942177363	6903.347583741859	23726.050040058388	18.822919898919448	5.312672026285391	-0.18782446631487026	30629.397623800247	126	0.015457786497941639	middle	73
Traditional Housing	548588.7287314398	10530.296201443603	5095.378965199883	100	0.9288158320318521	-0.574880975879072	15625.675166643487	134	0.019195247094839024	low	74
ODD Cubes Basic	326287.61307428667	7872.089201310148	7753.585965333338	42.08215586093126	2.376304111663614	-0.574880975879072	15625.675166643487	137	0.024126227554700005	low	74
Container (Base)	239474.47628608232	5777.6157084206325	9848.059458222855	24.31692023204915	4.1123628751391905	-0.574880975879072	15625.675166643487	56	0.024126227554700005	low	74
Container (Max)	410265.4781476177	9898.158283627226	5727.51688301626	71.63060127577681	1.3960513833326822	-0.574880975879072	15625.675166643487	100	0.024126227554700005	low	74
Traditional Housing	596040.9178604357	11544.944605300747	4047.0437497270595	100	0.6789875708960444	1.275185269868233	15591.988355027806	134	0.019369382636921617	low	75
ODD Cubes Basic	299700.4107600932	3763.494430900685	11828.49392412712	25.337157264694582	3.9467726767967957	1.275185269868233	15591.988355027806	129	0.012557521764337254	low	75
Container (Base)	233223.16834208433	2928.7050124034154	12663.28334262439	18.417274732932746	5.429684980546311	1.275185269868233	15591.988355027806	128	0.012557521764337254	low	75
Container (Max)	424471.6659539598	5330.312183561343	10261.676171466464	41.36474966285161	2.4175173502816305	1.275185269868233	15591.988355027806	46	0.012557521764337254	low	75
Traditional Housing	563847.1959258391	6347.751026134016	24227.963045210883	23.272579493111543	4.296902284922865	-1.5942041660661346	30575.714071344897	107	0.011257927807392898	middle	76
ODD Cubes Basic	351088.31490151776	3580.0105069504943	26995.703564394404	13.005340426266224	7.689148974373257	-1.5942041660661346	30575.714071344897	106	0.010196894499193764	middle	76
Container (Base)	249597.60660236294	2545.120461775564	28030.593609569332	8.90447095337835	11.230313459786183	-1.5942041660661346	30575.714071344897	43	0.010196894499193764	middle	76
Container (Max)	441472.7693324887	4501.651253150291	26074.062818194605	16.931491360235082	5.906154270311814	-1.5942041660661346	30575.714071344897	40	0.010196894499193764	middle	76
Traditional Housing	511713.03845523746	11963.983177871862	18222.48566624187	28.08140710480641	3.5610751137496957	-0.5739017559193282	30186.468844113733	81	0.02338025861914484	middle	77
ODD Cubes Basic	307421.4622807403	5777.452653494745	24409.01619061899	12.594586356122385	7.9399193568106945	-0.5739017559193282	30186.468844113733	148	0.018793263849024043	middle	77
Container (Base)	248015.10234473165	4661.013256907244	25525.45558720649	9.716382984718921	10.29189567324294	-0.5739017559193282	30186.468844113733	91	0.018793263849024043	middle	77
Container (Max)	445352.9146924412	8369.634831746944	21816.834012366788	20.4132696082298	4.898774273753973	-0.5739017559193282	30186.468844113733	84	0.018793263849024043	middle	77
Traditional Housing	515797.47020465817	8130.045387203069	7866.773026959924	65.56658854106861	1.5251670435371745	3.4465847643168264	15996.818414162994	97	0.015762088526679336	low	78
ODD Cubes Basic	337077.96108070435	2814.2335164214383	13182.584897741555	25.569944263241776	3.910841532171644	3.4465847643168264	15996.818414162994	119	0.008348909870579301	low	78
Container (Base)	268378.20792798226	2240.665469218315	13756.152944944679	19.509684793567956	5.125659438279006	3.4465847643168264	15996.818414162994	43	0.008348909870579301	low	78
Container (Max)	438962.8415164698	3664.861200354392	12331.9572138086	35.595553398850996	2.8093396632858063	3.4465847643168264	15996.818414162994	97	0.008348909870579301	low	78
Traditional Housing	523974.8510470595	9722.284045387216	21123.367087873594	24.805460647789463	4.031370407503862	-2.2859441913321166	30845.65113326081	81	0.018554867711607085	middle	79
ODD Cubes Basic	346952.94031036313	4310.072200496379	26535.57893276443	13.075009261696112	7.6481781388067525	-2.2859441913321166	30845.65113326081	58	0.01242264209273122	middle	79
Container (Base)	266828.1503882888	3314.7106125391724	27530.940520721637	9.69193733819068	10.31785457443623	-2.2859441913321166	30845.65113326081	100	0.01242264209273122	middle	79
Container (Max)	442044.55405429157	5491.361284057443	25354.289849203367	17.434704607519528	5.735686508670203	-2.2859441913321166	30845.65113326081	101	0.01242264209273122	middle	79
Traditional Housing	559958.355170625	10199.704023679391	5699.483255476904	98.24721471591911	1.0178405595430775	2.5029959802902804	15899.187279156295	144	0.018215111765894514	low	80
ODD Cubes Basic	316607.0546518056	6749.483208204956	9149.704070951339	34.602983025098695	2.889924256745919	2.5029959802902804	15899.187279156295	135	0.021318170612552596	low	80
Container (Base)	234056.20336729122	4989.650076310222	10909.537202846073	21.454274275377216	4.661075863785738	2.5029959802902804	15899.187279156295	109	0.021318170612552596	low	80
Container (Max)	496539.7710640095	10585.319555460363	5313.867723695932	93.44225277754059	1.0701796781170456	2.5029959802902804	15899.187279156295	91	0.021318170612552596	low	80
Traditional Housing	508323.3675562833	5601.39661890826	24601.004104220072	20.66270813186382	4.839636671138508	-0.2906075273092066	30202.400723128332	103	0.011019356922024747	middle	81
ODD Cubes Basic	351303.81495025364	6674.949787565112	23527.450935563218	14.93165646853973	6.697180598193851	-0.2906075273092066	30202.400723128332	64	0.019000504701351787	middle	81
Container (Base)	230721.93249008697	4383.833162982867	25818.567560145464	8.936279363779974	11.19033950587024	-0.2906075273092066	30202.400723128332	61	0.019000504701351787	middle	81
Container (Max)	477184.9195371857	9066.754307080471	21135.64641604786	22.57725693096706	4.429236036324659	-0.2906075273092066	30202.400723128332	62	0.019000504701351787	middle	81
ODD Cubes Basic	350910.7251276755	6796.60389191305	8939.753904974898	39.252839491744474	2.5475863987121663	0.47384927807721766	15736.357796887947	144	0.019368470112847563	low	82
Container (Base)	261868.38581622188	5071.990004181128	10664.36779270682	24.555453347671413	4.072415140707755	0.47384927807721766	15736.357796887947	89	0.019368470112847563	low	82
Container (Max)	425918.8992722141	8249.39747105081	7486.960325837137	56.88809353007904	1.7578370761735223	0.47384927807721766	15736.357796887947	55	0.019368470112847563	low	82
Traditional Housing	512922.43382809625	11974.572101824802	3529.092410739757	100	0.6880362756608374	-4.185457925744458	15503.66451256456	82	0.023345775719839208	low	83
ODD Cubes Basic	315470.60711934726	3785.9742227975344	11717.690289767024	26.922593046758156	3.714352470667433	-4.185457925744458	15503.66451256456	103	0.012001036348103402	low	83
Container (Base)	231390.06722364455	2776.920607341048	12726.743905223511	18.181403581844197	5.5001254193520674	-4.185457925744458	15503.66451256456	109	0.012001036348103402	low	83
Container (Max)	467928.7808166224	5615.630306903996	9888.034205660562	47.32273079605137	2.113149396026487	-4.185457925744458	15503.66451256456	126	0.012001036348103402	low	83
Traditional Housing	568588.2169639246	7901.2830971882	22180.905555236048	25.634130019984827	3.9010491060955923	3.785018570804546	30082.188652424247	105	0.013896318744307563	middle	84
ODD Cubes Basic	315630.84891849296	4880.334879109658	25201.85377331459	12.524112383062235	7.984597785567721	3.785018570804546	30082.188652424247	63	0.015462160608926832	middle	84
Container (Base)	238206.96822061247	3683.19440079264	26398.994251631608	9.023334978221374	11.08237699712567	3.785018570804546	30082.188652424247	63	0.015462160608926832	middle	84
Container (Max)	456765.4557354266	7062.580837190826	23019.607815233423	19.842451678657973	5.039699812274579	3.785018570804546	30082.188652424247	138	0.015462160608926832	middle	84
Traditional Housing	546219.4494134961	9227.250266342056	21607.354018963295	25.279330774796243	3.9558009225347477	-4.284441004186252	30834.60428530535	141	0.016892936119813802	middle	85
ODD Cubes Basic	299859.72819063504	4695.0165594600385	26139.58772584531	11.471478867057689	8.71727186694011	-4.284441004186252	30834.60428530535	125	0.015657376159812945	middle	85
Container (Base)	260109.34940453782	4072.629926311066	26761.974358994285	9.71936322467625	10.288739878155031	-4.284441004186252	30834.60428530535	92	0.015657376159812945	middle	85
Container (Max)	459443.03393090994	7193.672406261959	23640.931879043394	19.434218425974368	5.145563243559477	-4.284441004186252	30834.60428530535	129	0.015657376159812945	middle	85
Traditional Housing	543434.6849992668	15386.10840535528	516.9030274323504	100	0.09511778355351902	0.1701423694389117	15903.01143278763	85	0.028312709567619963	low	86
ODD Cubes Basic	320329.0334135812	6695.034239221363	9207.977193566268	34.78820881934843	2.874537189289902	0.1701423694389117	15903.01143278763	47	0.020900491497370183	low	86
Container (Base)	259282.90485106173	5419.140148253058	10483.871284534573	24.731599407706053	4.043410147135138	0.1701423694389117	15903.01143278763	125	0.020900491497370183	low	86
Container (Max)	422419.80875094945	8828.781621119959	7074.229811667672	59.71248036842736	1.674691779390133	0.1701423694389117	15903.01143278763	119	0.020900491497370183	low	86
Traditional Housing	518920.2290234292	12024.43137592658	18254.470432632334	28.427021804795235	3.5177796916851634	3.4118425940555763	30278.901808558912	142	0.023172022795402872	middle	87
ODD Cubes Basic	347507.6068254396	2815.1468292712143	27463.754979287696	12.65331732996886	7.90306584370204	3.4118425940555763	30278.901808558912	71	0.008100964623445846	middle	87
Container (Base)	260577.50214203517	2110.929126518511	28167.972682040403	9.250843327754879	10.809825272899673	3.4118425940555763	30278.901808558912	71	0.008100964623445846	middle	87
Container (Max)	455544.7738918919	3690.352097693853	26588.54971086506	17.133118535823694	5.836649048502738	3.4118425940555763	30278.901808558912	138	0.008100964623445846	middle	87
Traditional Housing	518912.6910594944	5508.24407284979	24731.52324520771	20.98183301993117	4.766027825357655	2.437176488457	30239.7673180575	105	0.010614972745421366	middle	88
ODD Cubes Basic	315909.63299726974	7241.017289780252	22998.75002827725	13.735947936685903	7.280167372571389	2.437176488457	30239.7673180575	98	0.022921166477512363	middle	88
Container (Base)	239315.84270309831	5485.398271303879	24754.36904675362	9.667620380511499	10.34380706565447	2.437176488457	30239.7673180575	90	0.022921166477512363	middle	88
Container (Max)	485163.2963014129	11120.508683303344	19119.25863475416	25.375633311403828	3.9407883449773813	2.437176488457	30239.7673180575	95	0.022921166477512363	middle	88
Traditional Housing	562806.26724201	11458.951106083161	18802.59389217272	29.932373717665573	3.340864341172572	-0.06741187657896042	30261.544998255882	109	0.020360382911577893	middle	89
ODD Cubes Basic	348449.4579196641	3551.875431626656	26709.669566629225	13.045816873564513	7.665292328503839	-0.06741187657896042	30261.544998255882	87	0.010193373388589257	middle	89
Container (Base)	234644.23750374827	2391.8163263565248	27869.728671899356	8.419322637336498	11.877440063472328	-0.06741187657896042	30261.544998255882	140	0.010193373388589257	middle	89
Container (Max)	478592.1461435785	4878.468446487774	25383.076551768107	18.854772988904738	5.303696844233866	-0.06741187657896042	30261.544998255882	80	0.010193373388589257	middle	89
Traditional Housing	576408.0269585076	10023.438472795404	5579.48125218637	100	0.9679742458874546	-4.64331924239422	15602.919724981773	122	0.01738948453873099	low	90
ODD Cubes Basic	305638.5791186143	6141.896085789908	9461.023639191866	32.30502224437113	3.0954939217670447	-4.64331924239422	15602.919724981773	139	0.02009529066488141	low	90
Container (Base)	223036.08724738398	4481.975001994031	11120.944722987742	20.055498233558644	4.986163835744111	-4.64331924239422	15602.919724981773	97	0.02009529066488141	low	90
Container (Max)	432215.55457546114	8685.497199076804	6917.422525904969	62.48216773760205	1.6004566362030932	-4.64331924239422	15602.919724981773	45	0.02009529066488141	low	90
Traditional Housing	528115.664460052	6068.198500490245	9878.82497730555	53.459360366570195	1.870579807059067	-3.016713128993649	15947.023477795796	113	0.01149028311192852	low	91
ODD Cubes Basic	355556.06197735877	7731.868957912512	8215.154519883283	43.28050812882462	2.310508917833163	-3.016713128993649	15947.023477795796	59	0.021745850471267918	low	91
Container (Base)	236519.2110367269	5143.311396786923	10803.712081008873	21.89240228388614	4.567794740077694	-3.016713128993649	15947.023477795796	74	0.021745850471267918	low	91
Container (Max)	439514.40190847596	9557.614463870468	6389.409013925328	68.78795847168041	1.453742809378031	-3.016713128993649	15947.023477795796	116	0.021745850471267918	low	91
Traditional Housing	547077.102198755	15123.971446761407	484.76995084637747	100	0.08861090126017719	-4.160626582831549	15608.741397607784	148	0.027645045617842028	low	92
ODD Cubes Basic	354763.2574245518	3062.8067403440873	12545.934657263697	28.27714850397018	3.53642447313808	-4.160626582831549	15608.741397607784	99	0.008633382054779053	low	92
Container (Base)	236115.52697437757	2038.4755534352907	13570.265844172493	17.39947689202958	5.747299221725935	-4.160626582831549	15608.741397607784	109	0.008633382054779053	low	92
Container (Max)	417064.9943011439	3600.681437476024	12008.05996013176	34.732087921433695	2.879181931884046	-4.160626582831549	15608.741397607784	146	0.008633382054779053	low	92
Traditional Housing	505301.53944901103	13156.087139570895	17074.365966783094	29.594161237497048	3.3790449135384106	-4.070300298261955	30230.453106353987	93	0.02603611133644379	middle	93
ODD Cubes Basic	301646.22998707526	3364.5494551613547	26865.90365119263	11.227846042457038	8.906427788719178	-4.070300298261955	30230.453106353987	62	0.011153958248725723	middle	93
Container (Base)	243156.4020271601	2712.1563561213106	27518.296750232676	8.836171956213247	11.317117921147284	-4.070300298261955	30230.453106353987	85	0.011153958248725723	middle	93
Container (Max)	426566.37076445424	4757.903489817179	25472.54961653681	16.74611992854955	5.971532535695951	-4.070300298261955	30230.453106353987	112	0.011153958248725723	middle	93
Traditional Housing	591481.4878115852	6523.405871995541	24024.783413308112	24.619638713743587	4.061798028911624	-2.4604949809333188	30548.18928530365	149	0.011028926528421721	middle	94
ODD Cubes Basic	320792.51187864	3432.5276652687717	27115.66162003488	11.830524970175054	8.452710277194091	-2.4604949809333188	30548.18928530365	57	0.010700148969086104	middle	94
Container (Base)	264128.20815709454	2826.2111742186953	27721.978111084958	9.527754733039046	10.495652207884158	-2.4604949809333188	30548.18928530365	55	0.010700148969086104	middle	94
Container (Max)	399150.4959867623	4270.969768142962	26277.21951716069	15.189982171671234	6.583286199406895	-2.4604949809333188	30548.18928530365	75	0.010700148969086104	middle	94
Traditional Housing	496415.6041007248	6891.25725475193	8576.625245204692	57.8800623681532	1.7277106469571128	-1.036678377186103	15467.882499956622	114	0.013882031905978656	low	95
ODD Cubes Basic	312575.4271857071	6314.318921578196	9153.563578378427	34.147949540006415	2.9284335178849865	-1.036678377186103	15467.882499956622	100	0.02020094470774485	low	95
Container (Base)	263284.08012605953	5318.5871450559935	10149.295354900629	25.941119153551064	3.854883800813623	-1.036678377186103	15467.882499956622	142	0.02020094470774485	low	95
Container (Max)	423555.6334549931	8556.223932078161	6911.658567878461	61.281330565639294	1.6318183544152747	-1.036678377186103	15467.882499956622	141	0.02020094470774485	low	95
Traditional Housing	538683.1974340644	12515.935900841429	17995.37185054169	29.934541053557005	3.3406224542105476	-2.506531422239876	30511.30775138312	101	0.023234316497078782	middle	96
ODD Cubes Basic	346727.4344709306	8338.35340022781	22172.95435115531	15.637403522317024	6.394923547076363	-2.506531422239876	30511.30775138312	57	0.024048726957390194	middle	96
Container (Base)	256519.27313398512	6168.961958907406	24342.345792475713	10.537984930494083	9.489480262078095	-2.506531422239876	30511.30775138312	128	0.024048726957390194	middle	96
Container (Max)	446057.4653217012	10727.114190827137	19784.193560555985	22.546153521820166	4.435346361995628	-2.506531422239876	30511.30775138312	111	0.024048726957390194	middle	96
Traditional Housing	595661.2665290427	13721.720995273912	1954.7010831513435	100	0.32815648641072714	-0.813530437747195	15676.422078425256	130	0.023036114258748568	low	97
ODD Cubes Basic	326600.90691269276	5793.576522292766	9882.84555613249	33.04725395713898	3.0259700285444646	-0.813530437747195	15676.422078425256	86	0.017739009291365838	low	97
Container (Base)	244826.89452649167	4342.98655678168	11333.435521643576	21.602178267917374	4.629162798295934	-0.813530437747195	15676.422078425256	72	0.017739009291365838	low	97
Container (Max)	447149.3598373455	7931.986648782958	7744.435429642298	57.73814810642673	1.7319571770066728	-0.813530437747195	15676.422078425256	61	0.017739009291365838	low	97
Traditional Housing	549616.8680094382	6078.087501885257	24216.97953495359	22.695516887898773	4.406156532760877	3.140246111040268	30295.067036838846	121	0.01105877176568184	middle	98
ODD Cubes Basic	304117.8693779794	5928.33794551026	24366.729091328583	12.480865537517147	8.012264830464096	3.140246111040268	30295.067036838846	129	0.019493553462135098	middle	98
Container (Base)	270265.4548864726	5268.434093797715	25026.63294304113	10.799113708247447	9.260019173946516	3.140246111040268	30295.067036838846	44	0.019493553462135098	middle	98
Container (Max)	506137.21674933995	9866.412893879518	20428.654142959327	24.77584735672754	4.036188896394955	3.140246111040268	30295.067036838846	93	0.019493553462135098	middle	98
Traditional Housing	552957.2537236629	9985.84811348426	5700.798917019452	96.99644940515907	1.0309655725880744	-0.6335869688775331	15686.647030503713	86	0.018058987464652426	low	99
ODD Cubes Basic	299827.5879352941	7324.102064317399	8362.544966186313	35.85362938526937	2.789117913989635	-0.6335869688775331	15686.647030503713	110	0.024427712322116324	low	99
Container (Base)	267278.11231172644	6528.992837549151	9157.654192954562	29.186307615476107	3.426264168715017	-0.6335869688775331	15686.647030503713	50	0.024427712322116324	low	99
Container (Max)	430986.8142663052	10528.021913522683	5158.625116981029	83.54683747954351	1.196933397083822	-0.6335869688775331	15686.647030503713	117	0.024427712322116324	low	99
Traditional Housing	520986.9003497177	10544.275219436255	19795.533259942324	26.318406961229577	3.7996220723888396	-4.943764311118324	30339.80847937858	134	0.02023904096697691	middle	100
ODD Cubes Basic	318681.2270213248	7259.870580781561	23079.937898597018	13.807715966198366	7.24232742365229	-4.943764311118324	30339.80847937858	109	0.022780979754090633	middle	100
Container (Base)	248288.50523144848	5656.255410851054	24683.553068527523	10.058864076097127	9.94148039415603	-4.943764311118324	30339.80847937858	125	0.022780979754090633	middle	100
Container (Max)	428737.7286882704	9767.06551706229	20572.74296231629	20.84008581031718	4.7984447333942155	-4.943764311118324	30339.80847937858	68	0.022780979754090633	middle	100
Traditional Housing	548198.4690735078	14924.191923912033	1045.684590434088	100	0.19074927228479224	-1.2742541086769976	15969.87651434612	146	0.02722406713235613	low	101
ODD Cubes Basic	341942.2925473741	5773.350890768857	10196.525623577263	33.535177095687025	2.9819433997520486	-1.2742541086769976	15969.87651434612	108	0.016883991879913463	low	101
Container (Base)	225979.22501529517	3815.431400187381	12154.44511415874	18.592311116864682	5.378567482624157	-1.2742541086769976	15969.87651434612	92	0.016883991879913463	low	101
Container (Max)	438672.47932914493	7406.542578934789	8563.33393541133	51.226833221478685	1.9521019300109972	-1.2742541086769976	15969.87651434612	131	0.016883991879913463	low	101
Traditional Housing	583387.3212145043	9596.621918780762	21120.333700453415	27.62206930480365	3.620293573827555	-2.835843056931291	30716.955619234177	104	0.016449829418305445	middle	102
ODD Cubes Basic	317880.2823637766	3718.4711445235052	26998.484474710673	11.774004672800551	8.493286929893337	-2.835843056931291	30716.955619234177	129	0.011697709329036497	middle	102
Container (Base)	255171.81013563529	2984.9256639307505	27732.029955303427	9.2013390489951	10.867983395408217	-2.835843056931291	30716.955619234177	118	0.011697709329036497	middle	102
Container (Max)	405080.5364561471	4738.51437031418	25978.441248919997	15.592950037869864	6.413154647269099	-2.835843056931291	30716.955619234177	67	0.011697709329036497	middle	102
Traditional Housing	552489.7354795858	13162.501325770269	2549.0762709646024	100	0.46137984242402075	-0.7572814727470076	15711.57759673487	82	0.023823974420709604	low	103
ODD Cubes Basic	320309.02412915265	7098.733894716581	8612.84370201829	37.1896942764784	2.6889169686788104	-0.7572814727470076	15711.57759673487	111	0.022162141432063687	low	103
Container (Base)	233880.63308652872	5183.2956686842435	10528.281928050626	22.214510846579607	4.501562095633409	-0.7572814727470076	15711.57759673487	54	0.022162141432063687	low	103
Container (Max)	404073.77840440074	8955.14022598669	6756.437370748181	59.805746169398034	1.6720801328479862	-0.7572814727470076	15711.57759673487	82	0.022162141432063687	low	103
Traditional Housing	587139.1638267789	6164.749597116066	9310.900865109974	63.05932931011225	1.585808176110175	3.4598365628669097	15475.65046222604	132	0.010499639569154725	low	104
ODD Cubes Basic	342724.8818852338	7739.040144385426	7736.610317840614	44.299101002271065	2.2573821530796607	3.4598365628669097	15475.65046222604	117	0.022580911259827793	low	104
Container (Base)	240117.16663245636	5422.06443168878	10053.586030537259	23.883733217492008	4.186950134192665	3.4598365628669097	15475.65046222604	57	0.022580911259827793	low	104
Container (Max)	444860.4552507566	10045.354463023927	5430.295999202113	81.92195329980558	1.2206740192587342	3.4598365628669097	15475.65046222604	140	0.022580911259827793	low	104
Traditional Housing	533767.4829375051	6814.992444374511	9121.843566197844	58.51530768576746	1.7089545275401974	0.4135405304796036	15936.836010572355	106	0.012767717521624351	low	105
ODD Cubes Basic	344061.6415383384	7606.168360068599	8330.667650503756	41.30060830328923	2.421271843398875	0.4135405304796036	15936.836010572355	85	0.022106993171515904	low	105
Container (Base)	261498.86572122393	5780.953638858252	10155.882371714102	25.748512650121246	3.883719473774308	0.4135405304796036	15936.836010572355	92	0.022106993171515904	low	105
Container (Max)	460332.558012684	10176.568716612854	5760.267293959501	79.91513839911757	1.2513273705486594	0.4135405304796036	15936.836010572355	110	0.022106993171515904	low	105
Traditional Housing	562187.9175474725	9221.676639541485	21144.413864501144	26.588011431771893	3.761093613812086	2.1629371979858583	30366.09050404263	128	0.01640319251215993	middle	106
ODD Cubes Basic	349084.23195581953	3375.5125306603577	26990.57797338227	12.933558973804914	7.731823870176475	2.1629371979858583	30366.09050404263	117	0.009669621889674943	middle	106
Container (Base)	265065.28825088596	2563.081113463765	27803.009390578864	9.533690563033229	10.489117445005904	2.1629371979858583	30366.09050404263	78	0.009669621889674943	middle	106
Container (Max)	416644.957466952	4028.7992009451245	26337.291303097503	15.819582684949488	6.321279264537015	2.1629371979858583	30366.09050404263	49	0.009669621889674943	middle	106
Traditional Housing	535598.9772138351	5743.4378107319535	10076.209288863467	53.154808704280825	1.881297335793939	-4.619987742469615	15819.64709959542	106	0.01072339204344469	low	107
ODD Cubes Basic	308848.22500393266	2760.4900138689954	13059.157085726425	23.649935671690617	4.228341310868839	-4.619987742469615	15819.64709959542	87	0.008938014825352631	low	107
Container (Base)	239194.51781408247	2137.924146365343	13681.722953230077	17.48277747121109	5.71991493712427	-4.619987742469615	15819.64709959542	98	0.008938014825352631	low	107
Container (Max)	408122.60177347506	3647.805865212808	12171.841234382613	33.530062865150086	2.9823982258004147	-4.619987742469615	15819.64709959542	103	0.008938014825352631	low	107
Traditional Housing	572167.0379449468	6171.748900146651	9725.31205940208	58.83276901040891	1.6997330175349663	4.3954894184251945	15897.060959548731	133	0.01078662084819449	low	108
ODD Cubes Basic	333463.8663398533	6378.352923398095	9518.708036150636	35.0324713262984	2.854494593561013	4.3954894184251945	15897.060959548731	54	0.0191275684331493	low	108
Container (Base)	245959.82689522565	4704.613420743984	11192.447538804747	21.97551751236459	4.550518546092701	4.3954894184251945	15897.060959548731	43	0.0191275684331493	low	108
Container (Max)	447298.55139112065	8555.73365178221	7341.327307766522	60.92883924653727	1.641258905251231	4.3954894184251945	15897.060959548731	66	0.0191275684331493	low	108
Traditional Housing	542677.3486662258	12775.30496772917	17467.786967361688	31.06732121706148	3.2188163022269913	4.97688741722976	30243.091935090855	115	0.02354125337850914	middle	109
ODD Cubes Basic	301665.7093505832	4794.054773029364	25449.03716206149	11.853717978780573	8.436171687145816	4.97688741722976	30243.091935090855	84	0.015891944707105955	middle	109
Container (Base)	248831.8953658811	3954.422722518957	26288.6692125719	9.465366746175324	10.564830997214878	4.97688741722976	30243.091935090855	117	0.015891944707105955	middle	109
Container (Max)	508952.52537716506	8088.245391835848	22154.846543255007	22.972514135157233	4.353028119240966	4.97688741722976	30243.091935090855	80	0.015891944707105955	middle	109
Traditional Housing	513011.0737703724	12469.94408611582	3047.509048641041	100	0.5940435215644349	0.5998263915086968	15517.45313475686	139	0.0243073585029423	low	110
ODD Cubes Basic	353206.2468454103	8561.52306314836	6955.930071608502	50.777716740866296	1.9693677939543752	0.5998263915086968	15517.45313475686	88	0.02423944406310437	low	110
Container (Base)	246720.9251762176	5980.378065006285	9537.075069750575	25.869663746147918	3.8655314959356724	0.5998263915086968	15517.45313475686	127	0.02423944406310437	low	110
Container (Max)	466809.53376111167	11315.203581726299	4202.249553030562	100	0.9002064544767954	0.5998263915086968	15517.45313475686	138	0.02423944406310437	low	110
Traditional Housing	571963.15563767	13319.168769688504	2595.4846849484293	100	0.45378529357450953	-0.7984789946313899	15914.653454636933	125	0.02328676006208693	low	111
ODD Cubes Basic	351624.3922447378	5244.249776880006	10670.403677756927	32.9532417763837	3.034602807171041	-0.7984789946313899	15914.653454636933	128	0.014914351485689592	low	111
Container (Base)	248943.72585297798	3712.8342275284645	12201.819227108468	20.402181119017573	4.9014367344669125	-0.7984789946313899	15914.653454636933	96	0.014914351485689592	low	111
Container (Max)	404649.7260535507	6035.088242950661	9879.565211686273	40.95825245172747	2.4415104164382475	-0.7984789946313899	15914.653454636933	143	0.014914351485689592	low	111
Traditional Housing	510071.9176524616	10797.291484298741	5010.203213928489	100	0.9822542744535487	3.7826825422969605	15807.49469822723	96	0.02116817474287125	low	112
ODD Cubes Basic	324294.3881602471	5271.666969892544	10535.827728334687	30.780152876655446	3.2488467617665044	3.7826825422969605	15807.49469822723	76	0.016255806953056486	low	112
Container (Base)	237111.76601486866	3854.4430946360044	11953.051603591226	19.836923145519574	5.041104372206346	3.7826825422969605	15807.49469822723	57	0.016255806953056486	low	112
Container (Max)	463331.8540006314	7531.833173836017	8275.661524391213	55.9872890686785	1.7861197008008725	3.7826825422969605	15807.49469822723	85	0.016255806953056486	low	112
Traditional Housing	579024.6292505496	13360.344505811203	2214.325300298804	100	0.3824233354572287	-2.586601661667236	15574.669806110007	117	0.02307387947055712	low	113
ODD Cubes Basic	295643.3953332287	5339.15695984323	10235.512846266778	28.884082290127687	3.4621144959893386	-2.586601661667236	15574.669806110007	60	0.018059449472312084	low	113
Container (Base)	250263.1218267004	4519.6142034123795	11055.055602697626	22.637889018453407	4.417373012054456	-2.586601661667236	15574.669806110007	59	0.018059449472312084	low	113
Container (Max)	415193.7454277914	7498.170466773205	8076.499339336802	51.407636896047194	1.9452362730115909	-2.586601661667236	15574.669806110007	109	0.018059449472312084	low	113
Traditional Housing	515887.5044971064	10145.259767628153	5428.7614528550985	95.02858229767868	1.0523149728441519	1.450771959588896	15574.021220483251	134	0.019665643535053012	low	114
ODD Cubes Basic	351977.33453676733	8452.892424096763	7121.128796386489	49.42718276846404	2.0231782270180867	1.450771959588896	15574.021220483251	92	0.024015445299117064	low	114
Container (Base)	240184.3717541997	5768.134641565781	9805.88657891747	24.49389658152818	4.082649719171835	1.450771959588896	15574.021220483251	148	0.024015445299117064	low	114
Container (Max)	451168.4032194377	10835.010108206397	4739.011112276854	95.20306927549579	1.0503863033094343	1.450771959588896	15574.021220483251	78	0.024015445299117064	low	114
Traditional Housing	546784.8891635609	7570.026272266271	7957.996877685923	68.70885947401358	1.4554163868463144	4.2727558093951075	15528.023149952194	127	0.013844614988988537	low	115
ODD Cubes Basic	335099.69822503376	3211.765726229162	12316.257423723033	27.207916065442046	3.675400929621888	4.2727558093951075	15528.023149952194	114	0.009584507963574244	low	115
Container (Base)	259333.65578202222	2485.5854890656137	13042.43766088658	19.883833262224204	5.029211353827959	4.2727558093951075	15528.023149952194	55	0.009584507963574244	low	115
Container (Max)	429028.0321592181	4112.022590826613	11416.000559125581	37.58129039475799	2.660898520236773	4.2727558093951075	15528.023149952194	91	0.009584507963574244	low	115
Traditional Housing	507785.2884291981	6972.435152890644	23537.1023398305	21.573823366094725	4.635246998321092	-4.885514609342287	30509.537492721145	120	0.01373106963074774	middle	116
ODD Cubes Basic	352473.6972424082	3611.9345957625223	26897.602896958622	13.104279165421959	7.631095059686177	-4.885514609342287	30509.537492721145	106	0.010247387603729398	middle	116
Container (Base)	255200.27843323306	2615.1361696850036	27894.40132303614	9.148799268994528	10.930396116450176	-4.885514609342287	30509.537492721145	119	0.010247387603729398	middle	116
Container (Max)	455373.62405800977	4666.39003023738	25843.147462483765	17.620671968036053	5.675152467590355	-4.885514609342287	30509.537492721145	80	0.010247387603729398	middle	116
Traditional Housing	535927.8232407823	5852.088634351221	10120.55574657812	52.95438676102207	1.888417676353994	-2.56844917171367	15972.644380929341	122	0.010919546216061986	low	117
ODD Cubes Basic	312513.4747148163	3546.3074294886806	12426.33695144066	25.149283810349658	3.9762563719149373	-2.56844917171367	15972.644380929341	107	0.011347694472133907	low	117
Container (Base)	247394.83798693458	2807.361035458801	13165.28334547054	18.79145564094902	5.3215675204047	-2.56844917171367	15972.644380929341	46	0.011347694472133907	low	117
Container (Max)	452406.30085499136	5133.768479370735	10838.875901558607	41.73922692388574	2.395827794854865	-2.56844917171367	15972.644380929341	146	0.011347694472133907	low	117
Traditional Housing	533114.6683523789	6747.328530960161	9066.877708273547	58.79804332928308	1.7007368670412402	2.363226313236245	15814.206239233708	101	0.012656430091884663	low	118
ODD Cubes Basic	323266.85525483213	3069.961489625756	12744.244749607953	25.365713041942065	3.9423295467645856	2.363226313236245	15814.206239233708	48	0.009496678795621336	low	118
Container (Base)	274258.17677740095	2604.5418119277115	13209.664427305997	20.761933680198236	4.816507052778775	2.363226313236245	15814.206239233708	63	0.009496678795621336	low	118
Container (Max)	415955.28218628303	3950.1937082651634	11864.012530968545	35.06025310581205	2.852232689199345	2.363226313236245	15814.206239233708	83	0.009496678795621336	low	118
Traditional Housing	565350.255382227	11745.845074506264	3898.053688999491	100	0.6894935753348268	0.6192582074351094	15643.898763505755	116	0.02077622670669005	low	119
ODD Cubes Basic	322710.36769824935	5080.136685981565	10563.762077524188	30.54881067274874	3.2734498593493733	0.6192582074351094	15643.898763505755	101	0.015742093203313975	low	119
Container (Base)	250558.67456140404	3944.318007844437	11699.580755661318	21.416038727726292	4.669397607622688	0.6192582074351094	15643.898763505755	127	0.015742093203313975	low	119
Container (Max)	460544.57472753135	7249.935619641396	8393.96314386436	54.86616593785862	1.822616876733467	0.6192582074351094	15643.898763505755	131	0.015742093203313975	low	119
Traditional Housing	563819.3829384957	14759.233623332348	15483.674468540707	36.413797260078546	2.746211807732361	3.1007458195527953	30242.908091873054	127	0.02617723701943457	middle	120
ODD Cubes Basic	339516.7872774329	6962.020788692983	23280.887303180072	14.583498595049525	6.857065151289947	3.1007458195527953	30242.908091873054	68	0.020505674681128606	middle	120
Container (Base)	251881.79287906663	5165.006102877556	25077.901988995498	10.043973893414034	9.956218630314375	3.1007458195527953	30242.908091873054	50	0.020505674681128606	middle	120
Container (Max)	455833.36206431175	9347.170631295887	20895.73746057717	21.814657794409378	4.584073742638669	3.1007458195527953	30242.908091873054	115	0.020505674681128606	middle	120
Traditional Housing	596879.9982921319	6386.790591857265	9170.644532666454	65.08593765312843	1.536430196841351	-4.53192849180166	15557.43512452372	147	0.010700292538084629	low	121
ODD Cubes Basic	320209.12690083164	5471.805490465788	10085.629634057932	31.74904676447019	3.1497008632053882	-4.53192849180166	15557.43512452372	102	0.017088224634397756	low	121
Container (Base)	243182.43205508954	4155.556026096539	11401.87909842718	21.328276677537747	4.688611345018642	-4.53192849180166	15557.43512452372	117	0.017088224634397756	low	121
Container (Max)	393175.868157641	6718.677555902124	8838.757568621595	44.483160116694634	2.248041724950871	-4.53192849180166	15557.43512452372	129	0.017088224634397756	low	121
Traditional Housing	588064.3604056212	8020.206929586715	22471.332477787684	26.169536719146816	3.821236924184274	3.3349447482137453	30491.5394073744	144	0.013638314901543642	middle	122
ODD Cubes Basic	305246.377322017	6738.247821502853	23753.291585871546	12.850698027197943	7.781678457337832	3.3349447482137453	30491.5394073744	140	0.022074783919202416	middle	122
Container (Base)	245342.48130916405	5415.882261100754	25075.657146273647	9.78408979984092	10.220674794054517	3.3349447482137453	30491.5394073744	135	0.022074783919202416	middle	122
Container (Max)	497347.60338090156	10978.840877366587	19512.698530007812	25.48840708096065	3.9233522786403583	3.3349447482137453	30491.5394073744	103	0.022074783919202416	middle	122
Traditional Housing	573367.2413164567	14128.351504084218	16228.709168678964	35.330428030779075	2.8304214121856166	-4.860812365303049	30357.060672763182	126	0.024641016238816482	middle	123
ODD Cubes Basic	331389.7161057584	5905.790230024752	24451.27044273843	13.553067390990105	7.378403509339786	-4.860812365303049	30357.060672763182	65	0.017821283953603443	middle	123
Container (Base)	255938.04465793792	4561.144568379151	25795.916104384032	9.921649753483308	10.078968970346072	-4.860812365303049	30357.060672763182	130	0.017821283953603443	middle	123
Container (Max)	407716.67414092337	7266.0346224842015	23091.026050278982	17.65693188570966	5.663498089434967	-4.860812365303049	30357.060672763182	76	0.017821283953603443	middle	123
Traditional Housing	564879.4942502395	13992.870588595804	16446.31941430631	34.34686388000361	2.9114739659890456	4.663377291192134	30439.190002902113	124	0.024771425996209052	middle	124
ODD Cubes Basic	296335.8218656093	2723.961911098568	27715.228091803543	10.692166085879958	9.352641849817475	4.663377291192134	30439.190002902113	71	0.009192145228847516	middle	124
Container (Base)	269119.5424122079	2473.785917774004	27965.40408512811	9.6233024773393	10.391443086765419	4.663377291192134	30439.190002902113	107	0.009192145228847516	middle	124
Container (Max)	476536.63428793213	4380.393949240869	26058.796053661245	18.286978159183953	5.468372036622067	4.663377291192134	30439.190002902113	56	0.009192145228847516	middle	124
Traditional Housing	595701.168517036	11951.721957088392	3907.4169751006375	100	0.6559357579955616	0.7823048209521355	15859.13893218903	145	0.020063284392813126	low	125
ODD Cubes Basic	318538.56529130973	4595.368594670362	11263.770337518668	28.279923661998385	3.536077437662134	0.7823048209521355	15859.13893218903	127	0.014426412043602344	low	125
Container (Base)	276410.56210961594	3987.612662197057	11871.526269991973	23.283489908817163	4.294888798527204	0.7823048209521355	15859.13893218903	68	0.014426412043602344	low	125
Container (Max)	484640.3575794997	6991.621491400641	8867.517440788388	54.6534428396243	1.8297108984230173	0.7823048209521355	15859.13893218903	100	0.014426412043602344	low	125
Traditional Housing	551837.6200703423	7274.299481757177	23695.22170693246	23.2889831922903	4.29387574263459	0.8329902115637946	30969.52118868964	107	0.01318195646181195	middle	126
ODD Cubes Basic	302442.2697708469	7234.427344719887	23735.093843969753	12.742408846539561	7.847809719836203	0.8329902115637946	30969.52118868964	136	0.023920027283888708	middle	126
Container (Base)	257228.07168442276	6152.9024928734725	24816.618695816167	10.365153884875896	9.647710117059908	0.8329902115637946	30969.52118868964	109	0.023920027283888708	middle	126
Container (Max)	428431.5337156246	10248.093975756025	20721.427212933617	20.67577340658331	4.836578445387649	0.8329902115637946	30969.52118868964	91	0.023920027283888708	middle	126
Traditional Housing	539572.3998160678	10663.386153857142	5313.740998864234	100	0.9848059316369053	1.9632308528209546	15977.127152721376	116	0.0197626605020793	low	127
ODD Cubes Basic	333294.8063888672	6504.197409159364	9472.929743562012	35.18392043553167	2.8422074277717964	1.9632308528209546	15977.127152721376	126	0.019514847769846973	low	127
Container (Base)	245241.768603595	4785.855781107193	11191.271371614182	21.913664717811443	4.563362691166846	1.9632308528209546	15977.127152721376	87	0.019514847769846973	low	127
Container (Max)	482954.1899207151	9424.777496112518	6552.349656608858	73.70702346960313	1.3567228100214916	1.9632308528209546	15977.127152721376	86	0.019514847769846973	low	127
Traditional Housing	573303.685855019	13960.692004366718	16858.455042411246	34.00689353874624	2.9405802645885184	3.686200768045582	30819.147046777965	134	0.02435130341704657	middle	128
ODD Cubes Basic	301582.6449343104	3709.0501029528623	27110.096943825105	11.124366156241363	8.989276206437584	3.686200768045582	30819.147046777965	126	0.012298619185333936	middle	128
Container (Base)	274050.21495173784	3370.439231350332	27448.70781542763	9.984084380019778	10.015940991055796	3.686200768045582	30819.147046777965	50	0.012298619185333936	middle	128
Container (Max)	443675.5200118457	5456.596262480696	25362.55078429727	17.493331951711212	5.716463866120023	3.686200768045582	30819.147046777965	70	0.012298619185333936	middle	128
Traditional Housing	591455.4668315949	7978.287326736167	22160.9809497939	26.689047211923874	3.746855375014023	-0.6548300645500396	30139.268276530067	136	0.013489244371136778	middle	129
ODD Cubes Basic	319052.20934703556	3359.2175778239693	26780.050698706098	11.913801543417199	8.393626470574674	-0.6548300645500396	30139.268276530067	133	0.010528739433269752	middle	129
Container (Base)	254241.4765922955	2676.8422601700304	27462.426016360037	9.257793773967299	10.801709612629057	-0.6548300645500396	30139.268276530067	75	0.010528739433269752	middle	129
Container (Max)	460833.18147298833	4851.992489933808	25287.27578659626	18.223915670554636	5.487294926500094	-0.6548300645500396	30139.268276530067	83	0.010528739433269752	middle	129
Traditional Housing	569572.8443453896	16753.734362862786	14009.684849536756	40.65565003514145	2.459682723399163	-4.413997485005106	30763.41921239954	87	0.029414559575988673	middle	130
ODD Cubes Basic	342343.31465872773	7624.208568739857	23139.210643659684	14.794943523820349	6.759066017318463	-4.413997485005106	30763.41921239954	149	0.022270651250602666	middle	130
Container (Base)	231635.10435197497	5158.664626419791	25604.75458597975	9.046566081082851	11.053918039587266	-4.413997485005106	30763.41921239954	116	0.022270651250602666	middle	130
Container (Max)	402729.2204857653	8969.042017865546	21794.377194533998	18.47858357644509	5.411670195732503	-4.413997485005106	30763.41921239954	97	0.022270651250602666	middle	130
Traditional Housing	555517.3872780907	13481.080860567406	17038.030486561474	32.6045541306108	3.067056203234963	2.698213824514095	30519.11134712888	144	0.0242676128043834	middle	131
ODD Cubes Basic	320932.16564822017	3740.620800206336	26778.490546922545	11.98469962621185	8.343972157740946	2.698213824514095	30519.11134712888	105	0.011655487360237058	middle	131
Container (Base)	279350.93652916385	3255.971309786054	27263.140037342826	10.246469634331618	9.759458971599543	2.698213824514095	30519.11134712888	126	0.011655487360237058	middle	131
Container (Max)	456735.6503650065	5323.476599798986	25195.634747329896	18.127570706009262	5.516458968594735	2.698213824514095	30519.11134712888	121	0.011655487360237058	middle	131
Traditional Housing	500901.28880124015	12361.551380697136	3114.9586035262782	100	0.6218707504189129	-2.0842199914230086	15476.509984223414	126	0.024678617637979874	low	132
ODD Cubes Basic	314269.88363220386	3402.581932961291	12073.928051262123	26.028802084782367	3.8418978973475153	-2.0842199914230086	15476.509984223414	66	0.010826942415339418	low	132
Container (Base)	261740.33085332814	2833.847489920871	12642.662494302544	20.702943780337588	4.830230959472246	-2.0842199914230086	15476.509984223414	83	0.010826942415339418	low	132
Container (Max)	476017.6631845852	5153.815827983939	10322.694156239475	46.11370403693109	2.1685527564628724	-2.0842199914230086	15476.509984223414	49	0.010826942415339418	low	132
Traditional Housing	564618.2351914743	12447.223066110912	3438.551388719061	100	0.6090046644619923	0.1866384527975118	15885.774454829972	114	0.02204537914346636	low	133
ODD Cubes Basic	297102.97609208885	4246.464655373319	11639.309799456652	25.525824229367814	3.917601214418323	0.1866384527975118	15885.774454829972	116	0.014292905144299536	low	133
Container (Base)	264949.8235734679	3786.9026963344736	12098.8717584955	21.898721538843265	4.566476623880674	0.1866384527975118	15885.774454829972	80	0.014292905144299536	low	133
Container (Max)	417830.93209756206	5972.017878824715	9913.756576005257	42.146579744438995	2.3726717709091076	0.1866384527975118	15885.774454829972	132	0.014292905144299536	low	133
Traditional Housing	597409.3856018862	11305.091762588929	18949.555759458002	31.526300309373237	3.171954812923879	4.434267240674284	30254.647522046933	130	0.018923525533833252	middle	134
ODD Cubes Basic	303541.16068529343	4990.725519671051	25263.922002375883	12.014807544796396	8.323062989328523	4.434267240674284	30254.647522046933	60	0.016441676339392253	middle	134
Container (Base)	282866.61930936616	4650.801401902681	25603.84612014425	11.047817502965547	9.05156153902408	4.434267240674284	30254.647522046933	90	0.016441676339392253	middle	134
Container (Max)	482561.6676164552	7934.12275274714	22320.524769299795	21.619638095614246	4.625424327537008	4.434267240674284	30254.647522046933	120	0.016441676339392253	middle	134
Traditional Housing	513098.9000866271	10467.289334399715	5080.389004316528	100	0.9901383541182411	4.1743817659923135	15547.678338716243	94	0.020400139880698456	low	135
ODD Cubes Basic	302993.87256500695	3437.9771987330073	12109.701139983235	25.020755596072984	3.9966818594277393	4.1743817659923135	15547.678338716243	83	0.011346688860829665	low	135
Container (Base)	260739.99659814054	2958.535614972886	12589.142723743356	20.71149738467736	4.828236131009114	4.1743817659923135	15547.678338716243	62	0.011346688860829665	low	135
Container (Max)	470581.3787784814	5339.54048869966	10208.137850016583	46.09865047793383	2.1692608994674862	4.1743817659923135	15547.678338716243	94	0.011346688860829665	low	135
Traditional Housing	497470.01034322684	10785.314426119148	4726.2814370564065	100	0.9500635895208103	-2.3766656727451463	15511.595863175555	133	0.021680330877991774	low	136
ODD Cubes Basic	296695.01244325103	6522.399834330608	8989.196028844946	33.005733937851886	3.0297765893736797	-2.3766656727451463	15511.595863175555	64	0.02198351694765395	low	136
Container (Base)	233589.40094103938	5135.116554379672	10376.479308795882	22.51143128508255	4.442187559449679	-2.3766656727451463	15511.595863175555	42	0.02198351694765395	low	136
Container (Max)	415722.86201408284	9139.050582613794	6372.545280561761	65.236548931581	1.5328830485021263	-2.3766656727451463	15511.595863175555	52	0.02198351694765395	low	136
Traditional Housing	567615.1648109005	14844.136714693963	15261.383995192526	37.19290235995008	2.688685035445946	1.0094571020834326	30105.52070988649	83	0.02615176202989441	middle	137
ODD Cubes Basic	340446.19890417095	6487.568793128996	23617.95191675749	14.414721484068075	6.93735221388255	1.0094571020834326	30105.52070988649	106	0.01905607644911648	middle	137
Container (Base)	232397.76080861595	4428.589496572471	25676.93121331402	9.05083862545509	11.04869992033162	1.0094571020834326	30105.52070988649	87	0.01905607644911648	middle	137
Container (Max)	459107.0353611251	8748.778764168821	21356.741945717666	21.497054022942045	4.6518001905413735	1.0094571020834326	30105.52070988649	72	0.01905607644911648	middle	137
Traditional Housing	503402.0692760759	7208.423372054514	23626.083218248656	21.307047157408256	4.693282896557112	1.3953935530351362	30834.50659030317	124	0.014319415457351384	middle	138
ODD Cubes Basic	330946.3971987981	4296.72272942002	26537.783860883148	12.470762401777455	8.018755933137419	1.3953935530351362	30834.50659030317	75	0.012983137951609115	middle	138
Container (Base)	230626.77981329136	2994.259297651342	27840.247292651828	8.283934312399701	12.071558782198004	1.3953935530351362	30834.50659030317	51	0.012983137951609115	middle	138
Container (Max)	467598.4673896158	6070.895408080378	24763.61118222279	18.882483008992388	5.295913675779667	1.3953935530351362	30834.50659030317	110	0.012983137951609115	middle	138
Traditional Housing	588413.9720095019	12164.432771824839	18483.236603651225	31.83500728943031	3.141196076722793	-0.6346172440672113	30647.669375476064	140	0.020673256160593692	middle	139
ODD Cubes Basic	294712.1366107679	4608.99219098335	26038.677184492713	11.31824533645216	8.835291781309468	-0.6346172440672113	30647.669375476064	42	0.01563896296904303	middle	139
Container (Base)	251594.4144352652	3934.6757305711776	26712.993644904887	9.41842826677171	10.617482786676925	-0.6346172440672113	30647.669375476064	72	0.01563896296904303	middle	139
Container (Max)	437059.50324507244	6835.15738651803	23812.511988958035	18.35419561983796	5.448345548410519	-0.6346172440672113	30647.669375476064	100	0.01563896296904303	middle	139
Traditional Housing	511432.7390227737	13200.81859409834	16852.859072224826	30.346942131953462	3.2952249213506803	-2.5957781548658065	30053.67766632317	91	0.025811446133311614	middle	140
ODD Cubes Basic	343990.7723982506	6238.038340920253	23815.639325402917	14.443902500292458	6.923336681203381	-2.5957781548658065	30053.67766632317	146	0.018134318829047688	middle	140
Container (Base)	227627.21083878132	4127.86441551732	25925.813250805848	8.779944861776169	11.389593166507673	-2.5957781548658065	30053.67766632317	56	0.018134318829047688	middle	140
Container (Max)	417767.77721424866	7575.93406850575	22477.743597817418	18.58584138555677	5.380439761942171	-2.5957781548658065	30053.67766632317	102	0.018134318829047688	middle	140
ODD Cubes Basic	314520.76466461574	3393.3496672924025	12462.548929329638	25.237274208361633	3.962393053005222	3.727628450132114	15855.89859662204	65	0.010788952745014617	low	141
Container (Base)	235831.68186283196	2544.3768713954146	13311.521725226627	17.716357808732567	5.644501035687426	3.727628450132114	15855.89859662204	130	0.010788952745014617	low	141
Container (Max)	467008.88991336554	5038.536844777034	10817.361751845006	43.172161625611956	2.316307459126041	3.727628450132114	15855.89859662204	136	0.010788952745014617	low	141
Traditional Housing	546240.2114585293	11168.139454129701	19728.930486922727	27.687269303351407	3.611768242810984	0.1691991122379486	30897.06994105243	126	0.020445472925380903	middle	142
ODD Cubes Basic	320683.89531190763	2848.998037368477	28048.07190368395	11.433366842937524	8.746330050782088	0.1691991122379486	30897.06994105243	54	0.008884131941198508	middle	142
Container (Base)	228700.4759745841	2031.8052035731046	28865.264737479323	7.923034070691689	12.621427486966477	0.1691991122379486	30897.06994105243	126	0.008884131941198508	middle	142
Container (Max)	490131.94323544845	4354.396852299741	26542.673088752686	18.465809438128492	5.415413840105945	0.1691991122379486	30897.06994105243	66	0.008884131941198508	middle	142
Traditional Housing	515429.56071247905	8378.303676028121	7573.364371488677	68.05820180168651	1.4693306222134415	1.6744983626078742	15951.668047516798	108	0.016254992562799036	low	143
ODD Cubes Basic	328819.6703984528	6342.080329375024	9609.587718141775	34.21787490192527	2.9224491668935726	1.6744983626078742	15951.668047516798	146	0.019287411612845123	low	143
Container (Base)	252370.0037834061	4867.564141705834	11084.103905810964	22.768642907713843	4.392005285748531	1.6744983626078742	15951.668047516798	128	0.019287411612845123	low	143
Container (Max)	491707.87945498835	9483.772264327592	6467.895783189206	76.022851316342	1.3153939673202422	1.6744983626078742	15951.668047516798	144	0.019287411612845123	low	143
Traditional Housing	567757.2509691862	15810.834173693826	14457.184946944706	39.27163227507666	2.5463672938153876	3.6889261648664657	30268.01912063853	142	0.02784787714591764	middle	144
ODD Cubes Basic	330250.0163438197	3556.574009449368	26711.445111189165	12.363614734025797	8.08824944413634	3.6889261648664657	30268.01912063853	70	0.010769337875661625	middle	144
Container (Base)	249897.38195585573	2691.229340525877	27576.789780112653	9.06187355194158	11.035245573314603	3.6889261648664657	30268.01912063853	59	0.010769337875661625	middle	144
Container (Max)	476644.3150087129	5133.143674842122	25134.87544579641	18.963464371908298	5.273298066155883	3.6889261648664657	30268.01912063853	140	0.010769337875661625	middle	144
Traditional Housing	535825.8879594249	9485.78822510661	21201.85904138763	25.2725898664571	3.956856045558054	2.580021212133376	30687.647266494238	101	0.01770311669940239	middle	145
ODD Cubes Basic	342598.4269406035	4781.995932927042	25905.651333567195	13.224852852731876	7.561520805832093	2.580021212133376	30687.647266494238	55	0.013958020693878144	middle	145
Container (Base)	270288.01938377717	3772.6857678660986	26914.961498628138	10.042296341295298	9.957881803267076	2.580021212133376	30687.647266494238	126	0.013958020693878144	middle	145
Container (Max)	495780.1829646159	6920.110053434801	23767.537213059437	20.859552191726532	4.79396676788022	2.580021212133376	30687.647266494238	73	0.013958020693878144	middle	145
Traditional Housing	538722.5487335608	7669.427638502131	8071.612446556417	66.7428661002419	1.4982874701516238	2.0466830219548138	15741.040085058548	104	0.014236321937018539	low	146
ODD Cubes Basic	294530.3869036059	6842.9617848273765	8898.078300231173	33.100448991997965	3.021107055803835	2.0466830219548138	15741.040085058548	109	0.02323346618584026	low	146
Container (Base)	266047.83478287666	6181.213373243982	9559.826711814567	27.829775873874357	3.5932736380344545	2.0466830219548138	15741.040085058548	128	0.02323346618584026	low	146
Container (Max)	447436.59799273347	10395.503069771576	5345.537015286973	83.70283410500582	1.1947026772659723	2.0466830219548138	15741.040085058548	108	0.02323346618584026	low	146
Traditional Housing	568293.0773538804	15200.684698742012	452.9180390631682	100	0.07969796872629027	-4.525765273597964	15653.60273780518	145	0.026747967385983888	low	147
ODD Cubes Basic	318591.35956080345	5831.281736801551	9822.32100100363	32.43544570863142	3.0830468894524525	-4.525765273597964	15653.60273780518	130	0.01830332669674504	low	147
Container (Base)	222017.8777465328	4063.6657489127897	11589.93698889239	19.15609014607337	5.2202719468042424	-4.525765273597964	15653.60273780518	65	0.01830332669674504	low	147
Container (Max)	403788.52250831976	7390.673243865764	8262.929493939417	48.86747766690799	2.046350758711614	-4.525765273597964	15653.60273780518	118	0.01830332669674504	low	147
Traditional Housing	542034.2668349942	13487.960681901579	2430.9926532854897	100	0.4484942746296022	-4.628616440198023	15918.953335187069	89	0.024883963076097505	low	148
ODD Cubes Basic	312479.120187131	4267.198829844143	11651.754505342926	26.81820321942445	3.7288105836848127	-4.628616440198023	15918.953335187069	96	0.013655948683191031	low	148
Container (Base)	221758.59967116782	3028.324057165771	12890.629278021297	17.203085659229167	5.812910659219537	-4.628616440198023	15918.953335187069	67	0.013655948683191031	low	148
Container (Max)	392562.06558512384	5360.807422597923	10558.145912589145	37.18096613128326	2.6895481856740173	-4.628616440198023	15918.953335187069	120	0.013655948683191031	low	148
Traditional Housing	540726.6160745771	9074.940076814155	21311.20410580493	25.372879607834516	3.9412160363982687	-1.5064206157756588	30386.144182619086	103	0.016782861814152936	middle	149
ODD Cubes Basic	345484.84959166474	2843.4310440849345	27542.713138534153	12.543602652866744	7.9721913047959765	-1.5064206157756588	30386.144182619086	70	0.008230262622067627	middle	149
Container (Base)	233669.28819637065	1923.1596085677375	28462.98457405135	8.209584893967806	12.180883843892941	-1.5064206157756588	30386.144182619086	91	0.008230262622067627	middle	149
Container (Max)	430454.0245136373	3542.749668473171	26843.394514145915	16.035752269959634	6.236065406631012	-1.5064206157756588	30386.144182619086	136	0.008230262622067627	middle	149
Traditional Housing	551953.0536854172	13693.766520317009	17282.247029324913	31.937574595991514	3.1311081465951704	-0.7843470712998819	30976.013549641924	105	0.024809658047696394	middle	150
ODD Cubes Basic	305390.42146956123	4994.144086501428	25981.869463140494	11.75398182578075	8.507755200085786	-0.7843470712998819	30976.013549641924	141	0.01635330951923521	middle	150
Container (Base)	238106.70839584697	3893.832701003567	27082.180848638356	8.792006438721442	11.373968012532787	-0.7843470712998819	30976.013549641924	64	0.01635330951923521	middle	150
Container (Max)	460138.06592685485	7524.780213684114	23451.23333595781	19.62106040799673	5.096564503682184	-0.7843470712998819	30976.013549641924	115	0.01635330951923521	middle	150
Traditional Housing	596171.0525258109	7329.121055266278	8331.545833174632	71.55587503965603	1.3975092882950606	0.06750165576459022	15660.66688844091	110	0.012293654688893114	low	151
ODD Cubes Basic	333118.1102437502	7350.201510153381	8310.465378287528	40.08417039003334	2.494750397150899	0.06750165576459022	15660.66688844091	107	0.022064851126752216	low	151
Container (Base)	259931.762108307	5735.355634034167	9925.311254406743	26.18877690036167	3.8184295654761558	0.06750165576459022	15660.66688844091	55	0.022064851126752216	low	151
Container (Max)	477370.0674715904	10533.099471128304	5127.567417312606	93.09874032271298	1.074128389421434	0.06750165576459022	15660.66688844091	149	0.022064851126752216	low	151
Traditional Housing	503452.1833914999	11682.744111445483	18531.730752716103	27.16703529257306	3.6809316483399295	0.739642555859108	30214.474864161584	137	0.02320527052389526	middle	152
ODD Cubes Basic	344850.2884537997	7532.439663088709	22682.035201072875	15.203674864127185	6.577357178029919	0.739642555859108	30214.474864161584	139	0.021842636979837834	middle	152
Container (Base)	248670.65888699447	5431.622929605705	24782.851934555878	10.033980735698197	9.966134342298165	0.739642555859108	30214.474864161584	97	0.021842636979837834	middle	152
Container (Max)	475981.0038438281	10396.680276259534	19817.794587902048	24.01785939059006	4.163568383582882	0.739642555859108	30214.474864161584	65	0.021842636979837834	middle	152
Traditional Housing	495961.7254400584	7499.512489791383	7963.922535163321	62.27606098002903	1.605753453675698	1.0843426805863619	15463.435024954704	88	0.015121151704069892	low	153
ODD Cubes Basic	341922.01974464447	5496.026471564333	9967.40855339037	34.30400368492382	2.9151116271582245	1.0843426805863619	15463.435024954704	125	0.01607391789411193	low	153
Container (Base)	258642.85695987887	4157.40404667163	11306.030978283074	22.876538854058243	4.37129063264132	1.0843426805863619	15463.435024954704	72	0.01607391789411193	low	153
Container (Max)	440465.0327548905	7079.998771729432	8383.436253225273	52.53991554900116	1.9033148217898328	1.0843426805863619	15463.435024954704	45	0.01607391789411193	low	153
Traditional Housing	557940.2149531061	12223.986476487264	18629.041025516424	29.950023417141473	3.3388955530086966	2.0655700997550603	30853.027502003686	82	0.02190913318107867	middle	154
ODD Cubes Basic	300164.80877577205	6350.414811693556	24502.612690310132	12.250318468873974	8.163053087483677	2.0655700997550603	30853.027502003686	118	0.021156426822963842	middle	154
Container (Base)	232261.1330689518	4913.8156655919465	25939.21183641174	8.954055139906721	11.168124211600707	2.0655700997550603	30853.027502003686	66	0.021156426822963842	middle	154
Container (Max)	458645.9462170476	9703.309398789977	21149.71810321371	21.685676564519135	4.611338719475984	2.0655700997550603	30853.027502003686	143	0.021156426822963842	middle	154
Traditional Housing	562772.1272644032	12831.062170386223	2871.9371933792954	100	0.5103197287576386	1.4350750121121045	15702.999363765519	125	0.022799747089034313	low	155
ODD Cubes Basic	327119.70607633167	3313.220700216546	12389.778663548972	26.402384978734588	3.7875366214280843	1.4350750121121045	15702.999363765519	55	0.010128465630998774	low	155
Container (Base)	244822.96322059925	2479.6809686591164	13223.318395106402	18.514487506494717	5.401175699026014	1.4350750121121045	15702.999363765519	93	0.010128465630998774	low	155
Container (Max)	451520.9058825615	4573.213976908956	11129.785386856562	40.5686983340913	2.4649546104851603	1.4350750121121045	15702.999363765519	48	0.010128465630998774	low	155
Traditional Housing	549571.6383715675	11690.137867984009	4011.5232615336354	100	0.7299363688817998	3.0258645127422508	15701.661129517644	93	0.02127136309767183	low	156
ODD Cubes Basic	307778.9657543081	7439.30039192276	8262.360737594885	37.2507296073229	2.6845111774761476	3.0258645127422508	15701.661129517644	92	0.024170918807561916	low	156
Container (Base)	240605.0598756203	5815.645366942192	9886.015762575453	24.337919911725805	4.108814572597095	3.0258645127422508	15701.661129517644	56	0.024170918807561916	low	156
Container (Max)	434086.60386472585	10492.272057464581	5209.3890720530635	83.32773725684665	1.200080588913189	3.0258645127422508	15701.661129517644	82	0.024170918807561916	low	156
Traditional Housing	556974.3224476884	15314.896697555057	238.73604247849653	100	0.04286302489302258	-4.28757985005357	15553.632740033554	83	0.027496593793142857	low	157
ODD Cubes Basic	307434.0227245599	2606.0920322430306	12947.540707790524	23.744588232078474	4.211485961458028	-4.28757985005357	15553.632740033554	107	0.008476914848744353	low	157
Container (Base)	241641.1514308055	2048.371464631478	13505.261275402076	17.892371461996127	5.588974061510106	-4.28757985005357	15553.632740033554	130	0.008476914848744353	low	157
Container (Max)	431659.6189458181	3659.1418334451346	11894.49090658842	36.290718311173755	2.7555255077221887	-4.28757985005357	15553.632740033554	133	0.008476914848744353	low	157
Traditional Housing	583792.5600099833	6368.486171797437	23740.773151416113	24.590292670193033	4.06664537674309	-3.5023263981211783	30109.25932321355	88	0.010908816946362818	middle	158
ODD Cubes Basic	337385.70898771373	4473.539760887041	25635.71956232651	13.16076610088705	7.598341861972601	-3.5023263981211783	30109.25932321355	138	0.013259422796268912	middle	158
Container (Base)	264603.8890263142	3508.49483813692	26600.76448507663	9.947228741292768	10.053051216655115	-3.5023263981211783	30109.25932321355	124	0.013259422796268912	middle	158
Container (Max)	469470.02986222104	6224.901616120181	23884.35770709337	19.655962099529017	5.087514897192244	-3.5023263981211783	30109.25932321355	140	0.013259422796268912	middle	158
Traditional Housing	563793.4988804584	15621.049762364022	196.27781373669677	100	0.034813777407233584	-4.336018397119387	15817.327576100719	145	0.02770704130747021	low	159
ODD Cubes Basic	323862.89788365224	5466.95593249497	10350.37164360575	31.289977696958175	3.1959115141753967	-4.336018397119387	15817.327576100719	123	0.016880463826575695	low	159
Container (Base)	234830.39448421943	3964.045979471367	11853.281596629353	19.811424589035052	5.047592592374532	-4.336018397119387	15817.327576100719	44	0.016880463826575695	low	159
Container (Max)	425820.6547952672	7188.050159880285	8629.277416220433	49.34603840581751	2.0265051305154174	-4.336018397119387	15817.327576100719	40	0.016880463826575695	low	159
Traditional Housing	587895.0484969483	9130.176998203731	21377.159560228225	27.50108342694486	3.6362203789405094	-3.2879038958418905	30507.336558431958	130	0.015530283885782932	middle	160
ODD Cubes Basic	329648.1992199419	2937.063483709798	27570.27307472216	11.956653397175826	8.36354426930366	-3.2879038958418905	30507.336558431958	136	0.008909690666170403	middle	160
Container (Base)	239361.99539790716	2132.6413362326566	28374.6952221993	8.435755645073476	11.85430259094815	-3.2879038958418905	30507.336558431958	79	0.008909690666170403	middle	160
Container (Max)	461060.9987324182	4107.910876941431	26399.425681490527	17.464811708221465	5.725798919030175	-3.2879038958418905	30507.336558431958	76	0.008909690666170403	middle	160
Traditional Housing	497308.6614932891	6073.219054333254	9818.632844333573	50.64948138683999	1.9743538781027383	-0.47257017699265624	15891.851898666826	137	0.012212172287723583	low	161
ODD Cubes Basic	317314.1067203725	4845.216382858527	11046.635515808299	28.72495487574292	3.4812935453711025	-0.47257017699265624	15891.851898666826	86	0.015269464168916665	low	161
Container (Base)	231624.0950118627	3536.775819441387	12355.076079225439	18.74728196949991	5.334106574099154	-0.47257017699265624	15891.851898666826	72	0.015269464168916665	low	161
Container (Max)	454543.6496194869	6940.637971073366	8951.21392759346	50.78011242902908	1.9692748837403864	-0.47257017699265624	15891.851898666826	113	0.015269464168916665	low	161
Traditional Housing	528253.7491182375	8402.283930571337	7341.363681141309	71.95580713093261	1.3897418983576608	-0.9619221728243303	15743.647611712646	147	0.015905772452342176	low	162
ODD Cubes Basic	328889.92312210036	5956.097183820781	9787.550427891865	33.602884148096265	2.9759350286503725	-0.9619221728243303	15743.647611712646	42	0.018109698002542876	low	162
Container (Base)	272194.31061976607	4929.356763334313	10814.290848378332	25.169871463239147	3.973003999883393	-0.9619221728243303	15743.647611712646	111	0.018109698002542876	low	162
Container (Max)	471857.7310702334	8545.20100984702	7198.446601865626	65.54993836419398	1.5255544474260563	-0.9619221728243303	15743.647611712646	147	0.018109698002542876	low	162
Traditional Housing	538479.2119959521	6506.434231721171	9057.184862053455	59.453265026310554	1.6819934103828582	0.770806083186808	15563.619093774625	135	0.012082981267938124	low	163
ODD Cubes Basic	315171.0793026718	4843.464413594716	10720.154680179909	29.39986303419481	3.40137639021279	0.770806083186808	15563.619093774625	76	0.015367731151954259	low	163
Container (Base)	274428.49858051306	4217.343386619786	11346.27570715484	24.186658747192382	4.134510725323237	0.770806083186808	15563.619093774625	133	0.015367731151954259	low	163
Container (Max)	462556.122167059	7108.438128153873	8455.180965620752	54.7068269795571	1.8279254257858548	0.770806083186808	15563.619093774625	52	0.015367731151954259	low	163
Traditional Housing	553641.598823225	12980.249294532347	2613.30409275929	100	0.47202090636142846	-3.1326225891353854	15593.553387291637	142	0.02344522037744652	low	164
ODD Cubes Basic	324929.61601636914	5192.785029477456	10400.76835781418	31.240924212320035	3.2009296306465997	-3.1326225891353854	15593.553387291637	136	0.015981261090142848	low	164
Container (Base)	221787.10116475206	3544.4375701398276	12049.11581715181	18.406919190621448	5.432739665144574	-3.1326225891353854	15593.553387291637	80	0.015981261090142848	low	164
Container (Max)	445898.6959270502	7126.023479364405	8467.529907927232	52.65983123479771	1.8989806396097948	-3.1326225891353854	15593.553387291637	47	0.015981261090142848	low	164
Traditional Housing	589633.7418191211	16649.66772686728	14111.209424337292	41.78477720004585	2.3932160633822948	-0.7455954874077957	30760.87715120457	94	0.028237304865729368	middle	165
ODD Cubes Basic	314124.7168877865	7725.467002017653	23035.41014918692	13.636601860066042	7.333205224158074	-0.7455954874077957	30760.87715120457	84	0.024593629812255078	middle	165
Container (Base)	227186.2356396593	5587.334177761532	25173.54297344304	9.024801788104702	11.080575767526192	-0.7455954874077957	30760.87715120457	84	0.024593629812255078	middle	165
Container (Max)	413425.7143920701	10167.638974625668	20593.238176578903	20.07579919423587	4.981121749250801	-0.7455954874077957	30760.87715120457	43	0.024593629812255078	middle	165
Traditional Housing	589481.9636912092	14431.256535205066	16079.049372487665	36.66149347733533	2.7276575642457517	-2.3329789582818607	30510.30590769273	136	0.02448125205534643	middle	166
ODD Cubes Basic	302466.90765350463	2757.8243268014603	27752.48158089127	10.89873375005735	9.175377827674138	-2.3329789582818607	30510.30590769273	114	0.009117772083552116	middle	166
Container (Base)	238608.52157410304	2175.5781169059997	28334.727790786732	8.421062779776856	11.874985689472538	-2.3329789582818607	30510.30590769273	75	0.009117772083552116	middle	166
Container (Max)	419068.77437782794	3820.97357211056	26689.33233558217	15.701733153478935	6.368723695819758	-2.3329789582818607	30510.30590769273	73	0.009117772083552116	middle	166
Traditional Housing	503493.5122728946	10588.503562017318	4902.206611934927	100	0.9736384863838962	0.8220308851656544	15490.710173952246	140	0.021030069512153568	low	167
ODD Cubes Basic	333240.5387687388	6910.5124230204965	8580.19775093175	38.83832849103638	2.574776100961176	0.8220308851656544	15490.710173952246	80	0.020737310198073566	low	167
Container (Base)	238465.472406341	4945.132472820445	10545.5777011318	22.61284105665902	4.422266081004096	0.8220308851656544	15490.710173952246	112	0.020737310198073566	low	167
Container (Max)	476551.05659050914	9882.387085737098	5608.323088215147	84.9721118228536	1.176856710451965	0.8220308851656544	15490.710173952246	84	0.020737310198073566	low	167
Traditional Housing	547080.1858097063	10656.953508063109	5313.081876458142	100	0.9711705914909918	2.9639602243078267	15970.03538452125	92	0.019479691980235546	low	168
ODD Cubes Basic	327871.13660507655	3900.8460189586694	12069.18936556258	27.165961745583523	3.681077111737353	2.9639602243078267	15970.03538452125	142	0.011897497472176912	low	168
Container (Base)	238044.53694271998	2832.1342765415343	13137.901107979716	18.118916787867747	5.51909372788549	2.9639602243078267	15970.03538452125	105	0.011897497472176912	low	168
Container (Max)	500433.9163864722	5953.911255199645	10016.124129321604	49.962830923938114	2.0014878690968683	2.9639602243078267	15970.03538452125	91	0.011897497472176912	low	168
Traditional Housing	511704.37437330803	8762.272535469461	21252.234354700304	24.077674179239214	4.153225068816	-4.125792816752223	30014.506890169767	139	0.017123700664472035	middle	169
ODD Cubes Basic	314471.91298522946	5733.059264051592	24281.447626118174	12.951118805905537	7.721340642354492	-4.125792816752223	30014.506890169767	72	0.01823075138771096	middle	169
Container (Base)	227692.07898546645	4150.997684935086	25863.50920523468	8.803603454529766	11.358985047031673	-4.125792816752223	30014.506890169767	142	0.01823075138771096	middle	169
Container (Max)	466303.1908881778	8501.057544378697	21513.449345791072	21.674961713166937	4.61361829946176	-4.125792816752223	30014.506890169767	100	0.01823075138771096	middle	169
ODD Cubes Basic	320307.49891405075	7381.723298739143	8177.142344671606	39.171080239635266	2.5529038103681136	-1.2520732389627365	15558.865643410749	47	0.02304573987111025	low	170
Container (Base)	224952.75238616468	5184.202614781827	10374.663028628922	21.682897243544847	4.6119298024054745	-1.2520732389627365	15558.865643410749	105	0.02304573987111025	low	170
Container (Max)	483743.61662124435	11148.229552963281	4410.636090447468	100	0.9117714299268683	-1.2520732389627365	15558.865643410749	132	0.02304573987111025	low	170
Traditional Housing	511452.32613245375	8009.955602752591	22739.25036482107	22.49204867912884	4.446015630972447	-2.5037503638066685	30749.20596757366	117	0.015661196935642066	middle	171
ODD Cubes Basic	299167.21233655704	5299.725899168665	25449.480068404995	11.755336907961706	8.506774478940843	-2.5037503638066685	30749.20596757366	119	0.017714928911416204	middle	171
Container (Base)	237196.75326345346	4201.923622080808	26547.28234549285	8.93487891440324	11.192093475245377	-2.5037503638066685	30749.20596757366	126	0.017714928911416204	middle	171
Container (Max)	435695.87636012834	7718.321476716857	23030.884490856803	18.917895946770884	5.286000107061013	-2.5037503638066685	30749.20596757366	89	0.017714928911416204	middle	171
Traditional Housing	522515.7577505913	12300.13163898375	3365.257463576596	100	0.6440489906110947	-3.0132862685964765	15665.389102560346	115	0.02354021186257675	low	172
ODD Cubes Basic	312625.05283803114	6718.5177901753505	8946.871312384996	34.94238845318696	2.8618535946382733	-3.0132862685964765	15665.389102560346	48	0.021490657032071474	low	172
Container (Base)	225645.68475102965	4849.274021751298	10816.115080809048	20.861990008907274	4.793406571343568	-3.0132862685964765	15665.389102560346	64	0.021490657032071474	low	172
Container (Max)	425307.8122329241	9140.144325758425	6525.244776801921	65.17882880730356	1.5342405168961026	-3.0132862685964765	15665.389102560346	48	0.021490657032071474	low	172
Traditional Housing	528519.5973029012	11005.461006326066	19042.34572097871	27.75496281010369	3.6029592503578067	3.718741242532918	30047.806727304775	98	0.020823184348297115	middle	173
ODD Cubes Basic	313749.69408049405	5965.590420239808	24082.216307064966	13.028273231996913	7.675614275144617	3.718741242532918	30047.806727304775	107	0.019013852548042026	middle	173
Container (Base)	249642.6409990434	4746.668365659602	25301.13836164517	9.866854108725988	10.134942596502224	3.718741242532918	30047.806727304775	144	0.019013852548042026	middle	173
Container (Max)	480368.5812604734	9133.657372798785	20914.14935450599	22.968592846783757	4.353771285296774	3.718741242532918	30047.806727304775	112	0.019013852548042026	middle	173
Traditional Housing	530457.4149431086	12205.165503032427	3531.873695958906	100	0.6658166322998235	0.8757401027436895	15737.039198991333	142	0.023008756516941946	low	174
ODD Cubes Basic	295348.40336758055	4661.501914239065	11075.537284752269	26.66673370096345	3.7499905733257113	0.8757401027436895	15737.039198991333	45	0.015783061161287262	low	174
Container (Base)	243032.27027185532	3835.7931858671886	11901.246013124144	20.420741660482488	4.896981787567321	0.8757401027436895	15737.039198991333	134	0.015783061161287262	low	174
Container (Max)	437559.153868058	6906.022887180663	8831.01631181067	49.54799520445489	2.018245129542778	0.8757401027436895	15737.039198991333	66	0.015783061161287262	low	174
Traditional Housing	515061.60673813743	5700.879853242426	24576.774964588163	20.957249577305085	4.771618509916086	4.795698110815893	30277.65481783059	120	0.011068345570049083	middle	175
ODD Cubes Basic	355899.3827764297	6827.2168926322765	23450.437925198312	15.176662538741054	6.589063948989622	4.795698110815893	30277.65481783059	105	0.019182997282467962	middle	175
Container (Base)	263799.5756671488	5060.466543139117	25217.18827469147	10.461101879938926	9.55922245550139	4.795698110815893	30277.65481783059	44	0.019182997282467962	middle	175
Container (Max)	516570.92447098467	9909.378640328861	20368.276177501728	25.361543606796513	3.9429776653342783	4.795698110815893	30277.65481783059	124	0.019182997282467962	middle	175
Traditional Housing	580935.352337084	8513.616824888999	21750.830047999993	26.708652086153442	3.744105081657901	-3.427869913183029	30264.44687288899	108	0.014655015899168464	middle	176
ODD Cubes Basic	345433.1434415533	3886.450543230974	26377.996329658017	13.095503506957677	7.636208867178702	-3.427869913183029	30264.44687288899	58	0.011250948604729223	middle	176
Container (Base)	258317.12927022716	2906.3127451405207	27358.13412774847	9.442059464436372	10.590909787917687	-3.427869913183029	30264.44687288899	137	0.011250948604729223	middle	176
Container (Max)	432503.47606937244	4866.074380623245	25398.372492265746	17.02878702960504	5.872408870117823	-3.427869913183029	30264.44687288899	110	0.011250948604729223	middle	176
Traditional Housing	539301.5157168165	6853.340052999931	8966.80163788361	60.14424512730776	1.662669467183922	3.686699141740977	15820.14169088354	123	0.01270780788348196	low	177
ODD Cubes Basic	356287.0473418876	6189.593702227884	9630.547988655657	36.99551134178215	2.703030621097581	3.686699141740977	15820.14169088354	47	0.01737249150202321	low	177
Container (Base)	277423.05016279494	4819.529581418515	11000.612109465026	25.21887395012298	3.9652841041902405	3.686699141740977	15820.14169088354	84	0.01737249150202321	low	177
Container (Max)	478348.4002491213	8310.103518334257	7510.0381725492825	63.69453646688269	1.5699933706558014	3.686699141740977	15820.14169088354	121	0.01737249150202321	low	177
Traditional Housing	561771.4548698589	9282.723386364927	21484.165013391874	26.14816328769054	3.824360391962055	-3.770399480462979	30766.8883997568	96	0.01652402112263853	middle	178
ODD Cubes Basic	355538.03901217587	5716.5896426250965	25050.298757131706	14.192966018457398	7.045743635964034	-3.770399480462979	30766.8883997568	92	0.016078700491536785	middle	178
Container (Base)	232902.35329922236	3744.7671824722806	27022.12121728452	8.618951540719458	11.602339278456206	-3.770399480462979	30766.8883997568	144	0.016078700491536785	middle	178
Container (Max)	413233.5702992446	6644.258809889965	24122.629589866836	17.130535821552023	5.8375290207904325	-3.770399480462979	30766.8883997568	134	0.016078700491536785	middle	178
Traditional Housing	593753.3571276235	13296.108078601852	17355.685267353103	34.21088525063904	2.9230462546458678	3.276955594478215	30651.793345954953	108	0.02239331857073431	middle	179
ODD Cubes Basic	306425.8631074392	7273.155373038151	23378.637972916804	13.107087909159679	7.629459777264223	3.276955594478215	30651.793345954953	41	0.023735448761673338	middle	179
Container (Base)	245429.71814807085	5825.384499695465	24826.40884625949	9.885832448338533	10.115486027360959	3.276955594478215	30651.793345954953	138	0.023735448761673338	middle	179
Container (Max)	505949.1192730977	12008.929396520363	18642.86394943459	27.139023309154297	3.6847309816882348	3.276955594478215	30651.793345954953	140	0.023735448761673338	middle	179
Traditional Housing	590070.4004772814	12910.896806350114	2586.3429742808275	100	0.43831091547531464	2.06883226778716	15497.239780630942	106	0.02188026512752897	low	180
ODD Cubes Basic	321922.59047055274	4242.255999359639	11254.983781271303	28.60267031270569	3.4961770669215686	2.06883226778716	15497.239780630942	131	0.013177876063803889	low	180
Container (Base)	278339.38432309724	3667.9219102852544	11829.317870345687	23.5296225339292	4.249961930150056	2.06883226778716	15497.239780630942	122	0.013177876063803889	low	180
Container (Max)	421811.77467960166	5558.583288980962	9938.656491649981	42.44152869494878	2.3561828019616455	2.06883226778716	15497.239780630942	84	0.013177876063803889	low	180
Traditional Housing	574391.9376980191	17140.814433309202	13322.794524784964	43.11347267492967	2.3194605721971837	4.892037773220528	30463.608958094166	114	0.029841669613268174	middle	181
ODD Cubes Basic	334909.7300010564	6029.56135362111	24434.047604473057	13.706682389361704	7.295711475565665	4.892037773220528	30463.608958094166	114	0.018003541890532986	middle	181
Container (Base)	247696.2053193024	4459.40900859212	26004.199949502046	9.525238453800057	10.498424841018588	4.892037773220528	30463.608958094166	41	0.018003541890532986	middle	181
Container (Max)	459987.6240771853	8281.406459200345	22182.20249889382	20.736787706275962	4.822347675852183	4.892037773220528	30463.608958094166	75	0.018003541890532986	middle	181
Traditional Housing	601751.557986371	10887.277770873601	19181.684969578208	31.37115216628454	3.187641928799568	2.587832191820281	30068.96274045181	86	0.01809264575451284	middle	182
ODD Cubes Basic	323767.1487777845	8026.723545397313	22042.2391950545	14.688487222769382	6.808053033874368	2.587832191820281	30068.96274045181	135	0.02479165528589932	middle	182
Container (Base)	253253.74190865157	6278.5794692634045	23790.383271188406	10.64521487618727	9.393892106743117	2.587832191820281	30068.96274045181	138	0.02479165528589932	middle	182
Container (Max)	451213.294545365	11186.324458783645	18882.638281668165	23.89567007611518	4.1848585823903965	2.587832191820281	30068.96274045181	91	0.02479165528589932	middle	182
Traditional Housing	536524.0090479777	10844.247991321008	19258.035054043426	27.859748283889893	3.5894078791022586	1.2306624521339362	30102.283045364435	100	0.020212046075185574	middle	183
ODD Cubes Basic	311303.78162783507	5940.9382933900015	24161.344751974433	12.884373151556298	7.761339944421048	1.2306624521339362	30102.283045364435	118	0.01908405436748731	middle	183
Container (Base)	275355.24549638096	5254.89447542575	24847.388569938685	11.081858551104087	9.023757119696947	1.2306624521339362	30102.283045364435	96	0.01908405436748731	middle	183
Container (Max)	412390.0957230699	7870.075007392363	22232.208037972072	18.549218998792995	5.391062556677293	1.2306624521339362	30102.283045364435	61	0.01908405436748731	middle	183
Traditional Housing	517508.93499436334	11477.891243074328	4156.9185975185555	100	0.8032554254476462	2.4165574455146572	15634.809840592883	101	0.02217911704886669	low	184
ODD Cubes Basic	329421.2014469636	2719.2055406016375	12915.604299991246	25.505674670382003	3.920696131050522	2.4165574455146572	15634.809840592883	88	0.00825449463682873	low	184
Container (Base)	270697.5295539676	2234.471305906012	13400.33853468687	20.200797827104527	4.950299530537575	2.4165574455146572	15634.809840592883	41	0.00825449463682873	low	184
Container (Max)	463408.52486517926	3825.2031831603354	11809.606657432549	39.23996271065695	2.5484224013505905	2.4165574455146572	15634.809840592883	108	0.00825449463682873	low	184
Traditional Housing	538901.1357855123	14744.359077908572	16099.224850637496	33.473731858846165	2.9874171311906714	-4.868351006313665	30843.583928546068	126	0.027360044540297584	middle	185
ODD Cubes Basic	297117.08989385935	4857.823495036211	25985.76043350986	11.433842417430775	8.745966259562142	-4.868351006313665	30843.583928546068	46	0.016349862260604385	middle	185
Container (Base)	241268.9394656623	3944.7139280256756	26898.870000520394	8.969482341116732	11.148915421974023	-4.868351006313665	30843.583928546068	102	0.016349862260604385	middle	185
Container (Max)	457443.6201908714	7479.140182112975	23364.44374643309	19.578622335518112	5.107611673911666	-4.868351006313665	30843.583928546068	138	0.016349862260604385	middle	185
Traditional Housing	527803.6580945741	6039.823745066306	24811.689218622894	21.272379056659343	4.700931651022591	-2.1761521197636413	30851.5129636892	117	0.011443315430724174	middle	186
ODD Cubes Basic	306376.2277294481	6168.664594377231	24682.84836931197	12.412515085186188	8.056384972240298	-2.1761521197636413	30851.5129636892	102	0.02013427947753374	middle	186
Container (Base)	242909.60707834273	4890.809916693261	25960.703046995943	9.356819291011117	10.687392466376657	-2.1761521197636413	30851.5129636892	69	0.02013427947753374	middle	186
Container (Max)	461208.21432169003	9286.095084487186	21565.417879202018	21.386472402488685	4.675852946573988	-2.1761521197636413	30851.5129636892	118	0.02013427947753374	middle	186
Traditional Housing	566446.06126616	11483.434264460915	4301.339725759877	100	0.7593555714987621	-2.409885274430498	15784.773990220792	119	0.020272776261860373	low	187
ODD Cubes Basic	329475.8804434096	7731.573354309978	8053.2006359108145	40.91241424859223	2.4442458807827734	-2.409885274430498	15784.773990220792	111	0.023466280274916644	low	187
Container (Base)	226533.67085762016	5315.902612050631	10468.87137817016	21.638786328962965	4.62133127430315	-2.409885274430498	15784.773990220792	64	0.023466280274916644	low	187
Container (Max)	407338.43786742963	9558.717949743823	6226.056040476969	65.42479464033607	1.5284725087749444	-2.409885274430498	15784.773990220792	98	0.023466280274916644	low	187
Traditional Housing	592704.670870549	6057.47120319111	9419.788491993073	62.921229215959016	1.5892887225196883	-1.944448292674358	15477.259695184184	140	0.010220049715980905	low	188
ODD Cubes Basic	311719.48086211045	7682.405464910456	7794.854230273728	39.99041824944608	2.5005990028970286	-1.944448292674358	15477.259695184184	144	0.024645252980864483	low	188
Container (Base)	242803.66622596755	5983.957778820351	9493.301916363833	25.576313527692722	3.9098676160551875	-1.944448292674358	15477.259695184184	144	0.024645252980864483	low	188
Container (Max)	465885.99230148154	11481.878140511095	3995.3815546730893	100	0.8575878263555133	-1.944448292674358	15477.259695184184	67	0.024645252980864483	low	188
Traditional Housing	551319.8874878632	14688.470528919903	16243.721038523307	33.94049221729203	2.9463332281625516	0.9627103487483311	30932.19156744321	147	0.026642373805612546	middle	189
ODD Cubes Basic	331527.90163848177	3037.630146261099	27894.56142118211	11.88503725270015	8.41394081261976	0.9627103487483311	30932.19156744321	77	0.009162517336394558	middle	189
Container (Base)	274057.25779626175	2511.054375723001	28421.13719172021	9.642726677245747	10.37051068096467	0.9627103487483311	30932.19156744321	115	0.009162517336394558	middle	189
Container (Max)	471463.74002703984	4319.794691479169	26612.39687596404	17.715944273056426	5.644632792850144	0.9627103487483311	30932.19156744321	46	0.009162517336394558	middle	189
Traditional Housing	564608.755486168	8142.163134356826	7474.582389246303	75.53716396229329	1.3238516612818305	-2.8755649252808926	15616.74552360313	137	0.014420894212569993	low	190
ODD Cubes Basic	303579.0583073106	4642.649577410267	10974.095946192861	27.663240762226835	3.6149054573731085	-2.8755649252808926	15616.74552360313	102	0.015293049538056575	low	190
Container (Base)	244798.4336565858	3743.714572748823	11873.030950854307	20.61802371019438	4.850125376010504	-2.8755649252808926	15616.74552360313	100	0.015293049538056575	low	190
Container (Max)	408489.5780155429	6247.0513523715235	9369.694171231606	43.59689553899801	2.2937413034501195	-2.8755649252808926	15616.74552360313	45	0.015293049538056575	low	190
Traditional Housing	563576.9636658104	12796.403709880651	2946.91558491823	100	0.5228949681956288	3.6530228145556105	15743.319294798881	114	0.02270568979016796	low	191
ODD Cubes Basic	332888.2275019378	7012.825125026003	8730.49416977288	38.129368284154964	2.6226503217876806	3.6530228145556105	15743.319294798881	130	0.021066605982589696	low	191
Container (Base)	259254.2167980291	5461.606434608966	10281.712860189915	25.215080436825232	3.9658806661570485	3.6530228145556105	15743.319294798881	140	0.021066605982589696	low	191
Container (Max)	431609.8232509837	9092.554084643654	6650.765210155227	64.89626525861226	1.5409207232727338	3.6530228145556105	15743.319294798881	119	0.021066605982589696	low	191
Traditional Housing	587458.5607103035	14846.380123766503	16103.55585305416	36.480052360540455	2.7412241356365885	4.769688592821389	30949.935976820663	137	0.02527221682805262	middle	192
ODD Cubes Basic	337282.0509997456	4095.718291127067	26854.217685693595	12.559742195708436	7.961946864973806	4.769688592821389	30949.935976820663	102	0.012143303442880678	middle	192
Container (Base)	278540.542760747	3382.402331888432	27567.53364493223	10.103934082327724	9.897135035243835	4.769688592821389	30949.935976820663	118	0.012143303442880678	middle	192
Container (Max)	447581.08788627037	5435.112965497626	25514.82301132304	17.542002454323967	5.700603466473166	4.769688592821389	30949.935976820663	101	0.012143303442880678	middle	192
Traditional Housing	509642.31451198616	9641.348809999998	20623.465274203234	24.711769226749198	4.046654817889576	0.27023225905909865	30264.814084203234	123	0.018917873448620885	middle	193
ODD Cubes Basic	355786.08364085597	3624.349593679818	26640.464490523416	13.35510061273206	7.487775861805577	0.27023225905909865	30264.814084203234	127	0.010186878465258845	middle	193
Container (Base)	236615.53734696124	2410.3737219454097	27854.440362257825	8.494715178969106	11.772025064192409	0.27023225905909865	30264.814084203234	58	0.010186878465258845	middle	193
Container (Max)	469216.6705028641	4779.853196286082	25484.96088791715	18.411512286264784	5.431384366758468	0.27023225905909865	30264.814084203234	81	0.010186878465258845	middle	193
Traditional Housing	584841.052815601	7836.7070455103685	8044.428297857762	72.70138177144852	1.3754896752082402	3.909498239120598	15881.13534336813	139	0.013399721185409438	low	194
ODD Cubes Basic	330672.38541082357	4427.518621395108	11453.616721973023	28.870564943599867	3.463735475746843	3.909498239120598	15881.13534336813	97	0.013389441685293466	low	194
Container (Base)	268981.3777117576	3601.5104713014744	12279.624872066655	21.904690128085985	4.565232350481002	3.909498239120598	15881.13534336813	148	0.013389441685293466	low	194
Container (Max)	496822.52246965014	6652.176192547783	9228.959150820348	53.832996153795776	1.8575967741849158	3.909498239120598	15881.13534336813	108	0.013389441685293466	low	194
Traditional Housing	596665.726347433	15093.680278196536	15722.470428078263	37.94987111452069	2.635055062459413	-0.47543598841387613	30816.1507062748	133	0.02529671072376566	middle	195
ODD Cubes Basic	329515.6480547315	5631.721611722605	25184.429094552193	13.084102356166222	7.642862863486574	-0.47543598841387613	30816.1507062748	47	0.017090907958298825	middle	195
Container (Base)	255326.10726860014	4363.754998678378	26452.39570759642	9.652286699887727	10.36023929968462	-0.47543598841387613	30816.1507062748	91	0.017090907958298825	middle	195
Container (Max)	433706.0411433611	7412.430030139347	23403.720676135454	18.53149963397089	5.396217358291161	-0.47543598841387613	30816.1507062748	137	0.017090907958298825	middle	195
Traditional Housing	559088.955708457	9615.116871068894	20862.8451973507	26.798308208673944	3.731578845250854	-2.9993373874730036	30477.962068419594	128	0.01719783010001507	middle	196
ODD Cubes Basic	319212.7137874914	7537.4615959995535	22940.50047242004	13.91481036655069	7.186587338652231	-2.9993373874730036	30477.962068419594	95	0.023612660995130187	middle	196
Container (Base)	222464.4475887626	5252.977584382358	25224.984484037235	8.819210482747435	11.338883474390913	-2.9993373874730036	30477.962068419594	116	0.023612660995130187	middle	196
Container (Max)	421134.7947090226	9944.113140717896	20533.8489277017	20.50929643983502	4.875837661879561	-2.9993373874730036	30477.962068419594	45	0.023612660995130187	middle	196
Traditional Housing	597256.1930889455	10244.242501053233	5337.289993257555	100	0.8936349350608922	-3.839398672700268	15581.532494310788	104	0.01715217459373858	low	197
ODD Cubes Basic	320567.7994962472	2794.0505658547677	12787.48192845602	25.068876053141217	3.9890101091097643	-3.839398672700268	15581.532494310788	112	0.008715942681222033	low	197
Container (Base)	224390.12328262383	1955.7714527636947	13625.761041547094	16.468080028588712	6.072353293547228	-3.839398672700268	15581.532494310788	44	0.008715942681222033	low	197
Container (Max)	442618.72955656424	3857.8394764503305	11723.693017860458	37.75420670621935	2.6487114609013025	-3.839398672700268	15581.532494310788	122	0.008715942681222033	low	197
Traditional Housing	504413.61703062605	10591.761958897188	5347.326990651925	94.33004899689702	1.060107580388191	3.236072239067841	15939.088949549114	113	0.020998168172478376	low	198
ODD Cubes Basic	339063.47062389797	4241.177872037412	11697.9110775117	28.984958799671542	3.4500652801042864	3.236072239067841	15939.088949549114	108	0.012508507225014183	low	198
Container (Base)	262348.84752028645	3281.5924546816473	12657.496494867466	20.72675648195259	4.8246815697899	3.236072239067841	15939.088949549114	81	0.012508507225014183	low	198
Container (Max)	494003.70959242556	6179.248970620663	9759.83997892845	50.615964058732764	1.975661273268725	3.236072239067841	15939.088949549114	147	0.012508507225014183	low	198
Traditional Housing	591970.4533080405	11945.306656800223	3684.0994489574805	100	0.6223451573250067	-0.12475671251601295	15629.406105757704	120	0.02017888999366039	low	199
ODD Cubes Basic	353949.9140723012	5092.446297401564	10536.95980835614	33.59127495120631	2.9769635164267223	-0.12475671251601295	15629.406105757704	97	0.014387477139947355	low	199
Container (Base)	253187.06573386054	3642.7231203762667	11986.682985381438	21.122362712239834	4.734318852599417	-0.12475671251601295	15629.406105757704	97	0.014387477139947355	low	199
Container (Max)	470710.6166025654	6772.338235899933	8857.06786985777	53.14519697929381	1.881637583147195	-0.12475671251601295	15629.406105757704	109	0.014387477139947355	low	199
Traditional Housing	500098.18495371146	11382.281728499449	19243.82041434147	25.987468921764254	3.848008449805243	-3.2069555681902884	30626.10214284092	84	0.02276009405943551	middle	200
ODD Cubes Basic	304845.30178444623	4933.995742263408	25692.10640057751	11.86532925839019	8.427916143101397	-3.2069555681902884	30626.10214284092	99	0.016185244494114587	middle	200
Container (Base)	236608.13104088217	3829.560450192181	26796.541692648738	8.829801015173251	11.325283528831354	-3.2069555681902884	30626.10214284092	138	0.016185244494114587	middle	200
Container (Max)	406413.4893133559	6577.901690242891	24048.200452598026	16.89995432774469	5.917175754482944	-3.2069555681902884	30626.10214284092	89	0.016185244494114587	middle	200
Traditional Housing	581670.018161975	8165.650933950259	7410.578614097478	78.49184907848327	1.2740176358950461	3.2078476113587815	15576.229548047737	80	0.014038287480852087	low	201
ODD Cubes Basic	337918.9895252272	7381.504394429443	8194.725153618294	41.236159015781354	2.4250561251771616	3.2078476113587815	15576.229548047737	110	0.021844005880818897	low	201
Container (Base)	269153.7960468664	5879.3971036924795	9696.832444355257	27.756878093067066	3.6027106385922187	3.2078476113587815	15576.229548047737	57	0.021844005880818897	low	201
Container (Max)	432667.793641859	9451.197828753706	6125.031719294031	70.63927396146255	1.4156430890633909	3.2078476113587815	15576.229548047737	75	0.021844005880818897	low	201
Traditional Housing	561560.0457897985	10195.668697407285	20110.095256932196	27.92428571894615	3.581112190531402	0.8417683253946775	30305.763954339483	110	0.018155972409090688	middle	202
ODD Cubes Basic	348470.00013461127	4251.066797282131	26054.69715705735	13.37455576758536	7.476883848535778	0.8417683253946775	30305.763954339483	108	0.012199233206990491	middle	202
Container (Base)	237098.01529669727	2892.4139815190088	27413.349972820473	8.648998226476259	11.562032663376048	0.8417683253946775	30305.763954339483	115	0.012199233206990491	middle	202
Container (Max)	474481.5278329449	5788.310810443244	24517.45314389624	19.352806551649095	5.167209196925434	0.8417683253946775	30305.763954339483	130	0.012199233206990491	middle	202
Traditional Housing	560750.7580946992	14609.965453231765	1011.9989472584712	100	0.18047214964042285	1.704690539624477	15621.964400490237	113	0.02605429460830875	low	203
ODD Cubes Basic	321429.9786058946	7124.325934525464	8497.638465964774	37.82580064959274	2.6436981711602363	1.704690539624477	15621.964400490237	125	0.02216447254056723	low	203
Container (Base)	242433.28646362876	5373.405920742569	10248.558479747668	23.655354745031204	4.227372663730819	1.704690539624477	15621.964400490237	92	0.02216447254056723	low	203
Container (Max)	454554.92820592446	10074.970224399722	5546.994176090515	81.94617008346884	1.2203132849057114	1.704690539624477	15621.964400490237	107	0.02216447254056723	low	203
Traditional Housing	535744.9836804629	9281.812441623935	6541.837075231691	81.8951889995653	1.221072949725176	-0.46734233415052806	15823.649516855627	109	0.01732505711553229	low	204
ODD Cubes Basic	327367.6223943029	5510.777602599932	10312.871914255695	31.743594327180183	3.1502418714561204	-0.46734233415052806	15823.649516855627	58	0.016833606091815615	low	204
Container (Base)	256917.38777678207	4324.8461039725935	11498.803412883033	22.34296722465373	4.475681273419125	-0.46734233415052806	15823.649516855627	40	0.016833606091815615	low	204
Container (Max)	409138.324962646	6887.273399486435	8936.376117369193	45.783471911776864	2.184194335298478	-0.46734233415052806	15823.649516855627	126	0.016833606091815615	low	204
Traditional Housing	522246.2087417663	14626.475413629623	1119.9228278632236	100	0.21444345772493467	-0.6157542125575972	15746.398241492847	105	0.028006858008349733	low	205
ODD Cubes Basic	326796.7894466332	4364.923266214186	11381.474975278661	28.713043797614816	3.4827376959703233	-0.6157542125575972	15746.398241492847	134	0.013356689561134717	low	205
Container (Base)	230927.07114384885	3084.42120053046	12661.977040962387	18.237836824121818	5.483106410280933	-0.6157542125575972	15746.398241492847	70	0.013356689561134717	low	205
Container (Max)	484395.08739177947	6469.91480723072	9276.483434262127	52.21753381272646	1.9150655478797813	-0.6157542125575972	15746.398241492847	60	0.013356689561134717	low	205
Traditional Housing	522903.65632665163	10403.273971076478	20456.604982020806	25.56160500660929	3.912117411021087	-2.2956172685418785	30859.878953097286	114	0.019895202194910026	middle	206
ODD Cubes Basic	339736.2999508075	6416.163804470549	24443.71514862674	13.8987178456747	7.194908272141099	-2.2956172685418785	30859.878953097286	103	0.018885717556232834	middle	206
Container (Base)	234985.1083124896	4437.862385510459	26422.016567586827	8.893534212704918	11.244123832923961	-2.2956172685418785	30859.878953097286	115	0.018885717556232834	middle	206
Container (Max)	408136.2675370679	7707.946273160143	23151.93267993714	17.628604625770535	5.672598717984412	-2.2956172685418785	30859.878953097286	67	0.018885717556232834	middle	206
Traditional Housing	592307.130271024	10787.114872370745	19935.706626350042	29.710867107571765	3.3657718449595557	4.798648279782489	30722.821498720787	92	0.018212029403452984	middle	207
ODD Cubes Basic	332255.14355646237	4293.060609425303	26429.760889295485	12.57125045315985	7.954658160108844	4.798648279782489	30722.821498720787	81	0.012920975619737107	middle	207
Container (Base)	266981.33820941777	3449.6593619286737	27273.162136792114	9.789159646040966	10.215381464377593	4.798648279782489	30722.821498720787	147	0.012920975619737107	middle	207
Container (Max)	463696.17665929504	5991.406993580062	24731.414505140725	18.749278435445337	5.333538586261055	4.798648279782489	30722.821498720787	48	0.012920975619737107	middle	207
Traditional Housing	515010.7647716009	12754.88190324599	17251.733951941635	29.852695746773783	3.3497812341053694	3.1738890961857535	30006.615855187625	87	0.024766243301540654	middle	208
ODD Cubes Basic	330183.91496702225	6752.086813545182	23254.529041642443	14.198692838532828	7.0429018457682995	3.1738890961857535	30006.615855187625	138	0.020449472271293286	middle	208
Container (Base)	236749.4230979548	4841.400762886309	25165.215092301318	9.40780447254681	10.629472614127232	3.1738890961857535	30006.615855187625	146	0.020449472271293286	middle	208
Container (Max)	475075.72345786396	9715.047833616187	20291.56802157144	23.412469797938893	4.271228147352633	3.1738890961857535	30006.615855187625	100	0.020449472271293286	middle	208
Traditional Housing	581404.2614094627	6375.687856138427	23951.344266354005	24.27438956844684	4.119568062382314	0.4320872813775143	30327.03212249243	115	0.010966015007668225	middle	209
ODD Cubes Basic	321254.57509457617	7824.962637675198	22502.06948481723	14.276667988752568	7.004435494247111	0.4320872813775143	30327.03212249243	96	0.024357513462248927	middle	209
Container (Base)	264991.0568959529	6454.523235718744	23872.508886773685	11.100260058663899	9.008797944508398	0.4320872813775143	30327.03212249243	96	0.024357513462248927	middle	209
Container (Max)	472522.6701112656	11509.47729845296	18817.55482403947	25.11073699690338	3.9823602155656306	0.4320872813775143	30327.03212249243	147	0.024357513462248927	middle	209
Traditional Housing	584384.9095894002	13133.008524164565	16941.849650967903	34.493571931563785	2.899090885641035	0.9514114170543087	30074.858175132467	106	0.022473216383003564	middle	210
ODD Cubes Basic	314645.95985956915	5301.422487911093	24773.435687221376	12.700941598579712	7.873431999024587	0.9514114170543087	30074.858175132467	101	0.016848849704846652	middle	210
Container (Base)	247423.33133453818	4168.798523128109	25906.05965200436	9.550789840607619	10.470338230543456	0.9514114170543087	30074.858175132467	54	0.016848849704846652	middle	210
Container (Max)	449528.9876226971	7574.0463504266945	22500.811824705772	19.97834527592985	5.005419548959402	0.9514114170543087	30074.858175132467	70	0.016848849704846652	middle	210
Traditional Housing	553026.719986662	10248.262748091087	20481.405933094917	27.001404190376054	3.7035110950134364	-2.577889996362097	30729.668681186005	125	0.018531225305602333	middle	211
ODD Cubes Basic	320812.96085377736	4230.550109970905	26499.1185712151	12.106552147823637	8.259990026803523	-2.577889996362097	30729.668681186005	148	0.013186967567370629	middle	211
Container (Base)	241644.35376581876	3186.556255948087	27543.11242523792	8.773313271030277	11.39820235648062	-2.577889996362097	30729.668681186005	138	0.013186967567370629	middle	211
Container (Max)	460091.2761358732	6067.208736433924	24662.45994475208	18.655530598592048	5.36034070280194	-2.577889996362097	30729.668681186005	48	0.013186967567370629	middle	211
Traditional Housing	588602.7297167891	6983.25322573594	8816.92726091187	66.75826082021166	1.4979419591129326	0.1791346466743402	15800.18048664781	96	0.011864119673885964	low	212
ODD Cubes Basic	330223.6837840644	6854.0029051431775	8946.177581504633	36.91226568839526	2.70912657717022	0.1791346466743402	15800.18048664781	107	0.020755636987034094	low	212
Container (Base)	265997.59084125864	5520.94943492679	10279.23105172102	25.877187651767343	3.864407575727043	0.1791346466743402	15800.18048664781	91	0.020755636987034094	low	212
Container (Max)	425094.10264226416	8823.098879771846	6977.081606875965	60.927208049756906	1.6413028464776172	0.1791346466743402	15800.18048664781	53	0.020755636987034094	low	212
Traditional Housing	582211.4835928835	15524.627717942247	26.718855010731204	100	0.004589200962826525	-3.8674527887546706	15551.346572952978	139	0.026664928733693583	low	213
ODD Cubes Basic	297705.1148029935	5203.235248300833	10348.111324652145	28.769029000854985	3.475960206965209	-3.8674527887546706	15551.346572952978	80	0.017477816099142524	low	213
Container (Base)	261964.3392112665	4578.564545267906	10972.782027685073	23.87401285747887	4.188654860704475	-3.8674527887546706	15551.346572952978	75	0.017477816099142524	low	213
Container (Max)	457187.4973529802	7990.6390015625975	7560.7075713903805	60.46887715681159	1.6537432924490045	-3.8674527887546706	15551.346572952978	101	0.017477816099142524	low	213
Traditional Housing	539172.8006088655	15607.008409955084	14583.81265494521	36.97063404239754	2.7048494728362256	-0.14881127823696438	30190.821064900294	130	0.02894620869660105	middle	214
ODD Cubes Basic	314651.041838264	4991.840166740502	25198.980898159793	12.486657421183331	8.008548375032078	-0.14881127823696438	30190.821064900294	147	0.01586468659876993	middle	214
Container (Base)	238331.13386928826	3781.0487455657394	26409.772319334556	9.024353977289172	11.081125613164284	-0.14881127823696438	30190.821064900294	77	0.01586468659876993	middle	214
Container (Max)	465458.02750698826	7384.345731280002	22806.475333620292	20.409029483869027	4.899792029750284	-0.14881127823696438	30190.821064900294	54	0.01586468659876993	middle	214
Traditional Housing	553641.4929511006	6970.539614169588	8848.22716664362	62.57089499671065	1.598187144442428	3.285807769748274	15818.76678081321	116	0.01259034899464309	low	215
ODD Cubes Basic	341086.29627301096	4819.2084968801955	10999.558283933015	31.00909031694787	3.2248608062309225	3.285807769748274	15818.76678081321	77	0.014129000635730096	low	215
Container (Base)	275202.83970006765	3888.3410970769837	11930.425683736226	23.067311007622234	4.335139018455882	3.285807769748274	15818.76678081321	123	0.014129000635730096	low	215
Container (Max)	438658.9925618633	6197.81318477529	9620.95359603792	45.59412829332333	2.193264872982421	3.285807769748274	15818.76678081321	87	0.014129000635730096	low	215
ODD Cubes Basic	338161.01262793405	7056.545182578402	8663.033312348194	39.03494312389668	2.561807242362326	3.3312264553036144	15719.578494926596	63	0.0208674120287854	low	216
Container (Base)	240760.2414504479	5024.0431584963535	10695.535336430243	22.510349774675646	4.442400984479635	3.3312264553036144	15719.578494926596	116	0.0208674120287854	low	216
Container (Max)	433253.02743780083	9040.869436263256	6678.70905866334	64.87077422182409	1.5415262296400587	3.3312264553036144	15719.578494926596	59	0.0208674120287854	low	216
Traditional Housing	586254.3886002449	6389.570776033989	24256.215100405032	24.169244301863714	4.137489726655993	-4.4648940333720155	30645.785876439022	100	0.010898973040167566	middle	217
ODD Cubes Basic	329181.2714448132	3260.4202103920857	27385.365666046935	12.020335074544592	8.319235643586138	-4.4648940333720155	30645.785876439022	115	0.009904634598687036	middle	217
Container (Base)	224740.49992602575	2225.972531293536	28419.813345145485	7.907880927881417	12.645612764277015	-4.4648940333720155	30645.785876439022	99	0.009904634598687036	middle	217
Container (Max)	414372.24894456554	4104.205713632102	26541.58016280692	15.612192130340116	6.40525040719067	-4.4648940333720155	30645.785876439022	116	0.009904634598687036	middle	217
Traditional Housing	512997.6402158175	5371.413692145221	10334.646968008361	49.63862256774115	2.0145603328039847	-1.608081659726488	15706.060660153582	100	0.01047064015710769	low	218
ODD Cubes Basic	319130.2299462589	3139.203233269799	12566.857426883784	25.394593023993107	3.9378461354162613	-1.608081659726488	15706.060660153582	115	0.009836746690523292	low	218
Container (Base)	257033.32698122674	2528.3717285367734	13177.688931616809	19.505190046225394	5.1268405877107455	-1.608081659726488	15706.060660153582	148	0.009836746690523292	low	218
Container (Max)	405286.157629943	3986.697269781243	11719.363390372338	34.58260863921095	2.8916268591322103	-1.608081659726488	15706.060660153582	95	0.009836746690523292	low	218
Traditional Housing	499692.3855643016	13154.228097967301	2365.6640208766676	100	0.4734240683305846	-0.013031190797899939	15519.892118843969	95	0.026324651881801754	low	219
ODD Cubes Basic	354842.25974808837	6995.912542104774	8523.979576739195	41.62870834608821	2.4021883928905727	-0.013031190797899939	15519.892118843969	140	0.019715556278644353	low	219
Container (Base)	231822.12179563098	4570.502088896508	10949.39002994746	21.172149422166793	4.723186012247869	-0.013031190797899939	15519.892118843969	69	0.019715556278644353	low	219
Container (Max)	407973.0858886976	8043.416335010824	7476.475783833145	54.56756601430897	1.832590443447258	-0.013031190797899939	15519.892118843969	48	0.019715556278644353	low	219
Traditional Housing	496203.40619353415	5348.835611905694	10380.473693643275	47.80161492027054	2.0919795317959946	-2.624117038482031	15729.30930554897	80	0.010779522157934339	low	220
ODD Cubes Basic	309555.53520620585	4582.075570725396	11147.233734823574	27.769717812515676	3.6010448746774983	-2.624117038482031	15729.30930554897	140	0.014802111574820052	low	220
Container (Base)	242150.92980645818	3584.3450809416127	12144.964224607356	19.938381482905264	5.015452236468533	-2.624117038482031	15729.30930554897	74	0.014802111574820052	low	220
Container (Max)	396069.9576297599	5862.6717042699565	9866.637601279013	40.14234368741965	2.4911350662203455	-2.624117038482031	15729.30930554897	109	0.014802111574820052	low	220
Traditional Housing	505997.33497139165	9486.230838970554	6415.992555603374	78.8650127920553	1.2679893968149307	-2.3304908414320655	15902.223394573928	147	0.0187475905174617	low	221
ODD Cubes Basic	348190.3908597998	5841.72334862943	10060.500045944498	34.60965054119346	2.8893675156002216	-2.3304908414320655	15902.223394573928	42	0.01677738243782156	low	221
Container (Base)	240932.1758975608	4042.2112566098717	11860.012137964057	20.314665203953183	4.922552205317184	-2.3304908414320655	15902.223394573928	70	0.01677738243782156	low	221
Container (Max)	441650.13167971023	7409.73316290475	8492.490231669177	52.00478536116079	1.9228999659459016	-2.3304908414320655	15902.223394573928	84	0.01677738243782156	low	221
Traditional Housing	597761.2604915017	11472.010131432444	4299.090483174399	100	0.7191985776461202	4.547436351492246	15771.100614606843	130	0.01919162530204739	low	222
ODD Cubes Basic	335227.2042313094	7171.458233603382	8599.642381003461	38.98152846120945	2.565317573411984	4.547436351492246	15771.100614606843	49	0.02139282893238885	low	222
Container (Base)	263077.90988635947	5627.980722089297	10143.119892517545	25.936586836603283	3.855557426657001	4.547436351492246	15771.100614606843	58	0.02139282893238885	low	222
Container (Max)	438376.95298563916	9378.123163123648	6392.977451483195	68.57164072805138	1.458328821335784	4.547436351492246	15771.100614606843	109	0.02139282893238885	low	222
Traditional Housing	511359.85294686106	9489.482496602317	6186.85853030418	82.65258538596643	1.2098835085802286	1.3466074459800232	15676.341026906497	97	0.018557347515485215	low	223
ODD Cubes Basic	347214.64109499607	7158.2642886788335	8518.076738227664	40.76209357644742	2.453259664213631	1.3466074459800232	15676.341026906497	109	0.0206162512793358	low	223
Container (Base)	264125.6821850723	5445.281433253437	10231.059593653059	25.816063308723695	3.873557281144731	1.3466074459800232	15676.341026906497	102	0.0206162512793358	low	223
Container (Max)	498769.3989758306	10282.755259729016	5393.585767177481	92.47454671270421	1.0813786447710365	1.3466074459800232	15676.341026906497	140	0.0206162512793358	low	223
Traditional Housing	597873.8870735728	16634.378080418097	13696.547595866214	43.65142988690219	2.290875700042198	-3.282540515202965	30330.92567628431	85	0.027822553284336887	middle	224
ODD Cubes Basic	310131.9195148322	4048.7892822145063	26282.136394069803	11.800103114327081	8.474502216729372	-3.282540515202965	30330.92567628431	64	0.013055055050600398	middle	224
Container (Base)	231887.81465176365	3027.308185842196	27303.617490442113	8.492933756229853	11.774494287871565	-3.282540515202965	30330.92567628431	58	0.013055055050600398	middle	224
Container (Max)	460280.21032286005	6008.983484466868	24321.94219181744	18.9244841835744	5.284159876166955	-3.282540515202965	30330.92567628431	117	0.013055055050600398	middle	224
Traditional Housing	514952.1797886103	6419.8452470316915	9344.674713488002	55.10648530604644	1.814668445004743	3.197890785019979	15764.519960519694	139	0.012466876535345594	low	225
ODD Cubes Basic	332131.284049688	7106.89777932099	8657.622181198705	38.36287575253166	2.606686752189081	3.197890785019979	15764.519960519694	129	0.021397857174627888	low	225
Container (Base)	264966.9780776757	5669.725552898863	10094.794407620831	26.247882559910778	3.8098311272061682	3.197890785019979	15764.519960519694	135	0.021397857174627888	low	225
Container (Max)	449124.2232901191	9610.295983627651	6154.223976892043	72.97820569685086	1.3702721113122018	3.197890785019979	15764.519960519694	75	0.021397857174627888	low	225
Traditional Housing	517885.3481821661	12004.229655027542	18374.855308061473	28.18445857121704	3.54805467514368	-0.8666161241597834	30379.084963089015	126	0.02317931893065462	middle	226
ODD Cubes Basic	305486.89389279136	3300.517275451016	27078.567687638	11.281501201123474	8.864068550561468	-0.8666161241597834	30379.084963089015	58	0.01080412070512364	middle	226
Container (Base)	267629.61576087	2891.5026729462998	27487.582290142716	9.736382521239209	10.270755055263828	-0.8666161241597834	30379.084963089015	112	0.01080412070512364	middle	226
Container (Max)	406348.0890661628	4390.233802567155	25988.85116052186	15.635477172743302	6.395711425700903	-0.8666161241597834	30379.084963089015	102	0.01080412070512364	middle	226
Traditional Housing	547643.2264639147	11560.82428996496	3926.6868744733983	100	0.7170155102305708	-3.6913764733827756	15487.511164438358	140	0.021110138373503146	low	227
ODD Cubes Basic	355980.2335512012	4604.3963865266505	10883.114777911707	32.709407262128316	3.057224461409982	-3.6913764733827756	15487.511164438358	144	0.012934415882011024	low	227
Container (Base)	249212.3298891279	3223.415917710907	12264.095246727451	20.3204822594335	4.921143047851455	-3.6913764733827756	15487.511164438358	98	0.012934415882011024	low	227
Container (Max)	461138.41157952644	5964.5559945395635	9522.955169898794	48.423877184379016	2.0650969276838254	-3.6913764733827756	15487.511164438358	85	0.012934415882011024	low	227
Traditional Housing	555881.8274283345	14300.90739901685	1164.3589275345403	100	0.20946159238937379	-4.9366998576399705	15465.266326551391	118	0.0257265244038951	low	228
ODD Cubes Basic	322620.0384699149	3251.3164887819953	12213.949837769396	26.414062834307025	3.785862123039941	-4.9366998576399705	15465.266326551391	63	0.01007785041562193	low	228
Container (Base)	232907.99865026242	2347.211970999219	13118.054355552173	17.754767005648585	5.632290188217369	-4.9366998576399705	15465.266326551391	143	0.01007785041562193	low	228
Container (Max)	451676.2854585494	4551.9260411350115	10913.34028541638	41.38753797149801	2.41618624593872	-4.9366998576399705	15465.266326551391	87	0.01007785041562193	low	228
Traditional Housing	570597.6850218808	8988.96119900848	21696.26830466918	26.299346828186316	3.802375802460045	4.552561785397733	30685.22950367766	113	0.015753588622890714	middle	229
ODD Cubes Basic	333083.70568401593	7008.907700266807	23676.32180341085	14.068220074455626	7.108219765596006	4.552561785397733	30685.22950367766	126	0.02104248145634568	middle	229
Container (Base)	281793.06221262447	5929.625286136014	24755.604217541644	11.383000783836572	8.785029703414954	4.552561785397733	30685.22950367766	90	0.02104248145634568	middle	229
Container (Max)	491555.2784991312	10343.542832586803	20341.686671090858	24.164922331525162	4.138229729360298	4.552561785397733	30685.22950367766	129	0.02104248145634568	middle	229
Traditional Housing	588689.9918353836	12516.46993099242	18228.451566093398	32.29511786565576	3.0964432585751602	2.4145939461866828	30744.92149708582	124	0.02126156398883102	middle	230
ODD Cubes Basic	308797.1588204764	6499.623247033183	24245.298250052634	12.73637286849239	7.851528926840931	2.4145939461866828	30744.92149708582	126	0.021048196401353005	middle	230
Container (Base)	274299.11230613064	5773.501588536223	24971.419908549597	10.98452203802065	9.103718819432533	2.4145939461866828	30744.92149708582	66	0.021048196401353005	middle	230
Container (Max)	437659.78827902884	9211.949180671572	21532.97231641425	20.325098729886335	4.920025301178906	2.4145939461866828	30744.92149708582	45	0.021048196401353005	middle	230
Traditional Housing	558602.7558924833	6765.268681005192	24016.683999749937	23.25894598514514	4.299420965329526	-2.0077988572243752	30781.95268075513	135	0.012111054966415763	middle	231
ODD Cubes Basic	307072.67372178135	4377.72277175435	26404.22990900078	11.629677319886735	8.59869085352868	-2.0077988572243752	30781.95268075513	99	0.014256308510605931	middle	231
Container (Base)	242297.60309419228	3454.2693810911514	27327.68329966398	8.866379211046096	11.278561137495217	-2.0077988572243752	30781.95268075513	130	0.014256308510605931	middle	231
Container (Max)	479501.9548292949	6835.927799485057	23946.024881270074	20.024281992805754	4.99393686305095	-2.0077988572243752	30781.95268075513	96	0.014256308510605931	middle	231
Traditional Housing	541563.9626110173	9835.740653801775	6050.207996937319	89.51162718457991	1.1171733007801574	3.6430838402210934	15885.948650739094	137	0.01816173403854491	low	232
ODD Cubes Basic	298070.6062491381	4780.93942085368	11105.009229885414	26.841094867979113	3.7256304369050905	3.6430838402210934	15885.948650739094	120	0.016039620548352895	low	232
Container (Base)	269952.40521895944	4329.934145827309	11556.014504911785	23.360338039054767	4.28075997157301	3.6430838402210934	15885.948650739094	85	0.016039620548352895	low	232
Container (Max)	483785.1908063202	7759.73088744588	8126.2177632932135	59.53386986398731	1.6797161049409808	3.6430838402210934	15885.948650739094	103	0.016039620548352895	low	232
Traditional Housing	557801.594660333	6883.3246095737395	8936.571833967047	62.41784937487807	1.6021058239191432	-1.5797388850186103	15819.896443540787	89	0.012340094892997325	low	233
ODD Cubes Basic	351160.381969745	3199.337722302312	12620.558721238474	27.8244719371097	3.593958592494591	-1.5797388850186103	15819.896443540787	110	0.009110759318452838	low	233
Container (Base)	261110.95903327042	2378.919103162526	13440.97734037826	19.426486067264076	5.147611341225103	-1.5797388850186103	15819.896443540787	100	0.009110759318452838	low	233
Container (Max)	401126.8187606547	3654.5699019049775	12165.32654163581	32.97295945059911	3.032788129006813	-1.5797388850186103	15819.896443540787	93	0.009110759318452838	low	233
Traditional Housing	590609.6662680143	10359.45664109318	5143.899944082725	100	0.8709474696860888	1.579335123059085	15503.356585175905	138	0.017540276146432277	low	234
ODD Cubes Basic	329695.12933480996	4025.9621531201033	11477.394432055802	28.725607653073904	3.4812144344420535	1.579335123059085	15503.356585175905	48	0.012211166604865683	low	234
Container (Base)	243505.10354064708	2973.4813884699097	12529.875196705994	19.433960811091133	5.145631452695383	1.579335123059085	15503.356585175905	129	0.012211166604865683	low	234
Container (Max)	461372.7187592611	5633.899135709175	9869.457449466729	46.74752600348768	2.139150636389599	1.579335123059085	15503.356585175905	93	0.012211166604865683	low	234
Traditional Housing	546789.9319831762	16122.760739793222	14665.770369292364	37.28341015948685	2.682158085116974	4.485299607776218	30788.531109085587	88	0.029486206304708065	middle	235
ODD Cubes Basic	305532.5569191685	7262.086991867981	23526.444117217605	12.986771625873006	7.700143105679485	4.485299607776218	30788.531109085587	75	0.023768619177920322	middle	235
Container (Base)	242270.3256213572	5758.431107804791	25030.100001280796	9.679159316541291	10.331475774874793	4.485299607776218	30788.531109085587	65	0.023768619177920322	middle	235
Container (Max)	493022.99010241224	11718.475697703816	19070.05541138177	25.853254197056838	3.867985021838531	4.485299607776218	30788.531109085587	40	0.023768619177920322	middle	235
Traditional Housing	549413.1399038153	7767.283074025431	22991.265184882934	23.896603144095867	4.184695180189532	-3.9083792179122234	30758.548258908366	123	0.014137417746115854	middle	236
ODD Cubes Basic	351579.6375603473	5221.268010985882	25537.280247922485	13.767309366820655	7.263583416015982	-3.9083792179122234	30758.548258908366	124	0.014850882853218913	middle	236
Container (Base)	223841.66623942423	3324.246362991016	27434.30189591735	8.15918943695576	12.25611940655107	-3.9083792179122234	30758.548258908366	133	0.014850882853218913	middle	236
Container (Max)	429079.59097794985	6372.21074032062	24386.337518587745	17.59508128889371	5.683406536071053	-3.9083792179122234	30758.548258908366	55	0.014850882853218913	middle	236
Traditional Housing	502170.6846752988	8778.081602063015	6824.777067356241	73.58052574013645	1.3590552526516178	-4.025898486683847	15602.858669419256	87	0.017480274874545655	low	237
ODD Cubes Basic	312736.4891063868	7717.149845031675	7885.708824387581	39.65864021496818	2.521518626406597	-4.025898486683847	15602.858669419256	79	0.024676205412047243	low	237
Container (Base)	227579.19241146286	5615.790899453081	9987.067769966176	22.78738841603291	4.388392306054752	-4.025898486683847	15602.858669419256	55	0.024676205412047243	low	237
Container (Max)	442885.5154120919	10928.733952329196	4674.124717090061	94.75260978654765	1.05537990167525	-4.025898486683847	15602.858669419256	48	0.024676205412047243	low	237
Traditional Housing	498018.97501838417	8942.928772878899	6800.1600521158925	73.23636079174693	1.3654419596893608	-0.29330938335730394	15743.088824994791	139	0.01795700409316487	low	238
ODD Cubes Basic	321920.79458613583	6916.174397529906	8826.914427464886	36.4703654070194	2.7419522366713975	-0.29330938335730394	15743.088824994791	119	0.021484087122801122	low	238
Container (Base)	226561.7733577155	4867.472877513482	10875.61594748131	20.832086610247124	4.8002872621896095	-0.29330938335730394	15743.088824994791	138	0.021484087122801122	low	238
Container (Max)	440146.55634073855	9456.14696322532	6286.941861769472	70.00964316486592	1.4283746563956867	-0.29330938335730394	15743.088824994791	111	0.021484087122801122	low	238
Traditional Housing	567753.7220091983	7787.192933298979	8002.806867400047	70.94432383742507	1.4095560376212544	2.877589293596589	15789.999800699026	97	0.013715793717285076	low	239
ODD Cubes Basic	335104.5792235837	5343.589424918372	10446.410375780655	32.07844294538749	3.117358288563031	2.877589293596589	15789.999800699026	81	0.015946035226672026	low	239
Container (Base)	237640.77461251087	3789.4281632647253	12000.571637434301	19.802454565682506	5.049879027284788	2.877589293596589	15789.999800699026	49	0.015946035226672026	low	239
Container (Max)	462229.50426548475	7370.727957824567	8419.27184287446	54.90136354923457	1.821448385527288	2.877589293596589	15789.999800699026	112	0.015946035226672026	low	239
Traditional Housing	529273.1222863604	9847.343717416006	5866.261696036763	90.22323750812829	1.1083619116526484	-1.0315668357845276	15713.60541345277	107	0.018605410520143802	low	240
ODD Cubes Basic	337982.89192952274	4593.65541420403	11119.94999924874	30.394281624679675	3.2900925652673294	-1.0315668357845276	15713.60541345277	98	0.01359138442771214	low	240
Container (Base)	268686.37437046494	3651.819804557171	12061.785608895598	22.27583734967964	4.489169068270206	-1.0315668357845276	15713.60541345277	98	0.01359138442771214	low	240
Container (Max)	477751.6823306574	6493.306775542173	9220.298637910597	51.81520697890543	1.9299353574079354	-1.0315668357845276	15713.60541345277	74	0.01359138442771214	low	240
Traditional Housing	501452.97856769187	12573.950275615862	3291.250905740999	100	0.6563428768818667	1.9073651195031598	15865.20118135686	84	0.02507503357848434	low	241
ODD Cubes Basic	318954.2799384122	3958.199685785229	11907.001495571632	26.78712017102168	3.733137394447502	1.9073651195031598	15865.20118135686	113	0.01240992811430381	low	241
Container (Base)	262873.342210493	3262.2392799990034	12602.961901357858	20.858060531165354	4.794309607577542	1.9073651195031598	15865.20118135686	89	0.01240992811430381	low	241
Container (Max)	429073.70136315335	5324.773789654993	10540.427391701867	40.707429159936055	2.456554050787841	1.9073651195031598	15865.20118135686	88	0.01240992811430381	low	241
Traditional Housing	499852.513028088	7580.552212204945	23038.963512025326	21.695963569159133	4.60915228223144	2.7964940457717287	30619.51572423027	111	0.015165577874725968	middle	242
ODD Cubes Basic	344728.04015771486	7617.438065457644	23002.077658772625	14.986821854600647	6.672528770287747	2.7964940457717287	30619.51572423027	44	0.022096949415465673	middle	242
Container (Base)	249847.4470267292	5520.866398532875	25098.649325697395	9.954617229976654	10.045589668567752	2.7964940457717287	30619.51572423027	116	0.022096949415465673	middle	242
Container (Max)	463133.78351390944	10233.843786900086	20385.671937330182	22.71859298715684	4.401681039689892	2.7964940457717287	30619.51572423027	106	0.022096949415465673	middle	242
Traditional Housing	564518.9217907581	12166.423805577177	3566.7236023109817	100	0.6318164838472866	1.1923235459820614	15733.147407888158	81	0.021551844120624046	low	243
ODD Cubes Basic	317333.98097635363	7779.007997870233	7954.139410017925	39.895451238468866	2.506551421169936	1.1923235459820614	15733.147407888158	111	0.024513630635887972	low	243
Container (Base)	242777.8274514921	5951.365988729221	9781.781419158939	24.819387905763154	4.029108226991353	1.1923235459820614	15733.147407888158	84	0.024513630635887972	low	243
Container (Max)	445881.4894927334	10930.17414080443	4802.9732670837275	92.83447246073555	1.0771860640700588	1.1923235459820614	15733.147407888158	80	0.024513630635887972	low	243
Traditional Housing	497746.4075691307	13949.755380289049	1865.694493516312	100	0.37482831922944426	-0.3981450372355466	15815.44987380536	95	0.028025828349854245	low	244
ODD Cubes Basic	298819.9128305341	6773.957676141221	9041.49219766414	33.04984468246668	3.025732827514653	-0.3981450372355466	15815.44987380536	142	0.022669030360044473	low	244
Container (Base)	226207.7361032114	5127.9100374006275	10687.539836404732	21.16555723448019	4.724657087557937	-0.3981450372355466	15815.44987380536	80	0.022669030360044473	low	244
Container (Max)	471544.9513360881	10689.466817963475	5125.983055841885	91.99112564343858	1.0870613801118616	-0.3981450372355466	15815.44987380536	61	0.022669030360044473	low	244
Traditional Housing	560836.2435178588	16669.698473951255	13406.913276847255	41.83186927048908	2.3905219093459564	-3.604056614843608	30076.61175079851	145	0.02972293368451042	middle	245
ODD Cubes Basic	355000.33246509166	5612.631057326063	24463.980693472447	14.511143419918326	6.891255713366992	-3.604056614843608	30076.61175079851	140	0.015810213523892884	middle	245
Container (Base)	246786.930856934	3901.754071754316	26174.857679044195	9.42839628329722	10.606257628050063	-3.604056614843608	30076.61175079851	142	0.015810213523892884	middle	245
Container (Max)	461950.9298464061	7303.542838432542	22773.06891236597	20.28496605459982	4.9297592971482445	-3.604056614843608	30076.61175079851	123	0.015810213523892884	middle	245
Traditional Housing	597218.7236057401	11009.25663757615	19608.04237086871	30.4578454243355	3.2832263282845684	-0.7140801897756388	30617.29900844486	117	0.018434212127689455	middle	246
ODD Cubes Basic	313251.9925599298	6738.205453429654	23879.093555015206	13.118253079340152	7.622966213198717	-0.7140801897756388	30617.29900844486	114	0.021510495107674485	middle	246
Container (Base)	238815.28575521315	5137.035035875397	25480.263972569464	9.372559327183874	10.66944433309301	-0.7140801897756388	30617.29900844486	115	0.021510495107674485	middle	246
Container (Max)	416081.78024330584	8950.12509831612	21667.17391012874	19.20332489918311	5.207431552868947	-0.7140801897756388	30617.29900844486	137	0.021510495107674485	middle	246
Traditional Housing	547722.7195511379	11503.18318537464	19304.427778172714	28.372906249541437	3.524489141876899	-3.0740971630697578	30807.610963547355	89	0.021001836832332917	middle	247
ODD Cubes Basic	355357.6922053257	3436.393885614539	27371.217077932815	12.982897004306823	7.702441139818558	-3.0740971630697578	30807.610963547355	65	0.009670239201207414	middle	247
Container (Base)	253683.75808608087	2453.1826221536376	28354.428341393716	8.94688318281967	11.177076749143867	-3.0740971630697578	30807.610963547355	79	0.009670239201207414	middle	247
Container (Max)	455031.56424942636	4400.264070391533	26407.346893155824	17.231248791879207	5.80340990997288	-3.0740971630697578	30807.610963547355	83	0.009670239201207414	middle	247
Traditional Housing	545852.3148138097	10163.65288143036	5408.860726621944	100	0.9909018574862887	2.2082450647564844	15572.513608052304	120	0.01861978525253151	low	248
ODD Cubes Basic	355131.7637992407	5851.0346513493205	9721.478956702984	36.530631335099116	2.7374287370697226	2.2082450647564844	15572.513608052304	139	0.01647567254687183	low	248
Container (Base)	252197.86124317977	4155.129378864048	11417.384229188257	22.088935274547584	4.527153471051499	2.2082450647564844	15572.513608052304	131	0.01647567254687183	low	248
Container (Max)	450537.9485668828	7422.915710527343	8149.597897524961	55.28345744563809	1.8088593698817237	2.2082450647564844	15572.513608052304	91	0.01647567254687183	low	248
Traditional Housing	598092.1607992165	8263.178984640901	22629.96167507734	26.42921669009731	3.783691403819347	1.946369259378593	30893.14065971824	121	0.013815895820468552	middle	249
ODD Cubes Basic	330230.24405410246	7842.718968191771	23050.42169152647	14.326429619094469	6.980106185474054	1.946369259378593	30893.14065971824	74	0.023749244987103235	middle	249
Container (Base)	260945.94775819746	6197.269241701274	24695.871418016966	10.566379430037985	9.463979659458483	1.946369259378593	30893.14065971824	133	0.023749244987103235	middle	249
Container (Max)	429975.9945056439	10211.605232087892	20681.535427630348	20.790332323740326	4.809927924327153	1.946369259378593	30893.14065971824	82	0.023749244987103235	middle	249
Traditional Housing	511408.9158728981	11950.563736394224	3647.016703521962	100	0.7131312322345911	-4.18697215261623	15597.580439916186	110	0.023367922156766488	low	250
ODD Cubes Basic	317487.64068123413	6371.243531857063	9226.336908059122	34.411017486681146	2.9060460080468467	-4.18697215261623	15597.580439916186	147	0.02006768993648467	low	250
Container (Base)	219158.47200278434	4398.004263105633	11199.576176810553	19.568461211645324	5.110263853577272	-4.18697215261623	15597.580439916186	55	0.02006768993648467	low	250
Container (Max)	451323.7235127646	9057.024544433896	6540.55589548229	69.0038783743908	1.4491939055575274	-4.18697215261623	15597.580439916186	109	0.02006768993648467	low	250
Traditional Housing	591746.5369698153	6240.4737317875515	23911.1495037011	24.747724356715743	4.0407755702541275	-2.309084804899327	30151.623235488652	100	0.0105458559398479	middle	251
ODD Cubes Basic	352311.41122299404	3111.9277352243153	27039.695500264337	13.029414891878123	7.6749417245386	-2.309084804899327	30151.623235488652	147	0.008832889415706814	middle	251
Container (Base)	243484.60916243008	2150.672627158339	28000.950608330313	8.695583681005214	11.500090582584095	-2.309084804899327	30151.623235488652	84	0.008832889415706814	middle	251
Container (Max)	469988.49333448434	4151.356388278159	26000.266847210492	18.076294989445785	5.532107108142849	-2.309084804899327	30151.623235488652	116	0.008832889415706814	middle	251
Traditional Housing	522457.0010800431	7659.265457145188	23217.668728260338	22.502560752110014	4.443938674429453	-0.5097838777056918	30876.934185405527	141	0.014660087703507966	middle	252
ODD Cubes Basic	331661.04223389144	6430.710291683957	24446.22389372157	13.566964111748591	7.370845767433183	-0.5097838777056918	30876.934185405527	131	0.019389405063585795	middle	252
Container (Base)	270657.252203732	5247.883096375258	25629.05108903027	10.560564699158078	9.469190601897672	-0.5097838777056918	30876.934185405527	103	0.019389405063585795	middle	252
Container (Max)	470246.97167041263	9117.809013642185	21759.125171763342	21.611483364259914	4.627169653952373	-0.5097838777056918	30876.934185405527	89	0.019389405063585795	middle	252
Traditional Housing	547511.3427758676	15961.379038467307	14673.466299089896	37.313020087818394	2.68002964554046	-2.4600534129092444	30634.845337557203	118	0.029152599757191422	middle	253
ODD Cubes Basic	352244.76168444863	7650.384475081287	22984.460862475917	15.32534366553353	6.525139153968763	-2.4600534129092444	30634.845337557203	121	0.02171894462957189	middle	253
Container (Base)	232170.76204013993	5042.5039253553105	25592.34141220189	9.071884369651531	11.023068187964702	-2.4600534129092444	30634.845337557203	92	0.02171894462957189	middle	253
Container (Max)	418261.6987821289	9084.202676519735	21550.64266103747	19.40831674306985	5.152430338180003	-2.4600534129092444	30634.845337557203	89	0.02171894462957189	middle	253
Traditional Housing	580684.3831989531	8593.47918091163	22348.54071988135	25.983100663139677	3.848655373985549	-0.9240974578428176	30942.01990079298	92	0.014798881164274996	middle	254
ODD Cubes Basic	294850.79613883485	6849.469264036086	24092.550636756896	12.238255740718236	8.171099061714102	-0.9240974578428176	30942.01990079298	124	0.023230289196203874	middle	254
Container (Base)	225717.44159424654	5243.481444861604	25698.538455931375	8.783279328562346	11.385269243892768	-0.9240974578428176	30942.01990079298	117	0.023230289196203874	middle	254
Container (Max)	415826.87434095796	9659.77854649398	21282.241354299	19.538678629681137	5.118053369693607	-0.9240974578428176	30942.01990079298	126	0.023230289196203874	middle	254
Traditional Housing	513377.0594920023	9467.320586780756	6136.519091104627	83.65932735973774	1.1953239782815472	-1.688670157725518	15603.839677885382	97	0.018441261469978563	low	255
ODD Cubes Basic	346488.1053667777	4063.1611027977333	11540.678575087648	30.023200378765093	3.3307575054766088	-1.688670157725518	15603.839677885382	95	0.01172669722239568	low	255
Container (Base)	225372.71314572275	2642.877569249725	12960.962108635656	17.388578969423957	5.750901219463638	-1.688670157725518	15603.839677885382	113	0.01172669722239568	low	255
Container (Max)	447725.10058972123	5250.33669348231	10353.502984403072	43.243827839156666	2.3124687382427194	-1.688670157725518	15603.839677885382	56	0.01172669722239568	low	255
Traditional Housing	511814.7825544179	13202.219721928184	2790.928495646398	100	0.5453004857962767	-3.871088227189483	15993.148217574582	129	0.02579491677836499	low	256
ODD Cubes Basic	351202.66819759656	4876.706707879311	11116.441509695273	31.593083802158542	3.1652497308024006	-3.871088227189483	15993.148217574582	111	0.013885733650336442	low	256
Container (Base)	252608.4447138362	3507.653581122068	12485.494636452515	20.232153556521766	4.942627571535278	-3.871088227189483	15993.148217574582	41	0.013885733650336442	low	256
Container (Max)	472393.5140599938	6559.530514383537	9433.617703191045	50.07554142248106	1.996982901419129	-3.871088227189483	15993.148217574582	86	0.013885733650336442	low	256
Traditional Housing	568974.0227584112	9486.622635860736	6377.855961683523	89.21086116975002	1.120939745326754	-2.744194617869251	15864.47859754426	148	0.01667320871675155	low	257
ODD Cubes Basic	303023.11824547814	4599.309389296347	11265.169208247913	26.899118215074527	3.7175939820941424	-2.744194617869251	15864.47859754426	66	0.01517808085378641	low	257
Container (Base)	255409.13861507844	3876.6205566956014	11987.858040848658	21.305652581534677	4.693590098557632	-2.744194617869251	15864.47859754426	60	0.01517808085378641	low	257
Container (Max)	399356.62318088906	6061.467116134646	9803.011481409612	40.73815724262153	2.4547011148402382	-2.744194617869251	15864.47859754426	129	0.01517808085378641	low	257
Traditional Housing	539560.5257864124	13545.44601686518	17001.46780261243	31.736114319700327	3.150984364142039	4.776691581666995	30546.91381947761	82	0.025104590438899545	middle	258
ODD Cubes Basic	316208.4690431508	6792.507104829537	23754.406714648074	13.311570894682118	7.51226138456351	4.776691581666995	30546.91381947761	123	0.021481104302436032	middle	258
Container (Base)	254203.50666632535	5460.572040744328	25086.34177873328	10.133143720533381	9.868605711904012	4.776691581666995	30546.91381947761	138	0.021481104302436032	middle	258
Container (Max)	500858.5147165512	10758.993995389428	19787.91982408818	25.311327272857014	3.9508003243763716	4.776691581666995	30546.91381947761	51	0.021481104302436032	middle	258
Traditional Housing	552430.5516545965	15241.218650255529	14825.757264071677	37.261540291998514	2.6837323206811674	-0.1695258930777115	30066.975914327206	114	0.02758938404946329	middle	259
ODD Cubes Basic	334436.1814548133	6822.005218985886	23244.97069534132	14.38746410301304	6.95049518692164	-0.1695258930777115	30066.975914327206	133	0.020398526227963253	middle	259
Container (Base)	234719.2003571272	4787.925764691421	25279.050149635783	9.28512736703871	10.769911499005406	-0.1695258930777115	30066.975914327206	66	0.020398526227963253	middle	259
Container (Max)	477901.5215158962	9748.486721025552	20318.489193301655	23.5205244331574	4.251605880820744	-0.1695258930777115	30066.975914327206	69	0.020398526227963253	middle	259
Traditional Housing	562516.5783532215	12185.008205152506	3465.1311359418287	100	0.6160051577654954	-0.6046892024072639	15650.139341094335	105	0.021661598384930023	low	260
ODD Cubes Basic	345194.6037752629	7244.306830147605	8405.83251094673	41.06608159581143	2.435099627576827	-0.6046892024072639	15650.139341094335	103	0.02098615317539544	low	260
Container (Base)	229125.34019175312	4808.45948562872	10841.679855465614	21.133748943549943	4.7317681433194165	-0.6046892024072639	15650.139341094335	102	0.02098615317539544	low	260
Container (Max)	443595.6880248379	9309.367056834177	6340.772284260158	69.9592523021187	1.4294034985987338	-0.6046892024072639	15650.139341094335	149	0.02098615317539544	low	260
Traditional Housing	573256.5099642467	12382.743087034089	3467.3115912586927	100	0.6048446953485003	3.1858204355454856	15850.054678292781	109	0.021600702079783422	low	261
ODD Cubes Basic	319153.71012168063	7758.614756266011	8091.439922026771	39.44337635788043	2.535279918551417	3.1858204355454856	15850.054678292781	71	0.024309962598611054	low	261
Container (Base)	282061.82328678516	6856.912374597788	8993.142303694993	31.36410097401606	3.1883585658280507	3.1858204355454856	15850.054678292781	107	0.024309962598611054	low	261
Container (Max)	466898.67824758904	11350.289405539826	4499.765272752955	100	0.9637562671288609	3.1858204355454856	15850.054678292781	54	0.024309962598611054	low	261
Traditional Housing	594090.6184362873	17393.842267586144	12629.931246318083	47.03830977777321	2.1259267280741563	-2.349898019302603	30023.773513904227	143	0.02927809618231083	middle	262
ODD Cubes Basic	312491.250996694	5044.273497844658	24979.50001605957	12.509908156519957	7.993663802230366	-2.349898019302603	30023.773513904227	105	0.01614212712117826	middle	262
Container (Base)	241748.47946391383	3902.3346868580493	26121.43882704618	9.254791861373542	10.805213288195828	-2.349898019302603	30023.773513904227	101	0.01614212712117826	middle	262
Container (Max)	435838.6577466532	7035.36301767018	22988.410496234046	18.959060167211305	5.274523057474374	-2.349898019302603	30023.773513904227	123	0.01614212712117826	middle	262
Traditional Housing	503018.5093604158	14108.684504558776	1424.1233543189392	100	0.28311549730639163	3.6714230524220586	15532.807858877715	134	0.028048042451753637	low	263
ODD Cubes Basic	322503.32493905304	4166.336003603263	11366.471855274453	28.373212817959857	3.5244510602867423	3.6714230524220586	15532.807858877715	99	0.012918738138252128	low	263
Container (Base)	276807.73415795504	3576.00663222953	11956.801226648186	23.15065115752131	4.319532928883145	3.6714230524220586	15532.807858877715	115	0.012918738138252128	low	263
Container (Max)	495848.5944082431	6405.738147380481	9127.069711497235	54.32724960823186	1.8406969011154881	3.6714230524220586	15532.807858877715	66	0.012918738138252128	low	263
Traditional Housing	586121.700126448	7036.454944692039	23417.4224133008	25.029300397875485	3.995317424393057	-4.076074085198561	30453.87735799284	143	0.012005109080885451	middle	264
ODD Cubes Basic	322847.9108473202	4755.932440538984	25697.944917453853	12.563180125273142	7.959768068502945	-4.076074085198561	30453.87735799284	71	0.014731185430492497	middle	264
Container (Base)	260653.4581311697	3839.734424829373	26614.142933163464	9.793794930227625	10.210546648404842	-4.076074085198561	30453.87735799284	127	0.014731185430492497	middle	264
Container (Max)	456139.85578705656	6719.480797837236	23734.3965601556	19.218514978080663	5.203315662737378	-4.076074085198561	30453.87735799284	138	0.014731185430492497	middle	264
Traditional Housing	559761.9082535781	8703.690030093578	6814.486032513059	82.14293867253669	1.217390096045268	-2.003720736966862	15518.176062606637	141	0.015548914461236817	low	265
ODD Cubes Basic	296214.73134532565	3168.794240960711	12349.381821645926	23.986199116956783	4.169064031879318	-2.003720736966862	15518.176062606637	142	0.010697625423856947	low	265
Container (Base)	266054.9035957159	2846.155700847339	12672.020361759298	20.995460550126406	4.762934338175208	-2.003720736966862	15518.176062606637	91	0.010697625423856947	low	265
Container (Max)	444890.61389678216	4759.273142057541	10758.902920549095	41.350927430254806	2.4183254455094527	-2.003720736966862	15518.176062606637	100	0.010697625423856947	low	265
Traditional Housing	518612.9803313487	12050.34686793829	18390.76100184026	28.199647653485034	3.546143598274412	-4.959799598388491	30441.10786977855	84	0.023235721674839612	middle	266
ODD Cubes Basic	345596.32709401584	8383.196506343422	22057.911363435127	15.667681377435517	6.3825653324823985	-4.959799598388491	30441.10786977855	54	0.02425719213174063	middle	266
Container (Base)	233862.5418607402	5672.848610333211	24768.259259445338	9.442025756071537	10.59094759783902	-4.959799598388491	30441.10786977855	90	0.02425719213174063	middle	266
Container (Max)	390251.3364150179	9466.401647087638	20974.70622269091	18.605807026409515	5.374666084521767	-4.959799598388491	30441.10786977855	89	0.02425719213174063	middle	266
Traditional Housing	520228.9579861123	12357.13664094521	3168.5720038269683	100	0.6090725929777163	1.813681963222983	15525.708644772178	89	0.023753265655917385	low	267
ODD Cubes Basic	327760.4200537301	6357.569780939241	9168.138863832937	35.749940628266486	2.7972074426588773	1.813681963222983	15525.708644772178	107	0.019397002786050367	low	267
Container (Base)	276971.01389405364	5372.407528158154	10153.301116614024	27.278912613045733	3.665835270581001	1.813681963222983	15525.708644772178	139	0.019397002786050367	low	267
Container (Max)	423600.45301526977	8216.579167309385	7309.129477462793	57.95498004535467	1.7254772570319505	1.813681963222983	15525.708644772178	73	0.019397002786050367	low	267
Traditional Housing	496421.39063616557	11687.445231869355	4286.752633847522	100	0.8635310070651941	1.7870531938321879	15974.197865716877	105	0.023543395696329395	low	268
ODD Cubes Basic	352058.1561059346	5843.272660705094	10130.925205011783	34.75083953159292	2.877628320578768	1.7870531938321879	15974.197865716877	148	0.016597464252317586	low	268
Container (Base)	238358.7229713771	3956.150383745502	12018.047481971375	19.833398339368024	5.042000280985958	1.7870531938321879	15974.197865716877	117	0.016597464252317586	low	268
Container (Max)	493273.6784909253	8187.092245362331	7787.105620354546	63.34493232011236	1.5786582499552133	1.7870531938321879	15974.197865716877	128	0.016597464252317586	low	268
Traditional Housing	532379.4692408645	5612.5011257393	24914.313720856175	21.36841797874613	4.679803628863116	1.8990915656827925	30526.814846595473	86	0.010542294453507626	middle	269
ODD Cubes Basic	323230.16784228146	5294.261669060776	25232.553177534697	12.81004603727787	7.806373194053718	1.8990915656827925	30526.814846595473	97	0.016379231259268115	middle	269
Container (Base)	242097.94133811956	3965.3781685697863	26561.436678025686	9.114640306275584	10.971359992247672	1.8990915656827925	30526.814846595473	79	0.016379231259268115	middle	269
Container (Max)	487269.4174464216	7981.098473923793	22545.71637267168	21.612505426399096	4.626950833652663	1.8990915656827925	30526.814846595473	117	0.016379231259268115	middle	269
Traditional Housing	551649.2148816976	14081.678177454578	1801.0284386450166	100	0.3264807399447222	0.6616876672789385	15882.706616099595	97	0.025526508146076897	low	270
ODD Cubes Basic	303602.1308957318	4534.025176074488	11348.681440025106	26.752194296772874	3.7380111287567552	0.6616876672789385	15882.706616099595	116	0.014934101953426801	low	270
Container (Base)	259901.77641819467	3881.3996269060567	12001.306989193537	21.656122674990378	4.617631766349626	0.6616876672789385	15882.706616099595	118	0.014934101953426801	low	270
Container (Max)	409044.5346297552	6108.712783652783	9773.993832446811	41.850295963135004	2.389469362130385	0.6616876672789385	15882.706616099595	137	0.014934101953426801	low	270
Traditional Housing	548526.4792676779	9238.806519849133	6621.429826765107	82.84109227442497	1.2071303896951684	1.892488607794725	15860.23634661424	124	0.016842954477208832	low	271
ODD Cubes Basic	354044.88909970823	3198.815725139948	12661.420621474292	27.962493284460788	3.576219008180205	1.892488607794725	15860.23634661424	110	0.00903505691968647	low	271
Container (Base)	233550.60328788278	2110.142994333135	13750.093352281105	16.98538310280907	5.887415043553645	1.892488607794725	15860.23634661424	90	0.00903505691968647	low	271
Container (Max)	437886.4782260905	3956.329255133778	11903.907091480462	36.78510550031784	2.7184915916344443	1.892488607794725	15860.23634661424	125	0.00903505691968647	low	271
Traditional Housing	526433.9202167183	14243.770034080377	1317.4918135301432	100	0.2502672724789026	1.9563363117300092	15561.26184761052	89	0.02705709014384295	low	272
ODD Cubes Basic	344328.1362745967	3083.5943717698356	12477.667475840684	27.595553170597498	3.6237722571384428	1.9563363117300092	15561.26184761052	91	0.008955394714856279	low	272
Container (Base)	251751.29396763703	2254.532207456006	13306.729640154514	18.919095884232135	5.285664844235165	1.9563363117300092	15561.26184761052	73	0.008955394714856279	low	272
Container (Max)	453827.2898798214	4064.202513247301	11497.059334363219	39.47333632726331	2.533355659904844	1.9563363117300092	15561.26184761052	141	0.008955394714856279	low	272
Traditional Housing	580030.2908530881	14908.089501229793	15996.36655871009	36.2601274935938	2.7578502038545603	-0.24524930839525982	30904.456059939883	129	0.025702260272137685	middle	273
ODD Cubes Basic	337427.8020169448	6374.463359487645	24529.99270045224	13.755723702711249	7.269701119417659	-0.24524930839525982	30904.456059939883	81	0.01889134007744725	middle	273
Container (Base)	238864.57274149393	4512.471876113698	26391.984183826185	9.050648525618527	11.048931987242975	-0.24524930839525982	30904.456059939883	55	0.01889134007744725	middle	273
Container (Max)	432748.17962314107	8175.193029156986	22729.263030782895	19.039252572204287	5.252307023122936	-0.24524930839525982	30904.456059939883	42	0.01889134007744725	middle	273
Traditional Housing	583824.5171256717	8591.34003558227	7349.233303460414	79.44019369350755	1.2588086124993014	4.003948401433924	15940.573339042685	132	0.01471562050507881	low	274
ODD Cubes Basic	351697.0372611164	7709.8371918240455	8230.736147218639	42.72971833509244	2.340291579171807	4.003948401433924	15940.573339042685	83	0.021921814445368504	low	274
Container (Base)	272636.8284275215	5976.693963761895	9963.87937528079	27.36251796703815	3.6546344207233963	4.003948401433924	15940.573339042685	125	0.021921814445368504	low	274
Container (Max)	475609.70594815264	10426.227722211679	5514.345616831006	86.24952786718451	1.159426636560722	4.003948401433924	15940.573339042685	138	0.021921814445368504	low	274
Traditional Housing	530468.9849469637	9376.714634082391	6440.8807592261255	82.35969656589323	1.2141861149281112	1.6280092334734189	15817.595393308517	129	0.01767627307187408	low	275
ODD Cubes Basic	347368.16877234564	6758.532333404403	9059.063059904114	38.34482291108175	2.6079139870300394	1.6280092334734189	15817.595393308517	104	0.01945639509022986	low	275
Container (Base)	231954.86722778995	4513.005539885691	11304.589853422825	20.518645102153634	4.87361614288577	1.6280092334734189	15817.595393308517	110	0.01945639509022986	low	275
Container (Max)	461842.5469029004	8985.791062020844	6831.8043312876725	67.60184052517373	1.4792496657359762	1.6280092334734189	15817.595393308517	44	0.01945639509022986	low	275
Traditional Housing	597097.0597390265	9649.412424009472	6273.513464656	95.17745727381929	1.0506689594817245	-3.5582539504003496	15922.925888665472	113	0.01616054252256232	low	276
ODD Cubes Basic	337824.3409055642	3694.656535540874	12228.269353124597	27.626504712152297	3.6197123393612722	-3.5582539504003496	15922.925888665472	43	0.010936620273237453	low	276
Container (Base)	249215.68616489577	2725.5773257197816	13197.34856294569	18.883769340200715	5.295552926878586	-3.5582539504003496	15922.925888665472	85	0.010936620273237453	low	276
Container (Max)	422487.7739886554	4620.588354199292	11302.33753446618	37.38056598471689	2.6751868883121026	-3.5582539504003496	15922.925888665472	45	0.010936620273237453	low	276
Traditional Housing	545851.2452564592	10793.09040497063	19319.653895089716	28.25367619008914	3.539362429412925	-1.2170159810712242	30112.744300060345	118	0.0197729518779419	middle	277
ODD Cubes Basic	310581.8671583553	6889.626576140167	23223.11772392018	13.373823052124093	7.477293486705548	-1.2170159810712242	30112.744300060345	81	0.022182964637234848	middle	277
Container (Base)	229774.30731664354	5097.075333750236	25015.66896631011	9.185215379452472	10.887060985385514	-1.2170159810712242	30112.744300060345	98	0.022182964637234848	middle	277
Container (Max)	402640.64149485173	8931.76311179385	21180.981188266494	19.009536806439364	5.260517445439575	-1.2170159810712242	30112.744300060345	69	0.022182964637234848	middle	277
Traditional Housing	574463.7247976767	14717.27424218296	15529.479692480196	36.991820471348305	2.703300316821502	1.1249460944579148	30246.753934663157	95	0.025619153319674473	middle	278
ODD Cubes Basic	339154.9707738394	7234.668181811452	23012.085752851704	14.738123889174654	6.785124127871615	1.1249460944579148	30246.753934663157	120	0.02133145259615194	middle	278
Container (Base)	254120.02976198678	5420.749368600541	24826.004566062617	10.236042174477454	9.769400935973085	1.1249460944579148	30246.753934663157	79	0.02133145259615194	middle	278
Container (Max)	426215.4059204	9091.79372714067	21154.960207522487	20.147303598748543	4.963443346642751	1.1249460944579148	30246.753934663157	141	0.02133145259615194	middle	278
Traditional Housing	581280.2056043826	15256.562008783369	704.0277376380254	100	0.12111675760677536	-3.3010589590635133	15960.589746421394	102	0.026246484675872372	low	279
ODD Cubes Basic	307213.78839133837	7039.858797013468	8920.730949407927	34.43818563003834	2.903753440273464	-3.3010589590635133	15960.589746421394	115	0.022915178494677065	low	279
Container (Base)	259164.34515715216	5938.797228732237	10021.792517689157	25.86007889304325	3.8669642275105933	-3.3010589590635133	15960.589746421394	52	0.022915178494677065	low	279
Container (Max)	465161.8873638815	10659.267677864213	5301.322068557181	87.74450624737858	1.1396724909257503	-3.3010589590635133	15960.589746421394	134	0.022915178494677065	low	279
Traditional Housing	553174.7376982614	12186.415913230252	3808.8119308608457	100	0.6885368530582514	-2.9387109788329124	15995.227844091098	86	0.02202995741262057	low	280
ODD Cubes Basic	295742.5846977225	4967.559288217238	11027.66855587386	26.818232992702338	3.7288064440044044	-2.9387109788329124	15995.227844091098	43	0.016796902256381384	low	280
Container (Base)	262072.57222651027	4402.007379767144	11593.220464323953	22.60567484531079	4.423667980907171	-2.9387109788329124	15995.227844091098	119	0.016796902256381384	low	280
Container (Max)	468330.01835182	7866.493541984821	8128.734302106277	57.614137816076564	1.7356850903372565	-2.9387109788329124	15995.227844091098	139	0.016796902256381384	low	280
Traditional Housing	499690.0164072033	14337.155020895709	1265.2286648316203	100	0.253202710338037	3.1546393703102193	15602.383685727329	94	0.02869209820116196	low	281
ODD Cubes Basic	333814.8022752735	3777.2985923968463	11825.085093330483	28.229378447648536	3.542408848478556	3.1546393703102193	15602.383685727329	88	0.011315551517340969	low	281
Container (Base)	260808.2177058241	2951.1888235961314	12651.194862131197	20.615303182666246	4.850765429638793	3.1546393703102193	15602.383685727329	81	0.011315551517340969	low	281
Container (Max)	440781.6084619947	4987.686998448116	10614.696687279213	41.52559620382116	2.4081532630902496	3.1546393703102193	15602.383685727329	61	0.011315551517340969	low	281
Traditional Housing	524653.0090288485	14156.356948948964	16673.249235310355	31.46675261818472	3.177957421072098	3.8973406752564195	30829.60618425932	125	0.026982322993158635	middle	282
ODD Cubes Basic	319682.72004890186	4708.56542668104	26121.04075757828	12.238513886785118	8.170926709326844	3.8973406752564195	30829.60618425932	129	0.014728870631358401	middle	282
Container (Base)	246994.68422389516	3637.9527505669716	27191.653433692347	9.08347426632952	11.009003501080906	3.8973406752564195	30829.60618425932	47	0.014728870631358401	middle	282
Container (Max)	473644.9540923901	6976.255254022502	23853.35093023682	19.85653736775371	5.036124785905338	3.8973406752564195	30829.60618425932	62	0.014728870631358401	middle	282
Traditional Housing	528039.7936835139	10776.280822383818	20050.47646613649	26.335523476228964	3.7971525453163006	4.526306964273038	30826.757288520308	98	0.020408084677123205	middle	283
ODD Cubes Basic	314500.90323053545	3616.5692774237796	27210.18801109653	11.558203975006696	8.65186323205912	4.526306964273038	30826.757288520308	43	0.011499392339654942	middle	283
Container (Base)	283782.33286570903	3263.3243846853434	27563.432903834964	10.29560918104021	9.712878397147605	4.526306964273038	30826.757288520308	141	0.011499392339654942	middle	283
Container (Max)	467454.2133991124	5375.43940070118	25451.31788781913	18.366601504075103	5.444665414982321	4.526306964273038	30826.757288520308	122	0.011499392339654942	middle	283
Traditional Housing	522614.59843975096	7305.692153818376	23318.0022288561	22.412494574385697	4.461796952949888	-2.0741619997244873	30623.69438267448	109	0.013979119939682674	middle	284
ODD Cubes Basic	318975.8987734959	5882.459943976311	24741.234438698168	12.892481155854558	7.756458884144994	-2.0741619997244873	30623.69438267448	148	0.018441706619826574	middle	284
Container (Base)	227310.68084515995	4191.996887699472	26431.697494975007	8.599927450303731	11.628005070725127	-2.0741619997244873	30623.69438267448	74	0.018441706619826574	middle	284
Container (Max)	446986.7937602519	8243.199313463492	22380.495069210985	19.972158452168244	5.006970089862453	-2.0741619997244873	30623.69438267448	110	0.018441706619826574	middle	284
Traditional Housing	514423.4224747229	6453.324476469129	24060.375750140833	21.380523222781	4.677154013398968	-0.7755445559433571	30513.700226609963	108	0.012544771864049842	middle	285
ODD Cubes Basic	348208.60387032863	3183.0207933214256	27330.679433288537	12.740576198270926	7.84893857575856	-0.7755445559433571	30513.700226609963	70	0.0091411319477527	middle	285
Container (Base)	258477.52097647486	2362.777124773973	28150.92310183599	9.181848852395788	10.891052728874682	-0.7755445559433571	30513.700226609963	82	0.0091411319477527	middle	285
Container (Max)	436607.3123749038	3991.085051772676	26522.615174837287	16.461699176223195	6.074707047522598	-0.7755445559433571	30513.700226609963	43	0.0091411319477527	middle	285
Traditional Housing	505266.53245820355	7248.530447839861	23576.827265526914	21.430641484021216	4.6662158981363415	-0.26330922628959463	30825.357713366775	109	0.014345954030587749	middle	286
ODD Cubes Basic	305908.2862620465	6739.395736698708	24085.961976668066	12.700687917650045	7.873589261336845	-0.26330922628959463	30825.357713366775	84	0.022030772095286172	middle	286
Container (Base)	271145.77793703607	5973.550838329915	24851.806875036862	10.910505594238966	9.165478092307898	-0.26330922628959463	30825.357713366775	147	0.022030772095286172	middle	286
Container (Max)	446414.74780931964	9834.861568961773	20990.496144405002	21.267470036829554	4.70201673385818	-0.26330922628959463	30825.357713366775	64	0.022030772095286172	middle	286
Traditional Housing	519826.0393730456	8658.900674560176	7190.366849851314	72.29478693201791	1.3832255995724085	-0.8939573768235807	15849.26752441149	121	0.016657304595598072	low	287
ODD Cubes Basic	321515.6475122837	3328.8571755232088	12520.410348888283	25.679321887467676	3.8941838276813363	-0.8939573768235807	15849.26752441149	91	0.010353639710166914	low	287
Container (Base)	228416.23800671782	2364.939432273291	13484.3280921382	16.939385963168004	5.90340170638027	-0.8939573768235807	15849.26752441149	54	0.010353639710166914	low	287
Container (Max)	418245.57876374206	4330.364032890024	11518.903491521467	36.30949587099096	2.754100479811228	-0.8939573768235807	15849.26752441149	135	0.010353639710166914	low	287
Traditional Housing	555878.7910969426	10174.153854968	19973.80212138775	27.830394419583893	3.5931937755661587	-1.4135868616850567	30147.95597635575	120	0.01830282791486045	middle	288
ODD Cubes Basic	325841.3633602056	3655.627121326172	26492.32885502958	12.299460917281513	8.130437640522418	-1.4135868616850567	30147.95597635575	50	0.011219039484821364	middle	288
Container (Base)	223549.35260906548	2508.009013727359	27639.946962628394	8.087908161015056	12.364136437900616	-1.4135868616850567	30147.95597635575	62	0.011219039484821364	middle	288
Container (Max)	431431.681932995	4840.249074609163	25307.70690174659	17.04744264693614	5.865982486116328	-1.4135868616850567	30147.95597635575	148	0.011219039484821364	middle	288
Traditional Housing	572698.9959856158	11864.200521737135	3977.6823176814505	100	0.6945502516266602	3.0845525831724103	15841.882839418586	106	0.02071629355892065	low	289
ODD Cubes Basic	320841.9255301744	3154.1024859042377	12687.780353514348	25.28747476632549	3.954526931774412	3.0845525831724103	15841.882839418586	117	0.009830705512355499	low	289
Container (Base)	280273.24982539535	2755.283782024304	13086.599057394282	21.41681338262086	4.669228713602519	3.0845525831724103	15841.882839418586	117	0.009830705512355499	low	289
Container (Max)	436942.0925041866	4295.449037361053	11546.433802057532	37.842168412754866	2.642554700070902	3.0845525831724103	15841.882839418586	63	0.009830705512355499	low	289
Traditional Housing	564461.7271925206	8040.944337606845	7469.549579734565	75.56837546455903	1.3233048796569569	-0.1672543305152452	15510.49391734141	113	0.014245331348859237	low	290
ODD Cubes Basic	306336.59716644336	5561.070856674063	9949.423060667346	30.789382992213035	3.2478728146416924	-0.1672543305152452	15510.49391734141	136	0.01815346552815738	low	290
Container (Base)	266623.83421428414	4840.146583394156	10670.347333947255	24.987362254463058	4.002023061963603	-0.1672543305152452	15510.49391734141	63	0.01815346552815738	low	290
Container (Max)	408396.05038923526	7413.803622576606	8096.690294764803	50.43987549496588	1.9825584226507547	-0.1672543305152452	15510.49391734141	78	0.01815346552815738	low	290
Traditional Housing	560035.9389541553	14099.346524788809	16441.185186456576	34.06299075175461	2.935737520195549	4.230402208984499	30540.531711245385	100	0.025175788809408864	middle	291
ODD Cubes Basic	351583.64410704625	8687.07112519569	21853.460586049696	16.08823658489503	6.215721621963734	4.230402208984499	30540.531711245385	79	0.024708405157069104	middle	291
Container (Base)	253013.44805752335	6251.558784792345	24288.97292645304	10.416803082767128	9.59987428056823	4.230402208984499	30540.531711245385	63	0.024708405157069104	middle	291
Container (Max)	457929.96708885895	11314.719160394847	19225.81255085054	23.81849744335515	4.198417647369182	4.230402208984499	30540.531711245385	148	0.024708405157069104	middle	291
Traditional Housing	561346.8578438772	15421.46169193521	15128.897724744593	37.10428003791359	2.6951068690140008	-4.696316383399656	30550.359416679803	109	0.027472250848911417	middle	292
ODD Cubes Basic	333781.2132550225	7914.816403310111	22635.543013369694	14.745889376626593	6.781550942495739	-4.696316383399656	30550.359416679803	129	0.02371258803371557	middle	292
Container (Base)	231239.7300247055	5483.292455103451	25067.06696157635	9.224841916254405	10.840294165236312	-4.696316383399656	30550.359416679803	75	0.02371258803371557	middle	292
Container (Max)	412704.4904534151	9786.291561786333	20764.06785489347	19.875897793126935	5.031219270738044	-4.696316383399656	30550.359416679803	52	0.02371258803371557	middle	292
Traditional Housing	595433.0525319105	13498.001254867968	2179.786708868054	100	0.366084264150122	-4.480256218068882	15677.787963736022	80	0.02266921729902554	low	293
ODD Cubes Basic	304748.2092472382	7054.730372073493	8623.05759166253	35.34108476115171	2.8295679285408886	-4.480256218068882	15677.787963736022	53	0.023149374329383125	low	293
Container (Base)	256022.6536626248	5926.764246438113	9751.023717297909	26.255976919474755	3.808656608234118	-4.480256218068882	15677.787963736022	81	0.023149374329383125	low	293
Container (Max)	427408.49732142256	9894.239296052756	5783.548667683266	73.90073497775734	1.353166514921645	-4.480256218068882	15677.787963736022	78	0.023149374329383125	low	293
Traditional Housing	513565.17042886274	14114.570622602056	16315.26591320787	31.47758505199176	3.176863785288143	-3.040413690446689	30429.836535809925	146	0.027483504402791577	middle	294
ODD Cubes Basic	335813.5990829313	7743.6986461064125	22686.137889703514	14.802590053697326	6.755574506707522	-3.040413690446689	30429.836535809925	115	0.023059514764302493	middle	294
Container (Base)	259417.1927962005	5982.034587397892	24447.801948412034	10.61106406799285	9.424125550390313	-3.040413690446689	30429.836535809925	65	0.023059514764302493	middle	294
Container (Max)	403632.5044462771	9307.569695631319	21122.266840178607	19.10933648837778	5.233044070411319	-3.040413690446689	30429.836535809925	109	0.023059514764302493	middle	294
Traditional Housing	496887.18700594606	10517.122196230184	5446.214844788932	91.23532603224045	1.0960666701038841	2.151348903424597	15963.337041019116	90	0.02116601609230936	low	295
ODD Cubes Basic	349329.6166332426	6943.833317117294	9019.503723901822	38.73046980484234	2.5819464753174084	2.151348903424597	15963.337041019116	50	0.01987759693564016	low	295
Container (Base)	239341.11872687607	4757.526288178039	11205.810752841076	21.358661502131337	4.681941328112775	2.151348903424597	15963.337041019116	142	0.01987759693564016	low	295
Container (Max)	440724.6450211316	8760.546853333142	7202.790187685974	61.188044290753155	1.6343061975444144	2.151348903424597	15963.337041019116	83	0.01987759693564016	low	295
Traditional Housing	572177.8922017828	13526.671753986233	17062.860566960902	33.53352680556391	2.9820901505477178	-3.790063193141957	30589.532320947135	127	0.023640675283581127	middle	296
ODD Cubes Basic	306896.4535711274	3026.202830478828	27563.329490468306	11.13423012547361	8.98131248169674	-3.790063193141957	30589.532320947135	58	0.009860664061982929	middle	296
Container (Base)	254643.30419724892	2510.9520783223993	28078.580242624736	9.06895227596612	11.026632069176586	-3.790063193141957	30589.532320947135	124	0.009860664061982929	middle	296
Container (Max)	451068.2799534962	4447.832777637895	26141.69954330924	17.254741957622397	5.795508286684307	-3.790063193141957	30589.532320947135	99	0.009860664061982929	middle	296
Traditional Housing	550522.6469624832	9076.387970962567	21455.016159120452	25.659390926557656	3.8972086393718444	2.963938511184403	30531.40413008302	141	0.016486856664374612	middle	297
ODD Cubes Basic	325807.93712397333	6269.086951733441	24262.317178349578	13.428558151680058	7.446815873339978	2.963938511184403	30531.40413008302	87	0.01924166429790809	middle	297
Container (Base)	251915.83215508334	4847.279873656274	25684.12425642675	9.80823132764779	10.195518096939297	2.963938511184403	30531.40413008302	144	0.01924166429790809	middle	297
Container (Max)	484598.874958473	9324.488871094876	21206.915258988145	22.850983702265943	4.376179218493943	2.963938511184403	30531.40413008302	70	0.01924166429790809	middle	297
Traditional Housing	496554.20590577525	13861.638995876225	1810.030696170239	100	0.36451824889259027	4.70722070398349	15671.669692046464	116	0.027915661232978402	low	298
ODD Cubes Basic	318039.98680446396	7027.186608237684	8644.48308380878	36.791093662981034	2.718049126672724	4.70722070398349	15671.669692046464	55	0.022095292729835604	low	298
Container (Base)	267784.4780423265	5916.776430851439	9754.893261195026	27.451297607486225	3.6428150475746204	4.70722070398349	15671.669692046464	98	0.022095292729835604	low	298
Container (Max)	486272.40429247747	10744.331119283257	4927.338572763207	98.68865252743944	1.0132877229446005	4.70722070398349	15671.669692046464	88	0.022095292729835604	low	298
Traditional Housing	577289.4137431219	17071.172622455353	13649.843968397901	42.2927481866944	2.3644715533397447	1.185067167499037	30721.016590853254	114	0.029571255276909618	middle	299
ODD Cubes Basic	311574.82696735905	7665.308680223798	23055.707910629455	13.513999577679964	7.3997338408358635	1.185067167499037	30721.016590853254	137	0.024601822794326142	middle	299
Container (Base)	248866.59137953914	6122.571780547396	24598.44481030586	10.117167703027837	9.884189225218861	1.185067167499037	30721.016590853254	127	0.024601822794326142	middle	299
Container (Max)	452278.3404573792	11126.87158564435	19594.145005208906	23.082320781904265	4.332320001305784	1.185067167499037	30721.016590853254	139	0.024601822794326142	middle	299
Traditional Housing	564511.2006148642	16826.737700307396	13893.90136453629	40.63014309686694	2.4612268719208914	1.8158035464434867	30720.639064843686	115	0.029807624156933915	middle	300
ODD Cubes Basic	337373.0817676449	6556.198229836536	24164.44083500715	13.961551358510675	7.162527818876091	1.8158035464434867	30720.639064843686	131	0.019433080420897097	middle	300
Container (Base)	260618.6499109059	5064.62318290426	25656.015881939427	10.158188672402897	9.844274725047535	1.8158035464434867	30720.639064843686	95	0.019433080420897097	middle	300
Container (Max)	490640.16285387013	9534.649742461306	21185.989322382382	23.15870905945955	4.318029979272674	1.8158035464434867	30720.639064843686	143	0.019433080420897097	middle	300
Traditional Housing	552353.8014195283	7757.33849062738	7981.389513326452	69.20521802591745	1.444977746657049	-3.074550348656179	15738.728003953833	114	0.01404414791876387	low	301
ODD Cubes Basic	339797.50829599914	7636.518986501204	8102.209017452628	41.93887217227494	2.384422728136887	-3.074550348656179	15738.728003953833	57	0.02247373450381219	low	301
Container (Base)	230133.52597110593	5171.959763100802	10566.76824085303	21.778988686566272	4.591581429200248	-3.074550348656179	15738.728003953833	46	0.02247373450381219	low	301
Container (Max)	427254.371928874	9602.00132032254	6136.726683631292	69.6225192933074	1.4363168844654648	-3.074550348656179	15738.728003953833	91	0.02247373450381219	low	301
Traditional Housing	570648.2871150171	8511.195848017578	21995.97631634709	25.94330339821832	3.8545592465633196	3.46679602428382	30507.172164364667	128	0.014914959074085687	middle	302
ODD Cubes Basic	334115.8369890694	2932.062554853583	27575.109609511084	12.116573305435844	8.253158502754001	3.46679602428382	30507.172164364667	83	0.008775586878120672	middle	302
Container (Base)	253880.36668223026	2227.9492144690444	28279.222949895622	8.977628810100219	11.138798686741836	3.46679602428382	30507.172164364667	65	0.008775586878120672	middle	302
Container (Max)	501979.97272020066	4405.168861682766	26102.0033026819	19.23147303673139	5.199809697832493	3.46679602428382	30507.172164364667	94	0.008775586878120672	middle	302
Traditional Housing	556912.7737358719	6826.023003949316	24150.16168685005	23.06041594906237	4.336435223930381	-1.7044294244859328	30976.184690799368	110	0.012256897894726164	middle	303
ODD Cubes Basic	349117.1876553595	3427.1679746889645	27549.016716110404	12.672582519113979	7.89105139770608	-1.7044294244859328	30976.184690799368	96	0.009816669290061383	middle	303
Container (Base)	227181.70386692602	2230.167655614272	28746.017035185097	7.903067182798084	12.653315185990227	-1.7044294244859328	30976.184690799368	43	0.009816669290061383	middle	303
Container (Max)	418277.2052924056	4106.088995926659	26870.09569487271	15.56664367861631	6.423992355999557	-1.7044294244859328	30976.184690799368	125	0.009816669290061383	middle	303
Traditional Housing	529519.0596856644	11039.475031296872	4531.508510605379	100	0.8557781684563716	1.22814484149192	15570.983541902251	101	0.020848116473560323	low	304
ODD Cubes Basic	324173.07424629637	3794.142594781405	11776.840947120847	27.526318450072033	3.6328868381502835	1.22814484149192	15570.983541902251	123	0.011704064576007126	low	304
Container (Base)	269496.0269443523	3154.1989023340557	12416.784639568195	21.70417179384407	4.607409163079095	1.22814484149192	15570.983541902251	99	0.011704064576007126	low	304
Container (Max)	452570.6344861376	5296.915931230272	10274.06761067198	44.04980107548047	2.270157811351916	1.22814484149192	15570.983541902251	42	0.011704064576007126	low	304
Traditional Housing	521215.3461273603	10055.544562048872	20268.244199601006	25.715860781745505	3.888650698831958	0.9973293853433995	30323.788761649877	84	0.019292495197545036	middle	305
ODD Cubes Basic	303651.5815163811	4823.464757512419	25500.32400413746	11.907753857053475	8.397889408905248	0.9973293853433995	30323.788761649877	147	0.015884866245138286	middle	305
Container (Base)	260831.92705003344	4143.280273651448	26180.508487998428	9.962828917918193	10.037309766521188	0.9973293853433995	30323.788761649877	41	0.015884866245138286	middle	305
Container (Max)	447529.241202921	7108.94213729663	23214.846624353246	19.277716904381613	5.187336264766451	0.9973293853433995	30323.788761649877	91	0.015884866245138286	middle	305
Traditional Housing	500460.1987157275	6252.470809795981	23817.260143020394	21.01250083806917	4.759071791151393	0.5025242840098443	30069.730952816375	124	0.012493442687032787	middle	306
ODD Cubes Basic	321144.09411022044	2786.2746971125002	27283.456255703873	11.770652922431047	8.495705434439618	0.5025242840098443	30069.730952816375	84	0.008676088859215383	middle	306
Container (Base)	245562.45804829584	2130.5217065143643	27939.20924630201	8.789169939761202	11.377638694595198	0.5025242840098443	30069.730952816375	147	0.008676088859215383	middle	306
Container (Max)	434327.35756838525	3768.2627482515236	26301.46820456485	16.513426330055747	6.055678452265964	0.5025242840098443	30069.730952816375	66	0.008676088859215383	middle	306
Traditional Housing	541990.6976240028	12014.840494389711	18381.53327648059	29.485608706945406	3.3914850120236704	3.7810030693003718	30396.3737708703	135	0.022167982858489595	middle	307
ODD Cubes Basic	297751.9852758502	3576.8446368996915	26819.52913397061	11.102058644971008	9.007338476391299	3.7810030693003718	30396.3737708703	117	0.012012832201894301	middle	307
Container (Base)	241891.78435094017	2905.805416424646	27490.568354445655	8.799082697459854	11.364821020362532	3.7810030693003718	30396.3737708703	125	0.012012832201894301	middle	307
Container (Max)	501101.24665095744	6019.645192178	24376.728578692302	20.55654207386015	4.86463139766881	3.7810030693003718	30396.3737708703	108	0.012012832201894301	middle	307
Traditional Housing	509792.07250895415	9776.647704930547	5906.025717954961	86.3172794793512	1.15851658675042	0.7204547292090782	15682.673422885508	96	0.019177716234021716	low	308
ODD Cubes Basic	351314.69749957405	2923.5217449232396	12759.151677962269	27.534330366678546	3.6318297437521068	0.7204547292090782	15682.673422885508	146	0.008321660795096067	low	308
Container (Base)	275352.7042178421	2291.3918035132997	13391.281619372208	20.56208748679507	4.863319449653145	0.7204547292090782	15682.673422885508	127	0.008321660795096067	low	308
Container (Max)	441543.1481632162	3674.37230541313	12008.301117472378	36.769826459528055	2.7196212119757583	0.7204547292090782	15682.673422885508	126	0.008321660795096067	low	308
Traditional Housing	553555.5968175926	6624.285408271999	9272.708560591536	59.69729267348822	1.675117840719272	0.28115493288695426	15896.993968863535	98	0.011966793301983053	low	309
ODD Cubes Basic	333914.6872676878	2949.7045718363242	12947.28939702721	25.790316183428864	3.877424351402614	0.28115493288695426	15896.993968863535	139	0.008833707184229512	low	309
Container (Base)	237606.62475372775	2098.9473481075306	13798.046620756004	17.220308880265918	5.807096765528853	0.28115493288695426	15896.993968863535	74	0.008833707184229512	low	309
Container (Max)	490818.43455748475	4335.746331502735	11561.2476373608	42.45376017821626	2.355503954896125	0.28115493288695426	15896.993968863535	146	0.008833707184229512	low	309
Traditional Housing	551542.5659590696	9531.117933043211	20621.555647920286	26.745924283102934	3.73888742604331	-0.24546530041891046	30152.673580963496	149	0.017280838363707585	middle	310
ODD Cubes Basic	353901.2774453502	2849.8465751854724	27302.827005778025	12.96207449032494	7.714814482407217	-0.24546530041891046	30152.673580963496	110	0.008052659757990133	middle	310
Container (Base)	235522.4354412094	1896.582037981256	28256.091542982238	8.335280025651828	11.997197417753206	-0.24546530041891046	30152.673580963496	58	0.008052659757990133	middle	310
Container (Max)	422192.0510372407	3399.7689395309044	26752.904641432593	15.781166818925001	6.336667063178025	-0.24546530041891046	30152.673580963496	49	0.008052659757990133	middle	310
Traditional Housing	575785.5686159243	11788.966437592015	3993.0931054875855	100	0.6935035060163454	-3.8994017002091486	15782.0595430796	97	0.020474577829260952	low	311
ODD Cubes Basic	310166.29673067917	5530.524133140686	10251.535409938915	30.255594340528873	3.305173875432519	-3.8994017002091486	15782.0595430796	44	0.017830835237211157	low	311
Container (Base)	255572.8062148561	4557.076598728795	11224.982944350806	22.76821332218399	4.392088153116782	-3.8994017002091486	15782.0595430796	84	0.017830835237211157	low	311
Container (Max)	457304.40472049237	8154.119493822027	7627.940049257573	59.951232150153274	1.6680224311243674	-3.8994017002091486	15782.0595430796	42	0.017830835237211157	low	311
Traditional Housing	516923.0538878257	9999.922193081056	5622.853378500775	91.93251523582377	1.08775442228989	-1.4261119496618635	15622.775571581831	80	0.019345088437961365	low	312
ODD Cubes Basic	312860.8610274835	5461.335048983447	10161.440522598383	30.789026450698724	3.2479104254928663	-1.4261119496618635	15622.775571581831	40	0.017456114616087093	low	312
Container (Base)	256616.8546208395	4479.533226681133	11143.242344900698	23.028921626053563	4.342365727054536	-1.4261119496618635	15622.775571581831	112	0.017456114616087093	low	312
Container (Max)	463010.6619875217	8082.367184124538	7540.408387457293	61.403923792468994	1.6285604212847502	-1.4261119496618635	15622.775571581831	138	0.017456114616087093	low	312
Traditional Housing	503788.3475181423	10361.244210803783	5205.476157950761	96.78045431994997	1.0332664865304975	-2.3336672867886152	15566.720368754544	84	0.02056666110251916	low	313
ODD Cubes Basic	302938.2955938947	6486.796071772617	9079.924296981928	33.36352657638217	2.9972850673042872	-2.3336672867886152	15566.720368754544	54	0.021412928527426985	low	313
Container (Base)	231529.5104091856	4957.724858382054	10608.99551037249	21.823886171204197	4.582135336278754	-2.3336672867886152	15566.720368754544	71	0.021412928527426985	low	313
Container (Max)	460388.6697369266	9858.269679913998	5708.450688840547	80.65037167386602	1.239919890318423	-2.3336672867886152	15566.720368754544	82	0.021412928527426985	low	313
Traditional Housing	600916.6616630651	7413.717171299293	23293.12110213507	25.79803105939223	3.876264811441617	-2.200120200803074	30706.83827343436	124	0.012337346664313622	middle	314
ODD Cubes Basic	305473.82169860555	4780.374319293197	25926.463954141163	11.782317181352957	8.487294855570767	-2.200120200803074	30706.83827343436	74	0.01564904741333198	middle	314
Container (Base)	242574.39977281485	3796.058283305326	26910.779990129035	9.014023371369836	11.093825240970423	-2.200120200803074	30706.83827343436	112	0.01564904741333198	middle	314
Container (Max)	434048.4427648576	6792.444660510168	23914.393612924192	18.150091940039086	5.509613963960154	-2.200120200803074	30706.83827343436	65	0.01564904741333198	middle	314
Traditional Housing	536380.3771118475	11591.949143095946	4242.961215662139	100	0.7910358761646838	4.456696421574129	15834.910358758085	114	0.02161143404520699	low	315
ODD Cubes Basic	332812.0844389157	6804.6924995736645	9030.21785918442	36.85537709374535	2.71330828458599	4.456696421574129	15834.910358758085	60	0.02044604994150264	low	315
Container (Base)	285957.1098376537	5846.6933488684235	9988.21700988966	28.629445030531297	3.492907385852468	4.456696421574129	15834.910358758085	91	0.02044604994150264	low	315
Container (Max)	475730.23485682835	9726.804140565493	6108.106218192592	77.88506254850272	1.2839432456990745	4.456696421574129	15834.910358758085	126	0.02044604994150264	low	315
Traditional Housing	546238.3844264763	12136.150217237313	3863.565891197499	100	0.7073039905926887	-1.5282417868566665	15999.716108434812	91	0.0222176810770625	low	316
ODD Cubes Basic	296547.5795164709	7133.2069035052755	8866.509204929536	33.44580969380809	2.989911170202983	-1.5282417868566665	15999.716108434812	63	0.02405417341505929	low	316
Container (Base)	231957.64838562455	5579.549499217161	10420.166609217651	22.260454854957448	4.492271189046696	-1.5282417868566665	15999.716108434812	48	0.02405417341505929	low	316
Container (Max)	475696.5268962337	11442.486750903423	4557.229357531389	100	0.9580119046203341	-1.5282417868566665	15999.716108434812	46	0.02405417341505929	low	316
Traditional Housing	528084.1228146803	6763.662483034061	23288.297644051934	22.675943552686356	4.4099598222960505	3.551364415860851	30051.960127085993	102	0.012807926220132965	middle	317
ODD Cubes Basic	297816.1728202614	7150.38904140848	22901.57108567751	13.004180879385766	7.689834594543364	3.551364415860851	30051.960127085993	135	0.024009404773742415	middle	317
Container (Base)	254005.61982050238	6098.523741075771	23953.436386010224	10.604141123102151	9.430278118624836	3.551364415860851	30051.960127085993	75	0.024009404773742415	middle	317
Container (Max)	473823.492219	11376.22001599416	18675.740111091833	25.371069066097593	3.941497291244469	3.551364415860851	30051.960127085993	43	0.024009404773742415	middle	317
Traditional Housing	555700.2139415973	7834.13013371646	22259.116364877915	24.965061722684656	4.005597947676388	4.74619609999748	30093.246498594373	82	0.014097763393230954	middle	318
ODD Cubes Basic	327713.3408653712	5021.598674136219	25071.647824458152	13.071073076643847	7.650481288998821	4.74619609999748	30093.246498594373	60	0.015323143882015947	middle	318
Container (Base)	258331.12629494342	3958.4450174206513	26134.801481173723	9.88456432244312	10.116783779022793	4.74619609999748	30093.246498594373	58	0.015323143882015947	middle	318
Container (Max)	481555.12441004603	7378.938458457225	22714.308040137148	21.200519230395116	4.716865606604121	4.74619609999748	30093.246498594373	126	0.015323143882015947	middle	318
Traditional Housing	510792.03232507716	14873.95463593582	16039.17832415414	31.846521187176517	3.1400603981908866	4.765469342523417	30913.13296008996	135	0.02911939438097924	middle	319
ODD Cubes Basic	307759.2381632961	7578.412781219461	23334.7201788705	13.18889773711411	7.582134761618161	4.765469342523417	30913.13296008996	96	0.024624485121705363	middle	319
Container (Base)	264723.75670513266	6518.68620834749	24394.44675174247	10.851804076525069	9.215057634179265	4.765469342523417	30913.13296008996	126	0.024624485121705363	middle	319
Container (Max)	433053.89239186316	10663.72913010003	20249.40382998993	21.386007016685515	4.675954698882278	4.765469342523417	30913.13296008996	65	0.024624485121705363	middle	319
Traditional Housing	572846.4768552339	14386.574750233689	1296.0112833226522	100	0.22624059598609905	0.9722484706570942	15682.586033556341	120	0.025114189109116877	low	320
ODD Cubes Basic	334583.3069190191	7186.261860344585	8496.324173211757	39.379771781064335	2.539374797699685	0.9722484706570942	15682.586033556341	49	0.021478243868526033	low	320
Container (Base)	246401.59944052142	5292.273642378387	10390.312391177955	23.714551609606296	4.2168201889801695	0.9722484706570942	15682.586033556341	105	0.021478243868526033	low	320
Container (Max)	485270.5872838008	10422.760015904323	5259.826017652018	92.25981727441723	1.0838954916045453	0.9722484706570942	15682.586033556341	105	0.021478243868526033	low	320
Traditional Housing	536810.5382562986	13986.144224608708	16339.442175889913	32.85366369779767	3.0438005611746566	3.6046028544902917	30325.58640049862	105	0.02605415361263095	middle	321
ODD Cubes Basic	300955.0972108075	6728.113779230918	23597.472621267705	12.753700450935815	7.840861590305141	3.6046028544902917	30325.58640049862	110	0.022355872492560352	middle	321
Container (Base)	272060.9096513138	6082.1590063747535	24243.427394123868	11.222048154678658	8.911029307810297	3.6046028544902917	30325.58640049862	43	0.022355872492560352	middle	321
Container (Max)	446657.92247716256	9985.427562691353	20340.15883780727	21.959411725287865	4.553856052748567	3.6046028544902917	30325.58640049862	63	0.022355872492560352	middle	321
Traditional Housing	565269.3733056589	16476.175230875084	14195.170748782122	39.82124507760192	2.5112223338352258	1.7526552665205122	30671.345979657206	117	0.029147475538119944	middle	322
ODD Cubes Basic	298843.00712173874	2773.136367153153	27898.20961250405	10.711906293362873	9.3354065337521	1.7526552665205122	30671.345979657206	44	0.009279575901280732	middle	322
Container (Base)	253664.97075200686	2353.9033495894046	28317.442630067802	8.957905347097352	11.163324027798888	1.7526552665205122	30671.345979657206	94	0.009279575901280732	middle	322
Container (Max)	473894.4745343668	4397.539745639206	26273.806234018	18.036765222116625	5.544231394517478	1.7526552665205122	30671.345979657206	80	0.009279575901280732	middle	322
Traditional Housing	517685.47103343555	9443.884995894308	21555.5867466041	24.016301533290086	4.163838460363493	1.270326392426079	30999.47174249841	86	0.018242515048842	middle	323
ODD Cubes Basic	339031.0639694589	5056.371606447869	25943.10013605054	13.068255612918875	7.652130702214233	1.270326392426079	30999.47174249841	56	0.014914183813266636	middle	323
Container (Base)	256700.66221739777	3828.48086129754	27170.99088120087	9.447600322703153	10.584698397930104	1.270326392426079	30999.47174249841	84	0.014914183813266636	middle	323
Container (Max)	475168.10164770554	7086.744410174845	23912.727332323564	19.87092877546453	5.0324774010299	1.270326392426079	30999.47174249841	63	0.014914183813266636	middle	323
Traditional Housing	501755.4033032762	8599.80659236393	7372.578237612914	68.05697913702087	1.4693570191922185	2.075976535240284	15972.384829976843	128	0.01713943992580374	low	324
ODD Cubes Basic	307759.09818992816	6540.745173462884	9431.639656513958	32.630497919561044	3.064617654518011	2.075976535240284	15972.384829976843	144	0.021252808485377018	low	324
Container (Base)	235498.38255270192	5005.002023008627	10967.382806968217	21.472614451195785	4.657094748629043	2.075976535240284	15972.384829976843	51	0.021252808485377018	low	324
Container (Max)	492705.2528333961	10471.37037820743	5501.014451769413	89.56625312535152	1.1164919432327491	2.075976535240284	15972.384829976843	110	0.021252808485377018	low	324
Traditional Housing	506495.76027850644	11114.189602048986	19175.26589943224	26.41401495733643	3.785868985139847	2.3954400686000987	30289.455501481225	98	0.02194330234065066	middle	325
ODD Cubes Basic	305527.48252607574	4753.407593555956	25536.04790792527	11.964556286380297	8.358019938761435	2.3954400686000987	30289.455501481225	102	0.015558036070127564	middle	325
Container (Base)	278109.61507114535	4326.8394227261715	25962.616078755054	10.711925725340121	9.335389598850567	2.3954400686000987	30289.455501481225	114	0.015558036070127564	middle	325
Container (Max)	494757.1245981901	7697.449190451239	22592.006311029985	21.89965414256445	4.566282159024544	2.3954400686000987	30289.455501481225	117	0.015558036070127564	middle	325
Traditional Housing	551806.9283211424	14922.916184508647	16002.104401169987	34.48339758868198	2.899946263787581	2.4070490592717695	30925.020585678634	106	0.027043727468067887	middle	326
ODD Cubes Basic	324141.60653760936	6262.203768832236	24662.816816846396	13.142927222984456	7.60865508142807	2.4070490592717695	30925.020585678634	123	0.01931934575052971	middle	326
Container (Base)	264082.60184512124	5101.903091745372	25823.117493933263	10.22659645595321	9.778424369310768	2.4070490592717695	30925.020585678634	75	0.01931934575052971	middle	326
Container (Max)	491026.2314387289	9486.305537744425	21438.71504793421	22.903715560417563	4.366103819976748	2.4070490592717695	30925.020585678634	136	0.01931934575052971	middle	326
Traditional Housing	525100.746444149	13316.576512020509	2234.139692628458	100	0.4254687710420322	2.918629894458279	15550.716204648967	111	0.02536004110105925	low	327
ODD Cubes Basic	324294.5252609228	6680.587530465592	8870.128674183376	36.56029547855221	2.735207653304229	2.918629894458279	15550.716204648967	122	0.020600370990199374	low	327
Container (Base)	241205.39829320443	4968.920689678814	10581.795514970152	22.794373407799196	4.387047549452908	2.918629894458279	15550.716204648967	108	0.020600370990199374	low	327
Container (Max)	435549.30181042466	8972.477201817064	6578.239002831902	66.21062287687064	1.5103316606153392	2.918629894458279	15550.716204648967	43	0.020600370990199374	low	327
Traditional Housing	532482.2905280684	12763.67986066089	17299.344564934276	30.780489314456954	3.2488112511269303	-3.558582297513019	30063.024425595166	139	0.02397014903162885	middle	328
ODD Cubes Basic	301924.0147060431	7464.670104024195	22598.354321570972	13.360442553015703	7.484782005026331	-3.558582297513019	30063.024425595166	48	0.024723671322706437	middle	328
Container (Base)	247618.0476960717	6122.027224807923	23940.997200787242	10.342846023470125	9.668518681712815	-3.558582297513019	30063.024425595166	123	0.024723671322706437	middle	328
Container (Max)	410305.1740895197	10144.250266195131	19918.774159400033	20.598916921596263	4.854624171776637	-3.558582297513019	30063.024425595166	75	0.024723671322706437	middle	328
Traditional Housing	561507.4384326978	8881.073767753594	6961.9847626321425	80.65335641734536	1.2398740045305037	-1.3457347296957	15843.058530385737	147	0.01581648462670914	low	329
ODD Cubes Basic	341287.5968636874	2937.284052148916	12905.77447823682	26.444565371819042	3.781495312702933	-1.3457347296957	15843.058530385737	112	0.008606477584129983	low	329
Container (Base)	267285.2795711793	2300.3847671972703	13542.673763188466	19.736522066839633	5.066748825418195	-1.3457347296957	15843.058530385737	85	0.008606477584129983	low	329
Container (Max)	449630.1551199726	3869.7318511889316	11973.326679196805	37.552650751706935	2.6629278625678525	-1.3457347296957	15843.058530385737	62	0.008606477584129983	low	329
ODD Cubes Basic	301747.58922570327	6953.169754784785	8768.664762981094	34.41203391645204	2.905960172037115	-4.917756988805021	15721.83451776588	140	0.023043000186436964	low	330
Container (Base)	259097.3328958695	5970.379890224841	9751.45462754104	26.570121360571246	3.7636260159652517	-4.917756988805021	15721.83451776588	70	0.023043000186436964	low	330
Container (Max)	430950.6816958788	9930.396638663271	5791.437879102608	74.4116902731339	1.3438748620403893	-4.917756988805021	15721.83451776588	99	0.023043000186436964	low	330
Traditional Housing	581223.0954949177	10423.11613423824	19750.84836908239	29.427753412595358	3.398152709720582	-1.8870181121395504	30173.96450332063	96	0.017933072885486158	middle	331
ODD Cubes Basic	337006.29533431533	2826.301789159592	27347.662714161037	12.323038310685627	8.114881856148042	-1.8870181121395504	30173.96450332063	125	0.00838649552927745	middle	331
Container (Base)	225874.48947766633	1894.2953961822752	28279.669107138354	7.9871687544127274	12.52008102930745	-1.8870181121395504	30173.96450332063	119	0.00838649552927745	middle	331
Container (Max)	462755.7980603927	3880.8994315807026	26293.065071739926	17.599918335795994	5.681844545642734	-1.8870181121395504	30173.96450332063	120	0.00838649552927745	middle	331
Traditional Housing	506640.22504121816	6141.894248956468	24432.102857772803	20.73666061372348	4.822377231453564	-0.7488593573051139	30573.99710672927	101	0.012122792359127799	middle	332
ODD Cubes Basic	306984.60330812016	6734.234956220974	23839.762150508297	12.876999416773746	7.765784307618956	-0.7488593573051139	30573.99710672927	144	0.021936718922224995	middle	332
Container (Base)	264504.9739746649	5802.371267612662	24771.62583911661	10.677739753237672	9.365277887549029	-0.7488593573051139	30573.99710672927	101	0.021936718922224995	middle	332
Container (Max)	423950.5274342864	9300.083557254979	21273.913549474295	19.92818699993085	5.018017946155714	-0.7488593573051139	30573.99710672927	94	0.021936718922224995	middle	332
ODD Cubes Basic	314408.71899748605	3027.556169362764	12922.256294598365	24.330791142790762	4.11001842945128	1.289076975441386	15949.812463961129	134	0.009629364538669081	low	333
Container (Base)	263375.38045559835	2536.1375489176166	13413.674915043512	19.63484146765935	5.092987390028615	1.289076975441386	15949.812463961129	147	0.009629364538669081	low	333
Container (Max)	436277.8746991685	4201.078695634086	11748.733768327042	37.134033616057685	2.6929474194464427	1.289076975441386	15949.812463961129	59	0.009629364538669081	low	333
Traditional Housing	499485.2595927116	14205.490198441734	1490.203810089768	100	0.2983479054626966	-4.2029866278199925	15695.694008531502	83	0.02844025909798644	low	334
ODD Cubes Basic	300615.97515144857	3519.4280037516087	12176.266004779893	24.68868329859411	4.050438769478422	-4.2029866278199925	15695.694008531502	65	0.01170738847786962	low	334
Container (Base)	257405.17181469125	3013.5423426473662	12682.151665884136	20.29664828146859	4.926921854940099	-4.2029866278199925	15695.694008531502	143	0.01170738847786962	low	334
Container (Max)	392209.49601328786	4591.748934537017	11103.945073994484	35.32163509452557	2.8311260147608173	-4.2029866278199925	15695.694008531502	75	0.01170738847786962	low	334
Traditional Housing	501645.43821843487	13093.2993156271	2525.6479121502052	100	0.5034727159325718	-4.26102448648932	15618.947227777306	94	0.026100704438033376	low	335
ODD Cubes Basic	317463.1963668148	7487.603853335238	8131.343374442067	39.04191247963348	2.5613499352052944	-4.26102448648932	15618.947227777306	99	0.023585738249430468	low	335
Container (Base)	232682.95406732458	5487.99924973617	10130.947978041135	22.967540112896216	4.353970843566754	-4.26102448648932	15618.947227777306	103	0.023585738249430468	low	335
Container (Max)	408251.7789049629	9628.919597116814	5990.027630660492	68.15524135736698	1.467238586621055	-4.26102448648932	15618.947227777306	95	0.023585738249430468	low	335
Traditional Housing	565315.1044492831	13452.594031182009	16584.47501986128	34.08700629789436	2.933669185439064	-2.142588771452427	30037.069051043287	91	0.023796629393596717	middle	336
ODD Cubes Basic	311373.7609334795	6489.274040808002	23547.795010235284	13.223053827253796	7.562549567323988	-2.142588771452427	30037.069051043287	117	0.020840786395595938	middle	336
Container (Base)	225890.71071580908	4707.740050777531	25329.329000265756	8.918148234935044	11.21309013549138	-2.142588771452427	30037.069051043287	114	0.020840786395595938	middle	336
Container (Max)	480134.00408744684	10006.370220448667	20030.69883059462	23.969907797430242	4.17189756611082	-2.142588771452427	30037.069051043287	113	0.020840786395595938	middle	336
Traditional Housing	547502.5493685709	14082.011634287517	16498.578649673786	33.18483131147763	3.0134249911167403	1.7044503611199975	30580.590283961305	83	0.025720449430834902	middle	337
ODD Cubes Basic	329887.76551487786	4129.340802165711	26451.249481795596	12.471538092819198	8.01825719135457	1.7044503611199975	30580.590283961305	132	0.012517411173829901	middle	337
Container (Base)	267891.36283425486	3353.306338514022	27227.28394544728	9.839077719650748	10.163554232352343	1.7044503611199975	30580.590283961305	123	0.012517411173829901	middle	337
Container (Max)	434489.54826912	5438.684326416189	25141.905957545117	17.281488086177855	5.786538722899817	1.7044503611199975	30580.590283961305	138	0.012517411173829901	middle	337
Traditional Housing	568237.7096795123	6482.927650612548	9034.17472006093	62.89868496982975	1.5898583578967735	-3.709185827460634	15517.102370673478	147	0.011408830389431454	low	338
ODD Cubes Basic	314119.5770795716	3807.6458173875703	11709.456553285907	26.826144804425052	3.7277067103397092	-3.709185827460634	15517.102370673478	97	0.012121644415760281	low	338
Container (Base)	222919.7976866657	2702.154520790983	12814.947849882494	17.39529495539147	5.748680908052449	-3.709185827460634	15517.102370673478	74	0.012121644415760281	low	338
Container (Max)	434426.68077538203	5265.965749078184	10251.136621595295	42.37839147126458	2.3596931485190225	-3.709185827460634	15517.102370673478	129	0.012121644415760281	low	338
Traditional Housing	589990.8741931586	10124.778547348062	5826.890418066208	100	0.9876238214760129	4.901696055467605	15951.66896541427	88	0.01716090704147618	low	339
ODD Cubes Basic	305778.3838251357	5572.97901189741	10378.68995351686	29.46213685875851	3.394186934892062	4.901696055467605	15951.66896541427	96	0.018225549308562006	low	339
Container (Base)	261021.14254148916	4757.253703967102	11194.415261447168	23.31708592591065	4.288700582814982	4.901696055467605	15951.66896541427	90	0.018225549308562006	low	339
Container (Max)	466170.9155041819	8496.221006738959	7455.447958675311	62.527552749092145	1.5992949604356925	4.901696055467605	15951.66896541427	137	0.018225549308562006	low	339
Traditional Housing	550460.0061187458	11422.54022188866	18825.668349592386	29.239865267820058	3.419988398854048	2.6365394054316074	30248.208571481046	92	0.020750899420337865	middle	340
ODD Cubes Basic	351846.4077992461	4644.660462145557	25603.54810933549	13.742095677393904	7.276910476216705	2.6365394054316074	30248.208571481046	111	0.013200818195636298	middle	340
Container (Base)	240148.93474117047	3170.162427393917	27078.04614408713	8.868768945266398	11.275522072696893	2.6365394054316074	30248.208571481046	129	0.013200818195636298	middle	340
Container (Max)	451040.9548184574	5954.109643344662	24294.098928136384	18.565864745700903	5.386229048294446	2.6365394054316074	30248.208571481046	136	0.013200818195636298	middle	340
Traditional Housing	571364.7281493642	13888.62061238451	1974.1788898508512	100	0.34551990919095865	0.07488159292289609	15862.79950223536	85	0.02430780187879185	low	341
ODD Cubes Basic	315006.120354614	7825.240958998091	8037.55854323727	39.19176683567143	2.5515563107755157	0.07488159292289609	15862.79950223536	93	0.024841552126634647	low	341
Container (Base)	248001.80353319406	6160.749729969245	9702.049772266117	25.561794605725677	3.912088393731191	0.07488159292289609	15862.79950223536	67	0.024841552126634647	low	341
Container (Max)	454977.61552830134	11302.350152598234	4560.449349637127	99.7659617828019	1.002345872409947	0.07488159292289609	15862.79950223536	86	0.024841552126634647	low	341
Traditional Housing	577796.2197995525	15327.474099456122	14818.765514210387	38.990847061145374	2.5647044764936804	3.4147023236235245	30146.23961366651	119	0.02652747382939523	middle	342
ODD Cubes Basic	352674.6369877409	4084.4808794065566	26061.75873425995	13.532265438560987	7.389745675180455	3.4147023236235245	30146.23961366651	73	0.011581442074465181	middle	342
Container (Base)	272885.25871615065	3160.4048167965434	26985.834796869964	10.112166652254245	9.889077527980376	3.4147023236235245	30146.23961366651	122	0.011581442074465181	middle	342
Container (Max)	437520.1208607419	5067.113936161687	25079.12567750482	17.445589072237215	5.73210796069588	3.4147023236235245	30146.23961366651	94	0.011581442074465181	middle	342
Traditional Housing	542575.8866609146	10845.157043785272	4943.280246124219	100	0.9110762876960556	3.6617645639021106	15788.43728990949	109	0.01998827686672151	low	343
ODD Cubes Basic	307592.92656178266	5812.225990751327	9976.211299158163	30.832639499901	3.243316226634476	3.6617645639021106	15788.43728990949	61	0.018895837611479963	low	343
Container (Base)	265209.60939926514	5011.357712212544	10777.079577696946	24.608671346188597	4.063608253904697	3.6617645639021106	15788.43728990949	90	0.018895837611479963	low	343
Container (Max)	444483.50181539584	8398.888071285679	7389.549218623812	60.15028639300057	1.6625024749946422	3.6617645639021106	15788.43728990949	61	0.018895837611479963	low	343
Traditional Housing	541343.7848144117	7188.473218060406	8326.539367112568	65.01425873905835	1.5381241275296338	1.9332799550713675	15515.012585172974	126	0.013278942918915793	low	344
ODD Cubes Basic	306132.9685390591	7261.540389087981	8253.472196084993	37.09141574188283	2.69604160423249	1.9332799550713675	15515.012585172974	143	0.02372021681866483	low	344
Container (Base)	257363.25330199342	6104.712169480241	9410.300415692733	27.349100659189507	3.656427362864644	1.9332799550713675	15515.012585172974	118	0.02372021681866483	low	344
Container (Max)	441061.99703438306	10462.08620012887	5052.926385044104	87.28842722503532	1.145627240392285	1.9332799550713675	15515.012585172974	137	0.02372021681866483	low	344
Traditional Housing	499917.20436136355	11628.298896496355	3901.7667264156935	100	0.7804825863915085	-1.5266558311222491	15530.065622912049	140	0.023260449520538757	low	345
ODD Cubes Basic	329787.2795958411	5372.671244063683	10157.394378848367	32.46770454070249	3.079983676537311	-1.5266558311222491	15530.065622912049	139	0.016291323457496502	low	345
Container (Base)	257843.68716112574	4200.614909015438	11329.450713896611	22.75871034461157	4.393922084591069	-1.5266558311222491	15530.065622912049	42	0.016291323457496502	low	345
Container (Max)	426770.6362244741	6952.658476894482	8577.407146017566	49.75520328688384	2.009840044736816	-1.5266558311222491	15530.065622912049	63	0.016291323457496502	low	345
Traditional Housing	523493.7868903961	5859.887724785338	24470.413816593853	21.392927427136726	4.674442071595632	-4.411880724891622	30330.30154137919	133	0.011193805679325517	middle	346
ODD Cubes Basic	330809.3038967425	4955.509768512834	25374.791772866356	13.036926838961566	7.670519382002248	-4.411880724891622	30330.30154137919	88	0.014979958877032148	middle	346
Container (Base)	230288.40670281433	3449.710862265413	26880.59067911378	8.567088776131264	11.67257660252216	-4.411880724891622	30330.30154137919	145	0.014979958877032148	middle	346
Container (Max)	418200.7541202661	6264.630099065419	24065.67144231377	17.377481244298856	5.754573899068811	-4.411880724891622	30330.30154137919	127	0.014979958877032148	middle	346
Traditional Housing	584489.4120330757	10545.67078140908	20027.782051927847	29.183931127152125	3.426543174197738	-0.45807519920041884	30573.452833336927	111	0.018042535184217008	middle	347
ODD Cubes Basic	320008.1011804237	2703.5384078907573	27869.91442544617	11.482206091319947	8.709127776028659	-0.45807519920041884	30573.452833336927	87	0.008448343644795655	middle	347
Container (Base)	236107.3835847796	1994.7163135978026	28578.736519739126	8.261645276784785	12.104126557091467	-0.45807519920041884	30573.452833336927	87	0.008448343644795655	middle	347
Container (Max)	428944.3291877465	3623.8690974644337	26949.583735872493	15.916547483320874	6.282769558209223	-0.45807519920041884	30573.452833336927	85	0.008448343644795655	middle	347
Traditional Housing	584191.069559111	9508.12352211568	6072.46258993656	96.20332128966054	1.039465152132409	0.7664927516403512	15580.58611205224	93	0.016275708441232183	low	348
ODD Cubes Basic	316972.6524162077	6316.779554526814	9263.806557525426	34.21624258320851	2.92258858513806	0.7664927516403512	15580.58611205224	129	0.019928468611962243	low	348
Container (Base)	266644.10481662984	5313.8086734029785	10266.777438649262	25.97154817176115	3.850367307280124	0.7664927516403512	15580.58611205224	105	0.019928468611962243	low	348
Container (Max)	492264.81434334285	9810.08390141473	5770.502210637511	85.30710090291407	1.1722353583883662	0.7664927516403512	15580.58611205224	99	0.019928468611962243	low	348
Traditional Housing	551214.213798566	12506.909940674426	17498.434483986435	31.500773072185726	3.17452526548617	-0.34392475133632505	30005.344424660863	85	0.022689744980424094	middle	349
ODD Cubes Basic	327618.96892082854	4925.899354843393	25079.44506981747	13.063246336144429	7.655065014223306	-0.34392475133632505	30005.344424660863	73	0.015035452223872214	middle	349
Container (Base)	262964.85977125895	3953.7955856480203	26051.548839012845	10.094020182687277	9.906855563010925	-0.34392475133632505	30005.344424660863	44	0.015035452223872214	middle	349
Container (Max)	449001.7362057444	6750.944153157145	23254.40027150372	19.308248372930848	5.179133708482576	-0.34392475133632505	30005.344424660863	146	0.015035452223872214	middle	349
Traditional Housing	554556.2356243839	14242.739244361948	1537.8658758694855	100	0.27731468462129494	-1.1571066031967892	15780.605120231434	81	0.02568312883241826	low	350
ODD Cubes Basic	356217.8984408043	7278.691654733654	8501.913465497779	41.89855611756077	2.3867170916204294	-1.1571066031967892	15780.605120231434	112	0.020433256404557718	low	350
Container (Base)	238481.3575246706	4872.950726008595	10907.654394222838	21.863670126088756	4.573797510815685	-1.1571066031967892	15780.605120231434	140	0.020433256404557718	low	350
Container (Max)	484704.2175078474	9904.08555670836	5876.519563523074	82.4815117636159	1.2123929091720629	-1.1571066031967892	15780.605120231434	130	0.020433256404557718	low	350
Traditional Housing	496201.8538212404	8927.191626255888	6729.883965530695	73.73111577594811	1.3562794886202045	3.006124721543028	15657.075591786583	148	0.017991048516864186	low	351
ODD Cubes Basic	323518.2460917992	4716.001253463664	10941.074338322918	29.569147972847894	3.3819033301813697	3.006124721543028	15657.075591786583	120	0.014577234237742143	low	351
Container (Base)	259170.38246724033	3777.9873727101817	11879.0882190764	21.817363225827684	4.583505301026417	3.006124721543028	15657.075591786583	88	0.014577234237742143	low	351
Container (Max)	447252.8456855965	6519.709495055681	9137.3660967309	48.94767714797061	2.0429978668384274	3.006124721543028	15657.075591786583	131	0.014577234237742143	low	351
Traditional Housing	533938.7741181266	5828.534080949489	24775.735500959665	21.55087481045497	4.640182864014737	-4.382414597446312	30604.269581909153	94	0.010916109418305715	middle	352
ODD Cubes Basic	313336.6953866624	2613.1123525556404	27991.157229353514	11.194131518723895	8.933252198505505	-4.382414597446312	30604.269581909153	60	0.00833963079023036	middle	352
Container (Base)	224600.848790648	1873.088154086361	28731.18142782279	7.817320333828957	12.792107234912246	-4.382414597446312	30604.269581909153	101	0.00833963079023036	middle	352
Container (Max)	450349.0931865255	3755.7451638906696	26848.52441801848	16.773699968564713	5.961713884677096	-4.382414597446312	30604.269581909153	88	0.00833963079023036	middle	352
Traditional Housing	542118.5251954958	14512.076504826284	16233.483490627783	33.39508279344244	2.9944528246426834	3.5257197664276045	30745.559995454067	145	0.02676919498294772	middle	353
ODD Cubes Basic	346927.80886405887	3654.470015416687	27091.08998003738	12.80597455176959	7.808855124281151	3.5257197664276045	30745.559995454067	132	0.010533805368276673	middle	353
Container (Base)	241692.41195792644	2545.940826554143	28199.619168899924	8.570768651531223	11.667564960131592	3.5257197664276045	30745.559995454067	142	0.010533805368276673	middle	353
Container (Max)	435764.18249975896	4590.255084918657	26155.304910535408	16.660642419971648	6.002169512991095	3.5257197664276045	30745.559995454067	124	0.010533805368276673	middle	353
Traditional Housing	545107.1053178855	14863.853404184561	701.8100209841723	100	0.12874717906582847	-4.245515168004123	15565.663425168734	138	0.027267766754785802	low	354
ODD Cubes Basic	340806.85861369036	7830.525741090158	7735.137684078576	44.05957237389342	2.2696543477860196	-4.245515168004123	15565.663425168734	119	0.022976432378569514	low	354
Container (Base)	230929.9242523218	5305.945788771652	10259.717636397083	22.508409337999844	4.442783961244872	-4.245515168004123	15565.663425168734	126	0.022976432378569514	low	354
Container (Max)	396709.39258748136	9114.966532729652	6450.696892439082	61.498687537538444	1.6260509614771954	-4.245515168004123	15565.663425168734	98	0.022976432378569514	low	354
Traditional Housing	505629.52038932964	12307.750124357128	17883.08921486408	28.274170883689383	3.5367969024226045	-1.384894610154077	30190.83933922121	95	0.024341438994464334	middle	355
ODD Cubes Basic	339920.7861641476	7364.591898520149	22826.24744070106	14.89166307546641	6.715166700537776	-1.384894610154077	30190.83933922121	147	0.021665612102237816	middle	355
Container (Base)	259069.86352193853	5612.907170446011	24577.932168775198	10.540751017739051	9.486990047645543	-1.384894610154077	30190.83933922121	127	0.021665612102237816	middle	355
Container (Max)	430530.9029025624	9327.715540313131	20863.123798908076	20.635975084665667	4.845906219101259	-1.384894610154077	30190.83933922121	108	0.021665612102237816	middle	355
Traditional Housing	515041.3987553463	6785.737601022904	23383.881548603567	22.025487842334005	4.5401945562265995	-1.8881980946367447	30169.619149626473	97	0.01317513042140181	middle	356
ODD Cubes Basic	300197.7952568206	6986.948908975144	23182.67024065133	12.949232859742667	7.72246519026512	-1.8881980946367447	30169.619149626473	134	0.023274484421172303	middle	356
Container (Base)	249910.7186728104	5816.5431284343	24353.076021192173	10.261977520019927	9.744710491219807	-1.8881980946367447	30169.619149626473	109	0.023274484421172303	middle	356
Container (Max)	463284.6175357129	10782.710613403719	19386.908536222756	23.896776356586496	4.184664848003138	-1.8881980946367447	30169.619149626473	122	0.023274484421172303	middle	356
Traditional Housing	579189.7427980473	16020.021942027772	14686.79268844314	39.43609439342088	2.535748063750527	1.4504501950584023	30706.81463047091	129	0.027659367489202336	middle	357
ODD Cubes Basic	302684.14040072006	2803.6675610938037	27903.147069377108	10.847670323642708	9.218569242655546	1.4504501950584023	30706.81463047091	58	0.009262684055339207	middle	357
Container (Base)	231190.48147227854	2141.444386479469	28565.37024399144	8.093382984276499	12.355772634790176	1.4504501950584023	30706.81463047091	69	0.009262684055339207	middle	357
Container (Max)	457466.5926554332	4237.368513639837	26469.446116831074	17.28281697456997	5.786093791720444	1.4504501950584023	30706.81463047091	54	0.009262684055339207	middle	357
Traditional Housing	591232.1776274507	12758.735146345976	17242.06507722887	34.290102431423655	2.9162934173203108	4.93554516138488	30000.800223574846	145	0.021579906556414723	middle	358
ODD Cubes Basic	302065.7157065716	4834.165341014512	25166.634882560335	12.002626378781112	8.331509858274465	4.93554516138488	30000.800223574846	101	0.01600368757409877	middle	358
Container (Base)	277096.53211842093	4434.566327889434	25566.23389568541	10.838378982568257	9.22647198080391	4.93554516138488	30000.800223574846	83	0.01600368757409877	middle	358
Container (Max)	435914.6130279724	6976.241275883836	23024.55894769101	18.932593411162284	5.281896559456137	4.93554516138488	30000.800223574846	88	0.01600368757409877	middle	358
Traditional Housing	511577.4508367782	6380.81216284017	24002.943600428815	21.313113064500925	4.691947145279297	-0.47753801464997636	30383.755763268986	84	0.012472817463715783	middle	359
ODD Cubes Basic	320029.07060560444	6105.004422111708	24278.75134115728	13.181446858969718	7.586420600857785	-0.47753801464997636	30383.755763268986	41	0.019076405810756352	middle	359
Container (Base)	236062.71010616576	4503.228054772153	25880.527708496833	9.12124794227685	10.963412093700628	-0.47753801464997636	30383.755763268986	129	0.019076405810756352	middle	359
Container (Max)	465274.11993278767	8875.75792508038	21507.997838188607	21.632609573108123	4.622650802347571	-0.47753801464997636	30383.755763268986	78	0.019076405810756352	middle	359
Traditional Housing	578702.15660146	6634.498885270546	23709.49223539505	24.40803669922278	4.097011211196035	3.3664070752765376	30343.991120665596	98	0.011464444722710075	middle	360
ODD Cubes Basic	350413.3741415303	7351.965852632642	22992.025268032954	15.240648444690464	6.5614006098827105	3.3664070752765376	30343.991120665596	64	0.020980836906251236	middle	360
Container (Base)	250600.48120787836	5257.8078248505735	25086.183295815023	9.98958184482709	10.010429020288077	3.3664070752765376	30343.991120665596	147	0.020980836906251236	middle	360
Container (Max)	427577.07771454006	8970.924932380276	21373.06618828532	20.005415879397646	4.9986463966982	3.3664070752765376	30343.991120665596	63	0.020980836906251236	middle	360
ODD Cubes Basic	331278.7536928156	3831.775992658732	12112.856690554965	27.349349716250764	3.656394065581048	1.7231814089865969	15944.632683213697	134	0.011566621613808102	low	361
Container (Base)	268017.0001048785	3100.051226281096	12844.5814569326	20.866152860140243	4.7924502743879485	1.7231814089865969	15944.632683213697	120	0.011566621613808102	low	361
Container (Max)	466636.85255320906	5397.411904541333	10547.220778672363	44.24263626839024	2.2602631405906153	1.7231814089865969	15944.632683213697	68	0.011566621613808102	low	361
Traditional Housing	558579.7696072579	10810.40174999524	4768.8009008265235	100	0.8537367732060019	3.480509388841508	15579.202650821764	95	0.019353371421947707	low	362
ODD Cubes Basic	301868.2154264504	6550.299750031022	9028.902900790741	33.43354322705289	2.991008141759998	3.480509388841508	15579.202650821764	55	0.021699203212823807	low	362
Container (Base)	278187.2654434618	6036.442004077435	9542.76064674433	29.15165492895077	3.4303369823676495	3.480509388841508	15579.202650821764	93	0.021699203212823807	low	362
Container (Max)	443886.25537483447	9631.978058757937	5947.224592063827	74.63754706139245	1.339808232413451	3.480509388841508	15579.202650821764	140	0.021699203212823807	low	362
Traditional Housing	599577.8867472579	9160.305546220092	20953.138649670364	28.61518251618549	3.494648337239764	4.272971888547797	30113.444195890457	113	0.015277924267546355	middle	363
ODD Cubes Basic	345065.35255477077	7159.435360167123	22954.008835723333	15.032901443243562	6.652075807025552	4.272971888547797	30113.444195890457	112	0.020748056294729665	middle	363
Container (Base)	255218.7887907747	5295.293797303714	24818.150398586742	10.283553959174492	9.724264626509282	4.272971888547797	30113.444195890457	93	0.020748056294729665	middle	363
Container (Max)	455362.92988606944	9447.895703809207	20665.548492081252	22.034882357976517	4.538258855909003	4.272971888547797	30113.444195890457	54	0.020748056294729665	middle	363
Traditional Housing	499925.65982709476	6040.535865909621	9622.730389733635	51.952578902185486	1.9248322626731686	2.147713172626222	15663.266255643255	100	0.012082868216844105	low	364
ODD Cubes Basic	304617.02012808714	4102.746673273834	11560.519582369421	26.349768966496004	3.795099688621596	2.147713172626222	15663.266255643255	78	0.013468540502263095	low	364
Container (Base)	269951.7519012263	3635.8561041385447	12027.410151504711	22.444711579695607	4.4553925161802495	2.147713172626222	15663.266255643255	41	0.013468540502263095	low	364
Container (Max)	420800.7813614291	5667.572367150365	9995.69388849289	42.098206093111536	2.375398129289002	2.147713172626222	15663.266255643255	135	0.013468540502263095	low	364
Traditional Housing	552226.3674111612	11135.189883342638	4816.26389583592	100	0.8721539173173819	-0.5010056844119992	15951.453779178559	101	0.02016417639661873	low	365
ODD Cubes Basic	345140.5097868185	3913.1799843911103	12038.273794787448	28.670265826339968	3.487934175626929	-0.5010056844119992	15951.453779178559	110	0.011337933025619472	low	365
Container (Base)	261135.09534944737	2960.732221710789	12990.72155746777	20.101662112781778	4.9747130082548905	-0.5010056844119992	15951.453779178559	64	0.011337933025619472	low	365
Container (Max)	425162.8339737321	4820.467736576745	11130.986042601813	38.19633160498981	2.6180524620572836	-0.5010056844119992	15951.453779178559	93	0.011337933025619472	low	365
Traditional Housing	528979.4990218888	12334.6109173689	18040.505452348913	29.321767087906874	3.4104356569029166	2.130924026052721	30375.116369717813	138	0.023317748495312672	middle	366
ODD Cubes Basic	295340.93519368867	5632.160373917082	24742.95599580073	11.936364242163009	8.37776042781674	2.130924026052721	30375.116369717813	68	0.019070029592150622	middle	366
Container (Base)	245873.99899448993	4688.824436765335	25686.291932952478	9.572187361113912	10.446932997387865	2.130924026052721	30375.116369717813	100	0.019070029592150622	middle	366
Container (Max)	448139.14122673566	8546.026684594815	21829.089685123	20.529447067696655	4.871051795513346	2.130924026052721	30375.116369717813	106	0.019070029592150622	middle	366
Traditional Housing	577805.9117612463	8183.096993985312	22302.382534546698	25.907811009259525	3.8598397975135654	-1.2904510412497618	30485.47952853201	130	0.014162362875523207	middle	367
ODD Cubes Basic	297898.98740915547	3807.8114365226884	26677.66809200932	11.166605206336765	8.955273169615824	-1.2904510412497618	30485.47952853201	88	0.012782223496761242	middle	367
Container (Base)	235406.9821522503	3009.024658568148	27476.45486996386	8.56758935118619	11.671894613641225	-1.2904510412497618	30485.47952853201	79	0.012782223496761242	middle	367
Container (Max)	413056.4313133095	5279.779621821331	25205.69990671068	16.38742160868696	6.102241242575347	-1.2904510412497618	30485.47952853201	54	0.012782223496761242	middle	367
Traditional Housing	586945.4539411435	14821.505995888114	16153.162512915951	36.336256350533596	2.752072173734857	4.795336873037607	30974.668508804065	96	0.025251930816341844	middle	368
ODD Cubes Basic	300921.43270306033	6826.841671246478	24147.826837557586	12.461636184794541	8.024628428971322	4.795336873037607	30974.668508804065	149	0.022686458754112696	middle	368
Container (Base)	249449.36654866074	5659.122765445731	25315.545743358336	9.853604148119345	10.148570867755629	4.795336873037607	30974.668508804065	70	0.022686458754112696	middle	368
Container (Max)	476293.04226443655	10805.402458202994	20169.266050601072	23.614792976080672	4.234633778127532	4.795336873037607	30974.668508804065	80	0.022686458754112696	middle	368
Traditional Housing	534830.1637940404	7727.094689148012	23227.221806944675	23.02600665027155	4.34291544855524	2.314492700106956	30954.316496092688	124	0.014447754095118061	middle	369
ODD Cubes Basic	330885.6739305118	4295.999995506741	26658.31650058595	12.41209938831805	8.05665479073729	2.314492700106956	30954.316496092688	130	0.012983336342355302	middle	369
Container (Base)	280401.08981884574	3640.541659881053	27313.774836211636	10.265922286475757	9.740966004753338	2.314492700106956	30954.316496092688	46	0.012983336342355302	middle	369
Container (Max)	435756.2663867637	5657.570169788328	25296.74632630436	17.225783140879685	5.8052513016190925	2.314492700106956	30954.316496092688	73	0.012983336342355302	middle	369
Traditional Housing	594171.7096701926	7321.553689476914	22742.225528117586	26.126366082140123	3.8275510526647483	-2.382226673911406	30063.7792175945	98	0.012322285915532558	middle	370
ODD Cubes Basic	319512.90071497636	7541.471510325927	22522.307707268574	14.186508099783252	7.048950967823283	-2.382226673911406	30063.7792175945	96	0.02360302664915977	middle	370
Container (Base)	238289.70874913014	5624.358345826238	24439.420871768263	9.750219123416127	10.256179757010795	-2.382226673911406	30063.7792175945	41	0.02360302664915977	middle	370
Container (Max)	432688.34066490346	10212.754435494437	19851.024782100063	21.79677600599564	4.587834456457827	-2.382226673911406	30063.7792175945	106	0.02360302664915977	middle	370
Traditional Housing	580558.0254628198	9693.924148750317	20714.156450627303	28.027114058281548	3.5679734913859837	-4.132235312088955	30408.08059937762	120	0.016697597352172227	middle	371
ODD Cubes Basic	302374.0858772649	5288.552542928604	25119.528056449017	12.037411100947633	8.307434145214797	-4.132235312088955	30408.08059937762	139	0.017490098490368824	middle	371
Container (Base)	229923.66439035986	4021.3875354539014	26386.693063923718	8.71362181813965	11.47628415452048	-4.132235312088955	30408.08059937762	56	0.017490098490368824	middle	371
Container (Max)	432281.1609268512	7560.640080141603	22847.440519236017	18.920332041696284	5.285319506001365	-4.132235312088955	30408.08059937762	55	0.017490098490368824	middle	371
Traditional Housing	578437.0698788832	8948.622401659848	6620.465112762324	87.37106230857185	1.144543712274277	4.567080392881207	15569.087514422172	93	0.015470347368182275	low	372
ODD Cubes Basic	319861.0645234841	6014.371928870206	9554.715585551967	33.47677507085168	2.98714555952166	4.567080392881207	15569.087514422172	63	0.018803076072513455	low	372
Container (Base)	239138.14016527453	4496.532641367043	11072.554873055129	21.597376839126177	4.6301919323294065	4.567080392881207	15569.087514422172	123	0.018803076072513455	low	372
Container (Max)	496174.32970676123	9329.603666704605	6239.483847717567	79.52169471329975	1.2575184716640013	4.567080392881207	15569.087514422172	100	0.018803076072513455	low	372
Traditional Housing	517160.1984524141	7251.6461134142755	8228.175771338998	62.85235182430417	1.5910303607975942	0.4229197883166229	15479.821884753273	134	0.01402204990854788	low	373
ODD Cubes Basic	301135.339574333	3567.5984006883914	11912.223484064882	25.27952400970022	3.955770684670651	0.4229197883166229	15479.821884753273	44	0.011847159505527768	low	373
Container (Base)	248052.20468169785	2938.7140345618964	12541.107850191376	19.779130172930664	5.055834059723115	0.4229197883166229	15479.821884753273	100	0.011847159505527768	low	373
Container (Max)	492609.4464789001	5836.022686365273	9643.799198388	51.080433794312285	1.9576967651189923	0.4229197883166229	15479.821884753273	123	0.011847159505527768	low	373
ODD Cubes Basic	307784.9599598832	4441.629518401395	11255.675817861582	27.344867153286398	3.656993447414926	-4.841266541710528	15697.305336262976	136	0.014430950488874827	low	374
Container (Base)	229638.45263349824	3313.9011402958404	12383.404195967136	18.54404887375669	5.392565597770763	-4.841266541710528	15697.305336262976	46	0.014430950488874827	low	374
Container (Max)	404404.5273027911	5835.941710983407	9861.36362527957	41.00898645153917	2.4384899177689077	-4.841266541710528	15697.305336262976	64	0.014430950488874827	low	374
Traditional Housing	590592.1635974639	7019.137988275231	8827.488488914649	66.90375913139003	1.4946843241440795	3.0243820040588965	15846.626477189879	105	0.011884915549030784	low	375
ODD Cubes Basic	322840.54569859756	7641.19531065134	8205.43116653854	39.34473876462824	2.5416358867758486	3.0243820040588965	15846.626477189879	85	0.023668635840385192	low	375
Container (Base)	243816.96887671947	5770.815048049603	10075.811429140274	24.198246522515888	4.132530838833814	3.0243820040588965	15846.626477189879	134	0.023668635840385192	low	375
Container (Max)	446850.90978144173	10576.351458561761	5270.275018628117	84.78701931151964	1.179425822631949	3.0243820040588965	15846.626477189879	127	0.023668635840385192	low	375
Traditional Housing	544916.0135586703	9635.526449942668	20381.898975565127	26.73529165324309	3.7403743821836937	2.5725979328014983	30017.425425507798	106	0.0176825899958714	middle	376
ODD Cubes Basic	316769.82240763085	3779.390629498306	26238.03479600949	12.072924853953161	8.282996971297802	2.5725979328014983	30017.425425507798	93	0.011931031184639961	middle	376
Container (Base)	264634.9466543551	3157.3678010786434	26860.057624429155	9.852359602299225	10.14985283085518	2.5725979328014983	30017.425425507798	123	0.011931031184639961	middle	376
Container (Max)	479545.0596060201	5721.467060599455	24295.958364908343	19.73764740635409	5.066459945363461	2.5725979328014983	30017.425425507798	92	0.011931031184639961	middle	376
Traditional Housing	553736.1777852571	5870.089042153233	9904.12863527687	55.90963104143663	1.788600606680563	4.613932482328353	15774.217677430102	145	0.010600876875394795	low	377
ODD Cubes Basic	340053.02530025074	5372.4496575777175	10401.768019852385	32.69184860220297	3.0588664843278828	4.613932482328353	15774.217677430102	71	0.01579885858340504	low	377
Container (Base)	238623.87712077296	3769.984889254913	12004.23278817519	19.878311369955288	5.03060839217677	4.613932482328353	15774.217677430102	99	0.01579885858340504	low	377
Container (Max)	482311.2008323598	7619.966455142719	8154.251222287384	59.14843529888997	1.690661798485085	4.613932482328353	15774.217677430102	141	0.01579885858340504	low	377
Traditional Housing	550416.3596641589	6468.389616833013	24059.493538685398	22.877304494341963	4.371144337600266	-4.5501723081322805	30527.88315551841	84	0.011751812066014453	middle	378
ODD Cubes Basic	323583.65055872744	6978.006755627892	23549.87639989052	13.740354516690022	7.277832597298187	-4.5501723081322805	30527.88315551841	88	0.021564769244611287	middle	378
Container (Base)	247466.72490399992	5336.5628182744595	25191.320337243953	9.823491646769076	10.1796798527222	-4.5501723081322805	30527.88315551841	66	0.021564769244611287	middle	378
Container (Max)	441614.8098213162	9523.321468799582	21004.56168671883	21.024709603940412	4.756308262220096	-4.5501723081322805	30527.88315551841	147	0.021564769244611287	middle	378
Traditional Housing	591568.6587963518	14932.191076086325	872.0652183181683	100	0.1474157234922714	2.6216009385959165	15804.256294404493	109	0.0252416872565028	low	379
ODD Cubes Basic	307833.8889609116	3447.099761858818	12357.156532545676	24.911385410563806	4.014228769372035	2.6216009385959165	15804.256294404493	121	0.011197921624205992	low	379
Container (Base)	243678.1871721994	2728.6892414828867	13075.567052921606	18.636146806172505	5.365916089847439	2.6216009385959165	15804.256294404493	71	0.011197921624205992	low	379
Container (Max)	474302.86014162976	5311.206254002706	10493.050040401788	45.20161995944015	2.212310091756246	2.6216009385959165	15804.256294404493	72	0.011197921624205992	low	379
ODD Cubes Basic	296118.0571725957	3846.754803121576	12109.655933495449	24.453052902480053	4.089468926387425	-3.500242293842053	15956.410736617025	53	0.012990612054703076	low	380
Container (Base)	230092.88454509428	2989.0473996729047	12967.36333694412	17.743999189839762	5.63570810222197	-3.500242293842053	15956.410736617025	114	0.012990612054703076	low	380
Container (Max)	440179.85667939973	5718.205752416882	10238.204984200143	42.993850714915006	2.3259140164737317	-3.500242293842053	15956.410736617025	82	0.012990612054703076	low	380
Traditional Housing	529994.8203709045	9883.089590764246	5640.654704869099	93.95980574974833	1.0642848737505808	-0.8669350477154172	15523.744295633345	116	0.018647521090579332	low	381
ODD Cubes Basic	324307.5562884401	4824.453751166617	10699.290544466729	30.31112716685311	3.2991184870668717	-0.8669350477154172	15523.744295633345	54	0.014876168185473094	low	381
Container (Base)	271902.340767842	4044.8649512862353	11478.87934434711	23.687185186918363	4.221691991297752	-0.8669350477154172	15523.744295633345	140	0.014876168185473094	low	381
Container (Max)	417044.975259716	6204.03119287	9319.713102763344	44.748692439476486	2.2347021677840537	-0.8669350477154172	15523.744295633345	77	0.014876168185473094	low	381
Traditional Housing	560254.7163985809	8654.90380421978	6987.837478711535	80.17569356834619	1.2472608037341701	-4.3348082405534685	15642.741282931316	126	0.015448158758671546	low	382
ODD Cubes Basic	342426.4952409495	6903.595229292227	8739.14605363909	39.183061266994024	2.5521232074900517	-4.3348082405534685	15642.741282931316	139	0.020160809181644923	low	382
Container (Base)	218279.50046171408	4400.691357073392	11242.049925857924	19.41634327380523	5.150300372723166	-4.3348082405534685	15642.741282931316	95	0.020160809181644923	low	382
Container (Max)	393549.8791257028	7934.284016512718	7708.457266418598	51.05429861305422	1.9586989287211694	-4.3348082405534685	15642.741282931316	80	0.020160809181644923	low	382
Traditional Housing	504182.40515500423	14902.381232092224	638.7376221971317	100	0.12668780498215923	0.10437164746208705	15541.118854289356	148	0.029557519420993446	low	383
ODD Cubes Basic	351933.13631322136	4404.75799548763	11136.360858801727	31.602167061160532	3.1643399582841036	0.10437164746208705	15541.118854289356	43	0.01251589447254374	low	383
Container (Base)	236073.86819130942	2954.675622007629	12586.443232281727	18.75620171915024	5.331569872054594	0.10437164746208705	15541.118854289356	118	0.01251589447254374	low	383
Container (Max)	465897.45980495453	5831.123441944999	9709.995412344357	47.98122347335583	2.084148605663013	0.10437164746208705	15541.118854289356	112	0.01251589447254374	low	383
ODD Cubes Basic	298890.15024354815	4290.715369950243	11186.131029675804	26.719707596006103	3.7425559258345844	-3.681721485187083	15476.846399626047	61	0.014355492700090618	low	384
Container (Base)	229995.01249235435	3301.6917228912434	12175.154676734805	18.890520785895724	5.293660303672689	-3.681721485187083	15476.846399626047	141	0.014355492700090618	low	384
Container (Max)	445909.93334283045	6401.256793000897	9075.58960662515	49.13288862437298	2.035296576281366	-3.681721485187083	15476.846399626047	56	0.014355492700090618	low	384
Traditional Housing	569317.0956007185	13859.24641164846	2096.9743174805353	100	0.3683315209897043	-4.100785574707629	15956.220729128996	132	0.02434363295735005	low	385
ODD Cubes Basic	305874.05064398417	6774.016688502988	9182.20404062601	33.31161552179261	3.001955877359942	-4.100785574707629	15956.220729128996	73	0.022146424890379032	low	385
Container (Base)	250255.24428222908	5542.258970919843	10413.961758209152	24.030743543393275	4.16133607432604	-4.100785574707629	15956.220729128996	111	0.022146424890379032	low	385
Container (Max)	400210.65786988183	8863.235274844517	7092.985454284479	56.4234426320636	1.7723129843759882	-4.100785574707629	15956.220729128996	51	0.022146424890379032	low	385
Traditional Housing	532623.7112783764	10770.953665451929	4739.57865014124	100	0.8898549857582465	2.184860257699861	15510.53231559317	106	0.02022244492195068	low	386
ODD Cubes Basic	309418.5704580908	6317.60791762204	9192.924397971128	33.65833950797847	2.971031888732827	2.184860257699861	15510.53231559317	119	0.02041767534595254	low	386
Container (Base)	234205.06755628597	4781.923033741129	10728.609281852041	21.82995590607024	4.5808612912586355	2.184860257699861	15510.53231559317	96	0.02041767534595254	low	386
Container (Max)	433322.915697238	8847.446612667767	6663.085702925402	65.03336967540268	1.537672128925877	2.184860257699861	15510.53231559317	96	0.02041767534595254	low	386
Traditional Housing	501329.6145965117	12241.298208329808	18525.47825102182	27.06162873656768	3.69526908278335	3.030639013492454	30766.77645935163	131	0.02441766425105776	middle	387
ODD Cubes Basic	348170.2322054613	5799.740555925169	24967.035903426462	13.945196920940006	7.170927780147782	3.030639013492454	30766.77645935163	69	0.016657772605047527	middle	387
Container (Base)	278561.44544197177	4640.213214705718	26126.563244645913	10.662001076588481	9.379102410670265	3.030639013492454	30766.77645935163	109	0.016657772605047527	middle	387
Container (Max)	473241.89221528696	7883.1558277046615	22883.62063164697	20.680376581702973	4.835501887740057	3.030639013492454	30766.77645935163	98	0.016657772605047527	middle	387
Traditional Housing	571675.9458994688	7439.852212725034	23451.709474203395	24.376728124161083	4.102273262049661	-0.6548979739757019	30891.56168692843	89	0.013014107495845834	middle	388
ODD Cubes Basic	318267.51623899647	4210.984304602067	26680.577382326366	11.928809173740815	8.383066452276937	-0.6548979739757019	30891.56168692843	55	0.013230958516796652	middle	388
Container (Base)	238195.08948201704	3151.5493478412336	27740.012339087196	8.58669731542935	11.645921164626476	-0.6548979739757019	30891.56168692843	112	0.013230958516796652	middle	388
Container (Max)	481948.18504265323	6376.636443544781	24514.925243383652	19.659378124056346	5.086630887761107	-0.6548979739757019	30891.56168692843	131	0.013230958516796652	middle	388
Traditional Housing	502414.6749980622	13504.393392914402	2256.080102088077	100	0.4490474132939646	2.8004409361422535	15760.47349500248	130	0.026878978789714868	low	389
ODD Cubes Basic	337205.39723801584	6454.526233824783	9305.947261177696	36.23547262563591	2.7597266643419442	2.8004409361422535	15760.47349500248	138	0.019141230498362596	low	389
Container (Base)	251389.07008465627	4811.896135259435	10948.577359743045	22.96088905659942	4.355232053667277	2.8004409361422535	15760.47349500248	128	0.019141230498362596	low	389
Container (Max)	486754.8610936356	9317.086992391747	6443.386502610732	75.54332817011864	1.3237436372250706	2.8004409361422535	15760.47349500248	62	0.019141230498362596	low	389
Traditional Housing	529936.7745742628	8231.858860528833	22666.510803942117	23.379724350079375	4.2772103940421555	0.3168443928033584	30898.369664470953	99	0.015533662231956052	middle	390
ODD Cubes Basic	313386.0426327453	5517.314447324844	25381.05521714611	12.34724245905419	8.098974352501708	0.3168443928033584	30898.369664470953	50	0.01760548874791639	middle	390
Container (Base)	232745.57943778663	4097.599679919233	26800.76998455172	8.68428703995982	11.515050059937066	0.3168443928033584	30898.369664470953	60	0.01760548874791639	middle	390
Container (Max)	467718.5861362971	8234.414305413942	22663.95535905701	20.637112045377663	4.845639243519937	0.3168443928033584	30898.369664470953	54	0.01760548874791639	middle	390
Traditional Housing	527916.4876126401	12903.061229093728	2564.0157250776065	100	0.48568585851006013	-3.6127878043354276	15467.076954171334	146	0.024441481809830076	low	391
ODD Cubes Basic	322982.1977539031	4802.79252571299	10664.284428458344	30.286345035209663	3.3018180266963246	-3.6127878043354276	15467.076954171334	105	0.014870146277760135	low	391
Container (Base)	251422.382224551	3738.6876011819927	11728.389352989341	21.437076708275228	4.664815140648239	-3.6127878043354276	15467.076954171334	98	0.014870146277760135	low	391
Container (Max)	437637.3902813903	6507.732010101476	8959.344944069859	48.84702989040065	2.0472073783067795	-3.6127878043354276	15467.076954171334	59	0.014870146277760135	low	391
Traditional Housing	536940.8266193144	6007.0348820490335	24742.25101425736	21.70137334351309	4.608003300855229	2.7374978283898797	30749.28589630639	118	0.01118751747724328	middle	392
ODD Cubes Basic	339975.84020208946	4772.06505864126	25977.220837665132	13.08746006074478	7.640902018868069	2.7374978283898797	30749.28589630639	135	0.014036482874208459	middle	392
Container (Base)	253568.23837736866	3559.2062354271434	27190.079660879248	9.32576298193784	10.722983223322343	2.7374978283898797	30749.28589630639	145	0.014036482874208459	middle	392
Container (Max)	467892.52257686533	6567.565380120364	24181.720516186026	19.349017050448566	5.1682211938348415	2.7374978283898797	30749.28589630639	49	0.014036482874208459	middle	392
Traditional Housing	548010.4111515234	11194.197873267043	4390.679300484862	100	0.80120362882501	-0.154023427488176	15584.877173751906	107	0.02042698030087585	low	393
ODD Cubes Basic	333768.31414878194	4210.509007959601	11374.368165792304	29.343899307969398	3.407863384156358	-0.154023427488176	15584.877173751906	106	0.012615065089979473	low	393
Container (Base)	253957.64328980361	3203.6922001986613	12381.184973553245	20.511578159301255	4.875295270961569	-0.154023427488176	15584.877173751906	91	0.012615065089979473	low	393
Container (Max)	420498.15967031894	5304.611654457655	10280.265519294251	40.903433756756364	2.444782523508364	-0.154023427488176	15584.877173751906	134	0.012615065089979473	low	393
Traditional Housing	545800.0966965547	9836.640156968057	21064.013959273296	25.911495204657786	3.8592909907423727	4.197295165083336	30900.654116241352	125	0.018022422891648692	middle	394
ODD Cubes Basic	350913.1862447191	6400.919839062772	24499.73427717858	14.323142540023118	6.981708079813509	4.197295165083336	30900.654116241352	84	0.018240750390607754	middle	394
Container (Base)	262169.6812203403	4782.171715125433	26118.482401115918	10.037707290724482	9.962434359129674	4.197295165083336	30900.654116241352	123	0.018240750390607754	middle	394
Container (Max)	491814.077553654	8971.057827243207	21929.596288998146	22.42695538359692	4.458920004502262	4.197295165083336	30900.654116241352	107	0.018240750390607754	middle	394
Traditional Housing	516414.0176547955	14718.49830313357	769.83961321879	100	0.14907411241756813	-0.4591376909157594	15488.33791635236	120	0.02850135317777599	low	395
ODD Cubes Basic	319846.7492154116	7596.502648158165	7891.835268194195	40.528817232724464	2.467380171145392	-0.4591376909157594	15488.33791635236	75	0.02375044507031098	low	395
Container (Base)	256122.83850125558	6083.0314070762015	9405.306509276159	27.231737556734558	3.67218580127912	-0.4591376909157594	15488.33791635236	115	0.02375044507031098	low	395
Container (Max)	462812.7713871768	10992.009304669537	4496.328611682824	100	0.9715221553212747	-0.4591376909157594	15488.33791635236	126	0.02375044507031098	low	395
Traditional Housing	519241.30295095214	6849.50426097452	23155.920990152634	22.423694707360873	4.459568385363974	2.6958995160520978	30005.425251127155	94	0.01319137022044937	middle	396
ODD Cubes Basic	342641.3097347524	7408.591333325725	22596.83391780143	15.163244150979265	6.5948947998401675	2.6958995160520978	30005.425251127155	139	0.021622002726585737	middle	396
Container (Base)	256642.12030412682	5549.116624972575	24456.30862615458	10.493902584696007	9.529343272715051	2.6958995160520978	30005.425251127155	60	0.021622002726585737	middle	396
Container (Max)	443550.7544559499	9590.455622225709	20414.969628901446	21.72674084354334	4.602623132485035	2.6958995160520978	30005.425251127155	140	0.021622002726585737	middle	396
Traditional Housing	579279.5796806517	14354.044322958547	16530.992978545095	35.042031681489135	2.853715815022927	-4.646451554915439	30885.037301503642	135	0.02477913053809306	middle	397
ODD Cubes Basic	356329.51038722886	5906.890303320556	24978.146998183085	14.26565030677209	7.009845177021387	-4.646451554915439	30885.037301503642	51	0.016577044929288753	middle	397
Container (Base)	256427.41119633798	4250.8087165028965	26634.228585000747	9.6277393722132	10.386654242906895	-4.646451554915439	30885.037301503642	96	0.016577044929288753	middle	397
Container (Max)	429253.8084332686	7115.759668466601	23769.27763303704	18.059186108232694	5.537348106425057	-4.646451554915439	30885.037301503642	65	0.016577044929288753	middle	397
Traditional Housing	517353.64350160526	11943.269194748409	3962.119252473316	100	0.7658435003291945	-0.6393008268922422	15905.388447221725	82	0.02308530991279537	low	398
ODD Cubes Basic	310510.8565383711	2870.366545901486	13035.021901320239	23.82127616578238	4.197927907138875	-0.6393008268922422	15905.388447221725	145	0.009244013487646873	low	398
Container (Base)	248679.21130368082	2298.793983388612	13606.594463833113	18.276374148188246	5.4715448036454815	-0.6393008268922422	15905.388447221725	48	0.009244013487646873	low	398
Container (Max)	434021.9940271196	4012.105166722084	11893.283280499641	36.49303424385315	2.74024898373157	-0.6393008268922422	15905.388447221725	115	0.009244013487646873	low	398
Traditional Housing	565149.8761132042	12609.593470903246	17807.449937716607	31.736710089871046	3.1509252130048466	-4.704862513575194	30417.04340861985	99	0.02231194591711711	middle	399
ODD Cubes Basic	350550.12762400345	7398.74712232852	23018.29628629133	15.229195213408364	6.566335160767799	-4.704862513575194	30417.04340861985	140	0.02110610306285309	middle	399
Container (Base)	256524.04451066547	5414.222921542018	25002.82048707783	10.259804274611513	9.746774628776873	-4.704862513575194	30417.04340861985	82	0.02110610306285309	middle	399
Container (Max)	425071.2443631827	8971.597492584544	21445.445916035307	19.821049467912722	5.045141538135247	-4.704862513575194	30417.04340861985	89	0.02110610306285309	middle	399
Traditional Housing	555249.7400165492	16226.16088766608	14054.47978989784	39.50695780399178	2.531199706546273	2.3289080607602646	30280.64067756392	109	0.029223176020185905	middle	400
ODD Cubes Basic	349401.9218447836	3474.556077455041	26806.08460010888	13.034425842383726	7.6719911723946	2.3289080607602646	30280.64067756392	129	0.009944295838757746	middle	400
Container (Base)	258085.63545657633	2566.4799107139806	27714.16076684994	9.312410273858385	10.738358497876542	2.3289080607602646	30280.64067756392	113	0.009944295838757746	middle	400
Container (Max)	481742.9785374876	4790.5946968211	25490.04598074282	18.89925890684678	5.291212766219751	2.3289080607602646	30280.64067756392	79	0.009944295838757746	middle	400
Traditional Housing	550337.773259302	8696.331025252248	6881.709156945095	79.97108867989506	1.2504519026904315	-2.071212803945123	15578.040182197343	141	0.01580180654100733	low	401
ODD Cubes Basic	299193.55726277496	4541.492598762811	11036.54758343453	27.10934329788547	3.6887651206143386	-2.071212803945123	15578.040182197343	95	0.015179112278725041	low	401
Container (Base)	261452.03656013616	3968.609818447631	11609.430363749712	22.52066021917118	4.440367157392345	-2.071212803945123	15578.040182197343	113	0.015179112278725041	low	401
Container (Max)	446751.86836739036	6781.296770678809	8796.743411518535	50.78605200447355	1.969044571355761	-2.071212803945123	15578.040182197343	53	0.015179112278725041	low	401
Traditional Housing	579703.3321621643	13179.667712814151	2458.191193414519	100	0.4240429642255141	-4.293054995429442	15637.85890622867	120	0.022735193989064935	low	402
ODD Cubes Basic	311181.0127543464	6588.064320986462	9049.794585242209	34.38542276548457	2.908209117625801	-4.293054995429442	15637.85890622867	121	0.021171164212988904	low	402
Container (Base)	224540.26105149186	4753.778739148531	10884.08016708014	20.63015501582152	4.847273320210574	-4.293054995429442	15637.85890622867	85	0.021171164212988904	low	402
Container (Max)	409798.4282748058	8675.909819230668	6961.949086998002	58.86260056686384	1.6988715931163614	-4.293054995429442	15637.85890622867	89	0.021171164212988904	low	402
Traditional Housing	585335.4611089156	16235.553889049668	14037.849089905507	41.69694782727257	2.3982570718184166	-2.5971701028961567	30273.402978955175	83	0.027737178024873937	middle	403
ODD Cubes Basic	296146.8814993422	6471.446533889523	23801.95644506565	12.442123494463246	8.037213265444606	-2.5971701028961567	30273.402978955175	53	0.021852151544279885	middle	403
Container (Base)	228788.4242131694	4999.519317483171	25273.883661472006	9.052365171797435	11.04683672191541	-2.5971701028961567	30273.402978955175	98	0.021852151544279885	middle	403
Container (Max)	480100.8665863867	10491.236893185822	19782.166085769353	24.269378009709243	4.120418741674956	-2.5971701028961567	30273.402978955175	124	0.021852151544279885	middle	403
Traditional Housing	569656.0931679211	11451.790124952278	19530.863738890315	29.16696879276304	3.428535913708393	3.022006161597025	30982.653863842595	121	0.02010298891260444	middle	404
ODD Cubes Basic	327431.40255623194	6549.348987360589	24433.304876482005	13.401027990748695	7.462114105651767	3.022006161597025	30982.653863842595	108	0.020002201793201023	middle	404
Container (Base)	268979.29470969335	5380.1781309761745	25602.47573286642	10.505987683230147	9.518381613907835	3.022006161597025	30982.653863842595	110	0.020002201793201023	middle	404
Container (Max)	420376.77342180925	8408.461051157774	22574.19281268482	18.62200686022281	5.369990503741201	3.022006161597025	30982.653863842595	41	0.020002201793201023	middle	404
Traditional Housing	510827.36279849015	7987.533527431825	22666.872686778297	22.536296464772505	4.437286319707166	-0.18497815500666182	30654.40621421012	129	0.01563646372362149	middle	405
ODD Cubes Basic	337590.1830656832	6508.990059874587	24145.416154335533	13.981543366568388	7.152286223215704	-0.18497815500666182	30654.40621421012	97	0.0192807444836397	middle	405
Container (Base)	244758.7341794199	4719.130613852486	25935.275600357636	9.437290659677616	10.59626153375423	-0.18497815500666182	30654.40621421012	60	0.0192807444836397	middle	405
Container (Max)	426544.92559893464	8224.103721266165	22430.302492943956	19.016458905675286	5.25860258715969	-0.18497815500666182	30654.40621421012	108	0.0192807444836397	middle	405
Traditional Housing	584241.9046746864	12182.608599045525	18433.623557605337	31.6943601917942	3.155135468735236	0.3383765432255341	30616.23215665086	96	0.020851993842908208	middle	406
ODD Cubes Basic	315604.64435968257	3070.60986626356	27545.622290387302	11.457524576230767	8.727888762940575	0.3383765432255341	30616.23215665086	130	0.009729292395216159	middle	406
Container (Base)	233882.14545715958	2275.5077791731824	28340.72437747768	8.252511204089945	12.117523687873334	0.3383765432255341	30616.23215665086	89	0.009729292395216159	middle	406
Container (Max)	448575.9980935577	4364.32704692815	26251.905109722713	17.087369324956995	5.852275917858507	0.3383765432255341	30616.23215665086	138	0.009729292395216159	middle	406
Traditional Housing	502495.41673040483	13134.20294807008	17827.659043821543	28.18628152441319	3.547825204022967	-2.8637023984760446	30961.861991891623	134	0.026137955712174678	middle	407
ODD Cubes Basic	320959.32617288525	7262.5959404947325	23699.26605139689	13.54300700607423	7.383884535771752	-2.8637023984760446	30961.861991891623	62	0.022627776631680502	middle	407
Container (Base)	256715.88118312467	5808.9096172167765	25152.952374674845	10.206192790377884	9.797972863522354	-2.8637023984760446	30961.861991891623	132	0.022627776631680502	middle	407
Container (Max)	431131.50153760985	9755.547315674054	21206.314676217567	20.330335945694266	4.918757873313887	-2.8637023984760446	30961.861991891623	65	0.022627776631680502	middle	407
Traditional Housing	564665.5025149161	12704.373809623841	17836.811455250747	31.657311842509362	3.158827903565717	-1.1834236066407664	30541.185264874588	113	0.02249893742940006	middle	408
ODD Cubes Basic	295295.755378689	3558.563926889293	26982.621337985296	10.943923930881422	9.137490413088608	-1.1834236066407664	30541.185264874588	60	0.012050846861397551	middle	408
Container (Base)	234526.93197471972	2826.248142100748	27714.93712277384	8.462113081324832	11.817379304548831	-1.1834236066407664	30541.185264874588	123	0.012050846861397551	middle	408
Container (Max)	479491.22979842604	5778.275381684014	24762.909883190572	19.363282912236084	5.164413516718686	-1.1834236066407664	30541.185264874588	121	0.012050846861397551	middle	408
Traditional Housing	568917.893587612	8199.285572449753	22696.072260507703	25.066799535070103	3.9893405562243163	-3.6917683676535007	30895.357832957456	143	0.014412071873403088	middle	409
ODD Cubes Basic	294181.6840880414	6620.652518854721	24274.705314102735	12.118857068766655	8.251603219063055	-3.6917683676535007	30895.357832957456	135	0.02250531857337971	middle	409
Container (Base)	258473.0168002138	5817.017585711338	25078.340247246117	10.306623733944955	9.70249837205652	-3.6917683676535007	30895.357832957456	140	0.02250531857337971	middle	409
Container (Max)	398025.1647017162	8957.683131834052	21937.674701123404	18.143452764450636	5.51163007936036	-3.6917683676535007	30895.357832957456	140	0.02250531857337971	middle	409
Traditional Housing	536115.8611186551	12652.883153517627	18305.883726391316	29.286532632442373	3.414538732018561	4.156021753606714	30958.76687990894	121	0.023601023717366283	middle	410
ODD Cubes Basic	351926.75896046957	5313.712940314519	25645.05393959442	13.722987668086587	7.287042910674213	4.156021753606714	30958.76687990894	109	0.01509891704742857	middle	410
Container (Base)	265522.92833507067	4009.108669121553	26949.658210787387	9.852552721013263	10.14965388479705	4.156021753606714	30958.76687990894	114	0.01509891704742857	middle	410
Container (Max)	463252.84977802716	6994.616350783321	23964.150529125618	19.33107744482733	5.1730174008877245	4.156021753606714	30958.76687990894	100	0.01509891704742857	middle	410
Traditional Housing	546156.9973919191	10383.567031912127	19982.090951875536	27.332324665485338	3.6586715994295873	-4.175114131445094	30365.657983787663	81	0.019012055290872597	middle	411
ODD Cubes Basic	356262.2618291024	3935.9157249335985	26429.742258854065	13.479596521973392	7.418619677301748	-4.175114131445094	30365.657983787663	128	0.011047804234796111	middle	411
Container (Base)	258222.92274779044	2852.796299454468	27512.861684333195	9.385534871308272	10.654693778369689	-4.175114131445094	30365.657983787663	86	0.011047804234796111	middle	411
Container (Max)	420849.68218456226	4649.464901051204	25716.19308273646	16.3651626362645	6.1105411673944685	-4.175114131445094	30365.657983787663	44	0.011047804234796111	middle	411
Traditional Housing	566446.4529508228	13276.689866471046	17452.238176794406	32.456951779629364	3.08100405358343	-3.2998979540817794	30728.928043265452	136	0.023438561221997254	middle	412
ODD Cubes Basic	308300.07054054673	6064.980115194406	24663.947928071047	12.500029250777724	7.999981279546063	-3.2998979540817794	30728.928043265452	81	0.019672328016534648	middle	412
Container (Base)	259686.45263175084	5108.63707762209	25620.290965643362	10.135968126981409	9.86585580649226	-3.2998979540817794	30728.928043265452	50	0.019672328016534648	middle	412
Container (Max)	420549.3755802402	8273.185263563311	22455.74277970214	18.727920946813523	5.339621001391219	-3.2998979540817794	30728.928043265452	122	0.019672328016534648	middle	412
Traditional Housing	503448.52800968033	8291.449621981257	22207.460198094457	22.670243401038693	4.411068652020659	-4.19931008483518	30498.909820075714	112	0.0164693094937837	middle	413
ODD Cubes Basic	355442.64479923784	7006.330435437064	23492.57938463865	15.129996539743736	6.60938683874238	-4.19931008483518	30498.909820075714	68	0.019711563983534953	middle	413
Container (Base)	248174.8395117646	4891.914228139666	25606.995591936047	9.691681268142128	10.318127189006265	-4.19931008483518	30498.909820075714	75	0.019711563983534953	middle	413
Container (Max)	440302.0781575033	8679.042585685032	21819.86723439068	20.178953126879495	4.955658471042999	-4.19931008483518	30498.909820075714	73	0.019711563983534953	middle	413
Traditional Housing	539236.6552321964	5985.71288617795	24903.76846520267	21.652813548505986	4.618337463442476	2.851960286917402	30889.48135138062	142	0.011100344956335524	middle	414
ODD Cubes Basic	310912.4914105682	3708.8671732988014	27180.614178081818	11.43875886591573	8.742207189800263	2.851960286917402	30889.48135138062	96	0.011928974472759745	middle	414
Container (Base)	267730.822990423	3193.754153023714	27695.727198356904	9.666863811624582	10.344616614930292	2.851960286917402	30889.48135138062	115	0.011928974472759745	middle	414
Container (Max)	447609.95733950846	5339.527754856074	25549.953596524545	17.51901253552159	5.70808427685292	2.851960286917402	30889.48135138062	96	0.011928974472759745	middle	414
Traditional Housing	598715.390603124	6816.371073524804	23328.669065194626	25.66436125995639	3.8964538796462502	4.328661287680827	30145.04013871943	129	0.011384993906133331	middle	415
ODD Cubes Basic	348042.0099645823	8411.45143384058	21733.58870487885	16.0140147442126	6.244530281585985	4.328661287680827	30145.04013871943	47	0.02416791994361989	middle	415
Container (Base)	277100.9334306376	6696.953175453994	23448.086963265436	11.817635010683526	8.461929980879994	4.328661287680827	30145.04013871943	142	0.02416791994361989	middle	415
Container (Max)	503317.75277373573	12164.143155238313	17980.896983481114	27.99180448206389	3.572474224163587	4.328661287680827	30145.04013871943	52	0.02416791994361989	middle	415
Traditional Housing	594710.6931247219	14000.240529919649	1571.5166922911321	100	0.26424893825838036	-0.20866849127215836	15571.757222210781	85	0.023541262485730248	low	416
ODD Cubes Basic	342825.8914083643	5591.830158130853	9979.927064079928	34.35154277251927	2.9110774052337045	-0.20866849127215836	15571.757222210781	88	0.01631099137570688	low	416
Container (Base)	254925.4732254845	4158.087195228873	11413.670026981908	22.33510103435975	4.477257561815483	-0.20866849127215836	15571.757222210781	66	0.01631099137570688	low	416
Container (Max)	407187.0505874662	6641.624470431682	8930.1327517791	45.59697620467564	2.193127885303625	-0.20866849127215836	15571.757222210781	88	0.01631099137570688	low	416
Traditional Housing	591273.8343130678	13991.178636510833	16612.437264548695	35.59223880862197	2.809601288013827	-2.0285218362738746	30603.61590105953	81	0.023662773193347128	middle	417
ODD Cubes Basic	332745.5406430342	4471.152655356253	26132.46324570328	12.733033909374942	7.853587818247548	-2.0285218362738746	30603.61590105953	105	0.013437152746557334	middle	417
Container (Base)	263018.89267188124	3534.2250360624375	27069.39086499709	9.716468833141935	10.291804740721204	-2.0285218362738746	30603.61590105953	74	0.013437152746557334	middle	417
Container (Max)	405192.0501426014	5444.627469456854	25158.988431602676	16.105260004556943	6.209151542521217	-2.0285218362738746	30603.61590105953	133	0.013437152746557334	middle	417
Traditional Housing	568020.6778666724	6898.037482611326	23981.807174504294	23.68548265497483	4.2219954499849	4.095000807967796	30879.84465711562	93	0.01214399008944258	middle	418
ODD Cubes Basic	312866.570380404	7636.476765065419	23243.3678920502	13.460466307355228	7.429163129761471	4.095000807967796	30879.84465711562	144	0.024408094338044754	middle	418
Container (Base)	280347.6918063659	6842.752909062875	24037.091748052746	11.663128582478244	8.574028768767244	4.095000807967796	30879.84465711562	55	0.024408094338044754	middle	418
Container (Max)	465515.3350922916	11362.342214739168	19517.50244237645	23.851173400217615	4.192665841718614	4.095000807967796	30879.84465711562	149	0.024408094338044754	middle	418
Traditional Housing	597640.2141419357	14515.787235947118	1368.3933148846536	100	0.22896607063989655	1.9810977048170608	15884.180550831772	113	0.024288504843651155	low	419
ODD Cubes Basic	343234.54197637667	3610.552252067235	12273.628298764537	27.96520585611401	3.575872121754365	1.9810977048170608	15884.180550831772	141	0.01051919842122339	low	419
Container (Base)	254508.36504365478	2677.2239917553597	13206.956559076412	19.270780812006624	5.189203332004855	1.9810977048170608	15884.180550831772	100	0.01051919842122339	low	419
Container (Max)	414083.66505301924	4355.828235680115	11528.352315151657	35.918720536393664	2.784063533072614	1.9810977048170608	15884.180550831772	91	0.01051919842122339	low	419
Traditional Housing	582272.0274284959	9377.867110827712	6333.069944238767	91.9415121821278	1.0876479799669716	1.195034227379404	15710.937055066479	122	0.016105645933642814	low	420
ODD Cubes Basic	351279.9756008783	6162.659144694955	9548.277910371524	36.78987759869361	2.7181389699309837	1.195034227379404	15710.937055066479	85	0.017543439913287065	low	420
Container (Base)	234839.90180252373	4119.89970651481	11591.037348551668	20.260473220877646	4.935718870423708	1.195034227379404	15710.937055066479	92	0.017543439913287065	low	420
Container (Max)	447816.5376130641	7856.242519791047	7854.694535275432	57.01259744754174	1.7539983175124008	1.195034227379404	15710.937055066479	132	0.017543439913287065	low	420
Traditional Housing	537308.6804785263	9403.600520000833	20921.229104482398	25.68246243063259	3.8937076329848206	1.4576159230955739	30324.82962448323	126	0.017501300205360542	middle	421
ODD Cubes Basic	350173.3317794794	4534.799365652502	25790.030258830728	13.57785656957797	7.3649327114013134	1.4576159230955739	30324.82962448323	132	0.012950156262922612	middle	421
Container (Base)	274790.52400589205	3558.580225446689	26766.24939903654	10.266306642714882	9.740601316536889	1.4576159230955739	30324.82962448323	61	0.012950156262922612	middle	421
Container (Max)	414718.80693775037	5370.673355016701	24954.15626946653	16.61922777349892	6.017126749984157	1.4576159230955739	30324.82962448323	77	0.012950156262922612	middle	421
Traditional Housing	601319.4401249414	17533.585431795036	13187.107970721307	45.59903820155425	2.1930287116580343	-4.1280222683079595	30720.693402516343	93	0.029158520849004867	middle	422
ODD Cubes Basic	333964.91497827426	7999.426001438125	22721.267401078218	14.698340065414936	6.803489343351029	-4.1280222683079595	30720.693402516343	145	0.023952893380906552	middle	422
Container (Base)	249156.4726729173	5968.018425097145	24752.6749774192	10.065840273837557	9.934590384859689	-4.1280222683079595	30720.693402516343	139	0.023952893380906552	middle	422
Container (Max)	465335.48140156094	11146.131172364414	19574.56223015193	23.772459170748423	4.206548396265548	-4.1280222683079595	30720.693402516343	121	0.023952893380906552	middle	422
Traditional Housing	526256.4476285772	8707.069229141489	6784.045081626549	77.57266369792482	1.28911391246547	-0.49115639795984745	15491.114310768038	87	0.016545297009428354	low	423
ODD Cubes Basic	346931.8952820875	3546.267935475893	11944.846375292145	29.044483652775508	3.4429945870442062	-0.49115639795984745	15491.114310768038	118	0.010221798525017284	low	423
Container (Base)	233780.00203391633	2389.6520799688237	13101.462230799214	17.843809943926793	5.604184325782699	-0.49115639795984745	15491.114310768038	76	0.010221798525017284	low	423
Container (Max)	489327.32266723795	5001.805305090629	10489.309005677409	46.65010082193081	2.1436180895238004	-0.49115639795984745	15491.114310768038	103	0.010221798525017284	low	423
Traditional Housing	593417.3385055168	10578.25545732485	5378.078727223756	100	0.906289448968259	-2.3977974712684325	15956.334184548607	91	0.01782599659788422	low	424
ODD Cubes Basic	301067.61529691785	4490.842926266728	11465.49125828188	26.258588360044964	3.808277833859488	-2.3977974712684325	15956.334184548607	98	0.014916393189077424	low	424
Container (Base)	228930.00376948022	3414.809949002544	12541.524235546063	18.253762419134894	5.4783226440579105	-2.3977974712684325	15956.334184548607	74	0.014916393189077424	low	424
Container (Max)	400573.26551943866	5975.108329520657	9981.22585502795	40.13267221256732	2.491735398787763	-2.3977974712684325	15956.334184548607	116	0.014916393189077424	low	424
Traditional Housing	549638.63470326	9157.635742475428	21428.630263372866	25.649732528295857	3.8986761319902112	2.2280013490696415	30586.266005848294	110	0.016661193672128725	middle	425
ODD Cubes Basic	301856.721344123	6896.956958925547	23689.309046922746	12.742318517868902	7.847865351958301	2.2280013490696415	30586.266005848294	114	0.022848445872645888	middle	425
Container (Base)	234104.18816676817	5348.916871888111	25237.349133960182	9.27610054939368	10.780391983411215	2.2280013490696415	30586.266005848294	130	0.022848445872645888	middle	425
Container (Max)	481772.22790181526	11007.746672158644	19578.51933368965	24.607184010734045	4.063853871145045	2.2280013490696415	30586.266005848294	63	0.022848445872645888	middle	425
Traditional Housing	533340.3445868881	14727.459334678144	1202.1688834563356	100	0.22540370246835634	-2.825516354460502	15929.62821813448	124	0.027613623241057567	low	426
ODD Cubes Basic	336131.6138375468	7411.044615003524	8518.583603130955	39.45862710251544	2.534300033809973	-2.825516354460502	15929.62821813448	136	0.022048044009883878	low	426
Container (Base)	248185.9604113311	5472.014977784325	10457.613240350154	23.732562555834303	4.213619990034177	-2.825516354460502	15929.62821813448	115	0.022048044009883878	low	426
Container (Max)	401431.7908136668	8850.785790826225	7078.842427308255	56.708677292356704	1.763398562171687	-2.825516354460502	15929.62821813448	62	0.022048044009883878	low	426
Traditional Housing	532644.5634453685	11254.547225374194	4718.177936669079	100	0.88580232681808	-1.976442858330877	15972.725162043273	115	0.021129563686100652	low	427
ODD Cubes Basic	354142.88311939326	8167.219775621994	7805.505386421279	45.3709100932109	2.20405541335975	-1.976442858330877	15972.725162043273	117	0.023061933939439224	low	427
Container (Base)	252891.48687375305	5832.166764129054	10140.558397914217	24.93861550324187	4.009845694401143	-1.976442858330877	15972.725162043273	96	0.023061933939439224	low	427
Container (Max)	420817.2147039687	9704.85880608174	6267.8663559615325	67.13883015449403	1.489451034072067	-1.976442858330877	15972.725162043273	143	0.023061933939439224	low	427
Traditional Housing	566504.0511380857	8732.738863080329	7063.559670680639	80.20092949586392	1.2468683421575202	-0.41048989729310925	15796.298533760968	89	0.015415139301363475	low	428
ODD Cubes Basic	298326.7368869335	2470.7437868925103	13325.554746868458	22.387566037882294	4.466765160213875	-0.41048989729310925	15796.298533760968	125	0.008282005872738547	low	428
Container (Base)	260337.83471383635	2156.11947599603	13640.179057764937	19.08610096768737	5.239414806056998	-0.41048989729310925	15796.298533760968	98	0.008282005872738547	low	428
Container (Max)	430517.2695894428	3565.5465550551294	12230.751978705839	35.19957483717994	2.840943405213346	-0.41048989729310925	15796.298533760968	140	0.008282005872738547	low	428
Traditional Housing	567402.7515019742	6851.642396555095	8990.91065873309	63.10848511778305	1.5845729748284112	2.287960974122976	15842.553055288185	116	0.012075447957236873	low	429
ODD Cubes Basic	331249.60614595964	8189.092850504444	7653.460204783741	43.28102548163959	2.310481299534397	2.287960974122976	15842.553055288185	87	0.024721819131449944	low	429
Container (Base)	235629.3878286362	5825.187107953817	10017.365947334369	23.522090444478312	4.251322825071208	2.287960974122976	15842.553055288185	50	0.024721819131449944	low	429
Container (Max)	423812.46972239594	10477.415222130177	5365.137833158007	78.99377106457916	1.265922599368598	2.287960974122976	15842.553055288185	78	0.024721819131449944	low	429
Traditional Housing	512097.03374342475	14316.038050500767	1249.9098498516942	100	0.24407676035825954	-0.8198158707898395	15565.947900352461	137	0.02795571367764163	low	430
ODD Cubes Basic	354227.6679163506	7653.863662588247	7912.084237764214	44.77046215276997	2.233615540057876	-0.8198158707898395	15565.947900352461	109	0.021607187568407772	low	430
Container (Base)	258484.6660090866	5585.126662015571	9980.82123833689	25.898136018730863	3.8612817512300825	-0.8198158707898395	15565.947900352461	137	0.021607187568407772	low	430
Container (Max)	425792.2384194991	9200.172760702319	6365.775139650143	66.88772837221207	1.4950425501599802	-0.8198158707898395	15565.947900352461	79	0.021607187568407772	low	430
Traditional Housing	595538.7967938356	7987.556092781217	7881.000781008221	75.56639230755766	1.3233396083406594	0.0759724583148822	15868.556873789437	109	0.013412318619346573	low	431
ODD Cubes Basic	344647.14972700353	4141.5726082434485	11726.984265545989	29.389239545548016	3.4026059042806485	0.0759724583148822	15868.556873789437	43	0.012016848569686434	low	431
Container (Base)	268892.8012339712	3231.2440739074254	12637.312799882013	21.27768818355764	4.699758692641954	0.0759724583148822	15868.556873789437	64	0.012016848569686434	low	431
Container (Max)	421707.38153917925	5067.593744675297	10800.963129114141	39.043497926815554	2.5612459259527247	0.0759724583148822	15868.556873789437	143	0.012016848569686434	low	431
ODD Cubes Basic	322026.0786791072	6740.187073677802	9066.106511034768	35.51977668552147	2.8153330153328886	-2.9301423193934353	15806.29358471257	82	0.020930562833062563	low	432
Container (Base)	220743.1376895738	4620.278113379006	11186.015471333565	19.733848773521984	5.067435204741998	-2.9301423193934353	15806.29358471257	47	0.020930562833062563	low	432
Container (Max)	450436.08037846483	9427.880682639878	6378.412902072692	70.61883375911486	1.4160528385544582	-2.9301423193934353	15806.29358471257	107	0.020930562833062563	low	432
Traditional Housing	573311.345872193	6305.259199050015	24059.58837705695	23.828809408015417	4.196600773782785	3.941362213409885	30364.847576106964	118	0.010997966889103974	middle	433
ODD Cubes Basic	348733.5599463622	8212.39164278879	22152.455933318175	15.742433299318884	6.352258135616597	3.941362213409885	30364.847576106964	85	0.023549186502302553	middle	433
Container (Base)	260091.69005453662	6124.947716793353	24239.899859313613	10.72989952780694	9.319751759170366	3.941362213409885	30364.847576106964	101	0.023549186502302553	middle	433
Container (Max)	502751.62529778737	11839.391788473326	18525.45578763364	27.138421373329493	3.684812709787012	3.941362213409885	30364.847576106964	110	0.023549186502302553	middle	433
Traditional Housing	582807.7129433381	14242.91548215137	16022.855568580722	36.37352346145889	2.7492524914711454	2.5245570804810704	30265.77105073209	133	0.024438447134168415	middle	434
ODD Cubes Basic	345500.791967057	6707.067828436196	23558.703222295895	14.66552673578722	6.818711785917464	2.5245570804810704	30265.77105073209	75	0.019412597552238623	middle	434
Container (Base)	256640.1039965699	4982.051054650078	25283.719996082014	10.15040919755238	9.851819572368917	2.5245570804810704	30265.77105073209	142	0.019412597552238623	middle	434
Container (Max)	420713.21400361106	8167.136308360944	22098.63474237115	19.037973110481357	5.252660008482993	2.5245570804810704	30265.77105073209	93	0.019412597552238623	middle	434
Traditional Housing	580902.3630305037	13611.841661652386	1959.9160134649846	100	0.337391640695059	-1.5937873210111975	15571.757675117371	147	0.023432236685423186	low	435
ODD Cubes Basic	352711.05074564385	7827.344984148556	7744.412690968815	45.54393790983784	2.1956818972915215	-1.5937873210111975	15571.757675117371	132	0.022191947112519633	low	435
Container (Base)	231447.79749807107	5136.277281386347	10435.480393731024	22.178930798155708	4.508783624876791	-1.5937873210111975	15571.757675117371	112	0.022191947112519633	low	435
Container (Max)	414108.11917008413	9189.865479487484	6381.892195629887	64.88798407683099	1.5411173797847444	-1.5937873210111975	15571.757675117371	97	0.022191947112519633	low	435
Traditional Housing	548787.191753633	12361.796819009534	18298.795422628507	29.990345215565185	3.3344064325107983	4.4606892472745585	30660.59224163804	103	0.022525665694761908	middle	436
ODD Cubes Basic	305811.5511444624	6113.637419732854	24546.954821905187	12.45822764425193	8.026823947637427	4.4606892472745585	30660.59224163804	96	0.019991518949671168	middle	436
Container (Base)	259699.5248812167	5191.787972883442	25468.8042687546	10.196769433727159	9.80702767184642	4.4606892472745585	30660.59224163804	114	0.019991518949671168	middle	436
Container (Max)	486113.5689915436	9718.148626186727	20942.443615451317	23.211883862153	4.308138046608534	4.4606892472745585	30660.59224163804	109	0.019991518949671168	middle	436
Traditional Housing	500522.0129955143	11347.910831653106	18827.133049982607	26.58514239351895	3.7614995067462367	4.057057157596111	30175.043881635713	124	0.02267215134802634	middle	437
ODD Cubes Basic	318360.4773029044	4142.944191717596	26032.099689918115	12.22953511607061	8.17692570084629	4.057057157596111	30175.043881635713	98	0.013013374734250658	middle	437
Container (Base)	263209.2392474508	3425.2404638441126	26749.8034177916	9.839670039309047	10.16294241580301	4.057057157596111	30175.043881635713	145	0.013013374734250658	middle	437
Container (Max)	452889.49302166555	5893.620685895732	24281.423195739982	18.65168649180012	5.36144546735563	4.057057157596111	30175.043881635713	86	0.013013374734250658	middle	437
Traditional Housing	520745.7500222986	5285.782600341171	10680.43652254112	48.756972519172024	2.050988706500971	-4.386993469811546	15966.219122882292	91	0.010150409485079486	low	438
ODD Cubes Basic	340623.4146577349	4304.846772932863	11661.37234994943	29.209547936200842	3.423538091668479	-4.386993469811546	15966.219122882292	109	0.012638141089796946	low	438
Container (Base)	223311.90113721677	2822.2473136029325	13143.97180927936	16.98968199091567	5.885925354781196	-4.386993469811546	15966.219122882292	140	0.012638141089796946	low	438
Container (Max)	406598.75851887086	5138.652477097768	10827.566645784525	37.55218248203267	2.662961068849895	-4.386993469811546	15966.219122882292	144	0.012638141089796946	low	438
Traditional Housing	576905.420348773	14914.099026708183	15566.576507706523	37.06052002270154	2.6982891750775404	-3.4721138115882244	30480.675534414706	100	0.025851896169898594	middle	439
ODD Cubes Basic	326023.95101735945	7801.049046269456	22679.62648814525	14.375190490362517	6.956429555979969	-3.4721138115882244	30480.675534414706	112	0.023927840337883893	middle	439
Container (Base)	253058.59146867518	6055.145572792247	24425.52996162246	10.360413545429	9.65212436371518	-3.4721138115882244	30480.675534414706	81	0.023927840337883893	middle	439
Container (Max)	435337.626610083	10416.68922259938	20063.986311815326	21.697464294706002	4.608833485874161	-3.4721138115882244	30480.675534414706	111	0.023927840337883893	middle	439
ODD Cubes Basic	345251.62827171903	5305.223470710865	10449.953879908506	33.03857914009682	3.0267645462584785	0.2883827495877611	15755.17735061937	125	0.015366251847291974	low	440
Container (Base)	265925.3171284245	4086.2753955663566	11668.901955053014	22.789232281900368	4.388037243335391	0.2883827495877611	15755.17735061937	127	0.015366251847291974	low	440
Container (Max)	443541.8483518153	6815.5757465873785	8939.601604031992	49.615393168277926	2.015503528528641	0.2883827495877611	15755.17735061937	87	0.015366251847291974	low	440
Traditional Housing	543465.0395937039	7605.5443440969775	22421.329882524136	24.23875133371536	4.12562506307423	-0.7469327948122748	30026.874226621116	123	0.013994542040428038	middle	441
ODD Cubes Basic	345032.418820002	3832.296498009125	26194.577728611992	13.171902307214047	7.591917831430586	-0.7469327948122748	30026.874226621116	121	0.011107062087427715	middle	441
Container (Base)	224727.2153041547	2496.059133117982	27530.815093503134	8.162751975955372	12.25077036452476	-0.7469327948122748	30026.874226621116	47	0.011107062087427715	middle	441
Container (Max)	465558.937774978	5170.992027223577	24855.88219939754	18.73033248388433	5.338933523259158	-0.7469327948122748	30026.874226621116	49	0.011107062087427715	middle	441
Traditional Housing	544087.8111421225	5568.207896146842	9929.20025146125	54.796740660160495	1.824926059383385	3.5288332415608057	15497.408147608092	98	0.010234024328643447	low	442
ODD Cubes Basic	328757.80946702056	4589.615833383015	10907.792314225077	30.139720302364093	3.3178808229403582	3.5288332415608057	15497.408147608092	110	0.013960476987067358	low	442
Container (Base)	246169.9532724528	3436.649967567524	12060.758180040568	20.410819087629264	4.89936242003187	3.5288332415608057	15497.408147608092	109	0.013960476987067358	low	442
Container (Max)	433931.34649723925	6057.888576741861	9439.519570866232	45.96964318359042	2.1753486230168644	3.5288332415608057	15497.408147608092	134	0.013960476987067358	low	442
Traditional Housing	539853.983575032	12771.088502313867	2940.992825984473	100	0.5447756088615983	-2.670014723072173	15712.08132829834	133	0.023656560645789637	low	443
ODD Cubes Basic	352810.056338451	7482.632815341332	8229.448512957008	42.87165243004591	2.3325436350551443	-2.670014723072173	15712.08132829834	133	0.0212086721478348	low	443
Container (Base)	243085.4735956679	5155.5201133916735	10556.561214906666	23.026956283113552	4.342736346502442	-2.670014723072173	15712.08132829834	48	0.0212086721478348	low	443
Container (Max)	402376.16621002794	8533.864189251166	7178.217139047174	56.05516779664299	1.7839568398542685	-2.670014723072173	15712.08132829834	107	0.0212086721478348	low	443
Traditional Housing	559473.7134974427	6949.176941613464	23705.534062986717	23.600974861435088	4.237113110247149	-3.5421898628074544	30654.71100460018	142	0.012420917683821133	middle	444
ODD Cubes Basic	331416.1952273283	5027.132948874593	25627.578055725586	12.932013883898206	7.732747652282612	-3.5421898628074544	30654.71100460018	121	0.015168639979788352	middle	444
Container (Base)	231068.88843492456	3505.000779199251	27149.71022540093	8.510915457901993	11.749617358395284	-3.5421898628074544	30654.71100460018	111	0.015168639979788352	middle	444
Container (Max)	396300.0311792936	6011.3324969376035	24643.378507662575	16.081400164188878	6.218364009291094	-3.5421898628074544	30654.71100460018	122	0.015168639979788352	middle	444
Traditional Housing	552918.8200647113	16266.815207785696	14343.125742605878	38.54939501940504	2.594074432287767	1.9546227587190943	30609.940950391574	129	0.029419897853869212	middle	445
ODD Cubes Basic	322203.4087781349	3653.126472238477	26956.814478153097	11.952577298748029	8.366396426524219	1.9546227587190943	30609.940950391574	92	0.011337951035626605	middle	445
Container (Base)	263960.6783509949	2992.7732464743635	27617.16770391721	9.557847538201928	10.46260673235352	1.9546227587190943	30609.940950391574	55	0.011337951035626605	middle	445
Container (Max)	492123.49490987504	5579.672088769602	25030.26886162197	19.661134989421974	5.086176360306855	1.9546227587190943	30609.940950391574	68	0.011337951035626605	middle	445
Traditional Housing	549825.0759501972	7209.113460368246	8327.840089625035	66.02253045602768	1.5146344635578908	-0.9845508497879409	15536.95354999328	104	0.01311164909659603	low	446
ODD Cubes Basic	338237.48922292225	6488.5848123065925	9048.368737686687	37.38104613422245	2.6751525262544678	-0.9845508497879409	15536.95354999328	145	0.0191835175551169	low	446
Container (Base)	256201.4254965799	4914.844543659616	10622.109006333665	24.11963813813379	4.1459991823798275	-0.9845508497879409	15536.95354999328	143	0.0191835175551169	low	446
Container (Max)	450982.81496119057	8651.436747864036	6885.516802129245	65.49730803383281	1.5267803059683724	-0.9845508497879409	15536.95354999328	70	0.0191835175551169	low	446
Traditional Housing	507922.521620041	9888.486939020893	20611.45955590324	24.642724608727143	4.057992839175962	-2.552835358046485	30499.94649492413	121	0.019468494737112922	middle	447
ODD Cubes Basic	298890.2622908024	7202.03383326411	23297.91266166002	12.829057548261318	7.794804850146821	-2.552835358046485	30499.94649492413	118	0.024095913256140012	middle	447
Container (Base)	263860.58486244484	6357.961764559841	24141.98473036429	10.929531594416817	9.149522935738934	-2.552835358046485	30499.94649492413	111	0.024095913256140012	middle	447
Container (Max)	437276.92454293004	10536.586842698123	19963.359652226005	21.9039746896596	4.565381462352031	-2.552835358046485	30499.94649492413	123	0.024095913256140012	middle	447
Traditional Housing	580118.1152839148	14710.974531035057	765.0683864685761	100	0.13188148522032364	-0.09467531166723475	15476.042917503633	129	0.02535858499063657	low	448
ODD Cubes Basic	306096.1466015315	5028.648168489125	10447.394749014507	29.298801658701105	3.4131088760861377	-0.09467531166723475	15476.042917503633	118	0.016428328890514578	low	448
Container (Base)	244383.19756198136	4014.80754486383	11461.235372639803	21.322587802827222	4.689862268347218	-0.09467531166723475	15476.042917503633	138	0.016428328890514578	low	448
Container (Max)	463597.2173722026	7616.127559717923	7859.9153577857105	58.982469437534355	1.6954190109979277	-0.09467531166723475	15476.042917503633	70	0.016428328890514578	low	448
Traditional Housing	525409.0045416201	14111.951690950522	1615.9985483115815	100	0.30756963324627806	0.9797947890366334	15727.950239262103	108	0.026858983323405618	low	449
ODD Cubes Basic	296689.07755961915	3656.2285657346183	12071.721673527485	24.57719665706337	4.068812297649108	0.9797947890366334	15727.950239262103	52	0.012323435010848708	low	449
Container (Base)	252225.13376444866	3108.2800440488054	12619.670195213297	19.98666604299365	5.003335713164383	0.9797947890366334	15727.950239262103	105	0.012323435010848708	low	449
Container (Max)	420319.3511587725	5179.77820780723	10548.172031454873	39.84760107299836	2.5095613614683137	0.9797947890366334	15727.950239262103	109	0.012323435010848708	low	449
Traditional Housing	540541.9109613115	11094.337133210316	4842.100503786782	100	0.8957863221328175	-4.387703402843939	15936.437636997098	143	0.02052447166118887	low	450
ODD Cubes Basic	338942.13311079284	5298.6231622492405	10637.814474747858	31.862008302116642	3.138534114102181	-4.387703402843939	15936.437636997098	48	0.0156328253251337	low	450
Container (Base)	247742.38065226923	3872.913362369708	12063.52427462739	20.536484613649215	4.869382558957376	-4.387703402843939	15936.437636997098	48	0.0156328253251337	low	450
Container (Max)	402547.8155821729	6292.959686010243	9643.477950986855	41.74301197432391	2.3956105530072893	-4.387703402843939	15936.437636997098	70	0.0156328253251337	low	450
ODD Cubes Basic	306278.7122331399	2633.2176540519968	12949.962225264477	23.65093479852871	4.228162685824192	4.77838061511582	15583.179879316474	144	0.008597455679673835	low	451
Container (Base)	258678.6879083794	2223.9785545684717	13359.201324748003	19.363334799751502	5.164399677749895	4.77838061511582	15583.179879316474	76	0.008597455679673835	low	451
Container (Max)	469902.6573058542	4039.967269948044	11543.212609368431	40.7081350060626	2.456511456128048	4.77838061511582	15583.179879316474	87	0.008597455679673835	low	451
Traditional Housing	548979.040350496	9380.636177042708	6188.318645301873	88.7121481320741	1.1272413317184091	-3.3825665521475914	15568.954822344582	145	0.017087421354107867	low	452
ODD Cubes Basic	336229.1237024047	3415.2475996051216	12153.70722273946	27.664737807187215	3.614709840988274	-3.3825665521475914	15568.954822344582	114	0.010157500819673034	low	452
Container (Base)	222078.23406577946	2255.7598445546946	13313.194977789888	16.681062242103998	5.9948220652036195	-3.3825665521475914	15568.954822344582	97	0.010157500819673034	low	452
Container (Max)	450424.85556225287	4575.190839574691	10993.763982769891	40.97094100511769	2.4407542894245213	-3.3825665521475914	15568.954822344582	107	0.010157500819673034	low	452
Traditional Housing	576546.8758798855	9491.387621871361	6347.732614191733	90.8272151525239	1.1009915897131985	1.6319535842323862	15839.120236063094	96	0.016462473424014776	low	453
ODD Cubes Basic	311900.72065680375	3927.6824659913614	11911.437770071732	26.18497671544528	3.8189837282159864	1.6319535842323862	15839.120236063094	71	0.012592732898213275	low	453
Container (Base)	244373.17029793415	3077.3260610514703	12761.794175011624	19.148809873178475	5.222256665677635	1.6319535842323862	15839.120236063094	96	0.012592732898213275	low	453
Container (Max)	452105.97644012823	5693.249802996439	10145.870433066655	44.56059038233512	2.244135437658887	1.6319535842323862	15839.120236063094	40	0.012592732898213275	low	453
Traditional Housing	544121.1534676854	6500.520036008754	23622.776996344906	23.033750585372584	4.341455362614905	-1.123789518430435	30123.29703235366	148	0.011946824699942142	middle	454
ODD Cubes Basic	344800.98501990683	4648.254901430347	25475.042130923313	13.534854358547431	7.388332179344712	-1.123789518430435	30123.29703235366	66	0.013480979183287377	middle	454
Container (Base)	244306.4338999285	3293.4899497481097	26829.807082605552	9.105784217819389	10.98203049928494	-1.123789518430435	30123.29703235366	146	0.013480979183287377	middle	454
Container (Max)	463061.914059076	6242.528024003612	23880.76900835005	19.390577995924826	5.1571438469248445	-1.123789518430435	30123.29703235366	60	0.013480979183287377	middle	454
Traditional Housing	509542.04317813925	14160.190073468802	1519.8784802847986	100	0.29828323307826415	0.5089572060112681	15680.068553753601	98	0.02779003276186634	low	455
ODD Cubes Basic	296956.2726758156	3162.8290632174526	12517.239490536149	23.72378293954781	4.215179352079591	0.5089572060112681	15680.068553753601	82	0.010650824226468802	low	455
Container (Base)	239013.80964509593	2545.69407422859	13134.374479525011	18.19757842428592	5.495236655583972	0.5089572060112681	15680.068553753601	46	0.010650824226468802	low	455
Container (Max)	410478.2968566847	4371.93218860083	11308.136365152772	36.29937627225803	2.754868272390274	0.5089572060112681	15680.068553753601	53	0.010650824226468802	low	455
Traditional Housing	548716.2027850781	11499.622870136516	18858.1124078484	29.097090467904547	3.4367697385518556	-2.4812267546120514	30357.735277984917	126	0.02095732331534723	middle	456
ODD Cubes Basic	322883.1351871174	4979.722843331032	25378.012434653887	12.722948103934955	7.859813557603995	-2.4812267546120514	30357.735277984917	68	0.015422678674267644	middle	456
Container (Base)	261818.25842407136	4037.9388707308203	26319.796407254096	9.947579167136364	10.052697075321419	-2.4812267546120514	30357.735277984917	83	0.015422678674267644	middle	456
Container (Max)	407906.48753849283	6291.010686455334	24066.724591529583	16.948982234252924	5.900059284852262	-2.4812267546120514	30357.735277984917	50	0.015422678674267644	middle	456
Traditional Housing	537916.1052895022	7385.055609417449	23537.47036679548	22.853607329373222	4.3756768268032795	-1.4808922002015934	30922.525976212928	114	0.013729010038550288	middle	457
ODD Cubes Basic	317816.9774168302	4098.825930352406	26823.70004586052	11.848364575858588	8.439983371523958	-1.4808922002015934	30922.525976212928	118	0.012896812384495828	middle	457
Container (Base)	266882.06065112	3441.9278650051306	27480.598111207797	9.711654002984517	10.296907197195113	-1.4808922002015934	30922.525976212928	52	0.012896812384495828	middle	457
Container (Max)	480178.4912162709	6192.771912286524	24729.754063926404	19.417034636697547	5.150116991139489	-1.4808922002015934	30922.525976212928	142	0.012896812384495828	middle	457
Traditional Housing	536802.656503659	10125.92103035646	5690.957692024038	94.32553983945373	1.0601582579882867	-4.232096700481219	15816.878722380497	112	0.01886339590103619	low	458
ODD Cubes Basic	354220.87175500527	5731.801141878444	10085.077580502053	35.12326691862409	2.8471155667747707	-4.232096700481219	15816.878722380497	64	0.016181432543711904	low	458
Container (Base)	244814.7146558482	3961.4527909116855	11855.425931468812	20.650014269501426	4.842611665779463	-4.232096700481219	15816.878722380497	44	0.016181432543711904	low	458
Container (Max)	455013.1637089813	7362.7648150578225	8454.113907322675	53.82150852200653	1.8579932585708188	-4.232096700481219	15816.878722380497	64	0.016181432543711904	low	458
Traditional Housing	588875.3287543812	14319.597691803023	1316.2218064159642	100	0.22351451014259727	2.9384924705543565	15635.819498218987	120	0.024316857902830738	low	459
ODD Cubes Basic	322237.82496841555	3465.9149341786915	12169.904564040295	26.478254062941936	3.7766840578796543	2.9384924705543565	15635.819498218987	148	0.010755766907619882	low	459
Container (Base)	255650.09970850623	2749.7128823744747	12886.106615844512	19.839204138988244	5.040524776065931	2.9384924705543565	15635.819498218987	111	0.010755766907619882	low	459
Container (Max)	424156.72367236525	4562.130852119697	11073.68864609929	38.303110844801886	2.6107540039028185	2.9384924705543565	15635.819498218987	116	0.010755766907619882	low	459
Traditional Housing	544252.0395538921	9160.248799469153	6523.879452135816	83.42460089076485	1.1986871849820269	3.3757862278496216	15684.128251604969	92	0.016830894757835998	low	460
ODD Cubes Basic	316913.0467066305	3709.8833788034426	11974.244872801526	26.46622397262573	3.7784007308118817	3.3757862278496216	15684.128251604969	140	0.011706313190184682	low	460
Container (Base)	273606.28233357804	3202.9208317989587	12481.20741980601	21.921459449460105	4.561740071665843	3.3757862278496216	15684.128251604969	128	0.011706313190184682	low	460
Container (Max)	462634.1462718754	5415.740208732284	10268.388042872684	45.05421341112942	2.2195482381964684	3.3757862278496216	15684.128251604969	51	0.011706313190184682	low	460
Traditional Housing	495755.1139356502	11620.690444768288	4289.355287761711	100	0.8652165488944359	-0.33592868226458794	15910.04573253	103	0.023440384411801896	low	461
ODD Cubes Basic	301929.86502457183	5587.239171607849	10322.80656092215	29.248815546689855	3.418941865880692	-0.33592868226458794	15910.04573253	130	0.01850508948875642	low	461
Container (Base)	233355.75011297435	4318.269038556471	11591.776693973528	20.131146093790274	4.967427067197448	-0.33592868226458794	15910.04573253	143	0.01850508948875642	low	461
Container (Max)	460408.93203718215	8519.908488770829	7390.137243759171	62.30045760327234	1.6051246467048017	-0.33592868226458794	15910.04573253	106	0.01850508948875642	low	461
Traditional Housing	557752.3056429994	6259.166332869545	9714.210518581254	57.416122965024876	1.7416710644310687	3.603736660027659	15973.3768514508	129	0.011222125430129286	low	462
ODD Cubes Basic	350911.209459147	7192.323124576895	8781.053726873904	39.96231208393631	2.5023577161892265	3.603736660027659	15973.3768514508	52	0.020496133867203302	low	462
Container (Base)	245540.6712290462	5032.634467353485	10940.742384097313	22.4427797135546	4.455776034713015	3.603736660027659	15973.3768514508	73	0.020496133867203302	low	462
Container (Max)	455721.1026586979	9340.520726202172	6632.856125248627	68.70661658466406	1.4554638981061527	3.603736660027659	15973.3768514508	49	0.020496133867203302	low	462
Traditional Housing	501102.799169644	9850.132634384678	20871.324592007124	24.00915174121465	4.16507842833688	-0.8085715799958981	30721.4572263918	144	0.019656910020672227	middle	463
ODD Cubes Basic	351479.0419711494	3745.374204414239	26976.083021977563	13.029283817253878	7.675018934469456	-0.8085715799958981	30721.4572263918	58	0.010656038503489697	middle	463
Container (Base)	254758.20546666547	2714.7132465327268	28006.743979859075	9.096316431852046	10.993461006901187	-0.8085715799958981	30721.4572263918	117	0.010656038503489697	middle	463
Container (Max)	437877.5281919989	4666.039800226836	26055.417426164968	16.805623223379268	5.950389263808095	-0.8085715799958981	30721.4572263918	139	0.010656038503489697	middle	463
Traditional Housing	522737.23796200415	7103.319107089181	23779.887374319762	21.982326061246006	4.549109121636411	-2.42293697177157	30883.206481408943	83	0.013588699237848242	middle	464
ODD Cubes Basic	308213.83674178086	3703.5661705462353	27179.640310862706	11.339879160159418	8.818436121553361	-2.42293697177157	30883.206481408943	65	0.012016222923985902	middle	464
Container (Base)	258314.4286051962	3103.963758602078	27779.242722806863	9.298829027946075	10.754042223968925	-2.42293697177157	30883.206481408943	70	0.012016222923985902	middle	464
Container (Max)	434119.76177283	5216.4798331699785	25666.726648238964	16.913717425771377	5.912360806479498	-2.42293697177157	30883.206481408943	135	0.012016222923985902	middle	464
Traditional Housing	575697.102051565	7663.425277155424	7906.445807870761	72.8136404196265	1.3733690476632943	-0.7745327535411395	15569.871085026185	80	0.013311557848469097	low	465
ODD Cubes Basic	302172.4386203654	3780.372763263769	11789.498321762416	25.630644355967263	3.9015796330035784	-0.7745327535411395	15569.871085026185	71	0.012510647167305829	low	465
Container (Base)	246142.47789042507	3079.401693773484	12490.4693912527	19.706423368108414	5.074487548148055	-0.7745327535411395	15569.871085026185	129	0.012510647167305829	low	465
Container (Max)	425242.65487943747	5320.060815685045	10249.81026934114	41.487856233925406	2.4103438711356726	-0.7745327535411395	15569.871085026185	144	0.012510647167305829	low	465
ODD Cubes Basic	295614.10673242155	5929.103552002437	9531.4838307615	31.014489661973656	3.2242993868317082	4.571093552478022	15460.587382763937	59	0.020056903297139442	low	466
Container (Base)	247240.0744513462	4958.870264448207	10501.71711831573	23.542823679771587	4.24757885291057	4.571093552478022	15460.587382763937	128	0.020056903297139442	low	466
Container (Max)	433343.38108466176	8691.526288870506	6769.0610938934315	64.01824050245219	1.5620548021179925	4.571093552478022	15460.587382763937	127	0.020056903297139442	low	466
Traditional Housing	599510.3921639121	11341.152518675166	19542.372368293407	30.677462329834114	3.2597220371369855	-0.2717119922168463	30883.524886968575	81	0.018917357675385188	middle	467
ODD Cubes Basic	294820.92960439133	6781.485680196564	24102.03920677201	12.23219857353625	8.175145244645146	-0.2717119922168463	30883.524886968575	140	0.023002049716403697	middle	467
Container (Base)	265136.04510426975	6098.672491099066	24784.852395869508	10.697503494047668	9.347975446387306	-0.2717119922168463	30883.524886968575	84	0.023002049716403697	middle	467
Container (Max)	473337.22337994457	10887.726344809967	19995.798542158605	23.671833979621923	4.224429762648967	-0.2717119922168463	30883.524886968575	42	0.023002049716403697	middle	467
Traditional Housing	549657.6874956687	9510.811465902878	6273.521064436303	87.61550042632354	1.1413505545641511	4.002195567607696	15784.332530339181	113	0.017303153730525826	low	468
ODD Cubes Basic	324826.8247123414	2927.7267751258487	12856.605755213332	25.265364039075763	3.9579876959357727	4.002195567607696	15784.332530339181	86	0.009013192730368162	low	468
Container (Base)	240406.8327201833	2166.8331170043907	13617.49941333479	17.654256881022334	5.664356232829956	4.002195567607696	15784.332530339181	74	0.009013192730368162	low	468
Container (Max)	457341.3060805365	4122.105335262172	11662.227195077008	39.215605941341515	2.550005223674969	4.002195567607696	15784.332530339181	60	0.009013192730368162	low	468
Traditional Housing	569521.5459973103	15086.142094388762	824.692650093315	100	0.14480446892472962	3.5085219703133035	15910.834744482077	100	0.026489150762454228	low	469
ODD Cubes Basic	336155.36110204173	5568.538544425489	10342.29620005659	32.5029717385393	3.076641754619267	3.5085219703133035	15910.834744482077	103	0.016565371815489595	low	469
Container (Base)	269611.43456141325	4466.213659217352	11444.621085264725	23.557917081985845	4.244857457133488	3.5085219703133035	15910.834744482077	121	0.016565371815489595	low	469
Container (Max)	470636.0771296079	7796.261607435394	8114.573137046684	57.99887057286379	1.7241715056221714	3.5085219703133035	15910.834744482077	104	0.016565371815489595	low	469
Traditional Housing	571463.9062507143	11724.89929717374	3738.8684333556303	100	0.6542615189620222	-4.592744020909274	15463.767730529371	103	0.02051730506323484	low	470
ODD Cubes Basic	332150.838550594	5714.463661421941	9749.304069107431	34.06918444600355	2.9352038103081273	-4.592744020909274	15463.767730529371	55	0.01720442340702235	low	470
Container (Base)	233081.1693014335	4010.0271248657214	11453.74060566365	20.349785919385972	4.914056609545766	-4.592744020909274	15463.767730529371	41	0.01720442340702235	low	470
Container (Max)	390372.70662080747	6716.137331249689	8747.630399279682	44.62610887777706	2.2408406763377497	-4.592744020909274	15463.767730529371	74	0.01720442340702235	low	470
Traditional Housing	586588.5379514683	11237.366321731888	4334.796102597851	100	0.7389841127370431	4.323307986111917	15572.16242432974	124	0.01915715291842545	low	471
ODD Cubes Basic	296723.18995542696	6311.582648988487	9260.579775341252	32.041534888078075	3.12094911649216	4.323307986111917	15572.16242432974	141	0.02127094498389761	low	471
Container (Base)	271595.1995862922	5777.086548290712	9795.075876039027	27.727727995520233	3.606498160114535	4.323307986111917	15572.16242432974	131	0.02127094498389761	low	471
Container (Max)	472501.93226309045	10050.562605953512	5521.599818376228	85.57337507339352	1.1685877752774532	4.323307986111917	15572.16242432974	41	0.02127094498389761	low	471
Traditional Housing	522069.7698899784	14858.275117903038	16096.51735553038	32.43370962543072	3.083211916085963	1.6552747856289418	30954.79247343342	116	0.028460324605721357	middle	472
ODD Cubes Basic	340252.8165697158	8207.494917005008	22747.297556428413	14.957944596524607	6.685410509090563	1.6552747856289418	30954.79247343342	130	0.02412175452285592	middle	472
Container (Base)	232579.93872287587	5610.236188814084	25344.556284619335	9.17672166405296	10.897137742743123	1.6552747856289418	30954.79247343342	76	0.02412175452285592	middle	472
Container (Max)	457383.5257885001	11032.893131868539	19921.89934156488	22.958831281424008	4.355622408398027	1.6552747856289418	30954.79247343342	96	0.02412175452285592	middle	472
Traditional Housing	584705.9213631599	8663.500836416308	6924.5694565261565	84.43931785709734	1.1842824236126246	2.74022634093774	15588.070292942464	114	0.014816851548584576	low	473
ODD Cubes Basic	309235.2520187464	2933.493728369422	12654.576564573043	24.436633690649277	4.092216680330449	2.74022634093774	15588.070292942464	90	0.009486284986006668	low	473
Container (Base)	240542.95213786443	2281.858995355144	13306.21129758732	18.077493792803338	5.531740248186951	2.74022634093774	15588.070292942464	97	0.009486284986006668	low	473
Container (Max)	499690.4007644587	4740.205546423539	10847.864746518924	46.06347999727865	2.170917177901188	2.74022634093774	15588.070292942464	91	0.009486284986006668	low	473
Traditional Housing	598626.8382122751	13555.43968556213	2012.0271687161912	100	0.3361070771108194	4.310926884249891	15567.466854278322	91	0.022644223112421376	low	474
ODD Cubes Basic	342046.65190124867	6649.424787933892	8918.042066344431	38.3544559844688	2.6072589855138046	4.310926884249891	15567.466854278322	132	0.01944011073043226	low	474
Container (Base)	282836.1832989301	5498.366721904037	10069.100132374286	28.08951937915008	3.560046672575918	4.310926884249891	15567.466854278322	128	0.01944011073043226	low	474
Container (Max)	438739.1479217838	8529.137617374976	7038.329236903346	62.33569546894567	1.604217282693475	4.310926884249891	15567.466854278322	46	0.01944011073043226	low	474
Traditional Housing	539137.128289952	8534.824404272042	21850.14002440982	24.67430999012622	4.052798235898651	-3.4867326702123314	30384.96442868186	103	0.015830526143400664	middle	475
ODD Cubes Basic	312835.6584963513	5710.565099241329	24674.39932944053	12.678552143033851	7.887335941189811	-3.4867326702123314	30384.96442868186	142	0.018254201348686515	middle	475
Container (Base)	241598.39025992702	4410.185661323251	25974.778767358606	9.301268450591516	10.751221785630804	-3.4867326702123314	30384.96442868186	43	0.018254201348686515	middle	475
Container (Max)	439534.86448333313	8023.357916046404	22361.606512635455	19.655782076076395	5.087561492743289	-3.4867326702123314	30384.96442868186	53	0.018254201348686515	middle	475
Traditional Housing	524962.9510538582	12258.643886093661	3625.387952636578	100	0.6905988213756126	4.9686409136373	15884.03183873024	144	0.023351445776286783	low	476
ODD Cubes Basic	328820.68553406064	4341.426450393172	11542.605388337068	28.487561904031576	3.5103039121732613	4.9686409136373	15884.03183873024	112	0.013203021103559705	low	476
Container (Base)	274585.9225260497	3625.3637298518447	12258.668108878395	22.399327568643418	4.464419732848987	4.9686409136373	15884.03183873024	133	0.013203021103559705	low	476
Container (Max)	463321.48741376295	6117.243376056585	9766.788462673656	47.438468559492975	2.1079938504884317	4.9686409136373	15884.03183873024	117	0.013203021103559705	low	476
Traditional Housing	588034.4021275067	16458.084913110408	14168.058606743747	41.504232756886864	2.4093928102647997	4.5322381530684055	30626.143519854155	139	0.027988302816238486	middle	477
ODD Cubes Basic	326145.29245100584	7425.093403734446	23201.05011611971	14.057350456926319	7.113716080879817	4.5322381530684055	30626.143519854155	49	0.022766213634219042	middle	477
Container (Base)	242115.41034281178	5512.05115600106	25114.092363853095	9.640619570679382	10.37277731652603	4.5322381530684055	30626.143519854155	124	0.022766213634219042	middle	477
Container (Max)	459907.0050627532	10470.3411291325	20155.802390721656	22.81759843381193	4.382582167447405	4.5322381530684055	30626.143519854155	117	0.022766213634219042	middle	477
Traditional Housing	583137.2189868987	7011.356475802097	8949.384980871322	65.15947411283717	1.534696241207061	-3.0828843382456994	15960.741456673419	80	0.01202351050063848	low	478
ODD Cubes Basic	354290.2943572594	4435.805058980821	11524.936397692598	30.741193021090485	3.2529641881950844	-3.0828843382456994	15960.741456673419	145	0.012520255648064246	low	478
Container (Base)	264835.2181788734	3315.804636210367	12644.936820463052	20.94397322336129	4.774643231899197	-3.0828843382456994	15960.741456673419	126	0.012520255648064246	low	478
Container (Max)	423201.84613600763	5298.5953043555655	10662.146152317853	39.69199447186413	2.519399726080419	-3.0828843382456994	15960.741456673419	40	0.012520255648064246	low	478
Traditional Housing	594786.2950213919	7346.442186019844	8385.923779176568	70.92674709235138	1.4099053474113692	2.0166962498421253	15732.365965196412	111	0.012351397884437844	low	479
ODD Cubes Basic	333498.6443857213	5804.411047925144	9927.954917271269	33.59187739718146	2.9769101267436318	2.0166962498421253	15732.365965196412	93	0.017404601624742493	low	479
Container (Base)	238687.43203374476	4154.259667380127	11578.106297816284	20.615412045298196	4.85073981447813	2.0166962498421253	15732.365965196412	55	0.017404601624742493	low	479
Container (Max)	465080.976580747	8094.549120634094	7637.816844562318	60.89187343001785	1.6422552693329193	2.0166962498421253	15732.365965196412	109	0.017404601624742493	low	479
Traditional Housing	512122.3179173247	12073.868915758281	3489.5072916080717	100	0.6813816093387685	-0.868335836181596	15563.376207366353	95	0.0235761428341177	low	480
ODD Cubes Basic	341730.4811596065	4879.379259053199	10683.996948313154	31.985265702791192	3.1264395590521388	-0.868335836181596	15563.376207366353	68	0.014278443182755673	low	480
Container (Base)	248459.34185273162	3547.6125958690973	12015.763611497256	20.677782110742747	4.836108605092947	-0.868335836181596	15563.376207366353	91	0.014278443182755673	low	480
Container (Max)	471361.83159852715	6730.313130999218	8833.063076367136	53.36334944325892	1.8739453397004189	-0.868335836181596	15563.376207366353	99	0.014278443182755673	low	480
Traditional Housing	533066.7318449597	15232.532885695211	722.5141535258663	100	0.13553915680035472	4.50529771888052	15955.047039221077	105	0.028575283310168252	low	481
ODD Cubes Basic	356682.27723679895	4820.969298185227	11134.07774103585	32.03518832298142	3.121567414924855	4.50529771888052	15955.047039221077	105	0.013516144776054062	low	481
Container (Base)	266545.2005641717	3602.6635201877116	12352.383519033367	21.578442747787204	4.634254712854785	4.50529771888052	15955.047039221077	116	0.013516144776054062	low	481
Container (Max)	436532.548358011	5900.237123066698	10054.80991615438	43.41529596264807	2.3033356742755835	4.50529771888052	15955.047039221077	136	0.013516144776054062	low	481
Traditional Housing	546687.2812217443	8346.482462377462	21891.43154918769	24.972660193254	4.0043791580927985	-4.231584795233212	30237.914011565153	119	0.01526737999780172	middle	482
ODD Cubes Basic	347551.49949640397	4730.485531937047	25507.428479628106	13.625501283831149	7.3391795220529685	-4.231584795233212	30237.914011565153	68	0.013610890871687903	middle	482
Container (Base)	260120.26221301893	3540.468502496243	26697.44550906891	9.74326409336272	10.263500921433684	-4.231584795233212	30237.914011565153	110	0.013610890871687903	middle	482
Container (Max)	471531.9679919389	6417.970158850513	23819.94385271464	19.795679238689754	5.0516074136296645	-4.231584795233212	30237.914011565153	83	0.013610890871687903	middle	482
Traditional Housing	535741.3954546326	12466.847018668028	3328.972702675528	100	0.6213767931541946	-2.741775491692219	15795.819721343556	125	0.023270270179679888	low	483
ODD Cubes Basic	297109.28242513275	5229.469444361772	10566.350276981784	28.118439634957877	3.556385108783786	-2.741775491692219	15795.819721343556	106	0.017601164802649755	low	483
Container (Base)	242333.95775910708	4265.359927796408	11530.459793547148	21.01685120091444	4.758086691675725	-2.741775491692219	15795.819721343556	55	0.017601164802649755	low	483
Container (Max)	406788.7890467701	7159.956515882525	8635.863205461032	47.104589242396806	2.12293539989081	-2.741775491692219	15795.819721343556	48	0.017601164802649755	low	483
Traditional Housing	549786.4974753308	6267.376136539373	24278.288039797004	22.64519213933536	4.4159484002035505	-1.5123928807725906	30545.664176336377	96	0.01139965453011256	middle	484
ODD Cubes Basic	323441.5246113495	3282.1992029069047	27263.464973429473	11.863551640503887	8.42917897019856	-1.5123928807725906	30545.664176336377	54	0.01014773599911399	middle	484
Container (Base)	224313.5927791082	2276.275120535152	28269.389055801224	7.934858172432853	12.602619710005436	-1.5123928807725906	30545.664176336377	110	0.01014773599911399	middle	484
Container (Max)	419895.1098500896	4260.984722077677	26284.6794542587	15.9748993926596	6.25982033075899	-1.5123928807725906	30545.664176336377	40	0.01014773599911399	middle	484
Traditional Housing	507361.18359126634	6152.1946621082925	24630.23748945546	20.599118616232367	4.854576638109105	-3.551543563161985	30782.432151563753	143	0.012125867845389889	middle	485
ODD Cubes Basic	330563.01168180845	6348.500353914226	24433.931797649526	13.528850551740005	7.391610958932395	-3.551543563161985	30782.432151563753	68	0.019205114091909142	middle	485
Container (Base)	242604.8103443093	4659.25306190844	26123.179089655314	9.28695582998089	10.76779106423356	-3.551543563161985	30782.432151563753	60	0.019205114091909142	middle	485
Container (Max)	410121.5530501383	7876.431217878874	22906.000933684878	17.904546246962987	5.5851736548175435	-3.551543563161985	30782.432151563753	143	0.019205114091909142	middle	485
Traditional Housing	545916.5762825606	9732.406968719883	6035.310138552519	90.45377350127208	1.1055370730176741	-3.1813464763031463	15767.717107272401	147	0.017827645086348307	low	486
ODD Cubes Basic	318471.34456368606	2836.48212418187	12931.234983090531	24.628068779210462	4.060407695645791	-3.1813464763031463	15767.717107272401	66	0.008906553674610579	low	486
Container (Base)	259459.53834113	2310.8903046249557	13456.826802647445	19.280885616368707	5.18648375337614	-3.1813464763031463	15767.717107272401	135	0.008906553674610579	low	486
Container (Max)	432892.5649422701	3855.5808649981745	11912.136242274228	36.340464559665214	2.751753485039137	-3.1813464763031463	15767.717107272401	91	0.008906553674610579	low	486
Traditional Housing	519827.2990895006	5210.461994232301	10636.223205302254	48.87329732139901	2.046107086705921	-0.37918632391912066	15846.685199534555	118	0.01002344817857516	low	487
ODD Cubes Basic	297736.6050141325	2753.131360330888	13093.553839203667	22.739174457180106	4.3976970310997405	-0.37918632391912066	15846.685199534555	90	0.009246868923625319	low	487
Container (Base)	238314.36487496397	2203.6616946158097	13643.023504918745	17.467855625187777	5.7248011516539545	-0.37918632391912066	15846.685199534555	121	0.009246868923625319	low	487
Container (Max)	475143.76718484546	4393.592135035811	11453.093064498744	41.48606533702698	2.4104479223954844	-0.37918632391912066	15846.685199534555	111	0.009246868923625319	low	487
Traditional Housing	584556.6212365073	14664.716823970211	15757.942245675786	37.09599972654541	2.6957084520474943	3.584691091831502	30422.659069645997	106	0.025086905684089368	middle	488
ODD Cubes Basic	354559.872163357	4993.21868436379	25429.440385282207	13.942889296477226	7.172114607928913	3.584691091831502	30422.659069645997	72	0.014082864634109684	middle	488
Container (Base)	258400.27893738373	3639.016149691359	26783.64291995464	9.647689812384243	10.365175699537431	3.584691091831502	30422.659069645997	86	0.014082864634109684	middle	488
Container (Max)	420743.2919785296	5925.270826643319	24497.38824300268	17.17502648874044	5.822407322955674	3.584691091831502	30422.659069645997	116	0.014082864634109684	middle	488
Traditional Housing	598767.6769734899	11947.779662520792	3539.8419468516295	100	0.5911878818749853	-3.6728171720617753	15487.621609372422	103	0.01995394895548073	low	489
ODD Cubes Basic	334183.22776163695	8175.797782399113	7311.823826973308	45.704496671382515	2.1879685213252587	-3.6728171720617753	15487.621609372422	85	0.024465015306605	low	489
Container (Base)	222328.7701297013	5439.276764321807	10048.344845050615	22.12590964562795	4.519588193281801	-3.6728171720617753	15487.621609372422	43	0.024465015306605	low	489
Container (Max)	404979.0229709275	9907.817995837679	5579.803613534743	72.57944024922014	1.3778006506611837	-3.6728171720617753	15487.621609372422	102	0.024465015306605	low	489
Traditional Housing	501338.701767825	8445.313275230206	7291.256298187554	68.75889164566149	1.4543573581048224	3.5695883282996395	15736.56957341776	99	0.016845524284182064	low	490
ODD Cubes Basic	302214.1623468069	4895.790752114783	10840.778821302978	27.877532355233782	3.5871180679026566	3.5695883282996395	15736.56957341776	81	0.016199739661758805	low	490
Container (Base)	235873.69778855646	3821.092497230988	11915.477076186773	19.795573125641184	5.051634492485095	3.5695883282996395	15736.56957341776	102	0.016199739661758805	low	490
Container (Max)	457966.7466582173	7418.94206960577	8317.627503811991	55.059780742565096	1.8162077409562394	3.5695883282996395	15736.56957341776	75	0.016199739661758805	low	490
Traditional Housing	507535.5558956381	5862.883879148936	9603.889936551132	52.846873428237146	1.8922595323599216	-3.6510403023061455	15466.773815700068	83	0.011551671229817227	low	491
ODD Cubes Basic	297554.91807492723	6183.871303762682	9282.902511937385	32.05408197406849	3.119727468124005	-3.6510403023061455	15466.773815700068	46	0.02078228564921761	low	491
Container (Base)	259803.7393116299	5399.31552310916	10067.458292590909	25.806289111009384	3.875024400828648	-3.6510403023061455	15466.773815700068	53	0.02078228564921761	low	491
Container (Max)	458351.8885159487	9525.599874996791	5941.1739407032765	77.14837052249173	1.2962036569631257	-3.6510403023061455	15466.773815700068	103	0.02078228564921761	low	491
Traditional Housing	557196.5447450469	14580.524200241634	16037.934487550068	34.74241306931311	2.878326263650549	2.673466131928782	30618.458687791703	148	0.02616765006486743	middle	492
ODD Cubes Basic	300245.2057462757	7391.053127187515	23227.405560604187	12.926334151392231	7.736145362544995	2.673466131928782	30618.458687791703	76	0.02461672321733382	middle	492
Container (Base)	272483.8866869065	6707.6604197549295	23910.79826803677	11.3958506793625	8.775123754569426	2.673466131928782	30618.458687791703	129	0.02461672321733382	middle	492
Container (Max)	485167.6583472466	11943.237959536149	18675.220728255554	25.97921949126895	3.849230344799536	2.673466131928782	30618.458687791703	64	0.02461672321733382	middle	492
Traditional Housing	591393.6272558289	7651.497205736408	7850.487575063229	75.33208881628805	1.327455558067286	-0.07014261697193724	15501.984780799638	108	0.01293807855394166	low	493
ODD Cubes Basic	312101.4520779224	3778.0631058322806	11723.921674967358	26.620909003879998	3.75644573163993	-0.07014261697193724	15501.984780799638	100	0.012105240397564734	low	493
Container (Base)	270244.0098509955	3271.3687052481528	12230.616075551485	22.09569887417221	4.525767687615012	-0.07014261697193724	15501.984780799638	69	0.012105240397564734	low	493
Container (Max)	468497.1366520555	5671.270464743868	9830.71431605577	47.65646946803186	2.098350992347018	-0.07014261697193724	15501.984780799638	125	0.012105240397564734	low	493
Traditional Housing	572581.6904392367	12335.280957101299	3528.8808743400223	100	0.6163104642121826	-1.638768354922461	15864.16183144132	88	0.02154326825861076	low	494
ODD Cubes Basic	300290.4826514435	5296.362043851953	10567.799787589367	28.415610504288626	3.51919238141681	-1.638768354922461	15864.16183144132	88	0.017637462223535086	low	494
Container (Base)	250940.752774762	4425.958047410322	11438.203784030999	21.938825143603676	4.558129222756273	-1.638768354922461	15864.16183144132	147	0.017637462223535086	low	494
Container (Max)	437771.95103501575	7721.186248903342	8142.975582537979	53.76068570975283	1.8600953220702467	-1.638768354922461	15864.16183144132	131	0.017637462223535086	low	494
ODD Cubes Basic	320349.06422449317	4449.883818730102	11402.07425502314	28.095683036212872	3.559265666227398	-1.843582037643856	15851.958073753243	136	0.013890734563256683	low	495
Container (Base)	247477.7716826364	3437.6480367497434	12414.310037003499	19.93487925990056	5.016333367072464	-1.843582037643856	15851.958073753243	61	0.013890734563256683	low	495
Container (Max)	450406.3326215399	6256.47481205571	9595.483261697533	46.939411005950596	2.130405939420987	-1.843582037643856	15851.958073753243	63	0.013890734563256683	low	495
ODD Cubes Basic	339235.6208037314	2803.892767544321	12739.09055904606	26.629500687773923	3.7552337602000843	-1.262711477726116	15542.983326590382	74	0.00826532532433127	low	496
Container (Base)	240670.65099201264	1989.221226467575	13553.762100122807	17.75674157581916	5.631663871043681	-1.262711477726116	15542.983326590382	77	0.00826532532433127	low	496
Container (Max)	402548.2002800241	3327.1918340384595	12215.791492551922	32.95310013481004	3.03461585073645	-1.262711477726116	15542.983326590382	51	0.00826532532433127	low	496
Traditional Housing	548457.2714538772	7806.00202376766	7748.378331327171	70.78349146123011	1.4127587935496584	0.17388044287495852	15554.38035509483	129	0.014232652988764522	low	497
ODD Cubes Basic	301361.76996148075	7268.199523250257	8286.180831844573	36.36920024763629	2.749579295643137	0.17388044287495852	15554.38035509483	131	0.024117855175124762	low	497
Container (Base)	268325.33826111496	6471.431647997933	9082.948707096897	29.541655129182978	3.38505068733316	0.17388044287495852	15554.38035509483	56	0.024117855175124762	low	497
Container (Max)	491928.06829332706	11864.249907677346	3690.130447417485	100	0.7501361856053175	0.17388044287495852	15554.38035509483	134	0.024117855175124762	low	497
Traditional Housing	568709.4187080706	11868.896655300237	3767.9241183985305	100	0.6625394260144437	-1.2491172100345462	15636.820773698768	135	0.020869878825398473	low	498
ODD Cubes Basic	335449.882364116	7283.150414984977	8353.67035871379	40.1559874832989	2.4902886535062936	-1.2491172100345462	15636.820773698768	93	0.02171159030868116	low	498
Container (Base)	232339.08426098808	5044.451010168724	10592.369763530045	21.934570775742827	4.559013304723007	-1.2491172100345462	15636.820773698768	112	0.02171159030868116	low	498
Container (Max)	460537.475531698	9999.000990538501	5637.8197831602665	81.68715802290949	1.2241826306645973	-1.2491172100345462	15636.820773698768	67	0.02171159030868116	low	498
ODD Cubes Basic	316918.09172945085	3218.349776613403	12712.149325854252	24.930331103403244	4.011178174298253	-2.4464826253744976	15930.499102467655	96	0.010155146899473538	low	499
Container (Base)	234700.03696508106	2383.4133526922674	13547.085749775388	17.324762041088608	5.77208505160608	-2.4464826253744976	15930.499102467655	117	0.010155146899473538	low	499
Container (Max)	425274.9217569731	4318.729303104176	11611.76979936348	36.624470610869786	2.730414892886424	-2.4464826253744976	15930.499102467655	81	0.010155146899473538	low	499
\.


--
-- Data for Name: sensitivity_model_summary; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_model_summary (model_name, annual_roi_percentage_mean, annual_roi_percentage_std, annual_roi_percentage_min, annual_roi_percentage_max, payback_years_mean, payback_years_std, payback_years_min, payback_years_max, roi_classification, payback_feasibility) FROM stdin;
Container (Base)	7.461622390266244	3.032622890761302	3.1883585658280507	12.792107234912246	15.97553403932216	6.509208523473862	7.817320333828957	31.36410097401606	Acceptable	Viable
Container (Max)	3.451486494785776	1.6904862869415327	1.002345872409947	6.583286199406895	38.735242606467125	21.691418114637326	15.189982171671234	99.7659617828019	Poor	Viable
ODD Cubes Basic	5.34919195780889	2.348479103520481	1.9693677939543752	9.352641849817475	23.154874549036947	10.575598320756836	10.692166085879958	50.777716740866296	Poor	Viable
Traditional Housing	2.869433185924101	1.155806179926937	1.0172916013551117	4.854576638109105	43.37745082075691	22.60769615070328	20.599118616232367	98.30023158236264	Poor	Viable
\.


--
-- Data for Name: sensitivity_optimal_scenarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_optimal_scenarios (model_name, adjusted_investment, annual_maintenance, annual_net_income, payback_years, annual_roi_percentage, container_price_increase, rental_income, expected_lifespan, maintenance_pct, income_segment, iteration, viability_issue) FROM stdin;
\.


--
-- Data for Name: shipping_container_prices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shipping_container_prices (id, ship_date, freight_index, base_price, calculated_date) FROM stdin;
517	2017-01-01	954.27	1420.15	2025-03-20 12:26:38.311732
518	2017-02-01	815.10	1509.99	2025-03-20 12:26:38.311732
519	2017-03-01	830.02	1765.18	2025-03-20 12:26:38.311732
520	2017-04-01	909.25	1892.92	2025-03-20 12:26:38.311732
521	2017-05-01	853.43	1853.51	2025-03-20 12:26:38.311732
522	2017-06-01	918.83	1838.11	2025-03-20 12:26:38.311732
523	2017-07-01	925.45	1947.89	2025-03-20 12:26:38.311732
524	2017-08-01	715.97	2070.80	2025-03-20 12:26:38.311732
525	2017-09-01	806.81	2384.88	2025-03-20 12:26:38.311732
526	2017-10-01	705.19	2152.64	2025-03-20 12:26:38.311732
527	2017-11-01	824.18	2173.18	2025-03-20 12:26:38.311732
528	2017-12-01	824.18	2456.76	2025-03-20 12:26:38.311732
529	2018-01-01	858.60	2420.84	2025-03-20 12:26:38.311732
530	2018-02-01	854.19	2335.61	2025-03-20 12:26:38.311732
531	2018-03-01	658.68	2331.98	2025-03-20 12:26:38.311732
532	2018-04-01	760.67	2392.02	2025-03-20 12:26:38.311732
533	2018-05-01	764.34	2444.68	2025-03-20 12:26:38.311732
534	2018-06-01	821.18	2534.68	2025-03-20 12:26:38.311732
535	2018-07-01	868.59	2306.63	2025-03-20 12:26:38.311732
536	2018-08-01	939.48	2223.22	2025-03-20 12:26:38.311732
537	2018-09-01	870.58	2271.45	2025-03-20 12:26:38.311732
538	2018-10-01	956.63	2397.73	2025-03-20 12:26:38.311732
539	2018-11-01	890.41	2394.04	2025-03-20 12:26:38.311732
540	2018-12-01	910.81	2545.57	2025-03-20 12:26:38.311732
541	2019-01-01	945.44	2442.95	2025-03-20 12:26:38.311732
542	2019-02-01	847.75	2355.88	2025-03-20 12:26:38.311732
543	2019-03-01	793.49	2307.86	2025-03-20 12:26:38.311732
544	2019-04-01	778.00	2315.46	2025-03-20 12:26:38.311732
545	2019-05-01	782.12	2411.14	2025-03-20 12:26:38.311732
546	2019-06-01	829.70	2143.90	2025-03-20 12:26:38.311732
547	2019-07-01	788.93	2247.81	2025-03-20 12:26:38.311732
548	2019-08-01	819.65	2168.15	2025-03-20 12:26:38.311732
549	2019-09-01	722.90	2114.81	2025-03-20 12:26:38.311732
550	2019-10-01	705.28	2042.28	2025-03-20 12:26:38.311732
551	2019-11-01	819.63	1990.81	2025-03-20 12:26:38.311732
552	2019-12-01	958.57	1976.95	2025-03-20 12:26:38.311732
553	2020-01-01	981.19	1735.97	2025-03-20 12:26:38.311732
554	2020-02-01	875.76	1898.27	2025-03-20 12:26:38.311732
555	2020-03-01	889.18	2074.10	2025-03-20 12:26:38.311732
556	2020-04-01	852.27	1973.70	2025-03-20 12:26:38.311732
557	2020-05-01	920.38	2037.92	2025-03-20 12:26:38.311732
558	2020-06-01	1001.30	2065.78	2025-03-20 12:26:38.311732
559	2020-07-01	1103.50	1973.78	2025-03-20 12:26:38.311732
560	2020-08-01	1263.30	2387.25	2025-03-20 12:26:38.311732
561	2020-09-01	1443.00	2312.53	2025-03-20 12:26:38.311732
562	2020-10-01	1530.00	2314.33	2025-03-20 12:26:38.311732
563	2020-11-01	2048.30	2473.81	2025-03-20 12:26:38.311732
564	2020-12-01	2641.90	3008.21	2025-03-20 12:26:38.311732
565	2021-01-01	2861.70	4071.73	2025-03-20 12:26:38.311732
566	2021-02-01	2775.30	3935.67	2025-03-20 12:26:38.311732
567	2021-03-01	2570.70	4307.26	2025-03-20 12:26:38.311732
568	2021-04-01	3100.70	4560.04	2025-03-20 12:26:38.311732
569	2021-05-01	3495.80	5142.27	2025-03-20 12:26:38.311732
570	2021-06-01	3785.40	6615.43	2025-03-20 12:26:38.311732
571	2021-07-01	4196.20	4735.52	2025-03-20 12:26:38.311732
572	2021-08-01	4385.60	4915.50	2025-03-20 12:26:38.311732
573	2021-09-01	4643.80	4209.95	2025-03-20 12:26:38.311732
574	2021-10-01	4567.30	4720.62	2025-03-20 12:26:38.311732
575	2021-11-01	4602.00	4284.20	2025-03-20 12:26:38.311732
576	2021-12-01	5046.70	3533.33	2025-03-20 12:26:38.311732
577	2022-01-01	5010.40	3423.21	2025-03-20 12:26:38.311732
578	2022-02-01	4818.50	3284.18	2025-03-20 12:26:38.311732
579	2022-03-01	4434.10	3508.14	2025-03-20 12:26:38.311732
580	2022-04-01	4177.30	3445.58	2025-03-20 12:26:38.311732
581	2022-05-01	4175.40	3388.88	2025-03-20 12:26:38.311732
582	2022-06-01	4216.10	3375.52	2025-03-20 12:26:38.311732
583	2022-07-01	3887.80	3278.26	2025-03-20 12:26:38.311732
584	2022-08-01	3154.30	3168.62	2025-03-20 12:26:38.311732
585	2022-09-01	1923.00	2656.75	2025-03-20 12:26:38.311732
586	2022-10-01	1663.75	2640.37	2025-03-20 12:26:38.311732
587	2022-11-01	1397.15	2637.31	2025-03-20 12:26:38.311732
588	2022-12-01	1107.50	2619.72	2025-03-20 12:26:38.311732
589	2023-01-01	1029.80	2627.46	2025-03-20 12:26:38.311732
590	2023-02-01	946.68	2613.53	2025-03-20 12:26:38.311732
591	2023-03-01	923.78	2590.85	2025-03-20 12:26:38.311732
592	2023-04-01	999.73	2596.26	2025-03-20 12:26:38.311732
593	2023-05-01	983.46	2586.56	2025-03-20 12:26:38.311732
594	2023-06-01	953.60	2583.17	2025-03-20 12:26:38.311732
595	2023-07-01	1029.20	2568.65	2025-03-20 12:26:38.311732
596	2023-08-01	1013.80	2565.52	2025-03-20 12:26:38.311732
597	2023-09-01	886.85	2548.18	2025-03-20 12:26:38.311732
598	2023-10-01	1012.60	2550.05	2025-03-20 12:26:38.311732
599	2023-11-01	993.21	2552.08	2025-03-20 12:26:38.311732
600	2023-12-01	1759.60	2560.14	2025-03-20 12:26:38.311732
601	2024-01-01	2179.10	2549.53	2025-03-20 12:26:38.311732
602	2024-02-01	2109.90	2540.68	2025-03-20 12:26:38.311732
603	2024-03-01	1731.00	2547.39	2025-03-20 12:26:38.311732
604	2024-04-01	1940.60	2540.82	2025-03-20 12:26:38.311732
605	2024-05-01	3044.80	2545.24	2025-03-20 12:26:38.311732
606	2024-06-01	3714.30	2550.43	2025-03-20 12:26:38.311732
607	2024-07-01	3447.90	2559.88	2025-03-20 12:26:38.311732
608	2024-08-01	2963.40	2552.16	2025-03-20 12:26:38.311732
609	2024-09-01	2135.10	2550.68	2025-03-20 12:26:38.311732
610	2024-10-01	2141.59	2560.32	2025-03-20 12:26:38.311732
611	2024-11-01	2232.20	2567.48	2025-03-20 12:26:38.311732
612	2024-12-01	2460.30	2590.06	2025-03-20 12:26:38.311732
\.


--
-- Data for Name: shipping_container_raw; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shipping_container_raw (id, container_id, ship_date, delivery_date, producer, producer_type, container_type, container_qty, origin, destination, freight_index, base_price, priority, status, import_date) FROM stdin;
1105	CS17_001	2017-01-15	2017-01-20	ShipEasy	Forwarder	40 ft HC CW	3.0	Shanghai	Los Angeles	921.96	1372.06	HIGH	in_transit	2025-03-20 12:26:38.311732
1106	CS17_002	2017-01-16	2017-01-22	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	976.38	1453.05	Medium	delivered	2025-03-20 12:26:38.311732
1107	CS17_003	2017-01-16	2017-01-25	Ocean Wave	Broker	40 ft HC CW	5.0	Dubai	Hamburg	964.47	1435.34	Low	completed	2025-03-20 12:26:38.311732
1108	CS17_004	2017-02-12	2017-02-17	Cargo Masters	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	798.80	1501.24	HIGH	processing	2025-03-20 12:26:38.311732
1109	CS17_005	2017-02-15	2017-02-20	Sea Transit	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	831.40	1518.74	Medium	delivered	2025-03-20 12:26:38.311732
1110	CS17_006	2017-03-10	2017-03-15	ShipEasy	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	815.42	1723.88	Low	completed	2025-03-20 12:26:38.311732
1111	CS17_007	2017-03-15	2017-03-20	Global Shipping	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	844.62	1806.48	HIGH	in_transit	2025-03-20 12:26:38.311732
1112	CS17_008	2017-04-05	2017-04-10	Ocean Wave	Broker	40 ft HC CW	4.0	Rotterdam	Singapore	927.44	1930.78	Medium	in_transit	2025-03-20 12:26:38.311732
1113	CS17_009	2017-04-12	2017-04-17	Cargo Masters	Agent	40 ft HC CW	6.0	Dubai	Hamburg	891.06	1855.06	Low	processing	2025-03-20 12:26:38.311732
1114	CS17_010	2017-05-05	2017-05-10	Sea Transit	Direct	40 ft HC CW	5.0	Shanghai	Los Angeles	836.36	1816.44	HIGH	completed	2025-03-20 12:26:38.311732
1115	CS17_011	2017-05-15	2017-05-20	ShipEasy	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	870.50	1890.58	Medium	in_transit	2025-03-20 12:26:38.311732
1116	CS17_012	2017-05-25	2017-05-30	Global Shipping	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	853.43	1853.51	Low	delivered	2025-03-20 12:26:38.311732
1117	CS17_013	2017-06-08	2017-06-13	Ocean Wave	Forwarder	40 ft HC CW	4.0	Shanghai	Los Angeles	900.45	1801.35	HIGH	completed	2025-03-20 12:26:38.311732
1118	CS17_014	2017-06-18	2017-06-23	Cargo Masters	Broker	40 ft HC CW	2.0	Rotterdam	Singapore	937.21	1874.87	Medium	processing	2025-03-20 12:26:38.311732
1119	CS17_015	2017-07-15	2017-07-20	Sea Transit	Agent	40 ft HC CW	4.0	Dubai	Hamburg	907.94	1908.93	Low	delivered	2025-03-20 12:26:38.311732
1120	CS17_016	2017-07-25	2017-07-30	ShipEasy	Direct	40 ft HC CW	5.0	Shanghai	Los Angeles	942.96	1986.85	Medium	completed	2025-03-20 12:26:38.311732
1121	CS17_017	2017-08-08	2017-08-13	Global Shipping	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	701.65	2029.38	HIGH	in_transit	2025-03-20 12:26:38.311732
1122	CS17_018	2017-08-18	2017-08-23	Ocean Wave	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	730.29	2112.22	Low	in_transit	2025-03-20 12:26:38.311732
1123	CS17_019	2017-09-05	2017-09-10	Cargo Masters	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	790.67	2336.18	Medium	processing	2025-03-20 12:26:38.311732
1124	CS17_020	2017-09-15	2017-09-20	Sea Transit	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	822.95	2433.58	HIGH	completed	2025-03-20 12:26:38.311732
1125	CS17_021	2017-10-18	2017-10-23	ShipEasy	Direct	40 ft HC CW	5.0	Dubai	Hamburg	691.09	2109.59	Low	in_transit	2025-03-20 12:26:38.311732
1126	CS17_022	2017-10-28	2017-11-02	Global Shipping	Carrier	40 ft HC CW	4.0	Shanghai	Los Angeles	719.29	2195.69	Medium	delivered	2025-03-20 12:26:38.311732
1127	CS17_023	2017-11-05	2017-11-10	Ocean Wave	Partner	40 ft HC CW	4.0	Rotterdam	Singapore	807.70	2129.72	HIGH	completed	2025-03-20 12:26:38.311732
1128	CS17_024	2017-11-15	2017-11-20	Cargo Masters	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	840.66	2216.64	Low	processing	2025-03-20 12:26:38.311732
1129	CS17_025	2017-12-08	2017-12-13	Sea Transit	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	807.70	2407.62	Medium	delivered	2025-03-20 12:26:38.311732
1130	CS17_026	2017-12-18	2017-12-23	ShipEasy	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	840.66	2505.89	HIGH	completed	2025-03-20 12:26:38.311732
1131	CS18_001	2018-01-12	2018-01-17	Global Shipping	Direct	40 ft HC CW	4.0	Dubai	Hamburg	841.43	2420.84	Low	in_transit	2025-03-20 12:26:38.311732
1132	CS18_002	2018-01-22	2018-01-27	Ocean Wave	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	875.77	2420.84	Medium	in_transit	2025-03-20 12:26:38.311732
1133	CS18_003	2018-02-05	2018-02-10	Cargo Masters	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	837.11	2335.61	HIGH	processing	2025-03-20 12:26:38.311732
1134	CS18_004	2018-02-15	2018-02-20	Sea Transit	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	871.27	2335.61	Low	completed	2025-03-20 12:26:38.311732
1135	CS18_005	2018-02-28	2018-03-05	ShipEasy	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	854.19	2335.61	HIGH	processing	2025-03-20 12:26:38.311732
1136	CS18_006	2018-03-03	2018-03-08	ShipEasy	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	645.51	2331.98	Medium	in_transit	2025-03-20 12:26:38.311732
1137	CS18_007	2018-03-13	2018-03-18	Global Shipping	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	671.85	2331.98	HIGH	delivered	2025-03-20 12:26:38.311732
1138	CS18_008	2018-04-24	2018-04-29	Ocean Wave	Direct	40 ft HC CW	1.0	Dubai	Hamburg	745.46	2392.02	Low	completed	2025-03-20 12:26:38.311732
1139	CS18_009	2018-04-12	2018-04-17	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	775.88	2392.02	HIGH	in_transit	2025-03-20 12:26:38.311732
1140	CS18_010	2018-04-25	2018-04-30	Ocean Wave	Broker	40 ft HC CW	5.0	Dubai	Hamburg	760.67	2392.02	Medium	processing	2025-03-20 12:26:38.311732
1141	CS18_011	2018-05-04	2018-05-09	Cargo Masters	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	749.05	2444.68	Medium	processing	2025-03-20 12:26:38.311732
1142	CS18_012	2018-05-14	2018-05-19	Sea Transit	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	779.63	2444.68	HIGH	delivered	2025-03-20 12:26:38.311732
1143	CS18_013	2018-06-25	2018-06-30	ShipEasy	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	804.75	2534.68	Low	completed	2025-03-20 12:26:38.311732
1144	CS18_014	2018-06-18	2018-06-23	Cargo Masters	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	837.61	2534.68	Medium	in_transit	2025-03-20 12:26:38.311732
1145	CS18_015	2018-06-28	2018-07-03	Sea Transit	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	821.18	2534.68	HIGH	processing	2025-03-20 12:26:38.311732
1146	CS18_016	2018-07-05	2018-07-10	Global Shipping	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	851.22	2306.63	Medium	in_transit	2025-03-20 12:26:38.311732
1147	CS18_017	2018-07-15	2018-07-20	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	885.96	2306.63	HIGH	in_transit	2025-03-20 12:26:38.311732
1148	CS18_018	2018-08-08	2018-08-13	Cargo Masters	Direct	40 ft HC CW	3.0	Dubai	Hamburg	920.69	2223.22	Low	processing	2025-03-20 12:26:38.311732
1149	CS18_019	2018-08-18	2018-08-23	Sea Transit	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	958.27	2223.22	Medium	completed	2025-03-20 12:26:38.311732
1150	CS18_020	2018-08-28	2018-09-02	ShipEasy	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	939.48	2223.22	HIGH	processing	2025-03-20 12:26:38.311732
1151	CS18_021	2018-09-28	2018-09-03	ShipEasy	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	853.17	2271.45	HIGH	in_transit	2025-03-20 12:26:38.311732
1152	CS18_022	2018-09-15	2018-09-20	Global Shipping	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	887.99	2271.45	HIGH	in_transit	2025-03-20 12:26:38.311732
1153	CS18_023	2018-10-08	2018-10-13	Global Shipping	Forwarder	40 ft HC CW	1.0	Dubai	Hamburg	937.50	2397.73	Low	delivered	2025-03-20 12:26:38.311732
1154	CS18_024	2018-10-18	2018-10-23	Ocean Wave	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	975.76	2397.73	Medium	completed	2025-03-20 12:26:38.311732
1155	CS18_025	2018-11-28	2018-11-03	Cargo Masters	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	872.60	2394.04	HIGH	processing	2025-03-20 12:26:38.311732
1156	CS18_026	2018-11-08	2018-11-13	Sea Transit	Direct	40 ft HC CW	5.0	Dubai	Hamburg	908.22	2394.04	Low	delivered	2025-03-20 12:26:38.311732
1157	CS18_027	2018-12-18	2018-12-23	ShipEasy	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	892.59	2545.57	Medium	completed	2025-03-20 12:26:38.311732
1158	CS18_028	2018-12-18	2018-12-23	Global Shipping	Partner	40 ft HC CW	3.0	Dubai	Hamburg	929.03	2545.57	Medium	completed	2025-03-20 12:26:38.311732
1159	CS18_029	2018-12-28	2019-01-02	Ocean Wave	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	910.81	2545.57	Medium	processing	2025-03-20 12:26:38.311732
1160	CS19_001	2019-01-10	2019-01-15	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	926.53	2442.95	HIGH	in_transit	2025-03-20 12:26:38.311732
1161	CS19_002	2019-01-20	2019-01-25	Ocean Wave	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	964.35	2442.95	Low	in_transit	2025-03-20 12:26:38.311732
1162	CS19_003	2019-02-05	2019-02-10	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	830.80	2355.88	Medium	processing	2025-03-20 12:26:38.311732
1163	CS19_004	2019-02-15	2019-02-20	Sea Transit	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	864.70	2355.88	HIGH	completed	2025-03-20 12:26:38.311732
1164	CS19_005	2019-03-05	2019-03-10	ShipEasy	Direct	40 ft HC CW	3.0	Dubai	Hamburg	777.62	2307.86	Low	in_transit	2025-03-20 12:26:38.311732
1165	CS19_006	2019-03-15	2019-03-20	Global Shipping	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	809.36	2307.86	Medium	delivered	2025-03-20 12:26:38.311732
1166	CS19_007	2019-03-25	2019-03-30	Cargo Masters	Broker	40 ft HC CW	5.0	Dubai	Hamburg	793.49	2307.86	Medium	delivered	2025-03-20 12:26:38.311732
1167	CS19_008	2019-04-08	2019-04-13	Ocean Wave	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	762.44	2315.46	HIGH	completed	2025-03-20 12:26:38.311732
1168	CS19_009	2019-04-18	2019-04-23	Cargo Masters	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	793.56	2315.46	Low	processing	2025-03-20 12:26:38.311732
1169	CS19_010	2019-05-05	2019-05-10	Sea Transit	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	766.68	2411.14	Medium	delivered	2025-03-20 12:26:38.311732
1170	CS19_011	2019-05-15	2019-05-20	ShipEasy	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	797.56	2411.14	Medium	completed	2025-03-20 12:26:38.311732
1171	CS19_012	2019-06-28	2019-06-03	Global Shipping	Direct	40 ft HC CW	3.0	Dubai	Hamburg	813.11	2143.90	HIGH	in_transit	2025-03-20 12:26:38.311732
1172	CS19_013	2019-06-08	2019-06-13	Ocean Wave	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	846.29	2143.90	Low	in_transit	2025-03-20 12:26:38.311732
1173	CS19_014	2019-07-18	2019-07-23	Cargo Masters	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	773.04	2247.81	Medium	processing	2025-03-20 12:26:38.311732
1174	CS19_015	2019-07-28	2019-08-02	Sea Transit	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	804.82	2247.81	HIGH	completed	2025-03-20 12:26:38.311732
1175	CS19_016	2019-08-08	2019-08-13	ShipEasy	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	803.26	2168.15	Low	in_transit	2025-03-20 12:26:38.311732
1176	CS19_017	2019-08-18	2019-08-23	Global Shipping	Agent	40 ft HC CW	5.0	Rotterdam	Singapore	836.04	2168.15	Medium	delivered	2025-03-20 12:26:38.311732
1177	CS19_018	2019-09-15	2019-09-20	Ocean Wave	Direct	40 ft HC CW	2.0	Dubai	Hamburg	708.44	2114.81	HIGH	completed	2025-03-20 12:26:38.311732
1178	CS19_019	2019-09-25	2019-09-30	Cargo Masters	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	737.36	2114.81	Low	processing	2025-03-20 12:26:38.311732
1179	CS19_020	2019-10-05	2019-10-10	Sea Transit	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	691.59	2042.28	Medium	delivered	2025-03-20 12:26:38.311732
1180	CS19_021	2019-10-15	2019-10-20	ShipEasy	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	718.97	2042.28	HIGH	completed	2025-03-20 12:26:38.311732
1181	CS19_022	2019-11-05	2019-11-10	Sea Transit	Agent	40 ft HC CW	3.0	Dubai	Hamburg	805.82	1990.81	Medium	in_transit	2025-03-20 12:26:38.311732
1182	CS19_023	2019-11-15	2019-11-20	ShipEasy	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	833.44	1990.81	HIGH	delivered	2025-03-20 12:26:38.311732
1183	CS19_024	2019-12-08	2019-12-13	Global Shipping	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	939.40	1976.95	HIGH	in_transit	2025-03-20 12:26:38.311732
1184	CS19_025	2019-12-18	2019-12-23	Ocean Wave	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	977.74	1976.95	Medium	completed	2025-03-20 12:26:38.311732
1185	CS20_001	2020-01-08	2020-01-13	Global Shipping	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	961.57	1735.97	Low	in_transit	2025-03-20 12:26:38.311732
1186	CS20_002	2020-01-18	2020-01-23	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1000.81	1735.97	Medium	in_transit	2025-03-20 12:26:38.311732
1187	CS20_003	2020-02-05	2020-02-10	Cargo Masters	Direct	40 ft HC CW	2.0	Dubai	Hamburg	858.24	1898.27	HIGH	processing	2025-03-20 12:26:38.311732
1188	CS20_004	2020-02-15	2020-02-20	Sea Transit	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	893.28	1898.27	Low	completed	2025-03-20 12:26:38.311732
1189	CS20_005	2020-03-08	2020-03-13	ShipEasy	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	871.40	2074.10	Medium	in_transit	2025-03-20 12:26:38.311732
1190	CS20_006	2020-03-18	2020-03-23	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	906.96	2074.10	HIGH	delivered	2025-03-20 12:26:38.311732
1191	CS20_007	2020-04-08	2020-04-13	Ocean Wave	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	835.22	1973.70	Low	completed	2025-03-20 12:26:38.311732
1192	CS20_008	2020-04-18	2020-04-23	Cargo Masters	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	869.32	1973.70	Medium	processing	2025-03-20 12:26:38.311732
1193	CS20_009	2020-05-08	2020-05-13	Sea Transit	Direct	40 ft HC CW	4.0	Dubai	Hamburg	902.17	2037.92	HIGH	delivered	2025-03-20 12:26:38.311732
1194	CS20_010	2020-05-18	2020-05-23	ShipEasy	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	938.59	2037.92	Low	completed	2025-03-20 12:26:38.311732
1195	CS20_011	2020-06-08	2020-06-13	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	981.27	2065.78	Medium	in_transit	2025-03-20 12:26:38.311732
1196	CS20_012	2020-06-18	2020-06-23	Ocean Wave	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	1021.33	2065.78	HIGH	in_transit	2025-03-20 12:26:38.311732
1197	CS20_013	2020-07-08	2020-07-13	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	1081.43	1973.78	Low	processing	2025-03-20 12:26:38.311732
1198	CS20_014	2020-07-18	2020-07-23	Sea Transit	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	1125.57	1973.78	Medium	completed	2025-03-20 12:26:38.311732
1199	CS20_015	2020-08-08	2020-08-13	ShipEasy	Direct	40 ft HC CW	1.0	Dubai	Hamburg	1238.03	2387.25	HIGH	in_transit	2025-03-20 12:26:38.311732
1200	CS20_016	2020-08-18	2020-08-23	Global Shipping	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	1288.57	2387.25	Low	delivered	2025-03-20 12:26:38.311732
1201	CS20_017	2020-09-08	2020-09-13	Ocean Wave	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	1414.14	2312.53	Medium	completed	2025-03-20 12:26:38.311732
1202	CS20_018	2020-09-18	2020-09-23	Cargo Masters	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	1471.86	2312.53	HIGH	processing	2025-03-20 12:26:38.311732
1203	CS20_019	2020-10-08	2020-10-13	Sea Transit	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	1499.40	2314.33	Low	delivered	2025-03-20 12:26:38.311732
1204	CS20_020	2020-10-18	2020-10-23	ShipEasy	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	1560.60	2314.33	Medium	completed	2025-03-20 12:26:38.311732
1205	CS20_021	2020-11-05	2020-11-10	Cargo Masters	Forwarder	40 ft HC CW	5.0	Rotterdam	Singapore	2007.33	2473.81	Medium	in_transit	2025-03-20 12:26:38.311732
1206	CS20_022	2020-11-15	2020-11-20	Sea Transit	Broker	40 ft HC CW	2.0	Dubai	Hamburg	2089.27	2473.81	HIGH	delivered	2025-03-20 12:26:38.311732
1207	CS20_023	2020-12-08	2020-12-13	ShipEasy	Agent	40 ft HC CW	3.0	Shanghai	Los Angeles	2589.06	3008.21	HIGH	in_transit	2025-03-20 12:26:38.311732
1208	CS20_024	2020-12-18	2020-12-23	Global Shipping	Direct	40 ft HC CW	4.0	Rotterdam	Singapore	2694.74	3008.21	Medium	completed	2025-03-20 12:26:38.311732
1209	CS21_001	2021-01-10	2021-01-15	Global Shipping	Direct	40 ft HC CW	4.0	Dubai	Hamburg	2804.47	4071.73	HIGH	in_transit	2025-03-20 12:26:38.311732
1210	CS21_002	2021-01-20	2021-01-25	Ocean Wave	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	2918.93	4071.73	Low	in_transit	2025-03-20 12:26:38.311732
1211	CS21_003	2021-02-05	2021-02-10	Cargo Masters	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	2719.79	3935.67	Medium	processing	2025-03-20 12:26:38.311732
1212	CS21_004	2021-02-15	2021-02-20	Sea Transit	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	2830.81	3935.67	HIGH	completed	2025-03-20 12:26:38.311732
1213	CS21_005	2021-03-05	2021-03-10	ShipEasy	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	2519.29	4307.26	Low	in_transit	2025-03-20 12:26:38.311732
1214	CS21_006	2021-03-15	2021-03-20	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	2622.11	4307.26	Medium	delivered	2025-03-20 12:26:38.311732
1215	CS21_007	2021-04-08	2021-04-13	Ocean Wave	Direct	40 ft HC CW	3.0	Dubai	Hamburg	3038.69	4560.04	HIGH	completed	2025-03-20 12:26:38.311732
1216	CS21_008	2021-04-18	2021-04-23	Cargo Masters	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	3162.71	4560.04	Low	processing	2025-03-20 12:26:38.311732
1217	CS21_009	2021-05-05	2021-05-10	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	3425.88	5142.27	Medium	delivered	2025-03-20 12:26:38.311732
1218	CS21_010	2021-05-15	2021-05-20	ShipEasy	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	3565.72	5142.27	HIGH	completed	2025-03-20 12:26:38.311732
1219	CS21_011	2021-06-08	2021-06-13	Global Shipping	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	3709.69	6615.43	Low	in_transit	2025-03-20 12:26:38.311732
1220	CS21_012	2021-06-18	2021-06-23	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	3861.11	6615.43	Medium	in_transit	2025-03-20 12:26:38.311732
1221	CS21_013	2021-07-08	2021-07-13	Cargo Masters	Direct	40 ft HC CW	5.0	Dubai	Hamburg	4112.27	4735.52	HIGH	processing	2025-03-20 12:26:38.311732
1222	CS21_014	2021-07-18	2021-07-23	Sea Transit	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	4280.13	4735.52	Low	completed	2025-03-20 12:26:38.311732
1223	CS21_015	2021-08-08	2021-08-13	ShipEasy	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	4297.89	4915.50	Medium	in_transit	2025-03-20 12:26:38.311732
1224	CS21_016	2021-08-18	2021-08-23	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	4473.31	4915.50	HIGH	delivered	2025-03-20 12:26:38.311732
1225	CS21_017	2021-09-08	2021-09-13	Ocean Wave	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	4550.92	4209.95	Low	completed	2025-03-20 12:26:38.311732
1226	CS21_018	2021-09-18	2021-09-23	Cargo Masters	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	4736.68	4209.95	Medium	processing	2025-03-20 12:26:38.311732
1227	CS21_019	2021-10-08	2021-10-13	Sea Transit	Direct	40 ft HC CW	3.0	Dubai	Hamburg	4475.95	4720.62	HIGH	delivered	2025-03-20 12:26:38.311732
1228	CS21_020	2021-10-18	2021-10-23	ShipEasy	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	4658.65	4720.62	Low	completed	2025-03-20 12:26:38.311732
1229	CS21_021	2021-11-05	2021-11-10	Ocean Wave	Partner	40 ft HC CW	2.0	Rotterdam	Singapore	4509.96	4284.20	Medium	in_transit	2025-03-20 12:26:38.311732
1230	CS21_022	2021-11-15	2021-11-20	Cargo Masters	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	4694.04	4284.20	HIGH	delivered	2025-03-20 12:26:38.311732
1231	CS21_023	2021-12-08	2021-12-13	Sea Transit	Forwarder	40 ft HC CW	1.0	Shanghai	Los Angeles	4945.77	3533.33	HIGH	in_transit	2025-03-20 12:26:38.311732
1232	CS21_024	2021-12-18	2021-12-23	ShipEasy	Broker	40 ft HC CW	3.0	Rotterdam	Singapore	5147.63	3533.33	Medium	completed	2025-03-20 12:26:38.311732
1233	CS22_001	2022-01-06	2022-01-11	Global Shipping	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	4910.19	3423.21	Medium	in_transit	2025-03-20 12:26:38.311732
1234	CS22_002	2022-01-16	2022-01-21	Ocean Wave	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	5110.61	3423.21	HIGH	in_transit	2025-03-20 12:26:38.311732
1235	CS22_003	2022-02-04	2022-02-09	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	4722.13	3284.18	Low	processing	2025-03-20 12:26:38.311732
1236	CS22_004	2022-02-14	2022-02-19	Sea Transit	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	4914.87	3284.18	Medium	completed	2025-03-20 12:26:38.311732
1237	CS22_005	2022-03-04	2022-03-09	ShipEasy	Direct	40 ft HC CW	4.0	Dubai	Hamburg	4345.42	3508.14	HIGH	in_transit	2025-03-20 12:26:38.311732
1238	CS22_006	2022-03-14	2022-03-19	Global Shipping	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	4522.78	3508.14	Low	delivered	2025-03-20 12:26:38.311732
1239	CS22_007	2022-04-07	2022-04-12	Ocean Wave	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	4093.75	3445.58	Medium	completed	2025-03-20 12:26:38.311732
1240	CS22_008	2022-04-17	2022-04-22	Cargo Masters	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	4260.85	3445.58	HIGH	processing	2025-03-20 12:26:38.311732
1241	CS22_009	2022-05-05	2022-05-10	Sea Transit	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	4091.89	3388.88	Low	delivered	2025-03-20 12:26:38.311732
1242	CS22_010	2022-05-15	2022-05-20	ShipEasy	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	4258.91	3388.88	Medium	completed	2025-03-20 12:26:38.311732
1243	CS22_011	2022-06-05	2022-06-10	Global Shipping	Direct	40 ft HC CW	5.0	Dubai	Hamburg	4131.78	3375.52	HIGH	in_transit	2025-03-20 12:26:38.311732
1244	CS22_012	2022-06-15	2022-06-20	Ocean Wave	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	4300.42	3375.52	Low	in_transit	2025-03-20 12:26:38.311732
1245	CS22_013	2022-07-07	2022-07-12	Cargo Masters	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	3810.04	3278.26	Medium	processing	2025-03-20 12:26:38.311732
1246	CS22_014	2022-07-17	2022-07-22	Sea Transit	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	3965.56	3278.26	HIGH	completed	2025-03-20 12:26:38.311732
1247	CS22_015	2022-08-05	2022-08-10	ShipEasy	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	3091.21	3168.62	Low	in_transit	2025-03-20 12:26:38.311732
1248	CS22_016	2022-08-15	2022-08-20	Global Shipping	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	3217.39	3168.62	Medium	delivered	2025-03-20 12:26:38.311732
1249	CS22_017	2022-09-05	2022-09-10	Ocean Wave	Direct	40 ft HC CW	5.0	Dubai	Hamburg	1884.54	2656.75	HIGH	completed	2025-03-20 12:26:38.311732
1250	CS22_018	2022-09-15	2022-09-20	Cargo Masters	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	1961.46	2656.75	Low	processing	2025-03-20 12:26:38.311732
1251	CS22_019	2022-10-08	2022-10-13	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	1663.75	2640.37	Medium	delivered	2025-03-20 12:26:38.311732
1252	CS22_020	2022-11-18	2022-10-23	ShipEasy	Forwarder	40 ft HC CW	1.0	Dubai	Hamburg	1731.65	2640.37	HIGH	completed	2025-03-20 12:26:38.311732
1253	CS22_021	2022-11-05	2022-11-10	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1205.30	2635.78	Medium	in_transit	2025-03-20 12:26:38.311732
1254	CS22_022	2022-11-15	2022-11-20	Ocean Wave	Direct	40 ft HC CW	2.0	Dubai	Hamburg	1254.50	2635.78	HIGH	delivered	2025-03-20 12:26:38.311732
1255	CS22_023	2022-12-08	2022-12-13	Cargo Masters	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	1085.35	2619.72	HIGH	in_transit	2025-03-20 12:26:38.311732
1256	CS22_024	2022-12-18	2022-12-23	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	1129.65	2619.72	Medium	completed	2025-03-20 12:26:38.311732
1257	CS23_001	2023-01-06	2023-01-11	Global Shipping	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	1009.20	2627.46	Low	in_transit	2025-03-20 12:26:38.311732
1258	CS23_002	2023-01-16	2023-01-21	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1050.40	2627.46	Medium	in_transit	2025-03-20 12:26:38.311732
1259	CS23_003	2023-02-05	2023-02-10	Cargo Masters	Direct	40 ft HC CW	2.0	Dubai	Hamburg	927.75	2613.53	HIGH	processing	2025-03-20 12:26:38.311732
1260	CS23_004	2023-02-15	2023-02-20	Sea Transit	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	965.61	2613.53	Low	completed	2025-03-20 12:26:38.311732
1261	CS23_005	2023-03-05	2023-03-10	ShipEasy	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	905.30	2590.85	Medium	in_transit	2025-03-20 12:26:38.311732
1262	CS23_006	2023-03-15	2023-03-20	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	942.26	2590.85	HIGH	delivered	2025-03-20 12:26:38.311732
1263	CS23_007	2023-04-06	2023-04-11	Ocean Wave	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	979.74	2596.26	Low	completed	2025-03-20 12:26:38.311732
1264	CS23_008	2023-04-16	2023-04-21	Cargo Masters	Agent	40 ft HC CW	6.0	Rotterdam	Singapore	1019.72	2596.26	Medium	processing	2025-03-20 12:26:38.311732
1265	CS23_009	2023-05-06	2023-05-11	Sea Transit	Direct	40 ft HC CW	5.0	Dubai	Hamburg	963.79	2586.56	HIGH	delivered	2025-03-20 12:26:38.311732
1266	CS23_010	2023-05-16	2023-05-21	ShipEasy	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	1003.13	2586.56	Low	completed	2025-03-20 12:26:38.311732
1267	CS23_011	2023-06-06	2023-06-11	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	934.53	2583.17	Medium	in_transit	2025-03-20 12:26:38.311732
1268	CS23_012	2023-06-16	2023-06-21	Ocean Wave	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	972.67	2583.17	HIGH	in_transit	2025-03-20 12:26:38.311732
1269	CS23_013	2023-07-06	2023-07-11	Cargo Masters	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	1008.62	2568.65	Low	processing	2025-03-20 12:26:38.311732
1270	CS23_014	2023-07-16	2023-07-21	Sea Transit	Agent	40 ft HC CW	5.0	Rotterdam	Singapore	1049.78	2568.65	Medium	completed	2025-03-20 12:26:38.311732
1271	CS23_015	2023-08-06	2023-08-11	ShipEasy	Direct	40 ft HC CW	3.0	Dubai	Hamburg	993.52	2565.52	HIGH	in_transit	2025-03-20 12:26:38.311732
1272	CS23_016	2023-08-16	2023-08-21	Global Shipping	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	1034.08	2565.52	Low	delivered	2025-03-20 12:26:38.311732
1273	CS23_017	2023-09-06	2023-09-11	Ocean Wave	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	869.11	2548.18	Medium	completed	2025-03-20 12:26:38.311732
1274	CS23_018	2023-09-16	2023-09-21	Cargo Masters	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	904.59	2548.18	HIGH	processing	2025-03-20 12:26:38.311732
1275	CS23_019	2023-10-07	2023-10-12	Sea Transit	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	992.35	2550.05	Low	delivered	2025-03-20 12:26:38.311732
1276	CS23_020	2023-10-17	2023-10-22	ShipEasy	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1032.85	2550.05	Medium	completed	2025-03-20 12:26:38.311732
1277	CS23_021	2023-11-05	2023-11-10	ShipEasy	Forwarder	40 ft HC CW	4.0	Rotterdam	Singapore	973.35	2552.08	Medium	in_transit	2025-03-20 12:26:38.311732
1278	CS23_022	2023-11-15	2023-11-20	Global Shipping	Broker	40 ft HC CW	3.0	Dubai	Hamburg	1013.07	2552.08	HIGH	delivered	2025-03-20 12:26:38.311732
1279	CS23_023	2023-12-08	2023-12-13	Ocean Wave	Agent	40 ft HC CW	3.0	Shanghai	Los Angeles	1724.41	2560.14	HIGH	in_transit	2025-03-20 12:26:38.311732
1280	CS23_024	2023-12-18	2023-12-23	Cargo Masters	Direct	40 ft HC CW	4.0	Rotterdam	Singapore	1794.79	2560.14	Medium	completed	2025-03-20 12:26:38.311732
1281	CS24_001	2024-01-05	2024-01-10	Global Shipping	Direct	40 ft HC CW	4.0	Dubai	Hamburg	2135.52	2549.53	HIGH	in_transit	2025-03-20 12:26:38.311732
1282	CS24_002	2024-01-15	2024-01-20	Ocean Wave	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	2222.68	2549.53	Low	in_transit	2025-03-20 12:26:38.311732
1283	CS24_003	2024-02-04	2024-02-09	Cargo Masters	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	2067.70	2540.68	Medium	processing	2025-03-20 12:26:38.311732
1284	CS24_004	2024-02-14	2024-02-19	Sea Transit	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	2152.10	2540.68	HIGH	completed	2025-03-20 12:26:38.311732
1285	CS24_005	2024-03-04	2024-03-09	ShipEasy	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	1696.38	2547.39	Low	in_transit	2025-03-20 12:26:38.311732
1286	CS24_006	2024-03-14	2024-03-19	Global Shipping	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	1765.62	2547.39	Medium	delivered	2025-03-20 12:26:38.311732
1287	CS24_007	2024-04-05	2024-04-10	Ocean Wave	Direct	40 ft HC CW	4.0	Dubai	Hamburg	1901.79	2540.82	HIGH	completed	2025-03-20 12:26:38.311732
1288	CS24_008	2024-04-15	2024-04-20	Cargo Masters	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	1979.41	2540.82	Low	processing	2025-03-20 12:26:38.311732
1289	CS24_009	2024-05-05	2024-05-10	Sea Transit	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	2983.90	2545.24	Medium	delivered	2025-03-20 12:26:38.311732
1290	CS24_010	2024-05-15	2024-05-20	ShipEasy	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	3105.70	2545.24	HIGH	completed	2025-03-20 12:26:38.311732
1291	CS24_011	2024-06-05	2024-06-10	Global Shipping	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	3640.01	2550.43	Low	in_transit	2025-03-20 12:26:38.311732
1292	CS24_012	2024-06-15	2024-06-20	Ocean Wave	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	3788.59	2550.43	Medium	in_transit	2025-03-20 12:26:38.311732
1293	CS24_013	2024-07-05	2024-07-10	Cargo Masters	Direct	40 ft HC CW	1.0	Dubai	Hamburg	3378.94	2559.88	HIGH	processing	2025-03-20 12:26:38.311732
1294	CS24_014	2024-07-15	2024-07-20	Sea Transit	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	3516.86	2559.88	Low	completed	2025-03-20 12:26:38.311732
1295	CS24_015	2024-08-05	2024-08-10	ShipEasy	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	2904.13	2552.16	Medium	in_transit	2025-03-20 12:26:38.311732
1296	CS24_016	2024-08-15	2024-08-20	Global Shipping	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	3022.67	2552.16	HIGH	delivered	2025-03-20 12:26:38.311732
1297	CS24_017	2024-09-05	2024-09-10	Ocean Wave	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	2092.40	2550.68	Low	completed	2025-03-20 12:26:38.311732
1298	CS24_018	2024-09-15	2024-09-20	Cargo Masters	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	2177.80	2550.68	Medium	processing	2025-03-20 12:26:38.311732
1299	CS24_019	2024-10-06	2024-10-11	Sea Transit	Direct	40 ft HC CW	3.0	Dubai	Hamburg	2141.59	2560.32	HIGH	delivered	2025-03-20 12:26:38.311732
1300	CS24_020	2024-11-16	2024-10-21	ShipEasy	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	2229.01	2560.32	Low	completed	2025-03-20 12:26:38.311732
1301	CS24_021	2024-11-05	2024-11-10	Sea Transit	Partner	40 ft HC CW	5.0	Rotterdam	Singapore	2189.12	2571.06	Medium	ordered	2025-03-20 12:26:38.311732
1302	CS24_022	2024-11-15	2024-11-20	ShipEasy	Carrier	40 ft HC CW	2.0	Dubai	Hamburg	2278.48	2571.06	HIGH	processing	2025-03-20 12:26:38.311732
1303	CS24_023	2024-12-08	2024-12-13	Global Shipping	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	2411.09	2590.06	HIGH	ordered	2025-03-20 12:26:38.311732
1304	CS24_024	2024-12-18	2024-12-23	Ocean Wave	Broker	40 ft HC CW	3.0	Rotterdam	Singapore	2509.51	2590.06	Medium	processing	2025-03-20 12:26:38.311732
\.


--
-- Data for Name: total_cost_comparison; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.total_cost_comparison (id, model_name, total_cost, citation) FROM stdin;
17	Traditional Housing	708000.00	2024 contractor rates: ₱29,500/sqm average for 24 sqm
18	ODD Cubes Basic	420000.00	ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)
19	Container (Base)	323343.00	Base estimate with modifications
20	Container (Max)	580005.00	Premium estimate with modifications
21	Traditional Housing	708000.00	2024 contractor rates: ₱29,500/sqm average for 24 sqm
22	ODD Cubes Basic	420000.00	ODD Cubes Inc. base unit (₱360,000) + fenestration (₱60,000)
23	Container (Base)	323343.00	Base estimate with modifications
24	Container (Max)	580005.00	Premium estimate with modifications
\.


--
-- Name: container_price_forecast_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.container_price_forecast_id_seq', 24, true);


--
-- Name: container_prices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.container_prices_id_seq', 1, false);


--
-- Name: container_prices_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.container_prices_raw_id_seq', 1, false);


--
-- Name: cost_breakdown_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cost_breakdown_id_seq', 16, true);


--
-- Name: cost_breakdownconcmod_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cost_breakdownconcmod_id_seq', 12, true);


--
-- Name: cost_per_sqm_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cost_per_sqm_id_seq', 24, true);


--
-- Name: efficiency_metrics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.efficiency_metrics_id_seq', 12, true);


--
-- Name: housing_models_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.housing_models_id_seq', 4, true);


--
-- Name: resource_usage_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.resource_usage_id_seq', 8, true);


--
-- Name: shipping_container_prices_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shipping_container_prices_id_seq', 612, true);


--
-- Name: shipping_container_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shipping_container_raw_id_seq', 1304, true);


--
-- Name: total_cost_comparison_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.total_cost_comparison_id_seq', 24, true);


--
-- Name: container_price_forecast container_price_forecast_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_price_forecast
    ADD CONSTRAINT container_price_forecast_pkey PRIMARY KEY (id);


--
-- Name: container_prices container_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_prices
    ADD CONSTRAINT container_prices_pkey PRIMARY KEY (id);


--
-- Name: container_prices_raw container_prices_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.container_prices_raw
    ADD CONSTRAINT container_prices_raw_pkey PRIMARY KEY (id);


--
-- Name: cost_breakdown cost_breakdown_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_breakdown
    ADD CONSTRAINT cost_breakdown_pkey PRIMARY KEY (id);


--
-- Name: cost_breakdown_concmod cost_breakdownconcmod_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_breakdown_concmod
    ADD CONSTRAINT cost_breakdownconcmod_pkey PRIMARY KEY (id);


--
-- Name: cost_per_sqm cost_per_sqm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cost_per_sqm
    ADD CONSTRAINT cost_per_sqm_pkey PRIMARY KEY (id);


--
-- Name: efficiency_metrics efficiency_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.efficiency_metrics
    ADD CONSTRAINT efficiency_metrics_pkey PRIMARY KEY (id);


--
-- Name: housing_models housing_models_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.housing_models
    ADD CONSTRAINT housing_models_pkey PRIMARY KEY (id);


--
-- Name: resource_usage resource_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resource_usage
    ADD CONSTRAINT resource_usage_pkey PRIMARY KEY (id);


--
-- Name: shipping_container_prices shipping_container_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shipping_container_prices
    ADD CONSTRAINT shipping_container_prices_pkey PRIMARY KEY (id);


--
-- Name: shipping_container_raw shipping_container_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shipping_container_raw
    ADD CONSTRAINT shipping_container_raw_pkey PRIMARY KEY (id);


--
-- Name: total_cost_comparison total_cost_comparison_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.total_cost_comparison
    ADD CONSTRAINT total_cost_comparison_pkey PRIMARY KEY (id);


--
-- Name: idx_shipping_container_price_ship_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shipping_container_price_ship_date ON public.shipping_container_prices USING btree (ship_date);


--
-- Name: idx_shipping_container_raw_ship_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_shipping_container_raw_ship_date ON public.shipping_container_raw USING btree (ship_date);


--
-- PostgreSQL database dump complete
--


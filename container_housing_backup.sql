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
-- Name: container_price_trends; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.container_price_trends AS
 SELECT EXTRACT(year FROM ship_date) AS year,
    EXTRACT(month FROM ship_date) AS month,
    avg(freight_index) AS avg_freight_index,
    max(freight_index) AS max_freight_index,
    min(freight_index) AS min_freight_index,
    (max(freight_index) - min(freight_index)) AS freight_index_range,
    avg(base_price) AS avg_base_price,
    max(base_price) AS max_base_price,
    min(base_price) AS min_base_price,
        CASE
            WHEN (((max(freight_index) - min(freight_index)) / NULLIF(min(freight_index), (0)::numeric)) > 0.1) THEN 'High Volatility'::text
            WHEN (((max(freight_index) - min(freight_index)) / NULLIF(min(freight_index), (0)::numeric)) > 0.05) THEN 'Moderate Volatility'::text
            ELSE 'Stable'::text
        END AS freight_index_trend
   FROM public.shipping_container_raw
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
-- Name: sensitivity_analysis_results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_analysis_results (
    model_name text,
    adjusted_investment text,
    annual_maintenance text,
    annual_rental_income text,
    annual_net_income text,
    payback_years text,
    annual_roi_percentage text,
    iteration bigint,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint
);


ALTER TABLE public.sensitivity_analysis_results OWNER TO postgres;

--
-- Name: sensitivity_model_summary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_model_summary (
    model_name text,
    annual_roi_percentage_mean double precision,
    annual_roi_percentage_std double precision,
    annual_roi_percentage_min text,
    annual_roi_percentage_max text,
    payback_years_mean double precision,
    payback_years_std double precision,
    payback_years_min text,
    payback_years_max text
);


ALTER TABLE public.sensitivity_model_summary OWNER TO postgres;

--
-- Name: sensitivity_optimal_scenarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sensitivity_optimal_scenarios (
    model_name text,
    adjusted_investment text,
    annual_maintenance text,
    annual_rental_income text,
    annual_net_income text,
    payback_years text,
    annual_roi_percentage text,
    iteration bigint,
    container_price_increase double precision,
    rental_income double precision,
    expected_lifespan bigint
);


ALTER TABLE public.sensitivity_optimal_scenarios OWNER TO postgres;

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
-- Data for Name: sensitivity_analysis_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_analysis_results (model_name, adjusted_investment, annual_maintenance, annual_rental_income, annual_net_income, payback_years, annual_roi_percentage, iteration, container_price_increase, rental_income, expected_lifespan) FROM stdin;
ODD Cubes Basic	420000.00	14700.00	13121.29053069534	-1578.70946930466	-266.04	-0.38	0	46.81463477668447	13121.29053069534	29
Container (Base)	474714.8445259748658321000000	16615.02	13121.29053069534	-3493.7290277137803041235000000	-135.88	-0.74	0	46.81463477668447	13121.29053069534	29
Traditional Housing	708000.00	21240.00	13121.29053069534	-8118.70946930466	-87.21	-1.15	0	46.81463477668447	13121.29053069534	29
Container (Max)	851532.2224365087602235000000	29803.63	13121.29053069534	-16682.3372545824666078225000000	-51.04	-1.96	0	46.81463477668447	13121.29053069534	29
ODD Cubes Basic	420000.00	14700.00	16546.93563785157	1846.93563785157	227.40	0.44	1	60.43623755561232	16546.93563785157	24
Container (Base)	518759.3435994435438576000000	18156.58	16546.93563785157	-1609.6413881289540350160000000	-322.28	-0.31	1	60.43623755561232	16546.93563785157	24
Traditional Housing	708000.00	21240.00	16546.93563785157	-4693.06436214843	-150.86	-0.66	1	60.43623755561232	16546.93563785157	24
Container (Max)	930538.1996344292366160000000	32568.84	16546.93563785157	-16021.9013493534532815600000000	-58.08	-1.72	1	60.43623755561232	16546.93563785157	24
Container (Base)	327849.3977840400065030910000	11474.73	10122.942204297533	-1351.7867181438672276081850000	-242.53	-0.41	2	1.3936896064055837	10122.942204297533	30
ODD Cubes Basic	420000.00	14700.00	10122.942204297533	-4577.057795702467	-91.76	-1.09	2	1.3936896064055837	10122.942204297533	30
Traditional Housing	708000.00	21240.00	10122.942204297533	-11117.057795702467	-63.69	-1.57	2	1.3936896064055837	10122.942204297533	30
Container (Max)	588088.4694016327057391850000	20583.10	10122.942204297533	-10460.1542247596117008714750000	-56.22	-1.78	2	1.3936896064055837	10122.942204297533	30
ODD Cubes Basic	420000.00	14700.00	12844.748659851253	-1855.251340148747	-226.38	-0.44	3	64.92258858797436	12844.748659851253	26
Container (Base)	533265.6456180139348548000000	18664.30	12844.748659851253	-5819.5489367792347199180000000	-91.63	-1.09	3	64.92258858797436	12844.748659851253	26
Traditional Housing	708000.00	21240.00	12844.748659851253	-8395.251340148747	-84.33	-1.19	3	64.92258858797436	12844.748659851253	26
Container (Max)	956559.2599396806867180000000	33479.57	12844.748659851253	-20634.8254380375710351300000000	-46.36	-2.16	3	64.92258858797436	12844.748659851253	26
Container (Base)	262460.4143868520966602000000	9186.11	16491.517572684963	7305.4030691451396168930000000	35.93	2.78	4	-18.82910272161386	16491.517572684963	32
ODD Cubes Basic	420000.00	14700.00	16491.517572684963	1791.517572684963	234.44	0.43	4	-18.82910272161386	16491.517572684963	32
Container (Max)	470795.2627595035313070000000	16477.83	16491.517572684963	13.6833761023394042550000000	34406.37	0.00	4	-18.82910272161386	16491.517572684963	32
Traditional Housing	708000.00	21240.00	16491.517572684963	-4748.482427315037	-149.10	-0.67	4	-18.82910272161386	16491.517572684963	32
ODD Cubes Basic	420000.00	14700.00	16202.440918757864	1502.440918757864	279.55	0.36	5	62.06631645670353	16202.440918757864	26
Container (Base)	524030.0896205988950079000000	18341.05	16202.440918757864	-2138.6122179630973252765000000	-245.03	-0.41	5	62.06631645670353	16202.440918757864	26
Traditional Housing	708000.00	21240.00	16202.440918757864	-5037.559081242136	-140.54	-0.71	5	62.06631645670353	16202.440918757864	26
Container (Max)	939992.7387647033091765000000	32899.75	16202.440918757864	-16697.3049380067518211775000000	-56.30	-1.78	5	62.06631645670353	16202.440918757864	26
Container (Base)	235055.1139909240034106000000	8226.93	19055.645577604162	10828.7165879218218806290000000	21.71	4.61	6	-27.30471542884058	19055.645577604162	16
ODD Cubes Basic	420000.00	14700.00	19055.645577604162	4355.645577604162	96.43	1.04	6	-27.30471542884058	19055.645577604162	16
Container (Max)	421636.2852769531939710000000	14757.27	19055.645577604162	4298.3755929108002110150000000	98.09	1.02	6	-27.30471542884058	19055.645577604162	16
Traditional Housing	708000.00	21240.00	19055.645577604162	-2184.354422395838	-324.12	-0.31	6	-27.30471542884058	19055.645577604162	16
Container (Base)	411443.4536283717815593500000	14400.52	13378.42796406629	-1022.0929129267223545772500000	-402.55	-0.25	7	27.246748384338545	13378.42796406629	29
ODD Cubes Basic	420000.00	14700.00	13378.42796406629	-1321.57203593371	-317.80	-0.31	7	27.246748384338545	13378.42796406629	29
Traditional Housing	708000.00	21240.00	13378.42796406629	-7861.57203593371	-90.06	-1.11	7	27.246748384338545	13378.42796406629	29
Container (Max)	738037.5029665827779272500000	25831.31	13378.42796406629	-12452.8846397641072274537500000	-59.27	-1.69	7	27.246748384338545	13378.42796406629	29
ODD Cubes Basic	420000.00	14700.00	8841.538262328153	-5858.461737671847	-71.69	-1.39	8	66.40935856663523	8841.538262328153	33
Traditional Housing	708000.00	21240.00	8841.538262328153	-12398.461737671847	-57.10	-1.75	8	66.40935856663523	8841.538262328153	33
Container (Base)	538073.0122701153517389000000	18832.56	8841.538262328153	-9991.0171671258843108615000000	-53.86	-1.86	8	66.40935856663523	8841.538262328153	33
Container (Max)	965182.6001544126657615000000	33781.39	8841.538262328153	-24939.8527430762903016525000000	-38.70	-2.58	8	66.40935856663523	8841.538262328153	33
Container (Base)	227479.3029517287769525800000	7961.78	16834.99503224899	8873.2194289384828066597000000	25.64	3.90	9	-29.647679723473594	16834.99503224899	39
Container (Max)	408046.9752198669811203000000	14281.64	16834.99503224899	2553.3508995536456607895000000	159.81	0.63	9	-29.647679723473594	16834.99503224899	39
ODD Cubes Basic	420000.00	14700.00	16834.99503224899	2134.99503224899	196.72	0.51	9	-29.647679723473594	16834.99503224899	39
Traditional Housing	708000.00	21240.00	16834.99503224899	-4405.00496775101	-160.73	-0.62	9	-29.647679723473594	16834.99503224899	39
ODD Cubes Basic	420000.00	14700.00	16955.768096424334	2255.768096424334	186.19	0.54	10	62.113051396498236	16955.768096424334	26
Container (Base)	524181.2037769792912294800000	18346.34	16955.768096424334	-1390.5740357699411930318000000	-376.95	-0.27	10	62.113051396498236	16955.768096424334	26
Traditional Housing	708000.00	21240.00	16955.768096424334	-4284.231903575666	-165.26	-0.61	10	62.113051396498236	16955.768096424334	26
Container (Max)	940263.8037522595937118000000	32909.23	16955.768096424334	-15953.4650349047517799130000000	-58.94	-1.70	10	62.113051396498236	16955.768096424334	26
ODD Cubes Basic	420000.00	14700.00	18849.166322680583	4149.166322680583	101.23	0.99	11	54.41721027286697	18849.166322680583	18
Container (Base)	499297.2402125962468071000000	17475.40	18849.166322680583	1373.7629152397143617515000000	363.45	0.28	11	54.41721027286697	18849.166322680583	18
Traditional Housing	708000.00	21240.00	18849.166322680583	-2390.833677319417	-296.13	-0.34	11	54.41721027286697	18849.166322680583	18
Container (Max)	895627.5404431420693485000000	31346.96	18849.166322680583	-12497.7975928293894271975000000	-71.66	-1.40	11	54.41721027286697	18849.166322680583	18
ODD Cubes Basic	420000.00	14700.00	10596.265874178047	-4103.734125821953	-102.35	-0.98	12	63.64116826627999	10596.265874178047	28
Traditional Housing	708000.00	21240.00	10596.265874178047	-10643.734125821953	-66.52	-1.50	12	63.64116826627999	10596.265874178047	28
Container (Base)	529122.2627072377080657000000	18519.28	10596.265874178047	-7923.0133205752727822995000000	-66.78	-1.50	12	63.64116826627999	10596.265874178047	28
Container (Max)	949126.9580028372559995000000	33219.44	10596.265874178047	-22623.1776559212569599825000000	-41.95	-2.38	12	63.64116826627999	10596.265874178047	28
Container (Base)	272227.1095684063967426100000	9527.95	14383.15217194427	4855.2033370500461140086500000	56.07	1.78	13	-15.808565650591973	14383.15217194427	16
ODD Cubes Basic	420000.00	14700.00	14383.15217194427	-316.84782805573	-1325.56	-0.08	13	-15.808565650591973	14383.15217194427	16
Container (Max)	488314.5287982840270013500000	17091.01	14383.15217194427	-2707.8563359956709450472500000	-180.33	-0.55	13	-15.808565650591973	14383.15217194427	16
Traditional Housing	708000.00	21240.00	14383.15217194427	-6856.84782805573	-103.25	-0.97	13	-15.808565650591973	14383.15217194427	16
Container (Base)	261802.4231093045297355000000	9163.08	14522.4382323582	5359.3534235325414592575000000	48.85	2.05	14	-19.03259909467515	14522.4382323582	25
ODD Cubes Basic	420000.00	14700.00	14522.4382323582	-177.5617676418	-2365.37	-0.04	14	-19.03259909467515	14522.4382323582	25
Container (Max)	469614.9736209293962425000000	16436.52	14522.4382323582	-1914.0858443743288684875000000	-245.35	-0.41	14	-19.03259909467515	14522.4382323582	25
Traditional Housing	708000.00	21240.00	14522.4382323582	-6717.5617676418	-105.40	-0.95	14	-19.03259909467515	14522.4382323582	25
ODD Cubes Basic	420000.00	14700.00	10800.580297868888	-3899.419702131112	-107.71	-0.93	15	53.41055526836466	10800.580297868888	26
Container (Base)	496042.2917213883425838000000	17361.48	10800.580297868888	-6560.8999123797039904330000000	-75.61	-1.32	15	53.41055526836466	10800.580297868888	26
Traditional Housing	708000.00	21240.00	10800.580297868888	-10439.419702131112	-67.82	-1.47	15	53.41055526836466	10800.580297868888	26
Container (Max)	889788.8910842784462330000000	31142.61	10800.580297868888	-20342.0308900808576181550000000	-43.74	-2.29	15	53.41055526836466	10800.580297868888	26
Container (Base)	382839.8954090248603039500000	13399.40	13614.557572937887	215.1612336220168893617500000	1779.32	0.06	16	18.400551553311765	13614.557572937887	17
ODD Cubes Basic	420000.00	14700.00	13614.557572937887	-1085.442427062113	-386.94	-0.26	16	18.400551553311765	13614.557572937887	17
Traditional Housing	708000.00	21240.00	13614.557572937887	-7625.442427062113	-92.85	-1.08	16	18.400551553311765	13614.557572937887	17
Container (Max)	686729.1190367859025882500000	24035.52	13614.557572937887	-10420.9615933496195905887500000	-65.90	-1.52	16	18.400551553311765	13614.557572937887	17
Container (Base)	413723.1685455256392270900000	14480.31	18760.04625914667	4279.7353600532726270518500000	96.67	1.03	17	27.951793774884763	18760.04625914667	24
ODD Cubes Basic	420000.00	14700.00	18760.04625914667	4060.04625914667	103.45	0.97	17	27.951793774884763	18760.04625914667	24
Traditional Housing	708000.00	21240.00	18760.04625914667	-2479.95374085333	-285.49	-0.35	17	27.951793774884763	18760.04625914667	24
Container (Max)	742126.8014840203696381500000	25974.44	18760.04625914667	-7214.3917927940429373352500000	-102.87	-0.97	17	27.951793774884763	18760.04625914667	24
Container (Base)	356817.4748316145298245500000	12488.61	14294.977790697416	1806.3661715909074561407500000	197.53	0.51	18	10.352620848948185	14294.977790697416	35
ODD Cubes Basic	420000.00	14700.00	14294.977790697416	-405.022209302584	-1036.98	-0.10	18	10.352620848948185	14294.977790697416	35
Traditional Housing	708000.00	21240.00	14294.977790697416	-6945.022209302584	-101.94	-0.98	18	10.352620848948185	14294.977790697416	35
Container (Max)	640050.7185549419204092500000	22401.78	14294.977790697416	-8106.7973587255512143237500000	-78.95	-1.27	18	10.352620848948185	14294.977790697416	35
Container (Base)	385196.9789305659748770900000	13481.89	9451.043690199776	-4030.8505723700331206981500000	-95.56	-1.05	19	19.129524662839763	9451.043690199776	38
ODD Cubes Basic	420000.00	14700.00	9451.043690199776	-5248.956309800224	-80.02	-1.25	19	19.129524662839763	9451.043690199776	38
Traditional Housing	708000.00	21240.00	9451.043690199776	-11788.956309800224	-60.06	-1.67	19	19.129524662839763	9451.043690199776	38
Container (Max)	690957.1995207037673881500000	24183.50	9451.043690199776	-14732.4582930248558585852500000	-46.90	-2.13	19	19.129524662839763	9451.043690199776	38
Container (Base)	300139.4133281006138609100000	10504.88	16241.973023499002	5737.0935570154805148681500000	52.32	1.91	20	-7.176152467163163	16241.973023499002	19
ODD Cubes Basic	420000.00	14700.00	16241.973023499002	1541.973023499002	272.38	0.37	20	-7.176152467163163	16241.973023499002	19
Container (Max)	538382.9568828302964418500000	18843.40	16241.973023499002	-2601.4304674000583754647500000	-206.96	-0.48	20	-7.176152467163163	16241.973023499002	19
Traditional Housing	708000.00	21240.00	16241.973023499002	-4998.026976500998	-141.66	-0.71	20	-7.176152467163163	16241.973023499002	19
Container (Base)	234525.0145987387215166500000	8208.38	10307.155621324584	2098.7801103687287469172500000	111.74	0.89	21	-27.468658793065345	10307.155621324584	28
ODD Cubes Basic	420000.00	14700.00	10307.155621324584	-4392.844378675416	-95.61	-1.05	21	-27.468658793065345	10307.155621324584	28
Container (Max)	420685.4055672813457327500000	14723.99	10307.155621324584	-4416.8335735302631006462500000	-95.25	-1.05	21	-27.468658793065345	10307.155621324584	28
Traditional Housing	708000.00	21240.00	10307.155621324584	-10932.844378675416	-64.76	-1.54	21	-27.468658793065345	10307.155621324584	28
Container (Base)	312432.5561800553130281220000	10935.14	8804.876893201601	-2130.2625731003349559842700000	-146.66	-0.68	22	-3.3742631879906746	8804.876893201601	31
ODD Cubes Basic	420000.00	14700.00	8804.876893201601	-5895.123106798399	-71.25	-1.40	22	-3.3742631879906746	8804.876893201601	31
Traditional Housing	708000.00	21240.00	8804.876893201601	-12435.123106798399	-56.94	-1.76	22	-3.3742631879906746	8804.876893201601	31
Container (Max)	560434.1047964946877862700000	19615.19	8804.876893201601	-10810.3167746757130725194500000	-51.84	-1.93	22	-3.3742631879906746	8804.876893201601	31
ODD Cubes Basic	420000.00	14700.00	14680.48154184605	-19.51845815395	-21518.09	0.00	23	29.942017860889926	14680.48154184605	26
Container (Base)	420158.4188119373134261800000	14705.54	14680.48154184605	-25.0631165717559699163000000	-16764.01	-0.01	23	29.942017860889926	14680.48154184605	26
Traditional Housing	708000.00	21240.00	14680.48154184605	-6559.51845815395	-107.93	-0.93	23	29.942017860889926	14680.48154184605	26
Container (Max)	753670.2006940546152963000000	26378.46	14680.48154184605	-11697.9754824458615353705000000	-64.43	-1.55	23	29.942017860889926	14680.48154184605	26
Container (Base)	353488.2174399527894449800000	12372.09	10176.153151821933	-2195.9344585764146305743000000	-160.97	-0.62	24	9.322984397359086	10176.153151821933	28
ODD Cubes Basic	420000.00	14700.00	10176.153151821933	-4523.846848178067	-92.84	-1.08	24	9.322984397359086	10176.153151821933	28
Traditional Housing	708000.00	21240.00	10176.153151821933	-11063.846848178067	-63.99	-1.56	24	9.322984397359086	10176.153151821933	28
Container (Max)	634078.7756539025667543000000	22192.76	10176.153151821933	-12016.6039960646568364005000000	-52.77	-1.90	24	9.322984397359086	10176.153151821933	28
Container (Base)	366220.6491251327680343700000	12817.72	11319.657452631458	-1498.0652667481888812029500000	-244.46	-0.41	25	13.260732140523459	11319.657452631458	15
ODD Cubes Basic	420000.00	14700.00	11319.657452631458	-3380.342547368542	-124.25	-0.80	25	13.260732140523459	11319.657452631458	15
Traditional Housing	708000.00	21240.00	11319.657452631458	-9920.342547368542	-71.37	-1.40	25	13.260732140523459	11319.657452631458	15
Container (Max)	656917.9094516430883729500000	22992.13	11319.657452631458	-11672.4693781760500930532500000	-56.28	-1.78	25	13.260732140523459	11319.657452631458	15
ODD Cubes Basic	420000.00	14700.00	14770.317652522612	70.317652522612	5972.90	0.02	26	67.92808925965416	14770.317652522612	21
Container (Base)	542983.7216548435505688000000	19004.43	14770.317652522612	-4234.1126053969122699080000000	-128.24	-0.78	26	67.92808925965416	14770.317652522612	21
Traditional Housing	708000.00	21240.00	14770.317652522612	-6469.682347477388	-109.43	-0.91	26	67.92808925965416	14770.317652522612	21
Container (Max)	973991.3141104571107080000000	34089.70	14770.317652522612	-19319.3783413433868747800000000	-50.42	-1.98	26	67.92808925965416	14770.317652522612	21
ODD Cubes Basic	420000.00	14700.00	16163.494875012171	1463.494875012171	286.98	0.35	27	33.82577339746288	16163.494875012171	16
Container (Base)	432716.2704765584000784000000	15145.07	16163.494875012171	1018.4254083326269972560000000	424.89	0.24	27	33.82577339746288	16163.494875012171	16
Traditional Housing	708000.00	21240.00	16163.494875012171	-5076.505124987829	-139.47	-0.72	27	33.82577339746288	16163.494875012171	16
Container (Max)	776196.1769939545771440000000	27166.87	16163.494875012171	-11003.3713197762392000400000000	-70.54	-1.42	27	33.82577339746288	16163.494875012171	16
Container (Base)	306735.2459687166469261200000	10735.73	14409.832447266337	3674.0988383612543575858000000	83.49	1.20	28	-5.136265214117316	14409.832447266337	16
ODD Cubes Basic	420000.00	14700.00	14409.832447266337	-290.167552733663	-1447.44	-0.07	28	-5.136265214117316	14409.832447266337	16
Container (Max)	550214.4049448588613342000000	19257.50	14409.832447266337	-4847.6717258037231466970000000	-113.50	-0.88	28	-5.136265214117316	14409.832447266337	16
Traditional Housing	708000.00	21240.00	14409.832447266337	-6830.167552733663	-103.66	-0.96	28	-5.136265214117316	14409.832447266337	16
ODD Cubes Basic	420000.00	14700.00	13685.955757768454	-1014.044242231546	-414.18	-0.24	29	47.79234730528711	13685.955757768454	24
Container (Base)	477876.2095473345000873000000	16725.67	13685.955757768454	-3039.7115763882535030555000000	-157.21	-0.64	29	47.79234730528711	13685.955757768454	24
Traditional Housing	708000.00	21240.00	13685.955757768454	-7554.044242231546	-93.72	-1.07	29	47.79234730528711	13685.955757768454	24
Container (Max)	857203.0039880305023555000000	30002.11	13685.955757768454	-16316.1493818126135824425000000	-52.54	-1.90	29	47.79234730528711	13685.955757768454	24
Container (Base)	341238.9619264607103033900000	11943.36	15646.883789405612	3703.5201219794871393813500000	92.14	1.09	30	5.534668116044173	15646.883789405612	34
ODD Cubes Basic	420000.00	14700.00	15646.883789405612	946.883789405612	443.56	0.23	30	5.534668116044173	15646.883789405612	34
Traditional Housing	708000.00	21240.00	15646.883789405612	-5593.116210594388	-126.58	-0.79	30	5.534668116044173	15646.883789405612	34
Container (Max)	612106.3518064620056086500000	21423.72	15646.883789405612	-5776.8385238205581963027500000	-105.96	-0.94	30	5.534668116044173	15646.883789405612	34
Container (Base)	322735.3678190186373647340000	11295.74	16574.44353071138	5278.7056570457276922343100000	61.14	1.64	31	-0.1879218603716062	16574.44353071138	21
ODD Cubes Basic	420000.00	14700.00	16574.44353071138	1874.44353071138	224.07	0.45	31	-0.1879218603716062	16574.44353071138	21
Container (Max)	578915.0438137516654596900000	20262.03	16574.44353071138	-3687.5830027699282910891500000	-156.99	-0.64	31	-0.1879218603716062	16574.44353071138	21
Traditional Housing	708000.00	21240.00	16574.44353071138	-4665.55646928862	-151.75	-0.66	31	-0.1879218603716062	16574.44353071138	21
ODD Cubes Basic	420000.00	14700.00	19544.14080172753	4844.14080172753	86.70	1.15	32	57.46676380083896	19544.14080172753	28
Container (Base)	509157.7580765467184328000000	17820.52	19544.14080172753	1723.6192690483948548520000000	295.40	0.34	32	57.46676380083896	19544.14080172753	28
Traditional Housing	708000.00	21240.00	19544.14080172753	-1695.85919827247	-417.49	-0.24	32	57.46676380083896	19544.14080172753	28
Container (Max)	913315.1033830560099480000000	31966.03	19544.14080172753	-12421.8878166794303481800000000	-73.52	-1.36	32	57.46676380083896	19544.14080172753	28
Container (Base)	353213.1970824286898052300000	12362.46	14031.92108701326	1669.4591891282558568169500000	211.57	0.47	33	9.237929097716261	14031.92108701326	29
ODD Cubes Basic	420000.00	14700.00	14031.92108701326	-668.07891298674	-628.67	-0.16	33	9.237929097716261	14031.92108701326	29
Traditional Housing	708000.00	21240.00	14031.92108701326	-7208.07891298674	-98.22	-1.02	33	9.237929097716261	14031.92108701326	29
Container (Max)	633585.4506632091996130500000	22175.49	14031.92108701326	-8143.5696861990619864567500000	-77.80	-1.29	33	9.237929097716261	14031.92108701326	29
Container (Base)	329633.0116896717494284860000	11537.16	18916.42102403957	7379.2656149010587700029900000	44.67	2.24	34	1.9453062814632602	18916.42102403957	35
ODD Cubes Basic	420000.00	14700.00	18916.42102403957	4216.42102403957	99.61	1.00	34	1.9453062814632602	18916.42102403957	35
Container (Max)	591287.8736978009823230100000	20695.08	18916.42102403957	-1778.6545553834643813053500000	-332.44	-0.30	34	1.9453062814632602	18916.42102403957	35
Traditional Housing	708000.00	21240.00	18916.42102403957	-2323.57897596043	-304.70	-0.33	34	1.9453062814632602	18916.42102403957	35
ODD Cubes Basic	420000.00	14700.00	15222.205009651354	522.205009651354	804.28	0.12	35	62.04071781701066	15222.205009651354	32
Container (Base)	523947.3182110567783638000000	18338.16	15222.205009651354	-3115.9511277356332427330000000	-168.15	-0.59	35	62.04071781701066	15222.205009651354	32
Traditional Housing	708000.00	21240.00	15222.205009651354	-6017.794990348646	-117.65	-0.85	35	62.04071781701066	15222.205009651354	32
Container (Max)	939844.2653745526785330000000	32894.55	15222.205009651354	-17672.3442784579897486550000000	-53.18	-1.88	35	62.04071781701066	15222.205009651354	32
ODD Cubes Basic	420000.00	14700.00	17596.007490302494	2896.007490302494	145.03	0.69	36	52.31214793174941	17596.007490302494	18
Container (Base)	492490.6684869564947763000000	17237.17	17596.007490302494	358.8340932590166828295000000	1372.47	0.07	36	52.31214793174941	17596.007490302494	18
Traditional Housing	708000.00	21240.00	17596.007490302494	-3643.992509697506	-194.29	-0.51	36	52.31214793174941	17596.007490302494	18
Container (Max)	883418.0736115431654705000000	30919.63	17596.007490302494	-13323.6250861015167914675000000	-66.30	-1.51	36	52.31214793174941	17596.007490302494	18
Container (Base)	329943.5104536678881144250000	11548.02	13417.123648994217	1869.1007831158409159951250000	176.53	0.57	37	2.0413339560985975	13417.123648994217	21
ODD Cubes Basic	420000.00	14700.00	13417.123648994217	-1282.876351005783	-327.39	-0.31	37	2.0413339560985975	13417.123648994217	21
Traditional Housing	708000.00	21240.00	13417.123648994217	-7822.876351005783	-90.50	-1.10	37	2.0413339560985975	13417.123648994217	21
Container (Max)	591844.8390120696704298750000	20714.57	13417.123648994217	-7297.4457164282214650456250000	-81.10	-1.23	37	2.0413339560985975	13417.123648994217	21
ODD Cubes Basic	420000.00	14700.00	16354.463207950314	1654.463207950314	253.86	0.39	38	58.48688269334562	16354.463207950314	31
Container (Base)	512456.2411071445280766000000	17935.97	16354.463207950314	-1581.5052307997444826810000000	-324.03	-0.31	38	58.48688269334562	16354.463207950314	31
Traditional Housing	708000.00	21240.00	16354.463207950314	-4885.536792049686	-144.92	-0.69	38	58.48688269334562	16354.463207950314	31
Container (Max)	919231.8439655392632810000000	32173.11	16354.463207950314	-15818.6513308435602148350000000	-58.11	-1.72	38	58.48688269334562	16354.463207950314	31
Container (Base)	391973.9875877641119955200000	13719.09	9386.055121474825	-4333.0344440969189198432000000	-90.46	-1.11	39	21.225444060259264	9386.055121474825	17
ODD Cubes Basic	420000.00	14700.00	9386.055121474825	-5313.944878525175	-79.04	-1.27	39	21.225444060259264	9386.055121474825	17
Traditional Housing	708000.00	21240.00	9386.055121474825	-11853.944878525175	-59.73	-1.67	39	21.225444060259264	9386.055121474825	17
Container (Max)	703113.6368217067441632000000	24608.98	9386.055121474825	-15222.9221672849110457120000000	-46.19	-2.17	39	21.225444060259264	9386.055121474825	17
ODD Cubes Basic	420000.00	14700.00	9876.930376016384	-4823.069623983616	-87.08	-1.15	40	41.61785059344024	9876.930376016384	32
Container (Base)	457911.4066443474752232000000	16026.90	9876.930376016384	-6149.9688565357776328120000000	-74.46	-1.34	40	41.61785059344024	9876.930376016384	32
Traditional Housing	708000.00	21240.00	9876.930376016384	-11363.069623983616	-62.31	-1.60	40	41.61785059344024	9876.930376016384	32
Container (Max)	821390.6143344830640120000000	28748.67	9876.930376016384	-18871.7411256905232404200000000	-43.52	-2.30	40	41.61785059344024	9876.930376016384	32
Container (Base)	310940.2573813044675521190000	10882.91	18146.836896105488	7263.9278877598316356758350000	42.81	2.34	41	-3.8357851008667367	18146.836896105488	36
ODD Cubes Basic	420000.00	14700.00	18146.836896105488	3446.836896105488	121.85	0.82	41	-3.8357851008667367	18146.836896105488	36
Container (Max)	557757.2546257178838031650000	19521.50	18146.836896105488	-1374.6670157946379331107750000	-405.74	-0.25	41	-3.8357851008667367	18146.836896105488	36
Traditional Housing	708000.00	21240.00	18146.836896105488	-3093.163103894512	-228.89	-0.44	41	-3.8357851008667367	18146.836896105488	36
ODD Cubes Basic	420000.00	14700.00	16532.780371559253	1832.780371559253	229.16	0.44	42	65.47888571368844	16532.780371559253	18
Container (Base)	535064.3934332116125492000000	18727.25	16532.780371559253	-2194.4733986031534392220000000	-243.82	-0.41	42	65.47888571368844	16532.780371559253	18
Traditional Housing	708000.00	21240.00	16532.780371559253	-4707.219628440747	-150.41	-0.66	42	65.47888571368844	16532.780371559253	18
Container (Max)	959785.8110836786364220000000	33592.50	16532.780371559253	-17059.7230163694992747700000000	-56.26	-1.78	42	65.47888571368844	16532.780371559253	18
ODD Cubes Basic	420000.00	14700.00	17284.778807593888	2584.778807593888	162.49	0.62	43	58.4558967628205	17284.778807593888	30
Container (Base)	512356.0502698066893150000000	17932.46	17284.778807593888	-647.6829518493461260250000000	-791.06	-0.13	43	58.4558967628205	17284.778807593888	30
Traditional Housing	708000.00	21240.00	17284.778807593888	-3955.221192406112	-179.00	-0.56	43	58.4558967628205	17284.778807593888	30
Container (Max)	919052.1240191970410250000000	32166.82	17284.778807593888	-14882.0455330780084358750000000	-61.76	-1.62	43	58.4558967628205	17284.778807593888	30
Container (Base)	348653.4377450366681066700000	12202.87	11879.82973896141	-323.0405821148733837334500000	-1079.29	-0.09	44	7.827736411500069	11879.82973896141	16
ODD Cubes Basic	420000.00	14700.00	11879.82973896141	-2820.17026103859	-148.93	-0.67	44	7.827736411500069	11879.82973896141	16
Traditional Housing	708000.00	21240.00	11879.82973896141	-9360.17026103859	-75.64	-1.32	44	7.827736411500069	11879.82973896141	16
Container (Max)	625406.2625735209752034500000	21889.22	11879.82973896141	-10009.3894511118241321207500000	-62.48	-1.60	44	7.827736411500069	11879.82973896141	16
ODD Cubes Basic	420000.00	14700.00	9652.503071777488	-5047.496928222512	-83.21	-1.20	45	39.208435592394025	9652.503071777488	23
Container (Base)	450120.7318975146122557500000	15754.23	9652.503071777488	-6101.7225446355234289512500000	-73.77	-1.36	45	39.208435592394025	9652.503071777488	23
Traditional Housing	708000.00	21240.00	9652.503071777488	-11587.496928222512	-61.10	-1.64	45	39.208435592394025	9652.503071777488	23
Container (Max)	807415.8868576649647012500000	28259.56	9652.503071777488	-18607.0529682407857645437500000	-43.39	-2.30	45	39.208435592394025	9652.503071777488	23
Container (Base)	387388.3019313451448173500000	13558.59	9849.37009829971	-3709.2204692973700686072500000	-104.44	-0.96	46	19.807233164579145	9849.37009829971	36
ODD Cubes Basic	420000.00	14700.00	9849.37009829971	-4850.62990170029	-86.59	-1.15	46	19.807233164579145	9849.37009829971	36
Traditional Housing	708000.00	21240.00	9849.37009829971	-11390.62990170029	-62.16	-1.61	46	19.807233164579145	9849.37009829971	36
Container (Max)	694887.9427162172699572500000	24321.08	9849.37009829971	-14471.7078967678944485037500000	-48.02	-2.08	46	19.807233164579145	9849.37009829971	36
ODD Cubes Basic	420000.00	14700.00	12760.133449162886	-1939.866550837114	-216.51	-0.46	47	49.295085846002266	12760.133449162886	34
Container (Base)	482735.2094270391069523800000	16895.73	12760.133449162886	-4135.5988807834827433333000000	-116.73	-0.86	47	49.295085846002266	12760.133449162886	34
Traditional Housing	708000.00	21240.00	12760.133449162886	-8479.866550837114	-83.49	-1.20	47	49.295085846002266	12760.133449162886	34
Container (Max)	865918.9626611054429133000000	30307.16	12760.133449162886	-17547.0302439758045019655000000	-49.35	-2.03	47	49.295085846002266	12760.133449162886	34
Container (Base)	382821.3181899045063765000000	13398.75	18238.958673541754	4840.2125368950962768225000000	79.09	1.26	48	18.39480619339355	18238.958673541754	30
ODD Cubes Basic	420000.00	14700.00	18238.958673541754	3538.958673541754	118.68	0.84	48	18.39480619339355	18238.958673541754	30
Traditional Housing	708000.00	21240.00	18238.958673541754	-3001.041326458246	-235.92	-0.42	48	18.39480619339355	18238.958673541754	30
Container (Max)	686695.7956619922596775000000	24034.35	18238.958673541754	-5795.3941746279750887125000000	-118.49	-0.84	48	18.39480619339355	18238.958673541754	30
Container (Base)	328348.5905383241760486450000	11492.20	19781.53790488206	8289.3372360407138382974250000	39.61	2.52	49	1.5480745024089515	19781.53790488206	38
ODD Cubes Basic	420000.00	14700.00	19781.53790488206	5081.53790488206	82.65	1.21	49	1.5480745024089515	19781.53790488206	38
Container (Max)	588983.9095176970391475750000	20614.44	19781.53790488206	-832.8989282373363701651250000	-707.15	-0.14	49	1.5480745024089515	19781.53790488206	38
Traditional Housing	708000.00	21240.00	19781.53790488206	-1458.46209511794	-485.44	-0.21	49	1.5480745024089515	19781.53790488206	38
Container (Base)	315779.5557200576007036000000	11052.28	8940.064223951842	-2112.2202262501740246260000000	-149.50	-0.67	50	-2.33913963807548	8940.064223951842	33
ODD Cubes Basic	420000.00	14700.00	8940.064223951842	-5759.935776048158	-72.92	-1.37	50	-2.33913963807548	8940.064223951842	33
Traditional Housing	708000.00	21240.00	8940.064223951842	-12299.935776048158	-57.56	-1.74	50	-2.33913963807548	8940.064223951842	33
Container (Max)	566437.8731421803122260000000	19825.33	8940.064223951842	-10885.2613360244689279100000000	-52.04	-1.92	50	-2.33913963807548	8940.064223951842	33
Container (Base)	342284.7319130700600808500000	11979.97	12282.584587268222	302.6189703107698971702500000	1131.07	0.09	51	5.858092463133595	12282.584587268222	23
ODD Cubes Basic	420000.00	14700.00	12282.584587268222	-2417.415412731778	-173.74	-0.58	51	5.858092463133595	12282.584587268222	23
Traditional Housing	708000.00	21240.00	12282.584587268222	-8957.415412731778	-79.04	-1.27	51	5.858092463133595	12282.584587268222	23
Container (Max)	613982.2291907980076797500000	21489.38	12282.584587268222	-9206.7934344097082687912500000	-66.69	-1.50	51	5.858092463133595	12282.584587268222	23
ODD Cubes Basic	420000.00	14700.00	9661.576077183126	-5038.423922816874	-83.36	-1.20	52	53.18419139542472	9661.576077183126	30
Container (Base)	495310.3599837081523896000000	17335.86	9661.576077183126	-7674.2865222466593336360000000	-64.54	-1.55	52	53.18419139542472	9661.576077183126	30
Traditional Housing	708000.00	21240.00	9661.576077183126	-11578.423922816874	-61.15	-1.64	52	53.18419139542472	9661.576077183126	30
Container (Max)	888475.9693030331472360000000	31096.66	9661.576077183126	-21435.0828484230341532600000000	-41.45	-2.41	52	53.18419139542472	9661.576077183126	30
Container (Base)	312401.3292065595809479950000	10934.05	9924.431600322043	-1009.6149219075423331798250000	-309.43	-0.32	53	-3.3839207261145035	9924.431600322043	28
ODD Cubes Basic	420000.00	14700.00	9924.431600322043	-4775.568399677957	-87.95	-1.14	53	-3.3839207261145035	9924.431600322043	28
Traditional Housing	708000.00	21240.00	9924.431600322043	-11315.568399677957	-62.57	-1.60	53	-3.3839207261145035	9924.431600322043	28
Container (Max)	560378.0905924995739748250000	19613.23	9924.431600322043	-9688.8015704154420891188750000	-57.84	-1.73	53	-3.3839207261145035	9924.431600322043	28
Container (Base)	404351.4964182248362546800000	14152.30	11989.563381260286	-2162.7389933775832689138000000	-186.96	-0.53	54	25.053425130039876	11989.563381260286	16
ODD Cubes Basic	420000.00	14700.00	11989.563381260286	-2710.436618739714	-154.96	-0.65	54	25.053425130039876	11989.563381260286	16
Traditional Housing	708000.00	21240.00	11989.563381260286	-9250.436618739714	-76.54	-1.31	54	25.053425130039876	11989.563381260286	16
Container (Max)	725316.1184254877827938000000	25386.06	11989.563381260286	-13396.5007636317863977830000000	-54.14	-1.85	54	25.053425130039876	11989.563381260286	16
Container (Base)	391212.5582584760990905800000	13692.44	10415.62212173858	-3276.8174173080834681703000000	-119.39	-0.84	55	20.989957493583006	10415.62212173858	35
ODD Cubes Basic	420000.00	14700.00	10415.62212173858	-4284.37787826142	-98.03	-1.02	55	20.989957493583006	10415.62212173858	35
Traditional Housing	708000.00	21240.00	10415.62212173858	-10824.37787826142	-65.41	-1.53	55	20.989957493583006	10415.62212173858	35
Container (Max)	701747.8029606561139503000000	24561.17	10415.62212173858	-14145.5509818843839882605000000	-49.61	-2.02	55	20.989957493583006	10415.62212173858	35
Container (Base)	296897.1090681211422717600000	10391.40	13538.557265510663	3147.1584481264230204884000000	94.34	1.06	56	-8.178897001598568	13538.557265510663	32
ODD Cubes Basic	420000.00	14700.00	13538.557265510663	-1161.442734489337	-361.62	-0.28	56	-8.178897001598568	13538.557265510663	32
Container (Max)	532566.9884458782256716000000	18639.84	13538.557265510663	-5101.2873300950748985060000000	-104.40	-0.96	56	-8.178897001598568	13538.557265510663	32
Traditional Housing	708000.00	21240.00	13538.557265510663	-7701.442734489337	-91.93	-1.09	56	-8.178897001598568	13538.557265510663	32
Container (Base)	268643.2547896964574760800000	9402.51	9571.474737469163	168.9608198297869883372000000	1589.97	0.06	57	-16.916941208037144	9571.474737469163	39
ODD Cubes Basic	420000.00	14700.00	9571.474737469163	-5128.525262530837	-81.89	-1.22	57	-16.916941208037144	9571.474737469163	39
Container (Max)	481885.8951463241629428000000	16866.01	9571.474737469163	-7294.5315926521827029980000000	-66.06	-1.51	57	-16.916941208037144	9571.474737469163	39
Traditional Housing	708000.00	21240.00	9571.474737469163	-11668.525262530837	-60.68	-1.65	57	-16.916941208037144	9571.474737469163	39
ODD Cubes Basic	420000.00	14700.00	12407.874865164074	-2292.125134835926	-183.24	-0.55	58	40.36923112223765	12407.874865164074	17
Container (Base)	453874.0829875768846395000000	15885.59	12407.874865164074	-3477.7180394011169623825000000	-130.51	-0.77	58	40.36923112223765	12407.874865164074	17
Traditional Housing	708000.00	21240.00	12407.874865164074	-8832.125134835926	-80.16	-1.25	58	40.36923112223765	12407.874865164074	17
Container (Max)	814148.5589705344818825000000	28495.20	12407.874865164074	-16087.3246988046328658875000000	-50.61	-1.98	58	40.36923112223765	12407.874865164074	17
ODD Cubes Basic	420000.00	14700.00	19774.89337575587	5074.89337575587	82.76	1.21	59	58.368798052624896	19774.89337575587	19
Container (Base)	512074.4226872989174732800000	17922.60	19774.89337575587	1852.2885817004078884352000000	276.45	0.36	59	58.368798052624896	19774.89337575587	19
Traditional Housing	708000.00	21240.00	19774.89337575587	-1465.10662424413	-483.24	-0.21	59	58.368798052624896	19774.89337575587	19
Container (Max)	918546.9471451270280448000000	32149.14	19774.89337575587	-12374.2497743235759815680000000	-74.23	-1.35	59	58.368798052624896	19774.89337575587	19
Container (Base)	410002.7296410398024239500000	14350.10	9719.731631587	-4630.3639058493930848382500000	-88.55	-1.13	60	26.801176967195765	9719.731631587	16
ODD Cubes Basic	420000.00	14700.00	9719.731631587	-4980.268368413	-84.33	-1.19	60	26.801176967195765	9719.731631587	16
Traditional Housing	708000.00	21240.00	9719.731631587	-11520.268368413	-61.46	-1.63	60	26.801176967195765	9719.731631587	16
Container (Max)	735453.1664685837967882500000	25740.86	9719.731631587	-16021.1291948134328875887500000	-45.91	-2.18	60	26.801176967195765	9719.731631587	16
Container (Base)	338037.7521381578036021700000	11831.32	12902.816496924519	1071.4951720889958739240500000	315.48	0.32	61	4.544632832056919	12902.816496924519	21
ODD Cubes Basic	420000.00	14700.00	12902.816496924519	-1797.183503075481	-233.70	-0.43	61	4.544632832056919	12902.816496924519	21
Traditional Housing	708000.00	21240.00	12902.816496924519	-8337.183503075481	-84.92	-1.18	61	4.544632832056919	12902.816496924519	21
Container (Max)	606364.0976575717330459500000	21222.74	12902.816496924519	-8319.9269210904916566082500000	-72.88	-1.37	61	4.544632832056919	12902.816496924519	21
ODD Cubes Basic	420000.00	14700.00	10153.584703641012	-4546.415296358988	-92.38	-1.08	62	59.966326463370876	10153.584703641012	27
Container (Base)	517239.9189764572915846800000	18103.40	10153.584703641012	-7949.8124605349932054638000000	-65.06	-1.54	62	59.966326463370876	10153.584703641012	27
Traditional Housing	708000.00	21240.00	10153.584703641012	-11086.415296358988	-63.86	-1.57	62	59.966326463370876	10153.584703641012	27
Container (Max)	927812.6918038742493438000000	32473.44	10153.584703641012	-22319.8595094945867270330000000	-41.57	-2.41	62	59.966326463370876	10153.584703641012	27
Container (Base)	313610.9929119439546249800000	10976.38	10140.456902693351	-835.9278492246874118743000000	-375.17	-0.27	63	-3.009809115414914	10140.456902693351	31
ODD Cubes Basic	420000.00	14700.00	10140.456902693351	-4559.543097306649	-92.11	-1.09	63	-3.009809115414914	10140.456902693351	31
Traditional Housing	708000.00	21240.00	10140.456902693351	-11099.543097306649	-63.79	-1.57	63	-3.009809115414914	10140.456902693351	31
Container (Max)	562547.9566401377280543000000	19689.18	10140.456902693351	-9548.7215797114694819005000000	-58.91	-1.70	63	-3.009809115414914	10140.456902693351	31
Container (Base)	406507.0941831459147480000000	14227.75	13859.518439559368	-368.2298568507390161800000000	-1103.95	-0.09	64	25.7200849200836	13859.518439559368	36
ODD Cubes Basic	420000.00	14700.00	13859.518439559368	-840.481560440632	-499.71	-0.20	64	25.7200849200836	13859.518439559368	36
Traditional Housing	708000.00	21240.00	13859.518439559368	-7380.481560440632	-95.93	-1.04	64	25.7200849200836	13859.518439559368	36
Container (Max)	729182.7785407308841800000000	25521.40	13859.518439559368	-11661.8788093662129463000000000	-62.53	-1.60	64	25.7200849200836	13859.518439559368	36
ODD Cubes Basic	420000.00	14700.00	19143.18999522086	4443.18999522086	94.53	1.06	65	49.70267766202258	19143.18999522086	37
Container (Base)	484053.1290327136708494000000	16941.86	19143.18999522086	2201.3304790758815202710000000	219.89	0.45	65	49.70267766202258	19143.18999522086	37
Traditional Housing	708000.00	21240.00	19143.18999522086	-2096.81000477914	-337.66	-0.30	65	49.70267766202258	19143.18999522086	37
Container (Max)	868283.0155736140651290000000	30389.91	19143.18999522086	-11246.7155498556322795150000000	-77.20	-1.30	65	49.70267766202258	19143.18999522086	37
ODD Cubes Basic	420000.00	14700.00	9167.129163159918	-5532.870836840082	-75.91	-1.32	66	38.05386418697189	9167.129163159918	25
Container (Base)	446387.5060780805182827000000	15623.56	9167.129163159918	-6456.4335495729001398945000000	-69.14	-1.45	66	38.05386418697189	9167.129163159918	25
Traditional Housing	708000.00	21240.00	9167.129163159918	-12072.870836840082	-58.64	-1.71	66	38.05386418697189	9167.129163159918	25
Container (Max)	800719.3149776463105945000000	28025.18	9167.129163159918	-18858.0468610577028708075000000	-42.46	-2.36	66	38.05386418697189	9167.129163159918	25
Container (Base)	307374.9581989110173418900000	10758.12	10747.18029870951	-10.9432382523756069661500000	-28088.12	0.00	67	-4.938421985658877	10747.18029870951	18
ODD Cubes Basic	420000.00	14700.00	10747.18029870951	-3952.81970129049	-106.25	-0.94	67	-4.938421985658877	10747.18029870951	18
Traditional Housing	708000.00	21240.00	10747.18029870951	-10492.81970129049	-67.47	-1.48	67	-4.938421985658877	10747.18029870951	18
Container (Max)	551361.9055620792304561500000	19297.67	10747.18029870951	-8550.4863959632630659652500000	-64.48	-1.55	67	-4.938421985658877	10747.18029870951	18
ODD Cubes Basic	420000.00	14700.00	18129.363629922023	3429.363629922023	122.47	0.82	68	44.58893218346151	18129.363629922023	15
Container (Base)	467518.1909899699502793000000	16363.14	18129.363629922023	1766.2269452730747402245000000	264.70	0.38	68	44.58893218346151	18129.363629922023	15
Traditional Housing	708000.00	21240.00	18129.363629922023	-3110.636370077977	-227.61	-0.44	68	44.58893218346151	18129.363629922023	15
Container (Max)	838623.0361106859310755000000	29351.81	18129.363629922023	-11222.4426339519845876425000000	-74.73	-1.34	68	44.58893218346151	18129.363629922023	15
Container (Base)	375865.8842865550772813400000	13155.31	12736.357487903642	-418.9484621257857048469000000	-897.16	-0.11	69	16.243705379907738	12736.357487903642	33
ODD Cubes Basic	420000.00	14700.00	12736.357487903642	-1963.642512096358	-213.89	-0.47	69	16.243705379907738	12736.357487903642	33
Traditional Housing	708000.00	21240.00	12736.357487903642	-8503.642512096358	-83.26	-1.20	69	16.243705379907738	12736.357487903642	33
Container (Max)	674219.3033887338757869000000	23597.68	12736.357487903642	-10861.3181307020436525415000000	-62.08	-1.61	69	16.243705379907738	12736.357487903642	33
Container (Base)	278494.9625142581069844000000	9747.32	13939.246525050774	4191.9228370517402555460000000	66.44	1.51	70	-13.87011238398292	13939.246525050774	24
ODD Cubes Basic	420000.00	14700.00	13939.246525050774	-760.753474949226	-552.08	-0.18	70	-13.87011238398292	13939.246525050774	24
Container (Max)	499557.6546672798648540000000	17484.52	13939.246525050774	-3545.2713883040212698900000000	-140.91	-0.71	70	-13.87011238398292	13939.246525050774	24
Traditional Housing	708000.00	21240.00	13939.246525050774	-7300.753474949226	-96.98	-1.03	70	-13.87011238398292	13939.246525050774	24
Container (Base)	270927.8799250327932465900000	9482.48	18204.46848083165	8721.9926834555022363693500000	31.06	3.22	71	-16.210377238711587	18204.46848083165	37
ODD Cubes Basic	420000.00	14700.00	18204.46848083165	3504.46848083165	119.85	0.83	71	-16.210377238711587	18204.46848083165	37
Container (Max)	485984.0014966108598206500000	17009.44	18204.46848083165	1195.0284284502699062772500000	406.67	0.25	71	-16.210377238711587	18204.46848083165	37
Traditional Housing	708000.00	21240.00	18204.46848083165	-3035.53151916835	-233.24	-0.43	71	-16.210377238711587	18204.46848083165	37
Container (Base)	273327.9321070735744446000000	9566.48	12226.719751492139	2660.2421277445638944390000000	102.75	0.97	72	-15.46811525003678	12226.719751492139	35
ODD Cubes Basic	420000.00	14700.00	12226.719751492139	-2473.280248507861	-169.81	-0.59	72	-15.46811525003678	12226.719751492139	35
Container (Max)	490289.1581440241741610000000	17160.12	12226.719751492139	-4933.4007835487070956350000000	-99.38	-1.01	72	-15.46811525003678	12226.719751492139	35
Traditional Housing	708000.00	21240.00	12226.719751492139	-9013.280248507861	-78.55	-1.27	72	-15.46811525003678	12226.719751492139	35
Container (Base)	229526.3672043716922250500000	8033.42	17378.78952520447	9345.3666730514607721232500000	24.56	4.07	73	-29.014585995561465	17378.78952520447	29
Container (Max)	411718.9504964437249267500000	14410.16	17378.78952520447	2968.6262578289396275637500000	138.69	0.72	73	-29.014585995561465	17378.78952520447	29
ODD Cubes Basic	420000.00	14700.00	17378.78952520447	2678.78952520447	156.79	0.64	73	-29.014585995561465	17378.78952520447	29
Traditional Housing	708000.00	21240.00	17378.78952520447	-3861.21047479553	-183.36	-0.55	73	-29.014585995561465	17378.78952520447	29
Container (Base)	320664.7081861081853241690000	11223.26	19111.08539669701	7887.8206101832235136540850000	40.65	2.46	74	-0.8283129104053017	19111.08539669701	31
ODD Cubes Basic	420000.00	14700.00	19111.08539669701	4411.08539669701	95.21	1.05	74	-0.8283129104053017	19111.08539669701	31
Container (Max)	575200.7437040037298749150000	20132.03	19111.08539669701	-1020.9406329431205456220250000	-563.40	-0.18	74	-0.8283129104053017	19111.08539669701	31
Traditional Housing	708000.00	21240.00	19111.08539669701	-2128.91460330299	-332.56	-0.30	74	-0.8283129104053017	19111.08539669701	31
ODD Cubes Basic	420000.00	14700.00	19093.281106450035	4393.281106450035	95.60	1.05	75	32.71393764644234	19093.281106450035	32
Container (Base)	429121.2274041360554262000000	15019.24	19093.281106450035	4074.0381473052730600830000000	105.33	0.95	75	32.71393764644234	19093.281106450035	32
Traditional Housing	708000.00	21240.00	19093.281106450035	-2146.718893549965	-329.81	-0.30	75	32.71393764644234	19093.281106450035	32
Container (Max)	769747.4740462478941170000000	26941.16	19093.281106450035	-7847.8804851686412940950000000	-98.08	-1.02	75	32.71393764644234	19093.281106450035	32
Container (Base)	298176.1912498774901832000000	10436.17	15081.925646711767	4645.7589529660548435880000000	64.18	1.56	76	-7.78331640088776	15081.925646711767	34
ODD Cubes Basic	420000.00	14700.00	15081.925646711767	381.925646711767	1099.69	0.09	76	-7.78331640088776	15081.925646711767	34
Container (Max)	534861.3757090309476120000000	18720.15	15081.925646711767	-3638.2225031043161664200000000	-147.01	-0.68	76	-7.78331640088776	15081.925646711767	34
Traditional Housing	708000.00	21240.00	15081.925646711767	-6158.074353288233	-114.97	-0.87	76	-7.78331640088776	15081.925646711767	34
Container (Base)	323768.6880415123240491255000	11331.90	19959.657467687946	8627.7533862350146582806075000	37.53	2.66	77	0.13165215932069785	19959.657467687946	19
ODD Cubes Basic	420000.00	14700.00	19959.657467687946	5259.657467687946	79.85	1.25	77	0.13165215932069785	19959.657467687946	19
Container (Max)	580768.5891066680135648925000	20326.90	19959.657467687946	-367.2431510454344747712375000	-1581.43	-0.06	77	0.13165215932069785	19959.657467687946	19
Traditional Housing	708000.00	21240.00	19959.657467687946	-1280.342532312054	-552.98	-0.18	77	0.13165215932069785	19959.657467687946	19
ODD Cubes Basic	420000.00	14700.00	16960.938779893047	2260.938779893047	185.76	0.54	78	53.53819628744303	16960.938779893047	33
Container (Base)	496455.0100217069164929000000	17375.93	16960.938779893047	-414.9865708666950772515000000	-1196.32	-0.08	78	53.53819628744303	16960.938779893047	33
Traditional Housing	708000.00	21240.00	16960.938779893047	-4279.061220106953	-165.46	-0.60	78	53.53819628744303	16960.938779893047	33
Container (Max)	890529.2153769839461515000000	31168.52	16960.938779893047	-14207.5837583013911153025000000	-62.68	-1.60	78	53.53819628744303	16960.938779893047	33
ODD Cubes Basic	420000.00	14700.00	18196.331031726324	3496.331031726324	120.13	0.83	79	37.57647527372181	18196.331031726324	34
Container (Base)	444843.9024443103121083000000	15569.54	18196.331031726324	2626.7944461754630762095000000	169.35	0.59	79	37.57647527372181	18196.331031726324	34
Traditional Housing	708000.00	21240.00	18196.331031726324	-3043.668968273676	-232.61	-0.43	79	37.57647527372181	18196.331031726324	34
Container (Max)	797950.4354113501840905000000	27928.27	18196.331031726324	-9731.9342076709324431675000000	-81.99	-1.22	79	37.57647527372181	18196.331031726324	34
Container (Base)	313560.0819237542585076000000	10974.60	8660.224233772533	-2314.3786335588660477660000000	-135.48	-0.74	80	-3.02555431113268	8660.224233772533	26
ODD Cubes Basic	420000.00	14700.00	8660.224233772533	-6039.775766227467	-69.54	-1.44	80	-3.02555431113268	8660.224233772533	26
Traditional Housing	708000.00	21240.00	8660.224233772533	-12579.775766227467	-56.28	-1.78	80	-3.02555431113268	8660.224233772533	26
Container (Max)	562456.6337177148993660000000	19685.98	8660.224233772533	-11025.7579463474884778100000000	-51.01	-1.96	80	-3.02555431113268	8660.224233772533	26
ODD Cubes Basic	420000.00	14700.00	13358.241507496288	-1341.758492503712	-313.02	-0.32	81	49.219147536681135	13358.241507496288	36
Container (Base)	482489.6682195308823430500000	16887.14	13358.241507496288	-3528.8968801872928820067500000	-136.73	-0.73	81	49.219147536681135	13358.241507496288	36
Traditional Housing	708000.00	21240.00	13358.241507496288	-7881.758492503712	-89.83	-1.11	81	49.219147536681135	13358.241507496288	36
Container (Max)	865478.5166701274170567500000	30291.75	13358.241507496288	-16933.5065759581715969862500000	-51.11	-1.96	81	49.219147536681135	13358.241507496288	36
ODD Cubes Basic	420000.00	14700.00	19572.988390328515	4872.988390328515	86.19	1.16	82	35.64312658084576	19572.988390328515	18
Container (Base)	438592.5547803041057568000000	15350.74	19572.988390328515	4222.2489730178712985120000000	103.88	0.96	82	35.64312658084576	19572.988390328515	18
Traditional Housing	708000.00	21240.00	19572.988390328515	-1667.011609671485	-424.71	-0.24	82	35.64312658084576	19572.988390328515	18
Container (Max)	786736.9163252344502880000000	27535.79	19572.988390328515	-7962.8036810546907600800000000	-98.80	-1.01	82	35.64312658084576	19572.988390328515	18
Container (Base)	242453.8704917032844401800000	8485.89	10219.10101039801	1733.2155431883950445937000000	139.89	0.71	83	-25.016508632720274	10219.10101039801	28
ODD Cubes Basic	420000.00	14700.00	10219.10101039801	-4480.89898960199	-93.73	-1.07	83	-25.016508632720274	10219.10101039801	28
Container (Max)	434907.9991047907747863000000	15221.78	10219.10101039801	-5002.6789582696671175205000000	-86.94	-1.15	83	-25.016508632720274	10219.10101039801	28
Traditional Housing	708000.00	21240.00	10219.10101039801	-11020.89898960199	-64.24	-1.56	83	-25.016508632720274	10219.10101039801	28
Container (Base)	353453.0771828093789348100000	12370.86	14169.983934036849	1799.1262326385207372816500000	196.46	0.51	84	9.312116601506567	14169.983934036849	16
ODD Cubes Basic	420000.00	14700.00	14169.983934036849	-530.016065963151	-792.43	-0.13	84	9.312116601506567	14169.983934036849	16
Traditional Housing	708000.00	21240.00	14169.983934036849	-7070.016065963151	-100.14	-1.00	84	9.312116601506567	14169.983934036849	16
Container (Max)	634015.7418945681639283500000	22190.55	14169.983934036849	-8020.5670322730367374922500000	-79.05	-1.27	84	9.312116601506567	14169.983934036849	16
Container (Base)	251991.5449205400606100800000	8819.70	8345.621563272314	-474.0825089465881213528000000	-531.54	-0.19	85	-22.066800604763344	8345.621563272314	39
ODD Cubes Basic	420000.00	14700.00	8345.621563272314	-6354.378436727686	-66.10	-1.51	85	-22.066800604763344	8345.621563272314	39
Container (Max)	452016.4531523423666328000000	15820.58	8345.621563272314	-7474.9542970596688321480000000	-60.47	-1.65	85	-22.066800604763344	8345.621563272314	39
Traditional Housing	708000.00	21240.00	8345.621563272314	-12894.378436727686	-54.91	-1.82	85	-22.066800604763344	8345.621563272314	39
ODD Cubes Basic	420000.00	14700.00	18279.086404094516	3579.086404094516	117.35	0.85	86	40.167273439456196	18279.086404094516	25
Container (Base)	453221.0669573408478322800000	15862.74	18279.086404094516	2416.3490605875863258702000000	187.56	0.53	86	40.167273439456196	18279.086404094516	25
Traditional Housing	708000.00	21240.00	18279.086404094516	-2960.913595905484	-239.12	-0.42	86	40.167273439456196	18279.086404094516	25
Container (Max)	812977.1943125179096098000000	28454.20	18279.086404094516	-10175.1153968436108363430000000	-79.90	-1.25	86	40.167273439456196	18279.086404094516	25
Container (Base)	409805.0768345332553014500000	14343.18	12093.326116103155	-2249.8515731055089355507500000	-182.15	-0.55	87	26.740049060760015	12093.326116103155	34
ODD Cubes Basic	420000.00	14700.00	12093.326116103155	-2606.673883896845	-161.12	-0.62	87	26.740049060760015	12093.326116103155	34
Traditional Housing	708000.00	21240.00	12093.326116103155	-9146.673883896845	-77.41	-1.29	87	26.740049060760015	12093.326116103155	34
Container (Max)	735098.6215548611250007500000	25728.45	12093.326116103155	-13635.1256383169843750262500000	-53.91	-1.85	87	26.740049060760015	12093.326116103155	34
ODD Cubes Basic	420000.00	14700.00	8609.198858378988	-6090.801141621012	-68.96	-1.45	88	43.957397091189165	8609.198858378988	25
Container (Base)	465476.1664765637817859500000	16291.67	8609.198858378988	-7682.4669683007443625082500000	-60.59	-1.65	88	43.957397091189165	8609.198858378988	25
Traditional Housing	708000.00	21240.00	8609.198858378988	-12630.801141621012	-56.05	-1.78	88	43.957397091189165	8609.198858378988	25
Container (Max)	834960.1009987517164582500000	29223.60	8609.198858378988	-20614.4046765773220760387500000	-40.50	-2.47	88	43.957397091189165	8609.198858378988	25
ODD Cubes Basic	420000.00	14700.00	17943.90090779379	3243.90090779379	129.47	0.77	89	32.039584724243724	17943.90090779379	23
Container (Base)	426940.7544349113844933200000	14942.93	17943.90090779379	3000.9745025718915427338000000	142.27	0.70	89	32.039584724243724	17943.90090779379	23
Traditional Housing	708000.00	21240.00	17943.90090779379	-3296.09909220621	-214.80	-0.47	89	32.039584724243724	17943.90090779379	23
Container (Max)	765836.1933798498113862000000	26804.27	17943.90090779379	-8860.3658605009533985170000000	-86.43	-1.16	89	32.039584724243724	17943.90090779379	23
Container (Base)	347895.7324109519229677700000	12176.35	17772.045193084006	5595.6945587006886961280500000	62.17	1.61	90	7.593401561484839	17772.045193084006	16
ODD Cubes Basic	420000.00	14700.00	17772.045193084006	3072.045193084006	136.72	0.73	90	7.593401561484839	17772.045193084006	16
Traditional Housing	708000.00	21240.00	17772.045193084006	-3467.954806915994	-204.15	-0.49	90	7.593401561484839	17772.045193084006	16
Container (Max)	624047.1087266901404419500000	21841.65	17772.045193084006	-4069.6036123501489154682500000	-153.34	-0.65	90	7.593401561484839	17772.045193084006	16
Container (Base)	411298.8009522340066389900000	14395.46	8595.212721698103	-5800.2453116300872323646500000	-70.91	-1.41	91	27.202011780751093	8595.212721698103	34
ODD Cubes Basic	420000.00	14700.00	8595.212721698103	-6104.787278301897	-68.80	-1.45	91	27.202011780751093	8595.212721698103	34
Traditional Housing	708000.00	21240.00	8595.212721698103	-12644.787278301897	-55.99	-1.79	91	27.202011780751093	8595.212721698103	34
Container (Max)	737778.0284289453769546500000	25822.23	8595.212721698103	-17227.0182733149851934127500000	-42.83	-2.33	91	27.202011780751093	8595.212721698103	34
Container (Base)	390246.3592285706850627900000	13658.62	14032.957421045074	374.3348480451000228023500000	1042.51	0.10	92	20.691141985003753	14032.957421045074	26
ODD Cubes Basic	420000.00	14700.00	14032.957421045074	-667.042578954926	-629.64	-0.16	92	20.691141985003753	14032.957421045074	26
Traditional Housing	708000.00	21240.00	14032.957421045074	-7207.042578954926	-98.24	-1.02	92	20.691141985003753	14032.957421045074	26
Container (Max)	700014.6580701210175876500000	24500.51	14032.957421045074	-10467.5556114091616155677500000	-66.87	-1.50	92	20.691141985003753	14032.957421045074	26
Container (Base)	321594.3853641464072844960000	11255.80	18754.708429047125	7498.9049413020007450426400000	42.89	2.33	93	-0.5407924822413328	18754.708429047125	36
ODD Cubes Basic	420000.00	14700.00	18754.708429047125	4054.708429047125	103.58	0.97	93	-0.5407924822413328	18754.708429047125	36
Container (Max)	576868.3765633761576933600000	20190.39	18754.708429047125	-1435.6847506710405192676000000	-401.81	-0.25	93	-0.5407924822413328	18754.708429047125	36
Traditional Housing	708000.00	21240.00	18754.708429047125	-2485.291570952875	-284.88	-0.35	93	-0.5407924822413328	18754.708429047125	36
ODD Cubes Basic	420000.00	14700.00	12995.354376222447	-1704.645623777553	-246.39	-0.41	94	31.448921920639165	12995.354376222447	16
Container (Base)	425030.8876058522952859500000	14876.08	12995.354376222447	-1880.7266899823833350082500000	-225.99	-0.44	94	31.448921920639165	12995.354376222447	16
Traditional Housing	708000.00	21240.00	12995.354376222447	-8244.645623777553	-85.87	-1.16	94	31.448921920639165	12995.354376222447	16
Container (Max)	762410.3195858031889582500000	26684.36	12995.354376222447	-13689.0068092806646135387500000	-55.70	-1.80	94	31.448921920639165	12995.354376222447	16
Container (Base)	405942.7991603824297458000000	14208.00	19223.224853304862	5015.2268826914769588970000000	80.94	1.24	95	25.54556590381806	19223.224853304862	15
ODD Cubes Basic	420000.00	14700.00	19223.224853304862	4523.224853304862	92.85	1.08	95	25.54556590381806	19223.224853304862	15
Traditional Housing	708000.00	21240.00	19223.224853304862	-2016.775146695138	-351.06	-0.28	95	25.54556590381806	19223.224853304862	15
Container (Max)	728170.5595204399389030000000	25485.97	19223.224853304862	-6262.7447299105358616050000000	-116.27	-0.86	95	25.54556590381806	19223.224853304862	15
Container (Base)	313752.7462157026879639500000	10981.35	15502.879726938814	4521.5336093892199212617500000	69.39	1.44	96	-2.965969198126235	15502.879726938814	25
ODD Cubes Basic	420000.00	14700.00	15502.879726938814	802.879726938814	523.12	0.19	96	-2.965969198126235	15502.879726938814	25
Container (Max)	562802.2303524079306882500000	19698.08	15502.879726938814	-4195.1983353954635740887500000	-134.15	-0.75	96	-2.965969198126235	15502.879726938814	25
Traditional Housing	708000.00	21240.00	15502.879726938814	-5737.120273061186	-123.41	-0.81	96	-2.965969198126235	15502.879726938814	25
Container (Base)	274864.7070566411595357600000	9620.26	12996.6930085661	3376.4282615836594162484000000	81.41	1.23	97	-14.992838237833768	12996.6930085661	32
ODD Cubes Basic	420000.00	14700.00	12996.6930085661	-1703.3069914339	-246.58	-0.41	97	-14.992838237833768	12996.6930085661	32
Container (Max)	493045.7885786522539116000000	17256.60	12996.6930085661	-4259.9095916867288869060000000	-115.74	-0.86	97	-14.992838237833768	12996.6930085661	32
Traditional Housing	708000.00	21240.00	12996.6930085661	-8243.3069914339	-85.89	-1.16	97	-14.992838237833768	12996.6930085661	32
Container (Base)	396376.4189686127380884000000	13873.17	17569.79523028722	3696.6205663857741669060000000	107.23	0.93	98	22.58698007026988	17569.79523028722	31
ODD Cubes Basic	420000.00	14700.00	17569.79523028722	2869.79523028722	146.35	0.68	98	22.58698007026988	17569.79523028722	31
Traditional Housing	708000.00	21240.00	17569.79523028722	-3670.20476971278	-192.90	-0.52	98	22.58698007026988	17569.79523028722	31
Container (Max)	711010.6137565688174940000000	24885.37	17569.79523028722	-7315.5762511926886122900000000	-97.19	-1.03	98	22.58698007026988	17569.79523028722	31
ODD Cubes Basic	420000.00	14700.00	14736.717207546335	36.717207546335	11438.78	0.01	99	49.66921269273362	14736.717207546335	39
Container (Base)	483944.9223970656689166000000	16938.07	14736.717207546335	-2201.3550763509634120810000000	-219.84	-0.45	99	49.66921269273362	14736.717207546335	39
Traditional Housing	708000.00	21240.00	14736.717207546335	-6503.282792453665	-108.87	-0.92	99	49.66921269273362	14736.717207546335	39
Container (Max)	868088.9170784896326810000000	30383.11	14736.717207546335	-15646.3948902008021438350000000	-55.48	-1.80	99	49.66921269273362	14736.717207546335	39
Container (Base)	363259.0454234979432672000000	12714.07	11720.341471802625	-993.7251180198030143520000000	-365.55	-0.27	100	12.34479961635104	11720.341471802625	34
ODD Cubes Basic	420000.00	14700.00	11720.341471802625	-2979.658528197375	-140.96	-0.71	100	12.34479961635104	11720.341471802625	34
Traditional Housing	708000.00	21240.00	11720.341471802625	-9519.658528197375	-74.37	-1.34	100	12.34479961635104	11720.341471802625	34
Container (Max)	651605.4550148168495520000000	22806.19	11720.341471802625	-11085.8494537159647343200000000	-58.78	-1.70	100	12.34479961635104	11720.341471802625	34
ODD Cubes Basic	420000.00	14700.00	14976.935788454444	276.935788454444	1516.60	0.07	101	45.8341492839467	14976.935788454444	21
Container (Base)	471544.5133191917781810000000	16504.06	14976.935788454444	-1527.1221777172682363350000000	-308.78	-0.32	101	45.8341492839467	14976.935788454444	21
Traditional Housing	708000.00	21240.00	14976.935788454444	-6263.064211545556	-113.04	-0.88	101	45.8341492839467	14976.935788454444	21
Container (Max)	845845.3575543550573350000000	29604.59	14976.935788454444	-14627.6517259479830067250000000	-57.83	-1.73	101	45.8341492839467	14976.935788454444	21
Container (Base)	368887.8772817704369897200000	12911.08	11227.076439158933	-1683.9992657030322946402000000	-219.05	-0.46	102	14.085623403559204	11227.076439158933	34
ODD Cubes Basic	420000.00	14700.00	11227.076439158933	-3472.923560841067	-120.94	-0.83	102	14.085623403559204	11227.076439158933	34
Traditional Housing	708000.00	21240.00	11227.076439158933	-10012.923560841067	-70.71	-1.41	102	14.085623403559204	11227.076439158933	34
Container (Max)	661702.3200218135611602000000	23159.58	11227.076439158933	-11932.5047616045416406070000000	-55.45	-1.80	102	14.085623403559204	11227.076439158933	34
ODD Cubes Basic	420000.00	14700.00	15186.832305049746	486.832305049746	862.72	0.12	103	46.79901037704002	15186.832305049746	29
Container (Base)	474664.3241234325118686000000	16613.25	15186.832305049746	-1426.4190392703919154010000000	-332.77	-0.30	103	46.79901037704002	15186.832305049746	29
Traditional Housing	708000.00	21240.00	15186.832305049746	-6053.167694950254	-116.96	-0.85	103	46.79901037704002	15186.832305049746	29
Container (Max)	851441.6001373509680010000000	29800.46	15186.832305049746	-14613.6236997575378800350000000	-58.26	-1.72	103	46.79901037704002	15186.832305049746	29
ODD Cubes Basic	420000.00	14700.00	12677.856317692347	-2022.143682307653	-207.70	-0.48	104	46.44858355717757	12677.856317692347	34
Container (Base)	473531.2435312846701651000000	16573.59	12677.856317692347	-3895.7372059026164557785000000	-121.55	-0.82	104	46.44858355717757	12677.856317692347	34
Traditional Housing	708000.00	21240.00	12677.856317692347	-8562.143682307653	-82.69	-1.21	104	46.44858355717757	12677.856317692347	34
Container (Max)	849409.1070608077648785000000	29729.32	12677.856317692347	-17051.4624294359247707475000000	-49.81	-2.01	104	46.44858355717757	12677.856317692347	34
ODD Cubes Basic	420000.00	14700.00	10606.007461260135	-4093.992538739865	-102.59	-0.97	105	54.14564653396785	10606.007461260135	33
Container (Base)	498419.1578723276652255000000	17444.67	10606.007461260135	-6838.6630642713332828925000000	-72.88	-1.37	105	54.14564653396785	10606.007461260135	33
Traditional Housing	708000.00	21240.00	10606.007461260135	-10633.992538739865	-66.58	-1.50	105	54.14564653396785	10606.007461260135	33
Container (Max)	894052.4571793402283925000000	31291.84	10606.007461260135	-20685.8285400167729937375000000	-43.22	-2.31	105	54.14564653396785	10606.007461260135	33
ODD Cubes Basic	420000.00	14700.00	14863.385724742235	163.385724742235	2570.60	0.04	106	30.21867263592089	14863.385724742235	19
Container (Base)	421052.9626611656833527000000	14736.85	14863.385724742235	126.5320316014360826555000000	3327.64	0.03	106	30.21867263592089	14863.385724742235	19
Traditional Housing	708000.00	21240.00	14863.385724742235	-6376.614275257765	-111.03	-0.90	106	30.21867263592089	14863.385724742235	19
Container (Max)	755274.8122219729580445000000	26434.62	14863.385724742235	-11571.2327030268185315575000000	-65.27	-1.53	106	30.21867263592089	14863.385724742235	19
Container (Base)	231973.6656373670811528900000	8119.08	16147.991194204162	8028.9128968963141596488500000	28.89	3.46	107	-28.257712201171177	16147.991194204162	32
Container (Max)	416108.8563475971148411500000	14563.81	16147.991194204162	1584.1812220382629805597500000	262.66	0.38	107	-28.257712201171177	16147.991194204162	32
ODD Cubes Basic	420000.00	14700.00	16147.991194204162	1447.991194204162	290.06	0.34	107	-28.257712201171177	16147.991194204162	32
Traditional Housing	708000.00	21240.00	16147.991194204162	-5092.008805795838	-139.04	-0.72	107	-28.257712201171177	16147.991194204162	32
Container (Base)	415771.8530599746196946100000	14552.01	16714.267176811853	2162.2523197127413106886500000	192.29	0.52	108	28.585388599714427	16714.267176811853	33
ODD Cubes Basic	420000.00	14700.00	16714.267176811853	2014.267176811853	208.51	0.48	108	28.585388599714427	16714.267176811853	33
Traditional Housing	708000.00	21240.00	16714.267176811853	-4525.732823188147	-156.44	-0.64	108	28.585388599714427	16714.267176811853	33
Container (Max)	745801.6831477736623213500000	26103.06	16714.267176811853	-9388.7917333602251812472500000	-79.44	-1.26	108	28.585388599714427	16714.267176811853	33
ODD Cubes Basic	420000.00	14700.00	11264.484597483462	-3435.515402516538	-122.25	-0.82	109	67.01698478551461	11264.484597483462	15
Traditional Housing	708000.00	21240.00	11264.484597483462	-9975.515402516538	-70.97	-1.41	109	67.01698478551461	11264.484597483462	15
Container (Base)	540037.7291150265054123000000	18901.32	11264.484597483462	-7636.8359215424656894305000000	-70.71	-1.41	109	67.01698478551461	11264.484597483462	15
Container (Max)	968706.8626052240137305000000	33904.74	11264.484597483462	-22640.2555936993784805675000000	-42.79	-2.34	109	67.01698478551461	11264.484597483462	15
Container (Base)	312616.8131139326458363950000	10941.59	9480.383498399005	-1461.2049605886376042738250000	-213.94	-0.47	110	-3.3172782110846235	9480.383498399005	28
ODD Cubes Basic	420000.00	14700.00	9480.383498399005	-5219.616501600995	-80.47	-1.24	110	-3.3172782110846235	9480.383498399005	28
Traditional Housing	708000.00	21240.00	9480.383498399005	-11759.616501600995	-60.21	-1.66	110	-3.3172782110846235	9480.383498399005	28
Container (Max)	560764.6205117986294688250000	19626.76	9480.383498399005	-10146.3782195139470314088750000	-55.27	-1.81	110	-3.3172782110846235	9480.383498399005	28
Container (Base)	333649.3180487863569588810000	11677.73	12041.329209154166	363.6030774466435064391650000	917.62	0.11	111	3.1874257518444367	12041.329209154166	37
ODD Cubes Basic	420000.00	14700.00	12041.329209154166	-2658.670790845834	-157.97	-0.63	111	3.1874257518444367	12041.329209154166	37
Traditional Housing	708000.00	21240.00	12041.329209154166	-9198.670790845834	-76.97	-1.30	111	3.1874257518444367	12041.329209154166	37
Container (Max)	598492.2287319853250818350000	20947.23	12041.329209154166	-8905.8987964653203778642250000	-67.20	-1.49	111	3.1874257518444367	12041.329209154166	37
ODD Cubes Basic	420000.00	14700.00	19245.458411674503	4545.458411674503	92.40	1.08	112	40.55769347398173	19245.458411674503	28
Container (Base)	454483.4628095767452339000000	15906.92	19245.458411674503	3338.5372133393169168135000000	136.13	0.73	112	40.55769347398173	19245.458411674503	28
Traditional Housing	708000.00	21240.00	19245.458411674503	-1994.541588325497	-354.97	-0.28	112	40.55769347398173	19245.458411674503	28
Container (Max)	815241.6500337677330865000000	28533.46	19245.458411674503	-9287.9993395073676580275000000	-87.77	-1.14	112	40.55769347398173	19245.458411674503	28
Container (Base)	234594.6805882986631897500000	8210.81	12822.353254475358	4611.5394338849047883587500000	50.87	1.97	113	-27.447113254872175	12822.353254475358	32
ODD Cubes Basic	420000.00	14700.00	12822.353254475358	-1877.646745524642	-223.68	-0.45	113	-27.447113254872175	12822.353254475358	32
Container (Max)	420810.3707660786413912500000	14728.36	12822.353254475358	-1906.0097223373944486937500000	-220.78	-0.45	113	-27.447113254872175	12822.353254475358	32
Traditional Housing	708000.00	21240.00	12822.353254475358	-8417.646745524642	-84.11	-1.19	113	-27.447113254872175	12822.353254475358	32
ODD Cubes Basic	420000.00	14700.00	9530.017471585788	-5169.982528414212	-81.24	-1.23	114	42.76747825424947	9530.017471585788	36
Container (Base)	461628.6472116378637821000000	16157.00	9530.017471585788	-6626.9851808215372323735000000	-69.66	-1.44	114	42.76747825424947	9530.017471585788	36
Traditional Housing	708000.00	21240.00	9530.017471585788	-11709.982528414212	-60.46	-1.65	114	42.76747825424947	9530.017471585788	36
Container (Max)	828058.5122485596384735000000	28982.05	9530.017471585788	-19452.0304571137993465725000000	-42.57	-2.35	114	42.76747825424947	9530.017471585788	36
Container (Base)	271360.6016268758755744800000	9497.62	12450.773071938846	2953.1520149981903548932000000	91.89	1.09	115	-16.076549785560264	12450.773071938846	17
ODD Cubes Basic	420000.00	14700.00	12450.773071938846	-2249.226928061154	-186.73	-0.54	115	-16.076549785560264	12450.773071938846	17
Container (Max)	486760.2074162611907868000000	17036.61	12450.773071938846	-4585.8341876302956775380000000	-106.14	-0.94	115	-16.076549785560264	12450.773071938846	17
Traditional Housing	708000.00	21240.00	12450.773071938846	-8789.226928061154	-80.55	-1.24	115	-16.076549785560264	12450.773071938846	17
Container (Base)	409417.9945114379482800000000	14329.63	10769.856615273433	-3559.7731926268951898000000000	-115.01	-0.87	116	26.620336457396	10769.856615273433	17
ODD Cubes Basic	420000.00	14700.00	10769.856615273433	-3930.143384726567	-106.87	-0.94	116	26.620336457396	10769.856615273433	17
Traditional Housing	708000.00	21240.00	10769.856615273433	-10470.143384726567	-67.62	-1.48	116	26.620336457396	10769.856615273433	17
Container (Max)	734404.2824697196698000000000	25704.15	10769.856615273433	-14934.2932711667554430000000000	-49.18	-2.03	116	26.620336457396	10769.856615273433	17
Container (Base)	283740.7763495355683853600000	9930.93	17032.57629846064	7101.6491262268951065124000000	39.95	2.50	117	-12.247744237687048	17032.57629846064	17
ODD Cubes Basic	420000.00	14700.00	17032.57629846064	2332.57629846064	180.06	0.56	117	-12.247744237687048	17032.57629846064	17
Container (Max)	508967.4710342032372476000000	17813.86	17032.57629846064	-781.2851877364733036660000000	-651.45	-0.15	117	-12.247744237687048	17032.57629846064	17
Traditional Housing	708000.00	21240.00	17032.57629846064	-4207.42370153936	-168.27	-0.59	117	-12.247744237687048	17032.57629846064	17
ODD Cubes Basic	420000.00	14700.00	12754.95098985446	-1945.04901014554	-215.93	-0.46	118	34.2542177077687	12754.95098985446	39
Container (Base)	434101.6151628305476410000000	15193.56	12754.95098985446	-2438.6055408446091674350000000	-178.01	-0.56	118	34.2542177077687	12754.95098985446	39
Traditional Housing	708000.00	21240.00	12754.95098985446	-8485.04901014554	-83.44	-1.20	118	34.2542177077687	12754.95098985446	39
Container (Max)	778681.1754159438484350000000	27253.84	12754.95098985446	-14498.8901497035746952250000000	-53.71	-1.86	118	34.2542177077687	12754.95098985446	39
ODD Cubes Basic	420000.00	14700.00	12116.510311916274	-2583.489688083726	-162.57	-0.62	119	51.560807630989856	12116.510311916274	25
Container (Base)	490061.2622182715300860800000	17152.14	12116.510311916274	-5035.6338657232295530128000000	-97.32	-1.03	119	51.560807630989856	12116.510311916274	25
Traditional Housing	708000.00	21240.00	12116.510311916274	-9123.489688083726	-77.60	-1.29	119	51.560807630989856	12116.510311916274	25
Container (Max)	879060.2623001227142928000000	30767.11	12116.510311916274	-18650.5988685880210002480000000	-47.13	-2.12	119	51.560807630989856	12116.510311916274	25
Container (Base)	417597.0486431266570328100000	14615.90	17995.849953263394	3379.9532507539610038516500000	123.55	0.81	120	29.149865202935167	17995.849953263394	36
ODD Cubes Basic	420000.00	14700.00	17995.849953263394	3295.849953263394	127.43	0.78	120	29.149865202935167	17995.849953263394	36
Traditional Housing	708000.00	21240.00	17995.849953263394	-3244.150046736606	-218.24	-0.46	120	29.149865202935167	17995.849953263394	36
Container (Max)	749075.6756702841153583500000	26217.65	17995.849953263394	-8221.7986951965500375422500000	-91.11	-1.10	120	29.149865202935167	17995.849953263394	36
ODD Cubes Basic	420000.00	14700.00	8512.986661903657	-6187.013338096343	-67.88	-1.47	121	34.430108164463036	8512.986661903657	36
Container (Base)	434670.3446422197144934800000	15213.46	8512.986661903657	-6700.4754005740330072718000000	-64.87	-1.54	121	34.430108164463036	8512.986661903657	36
Traditional Housing	708000.00	21240.00	8512.986661903657	-12727.013338096343	-55.63	-1.80	121	34.430108164463036	8512.986661903657	36
Container (Max)	779701.3488592938319518000000	27289.55	8512.986661903657	-18776.5605481716271183130000000	-41.53	-2.41	121	34.430108164463036	8512.986661903657	36
Container (Base)	333889.5503977484774754600000	11686.13	10778.011240383748	-908.1230235374487116411000000	-367.67	-0.27	122	3.261722195238022	10778.011240383748	31
ODD Cubes Basic	420000.00	14700.00	10778.011240383748	-3921.988759616252	-107.09	-0.93	122	3.261722195238022	10778.011240383748	31
Traditional Housing	708000.00	21240.00	10778.011240383748	-10461.988759616252	-67.67	-1.48	122	3.261722195238022	10778.011240383748	31
Container (Max)	598923.1518184902895011000000	20962.31	10778.011240383748	-10184.2990732634121325385000000	-58.81	-1.70	122	3.261722195238022	10778.011240383748	31
ODD Cubes Basic	420000.00	14700.00	11038.246661320438	-3661.753338679562	-114.70	-0.87	123	38.130037083738486	11038.246661320438	26
Container (Base)	446633.8058076725327869800000	15632.18	11038.246661320438	-4593.9365419481006475443000000	-97.22	-1.03	123	38.130037083738486	11038.246661320438	26
Traditional Housing	708000.00	21240.00	11038.246661320438	-10201.753338679562	-69.40	-1.44	123	38.130037083738486	11038.246661320438	26
Container (Max)	801161.1215875374057243000000	28040.64	11038.246661320438	-17002.3925942433712003505000000	-47.12	-2.12	123	38.130037083738486	11038.246661320438	26
Container (Base)	351573.9992253048845201400000	12305.09	12700.376570566332	395.2865976806610417951000000	889.42	0.11	124	8.730975844630898	12700.376570566332	37
ODD Cubes Basic	420000.00	14700.00	12700.376570566332	-1999.623429433668	-210.04	-0.48	124	8.730975844630898	12700.376570566332	37
Traditional Housing	708000.00	21240.00	12700.376570566332	-8539.623429433668	-82.91	-1.21	124	8.730975844630898	12700.376570566332	37
Container (Max)	630645.0964476514399449000000	22072.58	12700.376570566332	-9372.2018051014683980715000000	-67.29	-1.49	124	8.730975844630898	12700.376570566332	37
ODD Cubes Basic	420000.00	14700.00	9042.579635538306	-5657.420364461694	-74.24	-1.35	125	41.681089986958256	9042.579635538306	30
Container (Base)	458115.8867965304336980800000	16034.06	9042.579635538306	-6991.4764023402591794328000000	-65.52	-1.53	125	41.681089986958256	9042.579635538306	30
Traditional Housing	708000.00	21240.00	9042.579635538306	-12197.420364461694	-58.05	-1.72	125	41.681089986958256	9042.579635538306	30
Container (Max)	821757.4059788572327128000000	28761.51	9042.579635538306	-19718.9295737216971449480000000	-41.67	-2.40	125	41.681089986958256	9042.579635538306	30
Container (Base)	356732.9119277303484582000000	12485.65	13363.503372720612	877.8514552500498039630000000	406.37	0.25	126	10.32646815540474	13363.503372720612	39
ODD Cubes Basic	420000.00	14700.00	13363.503372720612	-1336.496627279388	-314.25	-0.32	126	10.32646815540474	13363.503372720612	39
Traditional Housing	708000.00	21240.00	13363.503372720612	-7876.496627279388	-89.89	-1.11	126	10.32646815540474	13363.503372720612	39
Container (Max)	639899.0316247552622370000000	22396.47	13363.503372720612	-9032.9627341458221782950000000	-70.84	-1.41	126	10.32646815540474	13363.503372720612	39
Container (Base)	363249.7590066375866700600000	12713.74	10643.517988055653	-2070.2235771766625334521000000	-175.46	-0.57	127	12.341927614526242	10643.517988055653	17
ODD Cubes Basic	420000.00	14700.00	10643.517988055653	-4056.482011944347	-103.54	-0.97	127	12.341927614526242	10643.517988055653	17
Traditional Housing	708000.00	21240.00	10643.517988055653	-10596.482011944347	-66.81	-1.50	127	12.341927614526242	10643.517988055653	17
Container (Max)	651588.7972606329299121000000	22805.61	10643.517988055653	-12162.0899160664995469235000000	-53.58	-1.87	127	12.341927614526242	10643.517988055653	17
Container (Base)	293949.6169778439240033900000	10288.24	19380.887394371355	9092.6508001468176598813500000	32.33	3.09	128	-9.090465240365827	19380.887394371355	24
ODD Cubes Basic	420000.00	14700.00	19380.887394371355	4680.887394371355	89.73	1.11	128	-9.090465240365827	19380.887394371355	24
Container (Max)	527279.8470826161851086500000	18454.79	19380.887394371355	926.0927464797885211972500000	569.36	0.18	128	-9.090465240365827	19380.887394371355	24
Traditional Housing	708000.00	21240.00	19380.887394371355	-1859.112605628645	-380.83	-0.26	128	-9.090465240365827	19380.887394371355	24
ODD Cubes Basic	420000.00	14700.00	17925.691248949544	3225.691248949544	130.20	0.77	129	56.67466093536734	17925.691248949544	17
Container (Base)	506596.5489082448181762000000	17730.88	17925.691248949544	194.8120371609753638330000000	2600.44	0.04	129	56.67466093536734	17925.691248949544	17
Traditional Housing	708000.00	21240.00	17925.691248949544	-3314.308751050456	-213.62	-0.47	129	56.67466093536734	17925.691248949544	17
Container (Max)	908720.8671581773403670000000	31805.23	17925.691248949544	-13879.5391015866629128450000000	-65.47	-1.53	129	56.67466093536734	17925.691248949544	17
Container (Base)	286838.3318990395359381300000	10039.34	18734.792762037272	8695.4511455708882421654500000	32.99	3.03	130	-11.289766007292709	18734.792762037272	32
ODD Cubes Basic	420000.00	14700.00	18734.792762037272	4034.792762037272	104.09	0.96	130	-11.289766007292709	18734.792762037272	32
Container (Max)	514523.7926694019231645500000	18008.33	18734.792762037272	726.4600186082046892407500000	708.26	0.14	130	-11.289766007292709	18734.792762037272	32
Traditional Housing	708000.00	21240.00	18734.792762037272	-2505.207237962728	-282.61	-0.35	130	-11.289766007292709	18734.792762037272	32
ODD Cubes Basic	420000.00	14700.00	19905.47820490675	5205.47820490675	80.68	1.24	131	40.03187766360071	19905.47820490675	21
Container (Base)	452783.2741938164437353000000	15847.41	19905.47820490675	4058.0636081231744692645000000	111.58	0.90	131	40.03187766360071	19905.47820490675	21
Traditional Housing	708000.00	21240.00	19905.47820490675	-1334.52179509325	-530.53	-0.19	131	40.03187766360071	19905.47820490675	21
Container (Max)	812191.8920427672980355000000	28426.72	19905.47820490675	-8521.2380165901054312425000000	-95.31	-1.05	131	40.03187766360071	19905.47820490675	21
Container (Base)	366074.4008082699395539200000	12812.60	17319.65245351407	4507.0484252246221156128000000	81.22	1.23	132	13.215502054558144	17319.65245351407	39
ODD Cubes Basic	420000.00	14700.00	17319.65245351407	2619.65245351407	160.33	0.62	132	13.215502054558144	17319.65245351407	39
Traditional Housing	708000.00	21240.00	17319.65245351407	-3920.34754648593	-180.60	-0.55	132	13.215502054558144	17319.65245351407	39
Container (Max)	656655.5726915399631072000000	22982.95	17319.65245351407	-5663.2925906898287087520000000	-115.95	-0.86	132	13.215502054558144	17319.65245351407	39
ODD Cubes Basic	420000.00	14700.00	18983.821620184015	4283.821620184015	98.04	1.02	133	48.584312166465025	18983.821620184015	24
Container (Base)	480436.9724884130057857500000	16815.29	18983.821620184015	2168.5275830895597974987500000	221.55	0.45	133	48.584312166465025	18983.821620184015	24
Traditional Housing	708000.00	21240.00	18983.821620184015	-2256.178379815985	-313.80	-0.32	133	48.584312166465025	18983.821620184015	24
Container (Max)	861796.4397811054682512500000	30162.88	18983.821620184015	-11179.0537721546763887937500000	-77.09	-1.30	133	48.584312166465025	18983.821620184015	24
Container (Base)	358863.5314113207725944800000	12560.22	13977.533155976846	1417.3095565806189591932000000	253.20	0.39	134	10.985402934753736	13977.533155976846	20
ODD Cubes Basic	420000.00	14700.00	13977.533155976846	-722.466844023154	-581.34	-0.17	134	10.985402934753736	13977.533155976846	20
Traditional Housing	708000.00	21240.00	13977.533155976846	-7262.466844023154	-97.49	-1.03	134	10.985402934753736	13977.533155976846	20
Container (Max)	643720.8862917184064868000000	22530.23	13977.533155976846	-8552.6978642332982270380000000	-75.27	-1.33	134	10.985402934753736	13977.533155976846	20
Container (Base)	341915.8933657368354737700000	11967.06	17352.30283711942	5385.2465693186307584180500000	63.49	1.58	135	5.744022095959039	17352.30283711942	15
ODD Cubes Basic	420000.00	14700.00	17352.30283711942	2652.30283711942	158.35	0.63	135	5.744022095959039	17352.30283711942	15
Traditional Housing	708000.00	21240.00	17352.30283711942	-3887.69716288058	-182.11	-0.55	135	5.744022095959039	17352.30283711942	15
Container (Max)	613320.6153576672241519500000	21466.22	17352.30283711942	-4113.9187003989328453182500000	-149.08	-0.67	135	5.744022095959039	17352.30283711942	15
Container (Base)	327868.8301150407765548190000	11475.41	12637.250016085722	1161.8409620592948205813350000	282.20	0.35	136	1.3996994260091533	12637.250016085722	24
ODD Cubes Basic	420000.00	14700.00	12637.250016085722	-2062.749983914278	-203.61	-0.49	136	1.3996994260091533	12637.250016085722	24
Traditional Housing	708000.00	21240.00	12637.250016085722	-8602.749983914278	-82.30	-1.22	136	1.3996994260091533	12637.250016085722	24
Container (Max)	588123.3266558243895976650000	20584.32	12637.250016085722	-7947.0664168681316359182750000	-74.01	-1.35	136	1.3996994260091533	12637.250016085722	24
Container (Base)	347786.1282882450204703800000	12172.51	15776.812946670014	3604.2984565814382835367000000	96.49	1.04	137	7.559504392624866	15776.812946670014	23
ODD Cubes Basic	420000.00	14700.00	15776.812946670014	1076.812946670014	390.04	0.26	137	7.559504392624866	15776.812946670014	23
Traditional Housing	708000.00	21240.00	15776.812946670014	-5463.187053329986	-129.59	-0.77	137	7.559504392624866	15776.812946670014	23
Container (Max)	623850.5034524438540433000000	21834.77	15776.812946670014	-6057.9546741655208915155000000	-102.98	-0.97	137	7.559504392624866	15776.812946670014	23
ODD Cubes Basic	420000.00	14700.00	19811.28603617412	5111.28603617412	82.17	1.22	138	32.22232409286508	19811.28603617412	27
Container (Base)	427531.6293915927356244000000	14963.61	19811.28603617412	4847.6790074683742531460000000	88.19	1.13	138	32.22232409286508	19811.28603617412	27
Traditional Housing	708000.00	21240.00	19811.28603617412	-1428.71396382588	-495.55	-0.20	138	32.22232409286508	19811.28603617412	27
Container (Max)	766896.0908548221072540000000	26841.36	19811.28603617412	-7030.0771437446537538900000000	-109.09	-0.92	138	32.22232409286508	19811.28603617412	27
Container (Base)	355818.2570255388998609100000	12453.64	17054.83420745845	4601.1952115645885048681500000	77.33	1.29	139	10.043593653036837	17054.83420745845	19
ODD Cubes Basic	420000.00	14700.00	17054.83420745845	2354.83420745845	178.36	0.56	139	10.043593653036837	17054.83420745845	19
Traditional Housing	708000.00	21240.00	17054.83420745845	-4185.16579254155	-169.17	-0.59	139	10.043593653036837	17054.83420745845	19
Container (Max)	638258.3453672963064418500000	22339.04	17054.83420745845	-5284.2078803969207254647500000	-120.79	-0.83	139	10.043593653036837	17054.83420745845	19
Container (Base)	332997.3153789948869031900000	11654.91	11747.237538117344	92.3314998525229583883500000	3606.54	0.03	140	2.985781470140033	11747.237538117344	31
ODD Cubes Basic	420000.00	14700.00	11747.237538117344	-2952.762461882656	-142.24	-0.70	140	2.985781470140033	11747.237538117344	31
Traditional Housing	708000.00	21240.00	11747.237538117344	-9492.762461882656	-74.58	-1.34	140	2.985781470140033	11747.237538117344	31
Container (Max)	597322.6818158856984016500000	20906.29	11747.237538117344	-9159.0563254386554440577500000	-65.22	-1.53	140	2.985781470140033	11747.237538117344	31
Container (Base)	403497.5245028417295000000000	14122.41	19404.389028419682	5281.9756708202214675000000000	76.39	1.31	141	24.78931800065	19404.389028419682	21
ODD Cubes Basic	420000.00	14700.00	19404.389028419682	4704.389028419682	89.28	1.12	141	24.78931800065	19404.389028419682	21
Traditional Housing	708000.00	21240.00	19404.389028419682	-1835.610971580318	-385.70	-0.26	141	24.78931800065	19404.389028419682	21
Container (Max)	723784.2838696700325000000000	25332.45	19404.389028419682	-5928.0609070187691375000000000	-122.09	-0.82	141	24.78931800065	19404.389028419682	21
Container (Base)	337921.0430990124986607600000	11827.24	8824.993210340837	-3002.2432981246004531266000000	-112.56	-0.89	142	4.508538332053732	8824.993210340837	19
ODD Cubes Basic	420000.00	14700.00	8824.993210340837	-5875.006789659163	-71.49	-1.40	142	4.508538332053732	8824.993210340837	19
Traditional Housing	708000.00	21240.00	8824.993210340837	-12415.006789659163	-57.03	-1.75	142	4.508538332053732	8824.993210340837	19
Container (Max)	606154.7477528282482866000000	21215.42	8824.993210340837	-12390.4229610081516900310000000	-48.92	-2.04	142	4.508538332053732	8824.993210340837	19
Container (Base)	382607.8588441210709042100000	13391.28	14602.488088470067	1211.2130289258295183526500000	315.89	0.32	143	18.328789812713147	14602.488088470067	16
ODD Cubes Basic	420000.00	14700.00	14602.488088470067	-97.511911529933	-4307.17	-0.02	143	18.328789812713147	14602.488088470067	16
Traditional Housing	708000.00	21240.00	14602.488088470067	-6637.511911529933	-106.67	-0.94	143	18.328789812713147	14602.488088470067	16
Container (Max)	686312.8973532268882573500000	24020.95	14602.488088470067	-9418.4633188928740890072500000	-72.87	-1.37	143	18.328789812713147	14602.488088470067	16
ODD Cubes Basic	420000.00	14700.00	9906.50691089162	-4793.49308910838	-87.62	-1.14	144	40.604085652048326	9906.50691089162	17
Container (Base)	454633.4686699026187381800000	15912.17	9906.50691089162	-6005.6644925549716558363000000	-75.70	-1.32	144	40.604085652048326	9906.50691089162	17
Traditional Housing	708000.00	21240.00	9906.50691089162	-11333.49308910838	-62.47	-1.60	144	40.604085652048326	9906.50691089162	17
Container (Max)	815510.7269861628932163000000	28542.88	9906.50691089162	-18636.3685336240812625705000000	-43.76	-2.29	144	40.604085652048326	9906.50691089162	17
Container (Base)	236283.7353658767252298800000	8269.93	11784.939713917192	3515.0089761115066169542000000	67.22	1.49	145	-26.924740796653484	11784.939713917192	39
ODD Cubes Basic	420000.00	14700.00	11784.939713917192	-2915.060286082808	-144.08	-0.69	145	-26.924740796653484	11784.939713917192	39
Container (Max)	423840.1571423699601258000000	14834.41	11784.939713917192	-3049.4657860657566044030000000	-138.99	-0.72	145	-26.924740796653484	11784.939713917192	39
Traditional Housing	708000.00	21240.00	11784.939713917192	-9455.060286082808	-74.88	-1.34	145	-26.924740796653484	11784.939713917192	39
Container (Base)	379633.2205355650645876800000	13287.16	13963.413220545921	676.2505018011437394312000000	561.38	0.18	146	17.408826087332976	13963.413220545921	28
ODD Cubes Basic	420000.00	14700.00	13963.413220545921	-736.586779454079	-570.20	-0.18	146	17.408826087332976	13963.413220545921	28
Traditional Housing	708000.00	21240.00	13963.413220545921	-7276.586779454079	-97.30	-1.03	146	17.408826087332976	13963.413220545921	28
Container (Max)	680977.0617478356274488000000	23834.20	13963.413220545921	-9870.7839406283259607080000000	-68.99	-1.45	146	17.408826087332976	13963.413220545921	28
Container (Base)	398942.9279348412059045100000	13963.00	12856.928562806734	-1106.0739149127082066578500000	-360.68	-0.28	147	23.380721999499357	12856.928562806734	27
ODD Cubes Basic	420000.00	14700.00	12856.928562806734	-1843.071437193266	-227.88	-0.44	147	23.380721999499357	12856.928562806734	27
Traditional Housing	708000.00	21240.00	12856.928562806734	-8383.071437193266	-84.46	-1.18	147	23.380721999499357	12856.928562806734	27
Container (Max)	715614.3566331962455678500000	25046.50	12856.928562806734	-12189.5739193551345948747500000	-58.71	-1.70	147	23.380721999499357	12856.928562806734	27
Container (Base)	409712.9288918460896038500000	14339.95	11666.080434603398	-2673.8720766112151361347500000	-153.23	-0.65	148	26.711550549059695	11666.080434603398	24
ODD Cubes Basic	420000.00	14700.00	11666.080434603398	-3033.919565396602	-138.43	-0.72	148	26.711550549059695	11666.080434603398	24
Traditional Housing	708000.00	21240.00	11666.080434603398	-9573.919565396602	-73.95	-1.35	148	26.711550549059695	11666.080434603398	24
Container (Max)	734933.3287620736839847500000	25722.67	11666.080434603398	-14056.5860720691809394662500000	-52.28	-1.91	148	26.711550549059695	11666.080434603398	24
ODD Cubes Basic	420000.00	14700.00	12063.221572225024	-2636.778427774976	-159.29	-0.63	149	53.80495250236997	12063.221572225024	37
Container (Base)	497317.5475697381320971000000	17406.11	12063.221572225024	-5342.8925927158106233985000000	-93.08	-1.07	149	53.80495250236997	12063.221572225024	37
Traditional Housing	708000.00	21240.00	12063.221572225024	-9176.778427774976	-77.15	-1.30	149	53.80495250236997	12063.221572225024	37
Container (Max)	892076.4147613709444985000000	31222.67	12063.221572225024	-19159.4529444229590574475000000	-46.56	-2.15	149	53.80495250236997	12063.221572225024	37
Container (Base)	314477.3950647542176594500000	11006.71	19547.090066034354	8540.3812387679563819192500000	36.82	2.72	150	-2.741857697629385	19547.090066034354	21
ODD Cubes Basic	420000.00	14700.00	19547.090066034354	4847.090066034354	86.65	1.15	150	-2.741857697629385	19547.090066034354	21
Container (Max)	564102.0882608646855307500000	19743.57	19547.090066034354	-196.4830230959099935762500000	-2871.00	-0.03	150	-2.741857697629385	19547.090066034354	21
Traditional Housing	708000.00	21240.00	19547.090066034354	-1692.909933965646	-418.21	-0.24	150	-2.741857697629385	19547.090066034354	21
ODD Cubes Basic	420000.00	14700.00	19118.255910703352	4418.255910703352	95.06	1.05	151	52.54276507689471	19118.255910703352	28
Container (Base)	493236.3528825836621553000000	17263.27	19118.255910703352	1854.9835598129238245645000000	265.90	0.38	151	52.54276507689471	19118.255910703352	28
Traditional Housing	708000.00	21240.00	19118.255910703352	-2121.744089296648	-333.69	-0.30	151	52.54276507689471	19118.255910703352	28
Container (Max)	884755.6645842431627355000000	30966.45	19118.255910703352	-11848.1923497451586957425000000	-74.67	-1.34	151	52.54276507689471	19118.255910703352	28
ODD Cubes Basic	420000.00	14700.00	14494.535246227215	-205.464753772785	-2044.15	-0.05	152	54.58964409449679	14494.535246227215	37
Container (Base)	499854.7929044687556897000000	17494.92	14494.535246227215	-3000.3825054291914491395000000	-166.60	-0.60	152	54.58964409449679	14494.535246227215	37
Traditional Housing	708000.00	21240.00	14494.535246227215	-6745.464753772785	-104.96	-0.95	152	54.58964409449679	14494.535246227215	37
Container (Max)	896627.6652302861068395000000	31381.97	14494.535246227215	-16887.4330368327987393825000000	-53.09	-1.88	152	54.58964409449679	14494.535246227215	37
ODD Cubes Basic	420000.00	14700.00	13790.539358588932	-909.460641411068	-461.81	-0.22	153	60.65303579825576	13790.539358588932	28
Container (Base)	519460.3455411541220568000000	18181.11	13790.539358588932	-4390.5727353514622719880000000	-118.31	-0.85	153	60.65303579825576	13790.539358588932	28
Traditional Housing	708000.00	21240.00	13790.539358588932	-7449.460641411068	-95.04	-1.05	153	60.65303579825576	13790.539358588932	28
Container (Max)	931795.6402816733207880000000	32612.85	13790.539358588932	-18822.3080512696342275800000000	-49.50	-2.02	153	60.65303579825576	13790.539358588932	28
Container (Base)	367324.5793172596417664100000	12856.36	8337.105384373745	-4519.2548917303424618243500000	-81.28	-1.23	154	13.602143642280687	8337.105384373745	29
ODD Cubes Basic	420000.00	14700.00	8337.105384373745	-6362.894615626255	-66.01	-1.51	154	13.602143642280687	8337.105384373745	29
Traditional Housing	708000.00	21240.00	8337.105384373745	-12902.894615626255	-54.87	-1.82	154	13.602143642280687	8337.105384373745	29
Container (Max)	658898.1132324100986343500000	23061.43	8337.105384373745	-14724.3285787606084522022500000	-44.75	-2.23	154	13.602143642280687	8337.105384373745	29
Container (Base)	300948.9231453909715687500000	10533.21	11894.93588888128	1361.7235787925959950937500000	221.01	0.45	155	-6.925796091026875	11894.93588888128	18
ODD Cubes Basic	420000.00	14700.00	11894.93588888128	-2805.06411111872	-149.73	-0.67	155	-6.925796091026875	11894.93588888128	18
Container (Max)	539835.0363822395736562500000	18894.23	11894.93588888128	-6999.2903844971050779687500000	-77.13	-1.30	155	-6.925796091026875	11894.93588888128	18
Traditional Housing	708000.00	21240.00	11894.93588888128	-9345.06411111872	-75.76	-1.32	155	-6.925796091026875	11894.93588888128	18
Container (Base)	239462.2358742417739255800000	8381.18	15283.639971389133	6902.4617157906709126047000000	34.69	2.88	156	-25.941728791332494	15283.639971389133	32
ODD Cubes Basic	420000.00	14700.00	15283.639971389133	583.639971389133	719.62	0.14	156	-25.941728791332494	15283.639971389133	32
Container (Max)	429541.6759238319681753000000	15033.96	15283.639971389133	249.6813140550141138645000000	1720.36	0.06	156	-25.941728791332494	15283.639971389133	32
Traditional Housing	708000.00	21240.00	15283.639971389133	-5956.360028610867	-118.86	-0.84	156	-25.941728791332494	15283.639971389133	32
ODD Cubes Basic	420000.00	14700.00	10688.340870069194	-4011.659129930806	-104.69	-0.96	157	42.801884735232804	10688.340870069194	28
Container (Base)	461739.8981594438054377200000	16160.90	10688.340870069194	-5472.5555655113391903202000000	-84.37	-1.19	157	42.801884735232804	10688.340870069194	28
Traditional Housing	708000.00	21240.00	10688.340870069194	-10551.659129930806	-67.10	-1.49	157	42.801884735232804	10688.340870069194	28
Container (Max)	828258.0715585870248402000000	28989.03	10688.340870069194	-18300.6916344813518694070000000	-45.26	-2.21	157	42.801884735232804	10688.340870069194	28
Container (Base)	246786.8089034961303073200000	8637.54	16396.119831668264	7758.5815200458994392438000000	31.81	3.14	158	-23.676464651006476	16396.119831668264	34
ODD Cubes Basic	420000.00	14700.00	16396.119831668264	1696.119831668264	247.62	0.40	158	-23.676464651006476	16396.119831668264	34
Container (Max)	442680.3212009298888762000000	15493.81	16396.119831668264	902.3085896357178893330000000	490.61	0.20	158	-23.676464651006476	16396.119831668264	34
Traditional Housing	708000.00	21240.00	16396.119831668264	-4843.880168331736	-146.16	-0.68	158	-23.676464651006476	16396.119831668264	34
Container (Base)	301446.2578563903662211600000	10550.62	15142.978227232848	4592.3592022591851822594000000	65.64	1.52	159	-6.771985830405988	15142.978227232848	19
ODD Cubes Basic	420000.00	14700.00	15142.978227232848	442.978227232848	948.13	0.11	159	-6.771985830405988	15142.978227232848	19
Container (Max)	540727.1435843537493006000000	18925.45	15142.978227232848	-3782.4717982195332255210000000	-142.96	-0.70	159	-6.771985830405988	15142.978227232848	19
Traditional Housing	708000.00	21240.00	15142.978227232848	-6097.021772767152	-116.12	-0.86	159	-6.771985830405988	15142.978227232848	19
Container (Base)	307296.7512940260717758100000	10755.39	14378.469794604825	3623.0834993139124878466500000	84.82	1.18	160	-4.962608965084733	14378.469794604825	30
ODD Cubes Basic	420000.00	14700.00	14378.469794604825	-321.530205395175	-1306.25	-0.08	160	-4.962608965084733	14378.469794604825	30
Container (Max)	551221.6198720602943633500000	19292.76	14378.469794604825	-4914.2869009172853027172500000	-112.17	-0.89	160	-4.962608965084733	14378.469794604825	30
Traditional Housing	708000.00	21240.00	14378.469794604825	-6861.530205395175	-103.18	-0.97	160	-4.962608965084733	14378.469794604825	30
ODD Cubes Basic	420000.00	14700.00	10899.409662962513	-3800.590337037487	-110.51	-0.90	161	33.45899726632977	10899.409662962513	21
Container (Base)	431530.3255308686682111000000	15103.56	10899.409662962513	-4204.1517306178903873885000000	-102.64	-0.97	161	33.45899726632977	10899.409662962513	21
Traditional Housing	708000.00	21240.00	10899.409662962513	-10340.590337037487	-68.47	-1.46	161	33.45899726632977	10899.409662962513	21
Container (Max)	774068.8570945759824885000000	27092.41	10899.409662962513	-16193.0003353476463870975000000	-47.80	-2.09	161	33.45899726632977	10899.409662962513	21
ODD Cubes Basic	420000.00	14700.00	9712.347692067107	-4987.652307932893	-84.21	-1.19	162	42.35032477802868	9712.347692067107	16
Container (Base)	460279.8106470212747724000000	16109.79	9712.347692067107	-6397.4456805786376170340000000	-71.95	-1.39	162	42.35032477802868	9712.347692067107	16
Traditional Housing	708000.00	21240.00	9712.347692067107	-11527.652307932893	-61.42	-1.63	162	42.35032477802868	9712.347692067107	16
Container (Max)	825639.0012288052454340000000	28897.37	9712.347692067107	-19185.0173509410765901900000000	-43.04	-2.32	162	42.35032477802868	9712.347692067107	16
Container (Base)	411721.3140775492648774500000	14410.25	19020.36674883289	4610.1207561186657292892500000	89.31	1.12	163	27.332682036583215	19020.36674883289	29
ODD Cubes Basic	420000.00	14700.00	19020.36674883289	4320.36674883289	97.21	1.03	163	27.332682036583215	19020.36674883289	29
Traditional Housing	708000.00	21240.00	19020.36674883289	-2219.63325116711	-318.97	-0.31	163	27.332682036583215	19020.36674883289	29
Container (Max)	738535.9224462844761607500000	25848.76	19020.36674883289	-6828.3905367870666656262500000	-108.16	-0.92	163	27.332682036583215	19020.36674883289	29
Container (Base)	402065.8223100472971149400000	14072.30	11613.158375667339	-2459.1454051843163990229000000	-163.50	-0.61	164	24.346536745823258	11613.158375667339	20
ODD Cubes Basic	420000.00	14700.00	11613.158375667339	-3086.841624332661	-136.06	-0.73	164	24.346536745823258	11613.158375667339	20
Traditional Housing	708000.00	21240.00	11613.158375667339	-9626.841624332661	-73.54	-1.36	164	24.346536745823258	11613.158375667339	20
Container (Max)	721216.1304526121875629000000	25242.56	11613.158375667339	-13629.4061901740875647015000000	-52.92	-1.89	164	24.346536745823258	11613.158375667339	20
Container (Base)	410306.9082193448850815100000	14360.74	18955.95496076429	4595.2131730872190221471500000	89.29	1.12	165	26.895250003663257	18955.95496076429	35
ODD Cubes Basic	420000.00	14700.00	18955.95496076429	4255.95496076429	98.69	1.01	165	26.895250003663257	18955.95496076429	35
Traditional Housing	708000.00	21240.00	18955.95496076429	-2284.04503923571	-309.98	-0.32	165	26.895250003663257	18955.95496076429	35
Container (Max)	735998.7947837470737628500000	25759.96	18955.95496076429	-6804.0028566668575816997500000	-108.17	-0.92	165	26.895250003663257	18955.95496076429	35
Container (Base)	311628.5735839503315500700000	10907.00	15192.79251189019	4285.7924364519283957475500000	72.71	1.38	166	-3.622910165381551	15192.79251189019	28
ODD Cubes Basic	420000.00	14700.00	15192.79251189019	492.79251189019	852.29	0.12	166	-3.622910165381551	15192.79251189019	28
Container (Max)	558991.9398952787351224500000	19564.72	15192.79251189019	-4371.9253844445657292857500000	-127.86	-0.78	166	-3.622910165381551	15192.79251189019	28
Traditional Housing	708000.00	21240.00	15192.79251189019	-6047.20748810981	-117.08	-0.85	166	-3.622910165381551	15192.79251189019	28
ODD Cubes Basic	420000.00	14700.00	16638.660394857234	1938.660394857234	216.64	0.46	167	53.2363126243837	16638.660394857234	32
Container (Base)	495478.8903290609870910000000	17341.76	16638.660394857234	-703.1007666599005481850000000	-704.71	-0.14	167	53.2363126243837	16638.660394857234	32
Traditional Housing	708000.00	21240.00	16638.660394857234	-4601.339605142766	-153.87	-0.65	167	53.2363126243837	16638.660394857234	32
Container (Max)	888778.2750370566791850000000	31107.24	16638.660394857234	-14468.5792314397497714750000000	-61.43	-1.63	167	53.2363126243837	16638.660394857234	32
ODD Cubes Basic	420000.00	14700.00	16617.07387596371	1917.07387596371	219.08	0.46	168	42.090283364586156	16617.07387596371	17
Container (Base)	459438.9849395538143950800000	16080.36	16617.07387596371	536.7094030793264961722000000	856.03	0.12	168	42.090283364586156	16617.07387596371	17
Traditional Housing	708000.00	21240.00	16617.07387596371	-4622.92612403629	-153.15	-0.65	168	42.090283364586156	16617.07387596371	17
Container (Max)	824130.7480287679341078000000	28844.58	16617.07387596371	-12227.5023050431676937730000000	-67.40	-1.48	168	42.090283364586156	16617.07387596371	17
Container (Base)	265626.0542462629074871500000	9296.91	10249.64730596961	952.7354073504082379497500000	278.80	0.36	169	-17.850068117675995	10249.64730596961	28
ODD Cubes Basic	420000.00	14700.00	10249.64730596961	-4450.35269403039	-94.37	-1.06	169	-17.850068117675995	10249.64730596961	28
Container (Max)	476473.7124140733452002500000	16676.58	10249.64730596961	-6426.9326285229570820087500000	-74.14	-1.35	169	-17.850068117675995	10249.64730596961	28
Traditional Housing	708000.00	21240.00	10249.64730596961	-10990.35269403039	-64.42	-1.55	169	-17.850068117675995	10249.64730596961	28
ODD Cubes Basic	420000.00	14700.00	19552.937501579516	4852.937501579516	86.55	1.16	170	40.97734158476992	19552.937501579516	30
Container (Base)	455840.3656004426024256000000	15954.41	19552.937501579516	3598.5247055640249151040000000	126.67	0.79	170	40.97734158476992	19552.937501579516	30
Traditional Housing	708000.00	21240.00	19552.937501579516	-1687.062498420484	-419.66	-0.24	170	40.97734158476992	19552.937501579516	30
Container (Max)	817675.6300587447744960000000	28618.65	19552.937501579516	-9065.7095504765511073600000000	-90.19	-1.11	170	40.97734158476992	19552.937501579516	30
Container (Base)	273254.1023740713984860400000	9563.89	12175.344721764635	2611.4511386721360529886000000	104.64	0.96	171	-15.490948505434972	12175.344721764635	36
ODD Cubes Basic	420000.00	14700.00	12175.344721764635	-2524.655278235365	-166.36	-0.60	171	-15.490948505434972	12175.344721764635	36
Container (Max)	490156.7241210518906514000000	17155.49	12175.344721764635	-4980.1406224721811727990000000	-98.42	-1.02	171	-15.490948505434972	12175.344721764635	36
Traditional Housing	708000.00	21240.00	12175.344721764635	-9064.655278235365	-78.11	-1.28	171	-15.490948505434972	12175.344721764635	36
ODD Cubes Basic	420000.00	14700.00	13371.117804553554	-1328.882195446446	-316.06	-0.32	172	52.72816545540667	13371.117804553554	15
Container (Base)	493835.8320284755889781000000	17284.25	13371.117804553554	-3913.1363164430916142335000000	-126.20	-0.79	172	52.72816545540667	13371.117804553554	15
Traditional Housing	708000.00	21240.00	13371.117804553554	-7868.882195446446	-89.97	-1.11	172	52.72816545540667	13371.117804553554	15
Container (Max)	885830.9960496314563335000000	31004.08	13371.117804553554	-17632.9670571835469716725000000	-50.24	-1.99	172	52.72816545540667	13371.117804553554	15
Container (Base)	392393.7787934183253242400000	13733.78	15937.567708486067	2203.7854507164256136516000000	178.05	0.56	173	21.355272510435768	15937.567708486067	21
ODD Cubes Basic	420000.00	14700.00	15937.567708486067	1237.567708486067	339.38	0.29	173	21.355272510435768	15937.567708486067	21
Traditional Housing	708000.00	21240.00	15937.567708486067	-5302.432291513933	-133.52	-0.75	173	21.355272510435768	15937.567708486067	21
Container (Max)	703866.6483241529761884000000	24635.33	15937.567708486067	-8697.7649828592871665940000000	-80.93	-1.24	173	21.355272510435768	15937.567708486067	21
Container (Base)	251799.4837941121110807000000	8812.98	17670.60181348733	8857.6198806934061121755000000	28.43	3.52	174	-22.12619917730951	17670.60181348733	24
ODD Cubes Basic	420000.00	14700.00	17670.60181348733	2970.60181348733	141.39	0.71	174	-22.12619917730951	17670.60181348733	24
Container (Max)	451671.9384616459765245000000	15808.52	17670.60181348733	1862.0839673297208216425000000	242.56	0.41	174	-22.12619917730951	17670.60181348733	24
Traditional Housing	708000.00	21240.00	17670.60181348733	-3569.39818651267	-198.35	-0.50	174	-22.12619917730951	17670.60181348733	24
ODD Cubes Basic	420000.00	14700.00	19808.36483009394	5108.36483009394	82.22	1.22	175	51.420328402148456	19808.36483009394	20
Container (Base)	489607.0324653588820840800000	17136.25	19808.36483009394	2672.1186938063791270572000000	183.23	0.55	175	51.420328402148456	19808.36483009394	20
Traditional Housing	708000.00	21240.00	19808.36483009394	-1431.63516990606	-494.54	-0.20	175	51.420328402148456	19808.36483009394	20
Container (Max)	878245.4757488811522228000000	30738.59	19808.36483009394	-10930.2268211169003277980000000	-80.35	-1.24	175	51.420328402148456	19808.36483009394	20
ODD Cubes Basic	420000.00	14700.00	16939.47013340413	2239.47013340413	187.54	0.53	176	62.90299980576192	16939.47013340413	37
Container (Base)	526735.4466619447649856000000	18435.74	16939.47013340413	-1496.2704997639367744960000000	-352.03	-0.28	176	62.90299980576192	16939.47013340413	37
Traditional Housing	708000.00	21240.00	16939.47013340413	-4300.52986659587	-164.63	-0.61	176	62.90299980576192	16939.47013340413	37
Container (Max)	944845.5440234094240960000000	33069.59	16939.47013340413	-16130.1239074151998433600000000	-58.58	-1.71	176	62.90299980576192	16939.47013340413	37
Container (Base)	355431.6650610681719929200000	12440.11	17305.641661689937	4865.5333845525509802478000000	73.05	1.37	177	9.924032702445444	17305.641661689937	25
ODD Cubes Basic	420000.00	14700.00	17305.641661689937	2605.641661689937	161.19	0.62	177	9.924032702445444	17305.641661689937	25
Traditional Housing	708000.00	21240.00	17305.641661689937	-3934.358338310063	-179.95	-0.56	177	9.924032702445444	17305.641661689937	25
Container (Max)	637564.8858758186974722000000	22314.77	17305.641661689937	-5009.1293439637174115270000000	-127.28	-0.79	177	9.924032702445444	17305.641661689937	25
Container (Base)	368835.1585413489041926500000	12909.23	10237.3289831558	-2671.9015657914116467427500000	-138.04	-0.72	178	14.069319125927855	10237.3289831558	36
ODD Cubes Basic	420000.00	14700.00	10237.3289831558	-4462.6710168442	-94.11	-1.06	178	14.069319125927855	10237.3289831558	36
Traditional Housing	708000.00	21240.00	10237.3289831558	-11002.6710168442	-64.35	-1.55	178	14.069319125927855	10237.3289831558	36
Container (Max)	661607.7543963378553927500000	23156.27	10237.3289831558	-12918.9424207160249387462500000	-51.21	-1.95	178	14.069319125927855	10237.3289831558	36
Container (Base)	227281.7806441002603054000000	7954.86	17117.655286473393	9162.7929639298838893110000000	24.80	4.03	179	-29.70876727063822	17117.655286473393	34
Container (Max)	407692.6643919347920890000000	14269.24	17117.655286473393	2848.4120327556752768850000000	143.13	0.70	179	-29.70876727063822	17117.655286473393	34
ODD Cubes Basic	420000.00	14700.00	17117.655286473393	2417.655286473393	173.72	0.58	179	-29.70876727063822	17117.655286473393	34
Traditional Housing	708000.00	21240.00	17117.655286473393	-4122.344713526607	-171.75	-0.58	179	-29.70876727063822	17117.655286473393	34
Container (Base)	245874.8438648417222064000000	8605.62	17837.224581643626	9231.6050463741657227760000000	26.63	3.75	180	-23.95850726168752	17837.224581643626	21
ODD Cubes Basic	420000.00	14700.00	17837.224581643626	3137.224581643626	133.88	0.75	180	-23.95850726168752	17837.224581643626	21
Container (Max)	441044.4599568492996240000000	15436.56	17837.224581643626	2400.6684831539005131600000000	183.72	0.54	180	-23.95850726168752	17837.224581643626	21
Traditional Housing	708000.00	21240.00	17837.224581643626	-3402.775418356374	-208.07	-0.48	180	-23.95850726168752	17837.224581643626	21
Container (Base)	323600.3138167912388876940000	11326.01	18451.841079206075	7125.8300956183816389307100000	45.41	2.20	181	0.0795792136496658	18451.841079206075	23
ODD Cubes Basic	420000.00	14700.00	18451.841079206075	3751.841079206075	111.95	0.89	181	0.0795792136496658	18451.841079206075	23
Container (Max)	580466.5634181287441232900000	20316.33	18451.841079206075	-1864.4886404284310443151500000	-311.33	-0.32	181	0.0795792136496658	18451.841079206075	23
Traditional Housing	708000.00	21240.00	18451.841079206075	-2788.158920793925	-253.93	-0.39	181	0.0795792136496658	18451.841079206075	23
Container (Base)	323851.6501079310330090930000	11334.81	15351.80609564119	4016.9983418636038446817450000	80.62	1.24	182	0.1573097632950251	15351.80609564119	17
ODD Cubes Basic	420000.00	14700.00	15351.80609564119	651.80609564119	644.36	0.16	182	0.1573097632950251	15351.80609564119	17
Traditional Housing	708000.00	21240.00	15351.80609564119	-5888.19390435881	-120.24	-0.83	182	0.1573097632950251	15351.80609564119	17
Container (Max)	580917.4044925993103312550000	20332.11	15351.80609564119	-4980.3030615997858615939250000	-116.64	-0.86	182	0.1573097632950251	15351.80609564119	17
Container (Base)	284650.7941129114647310500000	9962.78	10394.680774536879	431.9029805849777344132500000	659.06	0.15	183	-11.966303859087265	10394.680774536879	27
ODD Cubes Basic	420000.00	14700.00	10394.680774536879	-4305.319225463121	-97.55	-1.03	183	-11.966303859087265	10394.680774536879	27
Container (Max)	510599.8393021009086367500000	17870.99	10394.680774536879	-7476.3136010366528022862500000	-68.30	-1.46	183	-11.966303859087265	10394.680774536879	27
Traditional Housing	708000.00	21240.00	10394.680774536879	-10845.319225463121	-65.28	-1.53	183	-11.966303859087265	10394.680774536879	27
Container (Base)	373278.4262040136301739000000	13064.74	13261.780004360553	197.0350872200759439135000000	1894.48	0.05	184	15.44348453623973	13261.780004360553	15
ODD Cubes Basic	420000.00	14700.00	13261.780004360553	-1438.219995639447	-292.03	-0.34	184	15.44348453623973	13261.780004360553	15
Traditional Housing	708000.00	21240.00	13261.780004360553	-7978.219995639447	-88.74	-1.13	184	15.44348453623973	13261.780004360553	15
Container (Max)	669577.9824844172459865000000	23435.23	13261.780004360553	-10173.4493825940506095275000000	-65.82	-1.52	184	15.44348453623973	13261.780004360553	15
ODD Cubes Basic	420000.00	14700.00	14698.640988845993	-1.359011154007	-309048.24	0.00	185	38.43479965528849	14698.640988845993	38
Container (Base)	447619.2342493994622207000000	15666.67	14698.640988845993	-968.0322098829881777245000000	-462.40	-0.22	185	38.43479965528849	14698.640988845993	38
Traditional Housing	708000.00	21240.00	14698.640988845993	-6541.359011154007	-108.23	-0.92	185	38.43479965528849	14698.640988845993	38
Container (Max)	802928.7597406560064245000000	28102.51	14698.640988845993	-13403.8656020769672248575000000	-59.90	-1.67	185	38.43479965528849	14698.640988845993	38
Container (Base)	375820.5204532186090219800000	13153.72	13485.026727201373	331.3085113387216842307000000	1134.35	0.09	186	16.229675747802986	13485.026727201373	31
ODD Cubes Basic	420000.00	14700.00	13485.026727201373	-1214.973272798627	-345.69	-0.29	186	16.229675747802986	13485.026727201373	31
Traditional Housing	708000.00	21240.00	13485.026727201373	-7754.973272798627	-91.30	-1.10	186	16.229675747802986	13485.026727201373	31
Container (Max)	674137.9308210447089493000000	23594.83	13485.026727201373	-10109.8008515351918132255000000	-66.68	-1.50	186	16.229675747802986	13485.026727201373	31
ODD Cubes Basic	420000.00	14700.00	19366.535996427483	4666.535996427483	90.00	1.11	187	58.78021763291075	19366.535996427483	26
Container (Base)	513404.7191007826063725000000	17969.17	19366.535996427483	1397.3708279000917769625000000	367.41	0.27	187	58.78021763291075	19366.535996427483	26
Traditional Housing	708000.00	21240.00	19366.535996427483	-1873.464003572517	-377.91	-0.26	187	58.78021763291075	19366.535996427483	26
Container (Max)	920933.2012817639955375000000	32232.66	19366.535996427483	-12866.1260484342568438125000000	-71.58	-1.40	187	58.78021763291075	19366.535996427483	26
ODD Cubes Basic	420000.00	14700.00	9880.97838307025	-4819.02161692975	-87.15	-1.15	188	62.831425121024154	9880.97838307025	35
Traditional Housing	708000.00	21240.00	9880.97838307025	-11359.02161692975	-62.33	-1.60	188	62.831425121024154	9880.97838307025	35
Container (Base)	526504.0149290731302682200000	18427.64	9880.97838307025	-8546.6621394473095593877000000	-61.60	-1.62	188	62.831425121024154	9880.97838307025	35
Container (Max)	944430.4072731961444077000000	33055.06	9880.97838307025	-23174.0858714916150542695000000	-40.75	-2.45	188	62.831425121024154	9880.97838307025	35
ODD Cubes Basic	420000.00	14700.00	18959.769204830798	4259.769204830798	98.60	1.01	189	40.5096377087408	18959.769204830798	33
Container (Base)	454328.0778565737649440000000	15901.48	18959.769204830798	3058.2864798507162269600000000	148.56	0.67	189	40.5096377087408	18959.769204830798	33
Traditional Housing	708000.00	21240.00	18959.769204830798	-2280.230795169202	-310.49	-0.32	189	40.5096377087408	18959.769204830798	33
Container (Max)	814962.9241925820770400000000	28523.70	18959.769204830798	-9563.9331419095746964000000000	-85.21	-1.17	189	40.5096377087408	18959.769204830798	33
Container (Base)	415905.8646664606045548600000	14556.71	8890.091702345955	-5666.6135609801661594201000000	-73.40	-1.36	190	28.626834249221602	8890.091702345955	25
ODD Cubes Basic	420000.00	14700.00	8890.091702345955	-5809.908297654045	-72.29	-1.38	190	28.626834249221602	8890.091702345955	25
Traditional Housing	708000.00	21240.00	8890.091702345955	-12349.908297654045	-57.33	-1.74	190	28.626834249221602	8890.091702345955	25
Container (Max)	746042.0699871977526801000000	26111.47	8890.091702345955	-17221.3807472059663438035000000	-43.32	-2.31	190	28.626834249221602	8890.091702345955	25
Container (Base)	301690.3856044677594536700000	10559.16	14260.077845369957	3700.9143492135854191215500000	81.52	1.23	191	-6.696484660417031	14260.077845369957	30
ODD Cubes Basic	420000.00	14700.00	14260.077845369957	-439.922154630043	-954.71	-0.10	191	-6.696484660417031	14260.077845369957	30
Container (Max)	541165.0541453481993484500000	18940.78	14260.077845369957	-4680.6990497172299771957500000	-115.62	-0.86	191	-6.696484660417031	14260.077845369957	30
Traditional Housing	708000.00	21240.00	14260.077845369957	-6979.922154630043	-101.43	-0.99	191	-6.696484660417031	14260.077845369957	30
Container (Base)	367414.2841457965263451200000	12859.50	12854.546762227223	-4.9531828756554220792000000	-74177.41	0.00	192	13.629886574255984	12854.546762227223	20
ODD Cubes Basic	420000.00	14700.00	12854.546762227223	-1845.453237772777	-227.59	-0.44	192	13.629886574255984	12854.546762227223	20
Traditional Housing	708000.00	21240.00	12854.546762227223	-8385.453237772777	-84.43	-1.18	192	13.629886574255984	12854.546762227223	20
Container (Max)	659059.0236250134199992000000	23067.07	12854.546762227223	-10212.5190646482466999720000000	-64.53	-1.55	192	13.629886574255984	12854.546762227223	20
Container (Base)	301969.0357646641609564800000	10568.92	8864.65110922817	-1704.2651425350756334768000000	-177.18	-0.56	193	-6.610306774952864	8864.65110922817	24
ODD Cubes Basic	420000.00	14700.00	8864.65110922817	-5835.34889077183	-71.98	-1.39	193	-6.610306774952864	8864.65110922817	24
Traditional Housing	708000.00	21240.00	8864.65110922817	-12375.34889077183	-57.21	-1.75	193	-6.610306774952864	8864.65110922817	24
Container (Max)	541664.8901899346411568000000	18958.27	8864.65110922817	-10093.6200474195424404880000000	-53.66	-1.86	193	-6.610306774952864	8864.65110922817	24
ODD Cubes Basic	420000.00	14700.00	12873.803899543233	-1826.196100456767	-229.99	-0.43	194	50.258848260755116	12873.803899543233	24
Container (Base)	485851.4677317734147278800000	17004.80	12873.803899543233	-4130.9974710688365154758000000	-117.61	-0.85	194	50.258848260755116	12873.803899543233	24
Traditional Housing	708000.00	21240.00	12873.803899543233	-8366.196100456767	-84.63	-1.18	194	50.258848260755116	12873.803899543233	24
Container (Max)	871508.8328547927105558000000	30502.81	12873.803899543233	-17629.0052503745118694530000000	-49.44	-2.02	194	50.258848260755116	12873.803899543233	24
ODD Cubes Basic	420000.00	14700.00	13654.357641540286	-1045.642358459714	-401.67	-0.25	195	31.055564401003025	13654.357641540286	37
Container (Base)	423758.9936011352111257500000	14831.56	13654.357641540286	-1177.2071344994463894012500000	-359.97	-0.28	195	31.055564401003025	13654.357641540286	37
Traditional Housing	708000.00	21240.00	13654.357641540286	-7585.642358459714	-93.33	-1.07	195	31.055564401003025	13654.357641540286	37
Container (Max)	760128.8263040375951512500000	26604.51	13654.357641540286	-12950.1512791010298302937500000	-58.70	-1.70	195	31.055564401003025	13654.357641540286	37
ODD Cubes Basic	420000.00	14700.00	8460.172769702513	-6239.827230297487	-67.31	-1.49	196	37.83466625722144	8460.172769702513	38
Container (Base)	445678.7449160875207392000000	15598.76	8460.172769702513	-7138.5833023605502258720000000	-62.43	-1.60	196	37.83466625722144	8460.172769702513	38
Traditional Housing	708000.00	21240.00	8460.172769702513	-12779.827230297487	-55.40	-1.81	196	37.83466625722144	8460.172769702513	38
Container (Max)	799447.9560251972130720000000	27980.68	8460.172769702513	-19520.5056911793894575200000000	-40.95	-2.44	196	37.83466625722144	8460.172769702513	38
ODD Cubes Basic	420000.00	14700.00	13601.433855564861	-1098.566144435139	-382.32	-0.26	197	40.28384384249159	13601.433855564861	27
Container (Base)	453597.9891956275818537000000	15875.93	13601.433855564861	-2274.4957662821043648795000000	-199.43	-0.50	197	40.28384384249159	13601.433855564861	27
Traditional Housing	708000.00	21240.00	13601.433855564861	-7638.566144435139	-92.69	-1.08	197	40.28384384249159	13601.433855564861	27
Container (Max)	813653.3084786433465795000000	28477.87	13601.433855564861	-14876.4319411876561302825000000	-54.69	-1.83	197	40.28384384249159	13601.433855564861	27
Container (Base)	364532.9174423007075408600000	12758.65	11809.828609191094	-948.8235012894307639301000000	-384.19	-0.26	198	12.738768874631802	11809.828609191094	20
ODD Cubes Basic	420000.00	14700.00	11809.828609191094	-2890.171390808906	-145.32	-0.69	198	12.738768874631802	11809.828609191094	20
Traditional Housing	708000.00	21240.00	11809.828609191094	-9430.171390808906	-75.08	-1.33	198	12.738768874631802	11809.828609191094	20
Container (Max)	653890.4964113081831901000000	22886.17	11809.828609191094	-11076.3387652046924116535000000	-59.03	-1.69	198	12.738768874631802	11809.828609191094	20
Container (Base)	282382.3462237338733245000000	9883.38	8904.499788617157	-978.8823292135285663575000000	-288.47	-0.35	199	-12.66786470598285	8904.499788617157	35
ODD Cubes Basic	420000.00	14700.00	8904.499788617157	-5795.500211382843	-72.47	-1.38	199	-12.66786470598285	8904.499788617157	35
Traditional Housing	708000.00	21240.00	8904.499788617157	-12335.500211382843	-57.40	-1.74	199	-12.66786470598285	8904.499788617157	35
Container (Max)	506530.7513120641708575000000	17728.58	8904.499788617157	-8824.0765073050889800125000000	-57.40	-1.74	199	-12.66786470598285	8904.499788617157	35
ODD Cubes Basic	420000.00	14700.00	18943.824853052254	4243.824853052254	98.97	1.01	200	36.15473444956777	18943.824853052254	32
Container (Base)	440246.8030112659145511000000	15408.64	18943.824853052254	3535.1867476579469907115000000	124.53	0.80	200	36.15473444956777	18943.824853052254	32
Traditional Housing	708000.00	21240.00	18943.824853052254	-2296.175146947746	-308.34	-0.32	200	36.15473444956777	18943.824853052254	32
Container (Max)	789704.2675442155443885000000	27639.65	18943.824853052254	-8695.8245109952900535975000000	-90.81	-1.10	200	36.15473444956777	18943.824853052254	32
ODD Cubes Basic	420000.00	14700.00	11950.3048857708	-2749.6951142292	-152.74	-0.65	201	47.84572684423526	11950.3048857708	20
Container (Base)	478048.8085499556167418000000	16731.71	11950.3048857708	-4781.4034134776465859630000000	-99.98	-1.00	201	47.84572684423526	11950.3048857708	20
Traditional Housing	708000.00	21240.00	11950.3048857708	-9289.6951142292	-76.21	-1.31	201	47.84572684423526	11950.3048857708	20
Container (Max)	857512.6079829067197630000000	30012.94	11950.3048857708	-18062.6363936309351917050000000	-47.47	-2.11	201	47.84572684423526	11950.3048857708	20
Container (Base)	320046.6303590012567076780000	11201.63	9315.18966737871	-1886.4423951863339847687300000	-169.66	-0.59	202	-1.0194652863982654	9315.18966737871	38
ODD Cubes Basic	420000.00	14700.00	9315.18966737871	-5384.81033262129	-78.00	-1.28	202	-1.0194652863982654	9315.18966737871	38
Traditional Housing	708000.00	21240.00	9315.18966737871	-11924.81033262129	-59.37	-1.68	202	-1.0194652863982654	9315.18966737871	38
Container (Max)	574092.0503656257407667300000	20093.22	9315.18966737871	-10778.0320954181909268355500000	-53.27	-1.88	202	-1.0194652863982654	9315.18966737871	38
ODD Cubes Basic	420000.00	14700.00	19068.56566211073	4368.56566211073	96.14	1.04	203	39.5316398038989	19068.56566211073	18
Container (Base)	451165.7900911208202270000000	15790.80	19068.56566211073	3277.7630089215012920550000000	137.64	0.73	203	39.5316398038989	19068.56566211073	18
Traditional Housing	708000.00	21240.00	19068.56566211073	-2171.43433788927	-326.05	-0.31	203	39.5316398038989	19068.56566211073	18
Container (Max)	809290.4874446038149450000000	28325.17	19068.56566211073	-9256.6013984504035230750000000	-87.43	-1.14	203	39.5316398038989	19068.56566211073	18
ODD Cubes Basic	420000.00	14700.00	12255.56010396763	-2444.43989603237	-171.82	-0.58	204	30.235024695115726	12255.56010396763	39
Container (Base)	421105.8358999280419201800000	14738.70	12255.56010396763	-2483.1441525298514672063000000	-169.59	-0.59	204	30.235024695115726	12255.56010396763	39
Traditional Housing	708000.00	21240.00	12255.56010396763	-8984.43989603237	-78.80	-1.27	204	30.235024695115726	12255.56010396763	39
Container (Max)	755369.6549829059665863000000	26437.94	12255.56010396763	-14182.3778204340788305205000000	-53.26	-1.88	204	30.235024695115726	12255.56010396763	39
ODD Cubes Basic	420000.00	14700.00	17865.646317436585	3165.646317436585	132.67	0.75	205	53.74172690954549	17865.646317436585	37
Container (Base)	497113.1120411316737307000000	17398.96	17865.646317436585	466.6873959969764194255000000	1065.20	0.09	205	53.74172690954549	17865.646317436585	37
Traditional Housing	708000.00	21240.00	17865.646317436585	-3374.353682563415	-209.82	-0.48	205	53.74172690954549	17865.646317436585	37
Container (Max)	891709.7031617093192745000000	31209.84	17865.646317436585	-13344.1932932232411746075000000	-66.82	-1.50	205	53.74172690954549	17865.646317436585	37
Container (Base)	361566.1026837576908902800000	12654.81	19646.69564601702	6991.8820520855008188402000000	51.71	1.93	206	11.821224731556796	19646.69564601702	15
ODD Cubes Basic	420000.00	14700.00	19646.69564601702	4946.69564601702	84.91	1.18	206	11.821224731556796	19646.69564601702	15
Traditional Housing	708000.00	21240.00	19646.69564601702	-1593.30435398298	-444.36	-0.23	206	11.821224731556796	19646.69564601702	15
Container (Max)	648568.6945042659946398000000	22699.90	19646.69564601702	-3053.2086616322898123930000000	-212.42	-0.47	206	11.821224731556796	19646.69564601702	15
Container (Base)	335488.5923361091355324700000	11742.10	11779.173311134531	37.0725793707112563635500000	9049.51	0.01	207	3.756256463294129	11779.173311134531	31
ODD Cubes Basic	420000.00	14700.00	11779.173311134531	-2920.826688865469	-143.79	-0.70	207	3.756256463294129	11779.173311134531	31
Traditional Housing	708000.00	21240.00	11779.173311134531	-9460.826688865469	-74.83	-1.34	207	3.756256463294129	11779.173311134531	31
Container (Max)	601791.4752999291129064500000	21062.70	11779.173311134531	-9283.5283243629879517257500000	-64.82	-1.54	207	3.756256463294129	11779.173311134531	31
Container (Base)	413781.8643840132885104100000	14482.37	9752.486997066959	-4729.8782563735060978643500000	-87.48	-1.14	208	27.969946584281487	9752.486997066959	32
ODD Cubes Basic	420000.00	14700.00	9752.486997066959	-4947.513002933041	-84.89	-1.18	208	27.969946584281487	9752.486997066959	32
Traditional Housing	708000.00	21240.00	9752.486997066959	-11487.513002933041	-61.63	-1.62	208	27.969946584281487	9752.486997066959	32
Container (Max)	742232.0886861618386743500000	25978.12	9752.486997066959	-16225.6361069487053536022500000	-45.74	-2.19	208	27.969946584281487	9752.486997066959	32
Container (Base)	395234.3405131830893106000000	13833.20	8810.477400340316	-5022.7245176210921258710000000	-78.69	-1.27	209	22.23377048928942	8810.477400340316	31
ODD Cubes Basic	420000.00	14700.00	8810.477400340316	-5889.522599659684	-71.31	-1.40	209	22.23377048928942	8810.477400340316	31
Traditional Housing	708000.00	21240.00	8810.477400340316	-12429.522599659684	-56.96	-1.76	209	22.23377048928942	8810.477400340316	31
Container (Max)	708961.9805264031004710000000	24813.67	8810.477400340316	-16003.1919180837925164850000000	-44.30	-2.26	209	22.23377048928942	8810.477400340316	31
Container (Base)	330080.3472037203451628100000	11552.81	12893.787219142803	1340.9750670125909193016500000	246.15	0.41	210	2.083653335226167	12893.787219142803	26
ODD Cubes Basic	420000.00	14700.00	12893.787219142803	-1806.212780857197	-232.53	-0.43	210	2.083653335226167	12893.787219142803	26
Traditional Housing	708000.00	21240.00	12893.787219142803	-8346.212780857197	-84.83	-1.18	210	2.083653335226167	12893.787219142803	26
Container (Max)	592090.2935269785299083500000	20723.16	12893.787219142803	-7829.3730543014455467922500000	-75.62	-1.32	210	2.083653335226167	12893.787219142803	26
ODD Cubes Basic	420000.00	14700.00	12332.85836949318	-2367.14163050682	-177.43	-0.56	211	58.13432249885392	12332.85836949318	21
Container (Base)	511316.2623974692305456000000	17896.07	12332.85836949318	-5563.2108144182430690960000000	-91.91	-1.09	211	58.13432249885392	12332.85836949318	21
Traditional Housing	708000.00	21240.00	12332.85836949318	-8907.14163050682	-79.49	-1.26	211	58.13432249885392	12332.85836949318	21
Container (Max)	917186.9772094776786960000000	32101.54	12332.85836949318	-19768.6858328385387543600000000	-46.40	-2.16	211	58.13432249885392	12332.85836949318	21
ODD Cubes Basic	420000.00	14700.00	8517.166430716205	-6182.833569283795	-67.93	-1.47	212	57.98551106879509	8517.166430716205	30
Traditional Housing	708000.00	21240.00	8517.166430716205	-12722.833569283795	-55.65	-1.80	212	57.98551106879509	8517.166430716205	30
Container (Base)	510835.0910551741078587000000	17879.23	8517.166430716205	-9362.0617562148887750545000000	-54.56	-1.83	212	57.98551106879509	8517.166430716205	30
Container (Max)	916323.8634745649617545000000	32071.34	8517.166430716205	-23554.1687908935686614075000000	-38.90	-2.57	212	57.98551106879509	8517.166430716205	30
ODD Cubes Basic	420000.00	14700.00	15222.680313120627	522.680313120627	803.55	0.12	213	51.67878230717544	15222.680313120627	21
Container (Base)	490442.7250754902829592000000	17165.50	15222.680313120627	-1942.8150645215329035720000000	-252.44	-0.40	213	51.67878230717544	15222.680313120627	21
Traditional Housing	708000.00	21240.00	15222.680313120627	-6017.319686879373	-117.66	-0.85	213	51.67878230717544	15222.680313120627	21
Container (Max)	879744.5213207329107720000000	30791.06	15222.680313120627	-15568.3779331050248770200000000	-56.51	-1.77	213	51.67878230717544	15222.680313120627	21
Container (Base)	247326.6129805890249849000000	8656.43	16102.706230417261	7446.2747760966451255285000000	33.21	3.01	214	-23.50951992757257	16102.706230417261	23
ODD Cubes Basic	420000.00	14700.00	16102.706230417261	1402.706230417261	299.42	0.33	214	-23.50951992757257	16102.706230417261	23
Container (Max)	443648.6089440827153715000000	15527.70	16102.706230417261	575.0049173743659619975000000	771.56	0.13	214	-23.50951992757257	16102.706230417261	23
Traditional Housing	708000.00	21240.00	16102.706230417261	-5137.293769582739	-137.82	-0.73	214	-23.50951992757257	16102.706230417261	23
ODD Cubes Basic	420000.00	14700.00	17589.009696111974	2889.009696111974	145.38	0.69	215	65.14372672577286	17589.009696111974	27
Container (Base)	533980.6803069157387098000000	18689.32	17589.009696111974	-1100.3141146300768548430000000	-485.30	-0.21	215	65.14372672577286	17589.009696111974	27
Traditional Housing	708000.00	21240.00	17589.009696111974	-3650.990303888026	-193.92	-0.52	215	65.14372672577286	17589.009696111974	27
Container (Max)	957841.8721958188766430000000	33524.47	17589.009696111974	-15935.4558307416866825050000000	-60.11	-1.66	215	65.14372672577286	17589.009696111974	27
ODD Cubes Basic	420000.00	14700.00	12159.81540901004	-2540.18459098996	-165.34	-0.60	216	68.67208505068189	12159.81540901004	21
Container (Base)	545389.3799654263435827000000	19088.63	12159.81540901004	-6928.8128897798820253945000000	-78.71	-1.27	216	68.67208505068189	12159.81540901004	21
Traditional Housing	708000.00	21240.00	12159.81540901004	-9080.18459098996	-77.97	-1.28	216	68.67208505068189	12159.81540901004	21
Container (Max)	978306.5268982074960945000000	34240.73	12159.81540901004	-22080.9130324272223633075000000	-44.31	-2.26	216	68.67208505068189	12159.81540901004	21
ODD Cubes Basic	420000.00	14700.00	9110.683545182756	-5589.316454817244	-75.14	-1.33	217	62.43204769066941	9110.683545182756	16
Traditional Housing	708000.00	21240.00	9110.683545182756	-12129.316454817244	-58.37	-1.71	217	62.43204769066941	9110.683545182756	16
Container (Base)	525212.6559644411903763000000	18382.44	9110.683545182756	-9271.7594135726856631705000000	-56.65	-1.77	217	62.43204769066941	9110.683545182756	16
Container (Max)	942113.9982082671114705000000	32973.99	9110.683545182756	-23863.3063921065929014675000000	-39.48	-2.53	217	62.43204769066941	9110.683545182756	16
ODD Cubes Basic	420000.00	14700.00	13104.645748395718	-1595.354251604282	-263.26	-0.38	218	41.595643240992786	13104.645748395718	29
Container (Base)	457839.6007247233040359800000	16024.39	13104.645748395718	-2919.7402769695976412593000000	-156.81	-0.64	218	41.595643240992786	13104.645748395718	29
Traditional Housing	708000.00	21240.00	13104.645748395718	-8135.354251604282	-87.03	-1.15	218	41.595643240992786	13104.645748395718	29
Container (Max)	821261.8105799202084393000000	28744.16	13104.645748395718	-15639.5176219014892953755000000	-52.51	-1.90	218	41.595643240992786	13104.645748395718	29
Container (Base)	248227.2397945753440039000000	8687.95	12447.036915336615	3759.0835225264779598635000000	66.03	1.51	219	-23.23098387947927	12447.036915336615	21
ODD Cubes Basic	420000.00	14700.00	12447.036915336615	-2252.963084663385	-186.42	-0.54	219	-23.23098387947927	12447.036915336615	21
Container (Max)	445264.1319498262600365000000	15584.24	12447.036915336615	-3137.2077029073041012775000000	-141.93	-0.70	219	-23.23098387947927	12447.036915336615	21
Traditional Housing	708000.00	21240.00	12447.036915336615	-8792.963084663385	-80.52	-1.24	219	-23.23098387947927	12447.036915336615	21
Container (Base)	419079.2797918834197064200000	14667.77	13712.73006913481	-955.0447235811096897247000000	-438.81	-0.23	220	29.608273502714894	13712.73006913481	36
ODD Cubes Basic	420000.00	14700.00	13712.73006913481	-987.26993086519	-425.42	-0.24	220	29.608273502714894	13712.73006913481	36
Traditional Housing	708000.00	21240.00	13712.73006913481	-7527.26993086519	-94.06	-1.06	220	29.608273502714894	13712.73006913481	36
Container (Max)	751734.4667294215209447000000	26310.71	13712.73006913481	-12597.9762663949432330645000000	-59.67	-1.68	220	29.608273502714894	13712.73006913481	36
Container (Base)	227243.6271188721418023000000	7953.53	18803.683439962457	10850.1564908019320369195000000	20.94	4.77	221	-29.72056697721239	18803.683439962457	17
Container (Max)	407624.2255038192773805000000	14266.85	18803.683439962457	4536.8355473287822916825000000	89.85	1.11	221	-29.72056697721239	18803.683439962457	17
ODD Cubes Basic	420000.00	14700.00	18803.683439962457	4103.683439962457	102.35	0.98	221	-29.72056697721239	18803.683439962457	17
Traditional Housing	708000.00	21240.00	18803.683439962457	-2436.316560037543	-290.60	-0.34	221	-29.72056697721239	18803.683439962457	17
ODD Cubes Basic	420000.00	14700.00	9929.083928875169	-4770.916071124831	-88.03	-1.14	222	39.68201508634171	9929.083928875169	15
Container (Base)	451652.0180406298753653000000	15807.82	9929.083928875169	-5878.7367025468766377855000000	-76.83	-1.30	222	39.68201508634171	9929.083928875169	15
Traditional Housing	708000.00	21240.00	9929.083928875169	-11310.916071124831	-62.59	-1.60	222	39.68201508634171	9929.083928875169	15
Container (Max)	810162.6716015362350855000000	28355.69	9929.083928875169	-18426.6095771785992279925000000	-43.97	-2.27	222	39.68201508634171	9929.083928875169	15
Container (Base)	363977.5709165439201565500000	12739.21	18411.185251799987	5671.9702697209497945207500000	64.17	1.56	223	12.567017352020585	18411.185251799987	21
ODD Cubes Basic	420000.00	14700.00	18411.185251799987	3711.185251799987	113.17	0.88	223	12.567017352020585	18411.185251799987	21
Traditional Housing	708000.00	21240.00	18411.185251799987	-2828.814748200013	-250.28	-0.40	223	12.567017352020585	18411.185251799987	21
Container (Max)	652894.3289925869940292500000	22851.30	18411.185251799987	-4440.1162629405577910237500000	-147.04	-0.68	223	12.567017352020585	18411.185251799987	21
ODD Cubes Basic	420000.00	14700.00	14033.21227874787	-666.78772125213	-629.89	-0.16	224	54.82040190264051	14033.21227874787	35
Container (Base)	500600.9321240549042493000000	17521.03	14033.21227874787	-3487.8203455940516487255000000	-143.53	-0.70	224	54.82040190264051	14033.21227874787	35
Traditional Housing	708000.00	21240.00	14033.21227874787	-7206.78772125213	-98.24	-1.02	224	54.82040190264051	14033.21227874787	35
Container (Max)	897966.0720554100900255000000	31428.81	14033.21227874787	-17395.6002431914831508925000000	-51.62	-1.94	224	54.82040190264051	14033.21227874787	35
Container (Base)	260130.7884409121704235400000	9104.58	15120.666734513568	6016.0891390816420351761000000	43.24	2.31	225	-19.549584051328722	15120.666734513568	28
ODD Cubes Basic	420000.00	14700.00	15120.666734513568	420.666734513568	998.42	0.10	225	-19.549584051328722	15120.666734513568	28
Container (Max)	466616.4350230908459639000000	16331.58	15120.666734513568	-1210.9084912946116087365000000	-385.34	-0.26	225	-19.549584051328722	15120.666734513568	28
Traditional Housing	708000.00	21240.00	15120.666734513568	-6119.333265486432	-115.70	-0.86	225	-19.549584051328722	15120.666734513568	28
Container (Base)	264869.9719165206630827100000	9270.45	13345.763512888967	4075.3144958107437921051500000	64.99	1.54	226	-18.083901022591903	13345.763512888967	16
ODD Cubes Basic	420000.00	14700.00	13345.763512888967	-1354.236487111033	-310.14	-0.32	226	-18.083901022591903	13345.763512888967	16
Container (Max)	475117.4698739158330048500000	16629.11	13345.763512888967	-3283.3479326980871551697500000	-144.71	-0.69	226	-18.083901022591903	13345.763512888967	16
Traditional Housing	708000.00	21240.00	13345.763512888967	-7894.236487111033	-89.69	-1.12	226	-18.083901022591903	13345.763512888967	16
Container (Base)	234874.9659319103415834900000	8220.62	8599.059879167815	378.4360715509530445778500000	620.65	0.16	227	-27.360429657697757	8599.059879167815	24
ODD Cubes Basic	420000.00	14700.00	8599.059879167815	-6100.940120832185	-68.84	-1.45	227	-27.360429657697757	8599.059879167815	24
Container (Max)	421313.1399638701245121500000	14745.96	8599.059879167815	-6146.9000195676393579252500000	-68.54	-1.46	227	-27.360429657697757	8599.059879167815	24
Traditional Housing	708000.00	21240.00	8599.059879167815	-12640.940120832185	-56.01	-1.79	227	-27.360429657697757	8599.059879167815	24
Container (Base)	358589.9259503030633950800000	12550.65	10197.2688124569	-2353.3785958037072188278000000	-152.37	-0.66	228	10.900785218886156	10197.2688124569	26
ODD Cubes Basic	420000.00	14700.00	10197.2688124569	-4502.7311875431	-93.28	-1.07	228	10.900785218886156	10197.2688124569	26
Traditional Housing	708000.00	21240.00	10197.2688124569	-11042.7311875431	-64.11	-1.56	228	10.900785218886156	10197.2688124569	26
Container (Max)	643230.0993088006491078000000	22513.05	10197.2688124569	-12315.7846633511227187730000000	-52.23	-1.91	228	10.900785218886156	10197.2688124569	26
Container (Base)	340621.1063890307883167400000	11921.74	9709.316832126216	-2212.4218914898615910859000000	-153.96	-0.65	229	5.343584487380518	9709.316832126216	15
ODD Cubes Basic	420000.00	14700.00	9709.316832126216	-4990.683167873784	-84.16	-1.19	229	5.343584487380518	9709.316832126216	15
Traditional Housing	708000.00	21240.00	9709.316832126216	-11530.683167873784	-61.40	-1.63	229	5.343584487380518	9709.316832126216	15
Container (Max)	610998.0572060313734259000000	21384.93	9709.316832126216	-11675.6151700848820699065000000	-52.33	-1.91	229	5.343584487380518	9709.316832126216	15
Container (Base)	391898.8056958758756358200000	13716.46	9245.481316320293	-4470.9768830353626472537000000	-87.65	-1.14	230	21.202192623893474	9245.481316320293	34
ODD Cubes Basic	420000.00	14700.00	9245.481316320293	-5454.518683679707	-77.00	-1.30	230	21.202192623893474	9245.481316320293	34
Traditional Housing	708000.00	21240.00	9245.481316320293	-11994.518683679707	-59.03	-1.69	230	21.202192623893474	9245.481316320293	34
Container (Max)	702978.7773282133438737000000	24604.26	9245.481316320293	-15358.7758901671740355795000000	-45.77	-2.18	230	21.202192623893474	9245.481316320293	34
Container (Base)	350532.1112799147262881300000	12268.62	16228.321152046788	3959.6972572497725799154500000	88.52	1.13	231	8.408752092952291	16228.321152046788	23
ODD Cubes Basic	420000.00	14700.00	16228.321152046788	1528.321152046788	274.81	0.36	231	8.408752092952291	16228.321152046788	23
Traditional Housing	708000.00	21240.00	16228.321152046788	-5011.678847953212	-141.27	-0.71	231	8.408752092952291	16228.321152046788	23
Container (Max)	628776.1825767279354145500000	22007.17	16228.321152046788	-5778.8452381386897395092500000	-108.81	-0.92	231	8.408752092952291	16228.321152046788	23
ODD Cubes Basic	420000.00	14700.00	8599.19003036053	-6100.80996963947	-68.84	-1.45	232	31.664290355572362	8599.19003036053	17
Container (Base)	425727.2663644183424616600000	14900.45	8599.19003036053	-6301.2642923941119861581000000	-67.56	-1.48	232	31.664290355572362	8599.19003036053	17
Traditional Housing	708000.00	21240.00	8599.19003036053	-12640.80996963947	-56.01	-1.79	232	31.664290355572362	8599.19003036053	17
Container (Max)	763659.4672768374782181000000	26728.08	8599.19003036053	-18128.8913243287817376335000000	-42.12	-2.37	232	31.664290355572362	8599.19003036053	17
Container (Base)	270915.2854359972432116400000	9482.03	8296.189174341065	-1185.8458159188385124074000000	-228.46	-0.44	233	-16.214272325055052	8296.189174341065	34
ODD Cubes Basic	420000.00	14700.00	8296.189174341065	-6403.810825658935	-65.59	-1.52	233	-16.214272325055052	8296.189174341065	34
Container (Max)	485961.4098010644456474000000	17008.65	8296.189174341065	-8712.4601686961905976590000000	-55.78	-1.79	233	-16.214272325055052	8296.189174341065	34
Traditional Housing	708000.00	21240.00	8296.189174341065	-12943.810825658935	-54.70	-1.83	233	-16.214272325055052	8296.189174341065	34
Container (Base)	321919.6539522070688355405000	11267.19	10880.254375245237	-386.9335130820104092439175000	-831.98	-0.12	234	-0.44019695734651165	10880.254375245237	30
ODD Cubes Basic	420000.00	14700.00	10880.254375245237	-3819.745624754763	-109.95	-0.91	234	-0.44019695734651165	10880.254375245237	30
Traditional Housing	708000.00	21240.00	10880.254375245237	-10359.745624754763	-68.34	-1.46	234	-0.44019695734651165	10880.254375245237	30
Container (Max)	577451.8356375423651044175000	20210.81	10880.254375245237	-9330.5598720687457786546125000	-61.89	-1.62	234	-0.44019695734651165	10880.254375245237	30
Container (Base)	285675.3249344595790140600000	9998.64	15165.90541585334	5167.2690431472547345079000000	55.29	1.81	235	-11.649448129552958	15165.90541585334	26
ODD Cubes Basic	420000.00	14700.00	15165.90541585334	465.90541585334	901.47	0.11	235	-11.649448129552958	15165.90541585334	26
Container (Max)	512437.6183761863659521000000	17935.32	15165.90541585334	-2769.4112273131828083235000000	-185.03	-0.54	235	-11.649448129552958	15165.90541585334	26
Traditional Housing	708000.00	21240.00	15165.90541585334	-6074.09458414666	-116.56	-0.86	235	-11.649448129552958	15165.90541585334	26
Container (Base)	398237.9784380514397890000000	13938.33	15924.031481024638	1985.7022356928376073850000000	200.55	0.50	236	23.1627029000323	15924.031481024638	27
ODD Cubes Basic	420000.00	14700.00	15924.031481024638	1224.031481024638	343.13	0.29	236	23.1627029000323	15924.031481024638	27
Traditional Housing	708000.00	21240.00	15924.031481024638	-5315.968518975362	-133.18	-0.75	236	23.1627029000323	15924.031481024638	27
Container (Max)	714349.8349553323416150000000	25002.24	15924.031481024638	-9078.2127424119939565250000000	-78.69	-1.27	236	23.1627029000323	15924.031481024638	27
Container (Base)	260794.5681499005140384400000	9127.81	12432.526245756919	3304.7163605104010086546000000	78.92	1.27	237	-19.344297495260292	12432.526245756919	39
ODD Cubes Basic	420000.00	14700.00	12432.526245756919	-2267.473754243081	-185.23	-0.54	237	-19.344297495260292	12432.526245756919	39
Container (Max)	467807.1073126155433854000000	16373.25	12432.526245756919	-3940.7225101846250184890000000	-118.71	-0.84	237	-19.344297495260292	12432.526245756919	39
Traditional Housing	708000.00	21240.00	12432.526245756919	-8807.473754243081	-80.39	-1.24	237	-19.344297495260292	12432.526245756919	39
ODD Cubes Basic	420000.00	14700.00	18633.66123922353	3933.66123922353	106.77	0.94	238	34.598944522080046	18633.66123922353	15
Container (Base)	435216.2651860292831377800000	15232.57	18633.66123922353	3401.0919577125050901777000000	127.96	0.78	238	34.598944522080046	18633.66123922353	15
Traditional Housing	708000.00	21240.00	18633.66123922353	-2606.33876077647	-271.65	-0.37	238	34.598944522080046	18633.66123922353	15
Container (Max)	780680.6081752903708023000000	27323.82	18633.66123922353	-8690.1600469116329780805000000	-89.84	-1.11	238	34.598944522080046	18633.66123922353	15
ODD Cubes Basic	420000.00	14700.00	14610.107707620164	-89.892292379836	-4672.26	-0.02	239	68.01342068019743	14610.107707620164	27
Container (Base)	543259.6348299707760849000000	19014.09	14610.107707620164	-4403.9795114288131629715000000	-123.36	-0.81	239	68.01342068019743	14610.107707620164	27
Traditional Housing	708000.00	21240.00	14610.107707620164	-6629.892292379836	-106.79	-0.94	239	68.01342068019743	14610.107707620164	27
Container (Max)	974486.2406161791038715000000	34107.02	14610.107707620164	-19496.9107139461046355025000000	-49.98	-2.00	239	68.01342068019743	14610.107707620164	27
ODD Cubes Basic	420000.00	14700.00	19059.143139387004	4359.143139387004	96.35	1.04	240	37.208670464583804	19059.143139387004	20
Container (Base)	443654.6313402992093677200000	15527.91	19059.143139387004	3531.2310424765316721298000000	125.64	0.80	240	37.208670464583804	19059.143139387004	20
Traditional Housing	708000.00	21240.00	19059.143139387004	-2180.856860612996	-324.64	-0.31	240	37.208670464583804	19059.143139387004	20
Container (Max)	795817.1491281092923902000000	27853.60	19059.143139387004	-8794.4570800968212336570000000	-90.49	-1.11	240	37.208670464583804	19059.143139387004	20
Container (Base)	287821.3839620615207555400000	10073.75	9812.224427607343	-261.5240110648102264439000000	-1100.55	-0.09	241	-10.985738376256322	9812.224427607343	32
ODD Cubes Basic	420000.00	14700.00	9812.224427607343	-4887.775572392657	-85.93	-1.16	241	-10.985738376256322	9812.224427607343	32
Container (Max)	516287.1681307945195839000000	18070.05	9812.224427607343	-8257.8264569704651854365000000	-62.52	-1.60	241	-10.985738376256322	9812.224427607343	32
Traditional Housing	708000.00	21240.00	9812.224427607343	-11427.775572392657	-61.95	-1.61	241	-10.985738376256322	9812.224427607343	32
ODD Cubes Basic	420000.00	14700.00	16400.677054912667	1700.677054912667	246.96	0.40	242	36.31263899167392	16400.677054912667	27
Container (Base)	440757.3762948482031456000000	15426.51	16400.677054912667	974.1688845929798899040000000	452.44	0.22	242	36.31263899167392	16400.677054912667	27
Traditional Housing	708000.00	21240.00	16400.677054912667	-4839.322945087333	-146.30	-0.68	242	36.31263899167392	16400.677054912667	27
Container (Max)	790620.1217836583196960000000	27671.70	16400.677054912667	-11271.0272075153741893600000000	-70.15	-1.43	242	36.31263899167392	16400.677054912667	27
ODD Cubes Basic	420000.00	14700.00	17616.76557757904	2916.76557757904	144.00	0.69	243	34.29311936398406	17616.76557757904	21
Container (Base)	434227.4009450869791258000000	15197.96	17616.76557757904	2418.8065445009957305970000000	179.52	0.56	243	34.29311936398406	17616.76557757904	21
Traditional Housing	708000.00	21240.00	17616.76557757904	-3623.23442242096	-195.41	-0.51	243	34.29311936398406	17616.76557757904	21
Container (Max)	778906.8069670757472030000000	27261.74	17616.76557757904	-9644.9726662686111521050000000	-80.76	-1.24	243	34.29311936398406	17616.76557757904	21
ODD Cubes Basic	420000.00	14700.00	16692.1678828555	1992.1678828555	210.83	0.47	244	47.031846281897586	16692.1678828555	32
Container (Base)	475417.1827232761114999800000	16639.60	16692.1678828555	52.5664875408360975007000000	9044.11	0.01	244	47.031846281897586	16692.1678828555	32
Traditional Housing	708000.00	21240.00	16692.1678828555	-4547.8321171445	-155.68	-0.64	244	47.031846281897586	16692.1678828555	32
Container (Max)	852792.0600273200936793000000	29847.72	16692.1678828555	-13155.5542181007032787755000000	-64.82	-1.54	244	47.031846281897586	16692.1678828555	32
ODD Cubes Basic	420000.00	14700.00	9488.581925985116	-5211.418074014884	-80.59	-1.24	245	43.21668534317041	9488.581925985116	38
Container (Base)	463081.1268891674988063000000	16207.84	9488.581925985116	-6719.2575151357464582205000000	-68.92	-1.45	245	43.21668534317041	9488.581925985116	38
Traditional Housing	708000.00	21240.00	9488.581925985116	-11751.418074014884	-60.25	-1.66	245	43.21668534317041	9488.581925985116	38
Container (Max)	830663.9358246555365205000000	29073.24	9488.581925985116	-19584.6558278778277782175000000	-42.41	-2.36	245	43.21668534317041	9488.581925985116	38
ODD Cubes Basic	420000.00	14700.00	9864.326853098675	-4835.673146901325	-86.85	-1.15	246	43.38222310141762	9864.326853098675	23
Container (Base)	463616.3816428167750366000000	16226.57	9864.326853098675	-6362.2465043999121262810000000	-72.87	-1.37	246	43.38222310141762	9864.326853098675	23
Traditional Housing	708000.00	21240.00	9864.326853098675	-11375.673146901325	-62.24	-1.61	246	43.38222310141762	9864.326853098675	23
Container (Max)	831624.0630993772668810000000	29106.84	9864.326853098675	-19242.5153553795293408350000000	-43.22	-2.31	246	43.38222310141762	9864.326853098675	23
Container (Base)	247195.6185580425556654500000	8651.85	16121.717888871619	7469.8712393401295517092500000	33.09	3.02	247	-23.550032455305185	16121.717888871619	21
ODD Cubes Basic	420000.00	14700.00	16121.717888871619	1421.717888871619	295.42	0.34	247	-23.550032455305185	16121.717888871619	21
Container (Max)	443413.6342576071617407500000	15519.48	16121.717888871619	602.2406898553683390737500000	736.27	0.14	247	-23.550032455305185	16121.717888871619	21
Traditional Housing	708000.00	21240.00	16121.717888871619	-5118.282111128381	-138.33	-0.72	247	-23.550032455305185	16121.717888871619	21
Container (Base)	395182.6203473359624890000000	13831.39	9431.38736241947	-4400.0043497372886871150000000	-89.81	-1.11	248	22.2177750399223	9431.38736241947	17
ODD Cubes Basic	420000.00	14700.00	9431.38736241947	-5268.61263758053	-79.72	-1.25	248	22.2177750399223	9431.38736241947	17
Traditional Housing	708000.00	21240.00	9431.38736241947	-11808.61263758053	-59.96	-1.67	248	22.2177750399223	9431.38736241947	17
Container (Max)	708869.2061203013361150000000	24810.42	9431.38736241947	-15379.0348517910767640250000000	-46.09	-2.17	248	22.2177750399223	9431.38736241947	17
Container (Base)	334196.2730569806910674000000	11696.87	13870.036399837842	2173.1668428435178126410000000	153.78	0.65	249	3.35658203733518	13870.036399837842	18
ODD Cubes Basic	420000.00	14700.00	13870.036399837842	-829.963600162158	-506.05	-0.20	249	3.35658203733518	13870.036399837842	18
Traditional Housing	708000.00	21240.00	13870.036399837842	-7369.963600162158	-96.07	-1.04	249	3.35658203733518	13870.036399837842	18
Container (Max)	599473.3436456459107590000000	20981.57	13870.036399837842	-7111.5306277597648765650000000	-84.30	-1.19	249	3.35658203733518	13870.036399837842	18
ODD Cubes Basic	420000.00	14700.00	19085.88793825964	4385.88793825964	95.76	1.04	250	43.85438235100483	19085.88793825964	20
Container (Base)	465143.0755252095474669000000	16280.01	19085.88793825964	2805.8802948773058386585000000	165.77	0.60	250	43.85438235100483	19085.88793825964	20
Traditional Housing	708000.00	21240.00	19085.88793825964	-2154.11206174036	-328.67	-0.30	250	43.85438235100483	19085.88793825964	20
Container (Max)	834362.6103549455642415000000	29202.69	19085.88793825964	-10116.8034241634547484525000000	-82.47	-1.21	250	43.85438235100483	19085.88793825964	20
Container (Base)	324123.5691766498842118935000	11344.32	18349.646847375374	7005.3219261926280525837275000	46.27	2.16	251	0.24140593012679545	18349.646847375374	32
ODD Cubes Basic	420000.00	14700.00	18349.646847375374	3649.646847375374	115.08	0.87	251	0.24140593012679545	18349.646847375374	32
Container (Max)	581405.1664650319199497725000	20349.18	18349.646847375374	-1999.5339789007431982420375000	-290.77	-0.34	251	0.24140593012679545	18349.646847375374	32
Traditional Housing	708000.00	21240.00	18349.646847375374	-2890.353152624626	-244.95	-0.41	251	0.24140593012679545	18349.646847375374	32
Container (Base)	252706.6946152469594907000000	8844.73	16394.97585828704	7550.2415467533964178255000000	33.47	2.99	252	-21.84562689922251	16394.97585828704	31
ODD Cubes Basic	420000.00	14700.00	16394.97585828704	1694.97585828704	247.79	0.40	252	-21.84562689922251	16394.97585828704	31
Container (Max)	453299.2717031644808745000000	15865.47	16394.97585828704	529.5013486762831693925000000	856.09	0.12	252	-21.84562689922251	16394.97585828704	31
Traditional Housing	708000.00	21240.00	16394.97585828704	-4845.02414171296	-146.13	-0.68	252	-21.84562689922251	16394.97585828704	31
ODD Cubes Basic	420000.00	14700.00	16900.350452311093	2200.350452311093	190.88	0.52	253	62.35194044696911	16900.350452311093	17
Container (Base)	524953.6347994433293473000000	18373.38	16900.350452311093	-1473.0267656694235271555000000	-356.38	-0.28	253	62.35194044696911	16900.350452311093	17
Traditional Housing	708000.00	21240.00	16900.350452311093	-4339.649547688907	-163.15	-0.61	253	62.35194044696911	16900.350452311093	17
Container (Max)	941649.3721894431864555000000	32957.73	16900.350452311093	-16057.3775743194185259425000000	-58.64	-1.71	253	62.35194044696911	16900.350452311093	17
ODD Cubes Basic	420000.00	14700.00	10477.579558539925	-4222.420441460075	-99.47	-1.01	254	69.02568388813687	10477.579558539925	19
Traditional Housing	708000.00	21240.00	10477.579558539925	-10762.420441460075	-65.78	-1.52	254	69.02568388813687	10477.579558539925	19
Container (Base)	546532.7170544183995641000000	19128.65	10477.579558539925	-8651.0655383647189847435000000	-63.18	-1.58	254	69.02568388813687	10477.579558539925	19
Container (Max)	980357.4178353882528435000000	34312.51	10477.579558539925	-23834.9300656986638495225000000	-41.13	-2.43	254	69.02568388813687	10477.579558539925	19
ODD Cubes Basic	420000.00	14700.00	19222.267734311077	4522.267734311077	92.87	1.08	255	42.17929087732901	19222.267734311077	25
Container (Base)	459726.7845014819408043000000	16090.44	19222.267734311077	3131.8302767592090718495000000	146.79	0.68	255	42.17929087732901	19222.267734311077	25
Traditional Housing	708000.00	21240.00	19222.267734311077	-2017.732265688923	-350.89	-0.28	255	42.17929087732901	19222.267734311077	25
Container (Max)	824646.9960530521244505000000	28862.64	19222.267734311077	-9640.3771275457473557675000000	-85.54	-1.17	255	42.17929087732901	19222.267734311077	25
ODD Cubes Basic	420000.00	14700.00	9336.891991954844	-5363.108008045156	-78.31	-1.28	256	30.20597791062349	9336.891991954844	35
Container (Base)	421011.9151555473112707000000	14735.42	9336.891991954844	-5398.5250384893118944745000000	-77.99	-1.28	256	30.20597791062349	9336.891991954844	35
Traditional Housing	708000.00	21240.00	9336.891991954844	-11903.108008045156	-59.48	-1.68	256	30.20597791062349	9336.891991954844	35
Container (Max)	755201.1821805117731745000000	26432.04	9336.891991954844	-17095.1493843630680611075000000	-44.18	-2.26	256	30.20597791062349	9336.891991954844	35
Container (Base)	281665.3066330074439184100000	9858.29	15305.591351573492	5447.3056194182314628556500000	51.71	1.93	257	-12.889622897972913	15305.591351573492	28
ODD Cubes Basic	420000.00	14700.00	15305.591351573492	605.591351573492	693.54	0.14	257	-12.889622897972913	15305.591351573492	28
Container (Max)	505244.5427106122059543500000	17683.56	15305.591351573492	-2377.9676432979352084022500000	-212.47	-0.47	257	-12.889622897972913	15305.591351573492	28
Traditional Housing	708000.00	21240.00	15305.591351573492	-5934.408648426508	-119.30	-0.84	257	-12.889622897972913	15305.591351573492	28
ODD Cubes Basic	420000.00	14700.00	11220.897184574136	-3479.102815425864	-120.72	-0.83	258	42.44373181662911	11220.897184574136	17
Container (Base)	460581.8357678430631473000000	16120.36	11220.897184574136	-4899.4670673003712101555000000	-94.01	-1.06	258	42.44373181662911	11220.897184574136	17
Traditional Housing	708000.00	21240.00	11220.897184574136	-10019.102815425864	-70.67	-1.42	258	42.44373181662911	11220.897184574136	17
Container (Max)	826180.7667230396694555000000	28916.33	11220.897184574136	-17695.4296507322524309425000000	-46.69	-2.14	258	42.44373181662911	11220.897184574136	17
ODD Cubes Basic	420000.00	14700.00	12798.758138876545	-1901.241861123455	-220.91	-0.45	259	44.13431408897324	12798.758138876545	29
Container (Base)	466048.2152047087434132000000	16311.69	12798.758138876545	-3512.9293932882610194620000000	-132.67	-0.75	259	44.13431408897324	12798.758138876545	29
Traditional Housing	708000.00	21240.00	12798.758138876545	-8441.241861123455	-83.87	-1.19	259	44.13431408897324	12798.758138876545	29
Container (Max)	835986.2284317492406620000000	29259.52	12798.758138876545	-16460.7598562346784231700000000	-50.79	-1.97	259	44.13431408897324	12798.758138876545	29
Container (Base)	397923.2524264377774110400000	13927.31	14084.55718624924	157.2433513239177906136000000	2530.62	0.04	260	23.065367868312528	14084.55718624924	21
ODD Cubes Basic	420000.00	14700.00	14084.55718624924	-615.44281375076	-682.44	-0.15	260	23.065367868312528	14084.55718624924	21
Traditional Housing	708000.00	21240.00	14084.55718624924	-7155.44281375076	-98.95	-1.01	260	23.065367868312528	14084.55718624924	21
Container (Max)	713785.2869046060780264000000	24982.49	14084.55718624924	-10897.9278554119727309240000000	-65.50	-1.53	260	23.065367868312528	14084.55718624924	21
ODD Cubes Basic	420000.00	14700.00	15679.114998812072	979.114998812072	428.96	0.23	261	50.74245667809046	15679.114998812072	16
Container (Base)	487415.1816966380360778000000	17059.53	15679.114998812072	-1380.4163605702592627230000000	-353.09	-0.28	261	50.74245667809046	15679.114998812072	16
Traditional Housing	708000.00	21240.00	15679.114998812072	-5560.885001187928	-127.32	-0.79	261	50.74245667809046	15679.114998812072	16
Container (Max)	874313.7858557585725230000000	30600.98	15679.114998812072	-14921.8675061394780383050000000	-58.59	-1.71	261	50.74245667809046	15679.114998812072	16
Container (Base)	374150.2072756591895835600000	13095.26	9143.170453297955	-3952.0868013501166354246000000	-94.67	-1.06	262	15.713099487435692	9143.170453297955	24
ODD Cubes Basic	420000.00	14700.00	9143.170453297955	-5556.829546702045	-75.58	-1.32	262	15.713099487435692	9143.170453297955	24
Traditional Housing	708000.00	21240.00	9143.170453297955	-12096.829546702045	-58.53	-1.71	262	15.713099487435692	9143.170453297955	24
Container (Max)	671141.7626821013853846000000	23489.96	9143.170453297955	-14346.7912405755934884610000000	-46.78	-2.14	262	15.713099487435692	9143.170453297955	24
Container (Base)	346617.4933967417336300400000	12131.61	15572.612944655732	3441.0006757697713229486000000	100.73	0.99	263	7.198081726445828	15572.612944655732	19
ODD Cubes Basic	420000.00	14700.00	15572.612944655732	872.612944655732	481.31	0.21	263	7.198081726445828	15572.612944655732	19
Traditional Housing	708000.00	21240.00	15572.612944655732	-5667.387055344268	-124.93	-0.80	263	7.198081726445828	15572.612944655732	19
Container (Max)	621754.2339174721246914000000	21761.40	15572.612944655732	-6188.7852424557923641990000000	-100.46	-1.00	263	7.198081726445828	15572.612944655732	19
ODD Cubes Basic	420000.00	14700.00	8018.14907020541	-6681.85092979459	-62.86	-1.59	264	68.7086059605516	8018.14907020541	20
Traditional Housing	708000.00	21240.00	8018.14907020541	-13221.85092979459	-53.55	-1.87	264	68.7086059605516	8018.14907020541	20
Container (Base)	545507.4677710263599880000000	19092.76	8018.14907020541	-11074.6123017805125995800000000	-49.26	-2.03	264	68.7086059605516	8018.14907020541	20
Container (Max)	978518.3500014973075800000000	34248.14	8018.14907020541	-26229.9931798469957653000000000	-37.31	-2.68	264	68.7086059605516	8018.14907020541	20
ODD Cubes Basic	420000.00	14700.00	16185.444258316405	1485.444258316405	282.74	0.35	265	31.599319845600654	16185.444258316405	32
Container (Base)	425517.1887683605226632200000	14893.10	16185.444258316405	1292.3426514237867067873000000	329.26	0.30	265	31.599319845600654	16185.444258316405	32
Traditional Housing	708000.00	21240.00	16185.444258316405	-5054.555741683595	-140.07	-0.71	265	31.599319845600654	16185.444258316405	32
Container (Max)	763282.6350704760732327000000	26714.89	16185.444258316405	-10529.4479691502575631445000000	-72.49	-1.38	265	31.599319845600654	16185.444258316405	32
ODD Cubes Basic	420000.00	14700.00	19979.177780765065	5279.177780765065	79.56	1.26	266	53.28984763708107	19979.177780765065	32
Container (Base)	495651.9920451670441701000000	17347.82	19979.177780765065	2631.3580591842184540465000000	188.36	0.53	266	53.28984763708107	19979.177780765065	32
Traditional Housing	708000.00	21240.00	19979.177780765065	-1260.822219234935	-561.54	-0.18	266	53.28984763708107	19979.177780765065	32
Container (Max)	889088.7807874520600535000000	31118.11	19979.177780765065	-11138.9295467957571018725000000	-79.82	-1.25	266	53.28984763708107	19979.177780765065	32
ODD Cubes Basic	420000.00	14700.00	13683.892306585421	-1016.107693414579	-413.34	-0.24	267	69.43122084799234	13683.892306585421	17
Container (Base)	547843.9924265238719262000000	19174.54	13683.892306585421	-5490.6474283429145174170000000	-99.78	-1.00	267	69.43122084799234	13683.892306585421	17
Traditional Housing	708000.00	21240.00	13683.892306585421	-7556.107693414579	-93.70	-1.07	267	69.43122084799234	13683.892306585421	17
Container (Max)	982709.5524793979716170000000	34394.83	13683.892306585421	-20710.9420301935080065950000000	-47.45	-2.11	267	69.43122084799234	13683.892306585421	17
ODD Cubes Basic	420000.00	14700.00	9427.18863647848	-5272.81136352152	-79.65	-1.26	268	56.37158641655172	9427.18863647848	28
Container (Base)	505616.5786668708279996000000	17696.58	9427.18863647848	-8269.3916168619989799860000000	-61.14	-1.64	268	56.37158641655172	9427.18863647848	28
Traditional Housing	708000.00	21240.00	9427.18863647848	-11812.81136352152	-59.93	-1.67	268	56.37158641655172	9427.18863647848	28
Container (Max)	906963.0197953208035860000000	31743.71	9427.18863647848	-22316.5170563577481255100000000	-40.64	-2.46	268	56.37158641655172	9427.18863647848	28
Container (Base)	280170.8638694687594671200000	9805.98	15883.976919777659	6077.9966843462524186508000000	46.10	2.17	269	-13.351807872918616	15883.976919777659	22
ODD Cubes Basic	420000.00	14700.00	15883.976919777659	1183.976919777659	354.74	0.28	269	-13.351807872918616	15883.976919777659	22
Container (Max)	502563.8467466783812692000000	17589.73	15883.976919777659	-1705.7577163560843444220000000	-294.63	-0.34	269	-13.351807872918616	15883.976919777659	22
Traditional Housing	708000.00	21240.00	15883.976919777659	-5356.023080222341	-132.19	-0.76	269	-13.351807872918616	15883.976919777659	22
Container (Base)	309281.1847946608872582900000	10824.84	17713.0746998103	6888.2332319971689459598500000	44.90	2.23	270	-4.348884993749397	17713.0746998103	16
ODD Cubes Basic	420000.00	14700.00	17713.0746998103	3013.0746998103	139.39	0.72	270	-4.348884993749397	17713.0746998103	16
Container (Max)	554781.2495920038099301500000	19417.34	17713.0746998103	-1704.2690359098333475552500000	-325.52	-0.31	270	-4.348884993749397	17713.0746998103	16
Traditional Housing	708000.00	21240.00	17713.0746998103	-3526.9253001897	-200.74	-0.50	270	-4.348884993749397	17713.0746998103	16
Container (Base)	308515.2866565657608593800000	10798.04	18410.48769741101	7612.4526644312083699217000000	40.53	2.47	271	-4.585753624922834	18410.48769741101	18
ODD Cubes Basic	420000.00	14700.00	18410.48769741101	3710.48769741101	113.19	0.88	271	-4.585753624922834	18410.48769741101	18
Container (Max)	553407.3996877663166583000000	19369.26	18410.48769741101	-958.7712916608110830405000000	-577.20	-0.17	271	-4.585753624922834	18410.48769741101	18
Traditional Housing	708000.00	21240.00	18410.48769741101	-2829.51230258899	-250.22	-0.40	271	-4.585753624922834	18410.48769741101	18
Container (Base)	232327.5056919039859357500000	8131.46	12687.637277836591	4556.1745786199514922487500000	50.99	1.96	272	-28.148280404429975	12687.637277836591	24
Container (Max)	416743.5662402859235012500000	14586.02	12687.637277836591	-1898.3875405734163225437500000	-219.53	-0.46	272	-28.148280404429975	12687.637277836591	24
ODD Cubes Basic	420000.00	14700.00	12687.637277836591	-2012.362722163409	-208.71	-0.48	272	-28.148280404429975	12687.637277836591	24
Traditional Housing	708000.00	21240.00	12687.637277836591	-8552.362722163409	-82.78	-1.21	272	-28.148280404429975	12687.637277836591	24
ODD Cubes Basic	420000.00	14700.00	14110.224217844665	-589.775782155335	-712.14	-0.14	273	37.91430582345504	14110.224217844665	38
Container (Base)	445936.2538787342299872000000	15607.77	14110.224217844665	-1497.5446679110330495520000000	-297.78	-0.34	273	37.91430582345504	14110.224217844665	38
Traditional Housing	708000.00	21240.00	14110.224217844665	-7129.775782155335	-99.30	-1.01	273	37.91430582345504	14110.224217844665	38
Container (Max)	799909.8694913304047520000000	27996.85	14110.224217844665	-13886.6212143518991663200000000	-57.60	-1.74	273	37.91430582345504	14110.224217844665	38
Container (Base)	338430.0744613956469626900000	11845.05	14788.708340364969	2943.6557342161213563058500000	114.97	0.87	274	4.665966005571683	14788.708340364969	26
ODD Cubes Basic	420000.00	14700.00	14788.708340364969	88.708340364969	4734.62	0.02	274	4.665966005571683	14788.708340364969	26
Traditional Housing	708000.00	21240.00	14788.708340364969	-6451.291659635031	-109.75	-0.91	274	4.665966005571683	14788.708340364969	26
Container (Max)	607067.8361306160399841500000	21247.37	14788.708340364969	-6458.6659242065923994452500000	-93.99	-1.06	274	4.665966005571683	14788.708340364969	26
Container (Base)	398081.0695206478849974000000	13932.84	18870.45974816404	4937.6223149413640250910000000	80.62	1.24	275	23.11417581968618	18870.45974816404	19
ODD Cubes Basic	420000.00	14700.00	18870.45974816404	4170.45974816404	100.71	0.99	275	23.11417581968618	18870.45974816404	19
Traditional Housing	708000.00	21240.00	18870.45974816404	-2369.54025183596	-298.79	-0.33	275	23.11417581968618	18870.45974816404	19
Container (Max)	714068.3754629708283090000000	24992.39	18870.45974816404	-6121.9333930399389908150000000	-116.64	-0.86	275	23.11417581968618	18870.45974816404	19
ODD Cubes Basic	420000.00	14700.00	16257.0796508844	1557.0796508844	269.74	0.37	276	45.6890518127713	16257.0796508844	22
Container (Base)	471075.3508029691045590000000	16487.64	16257.0796508844	-230.5576272195186595650000000	-2043.20	-0.05	276	45.6890518127713	16257.0796508844	22
Traditional Housing	708000.00	21240.00	16257.0796508844	-4982.9203491156	-142.09	-0.70	276	45.6890518127713	16257.0796508844	22
Container (Max)	845003.7849666641785650000000	29575.13	16257.0796508844	-13318.0528229488462497750000000	-63.45	-1.58	276	45.6890518127713	16257.0796508844	22
ODD Cubes Basic	420000.00	14700.00	15268.836863730907	568.836863730907	738.35	0.14	277	53.22904352152449	15268.836863730907	34
Container (Base)	495455.3861938029317007000000	17340.94	15268.836863730907	-2072.1016530521956095245000000	-239.11	-0.42	277	53.22904352152449	15268.836863730907	34
Traditional Housing	708000.00	21240.00	15268.836863730907	-5971.163136269093	-118.57	-0.84	277	53.22904352152449	15268.836863730907	34
Container (Max)	888736.1138770181182245000000	31105.76	15268.836863730907	-15836.9271219647271378575000000	-56.12	-1.78	277	53.22904352152449	15268.836863730907	34
Container (Base)	242388.0800444119767327900000	8483.58	18708.7437697573	10225.1609682028808143523500000	23.71	4.22	278	-25.036855585427247	18708.7437697573	34
ODD Cubes Basic	420000.00	14700.00	18708.7437697573	4008.7437697573	104.77	0.95	278	-25.036855585427247	18708.7437697573	34
Container (Max)	434789.9857617426960376500000	15217.65	18708.7437697573	3491.0942680963056386822500000	124.54	0.80	278	-25.036855585427247	18708.7437697573	34
Traditional Housing	708000.00	21240.00	18708.7437697573	-2531.2562302427	-279.70	-0.36	278	-25.036855585427247	18708.7437697573	34
ODD Cubes Basic	420000.00	14700.00	19049.323035068228	4349.323035068228	96.57	1.04	279	34.740975706336116	19049.323035068228	15
Container (Base)	435675.5130781383875578800000	15248.64	19049.323035068228	3800.6800773333844354742000000	114.63	0.87	279	34.740975706336116	19049.323035068228	15
Traditional Housing	708000.00	21240.00	19049.323035068228	-2190.676964931772	-323.19	-0.31	279	34.740975706336116	19049.323035068228	15
Container (Max)	781504.3961455347896058000000	27352.65	19049.323035068228	-8303.3308300254896362030000000	-94.12	-1.06	279	34.740975706336116	19049.323035068228	15
Container (Base)	235483.3488662864670023100000	8241.92	10090.199157943338	1848.2819476233116549191500000	127.41	0.78	280	-27.172275612496183	10090.199157943338	29
ODD Cubes Basic	420000.00	14700.00	10090.199157943338	-4609.800842056662	-91.11	-1.10	280	-27.172275612496183	10090.199157943338	29
Container (Max)	422404.4428337415137908500000	14784.16	10090.199157943338	-4693.9563412376149826797500000	-89.99	-1.11	280	-27.172275612496183	10090.199157943338	29
Traditional Housing	708000.00	21240.00	10090.199157943338	-11149.800842056662	-63.50	-1.57	280	-27.172275612496183	10090.199157943338	29
Container (Base)	295639.7382536375678736600000	10347.39	14282.061475197883	3934.6706363205681244219000000	75.14	1.33	281	-8.567762947199238	14282.061475197883	17
ODD Cubes Basic	420000.00	14700.00	14282.061475197883	-417.938524802117	-1004.93	-0.10	281	-8.567762947199238	14282.061475197883	17
Container (Max)	530311.5465180970596381000000	18560.90	14282.061475197883	-4278.8426529355140873335000000	-123.94	-0.81	281	-8.567762947199238	14282.061475197883	17
Traditional Housing	708000.00	21240.00	14282.061475197883	-6957.938524802117	-101.75	-0.98	281	-8.567762947199238	14282.061475197883	17
Container (Base)	343236.4258451077446233400000	12013.27	14146.909231076923	2133.6343264981519381831000000	160.87	0.62	282	6.152421993087138	14146.909231076923	27
ODD Cubes Basic	420000.00	14700.00	14146.909231076923	-553.090768923077	-759.37	-0.13	282	6.152421993087138	14146.909231076923	27
Traditional Housing	708000.00	21240.00	14146.909231076923	-7093.090768923077	-99.82	-1.00	282	6.152421993087138	14146.909231076923	27
Container (Max)	615689.3551810050547569000000	21549.13	14146.909231076923	-7402.2182002582539164915000000	-83.18	-1.20	282	6.152421993087138	14146.909231076923	27
Container (Base)	345146.5931929218647468550000	12080.13	17892.7870920836	5812.6563303313347338600750000	59.38	1.68	283	6.7431777378578985	17892.7870920836	15
ODD Cubes Basic	420000.00	14700.00	17892.7870920836	3192.7870920836	131.55	0.76	283	6.7431777378578985	17892.7870920836	15
Traditional Housing	708000.00	21240.00	17892.7870920836	-3347.2129079164	-211.52	-0.47	283	6.7431777378578985	17892.7870920836	15
Container (Max)	619115.7680384627041949250000	21669.05	17892.7870920836	-3776.2647892625946468223750000	-163.95	-0.61	283	6.7431777378578985	17892.7870920836	15
Container (Base)	255562.4560917605150583000000	8944.69	19032.277592522347	10087.5916293107289729595000000	25.33	3.95	284	-20.96242810521319	19032.277592522347	17
ODD Cubes Basic	420000.00	14700.00	19032.277592522347	4332.277592522347	96.95	1.03	284	-20.96242810521319	19032.277592522347	17
Container (Max)	458421.8688683582373405000000	16044.77	19032.277592522347	2987.5121821298086930825000000	153.45	0.65	284	-20.96242810521319	19032.277592522347	17
Traditional Housing	708000.00	21240.00	19032.277592522347	-2207.722407477653	-320.69	-0.31	284	-20.96242810521319	19032.277592522347	17
ODD Cubes Basic	420000.00	14700.00	10090.713890291672	-4609.286109708328	-91.12	-1.10	285	62.302505909260276	10090.713890291672	34
Traditional Housing	708000.00	21240.00	10090.713890291672	-11149.286109708328	-63.50	-1.57	285	62.302505909260276	10090.713890291672	34
Container (Base)	524793.7916821794542266800000	18367.78	10090.713890291672	-8277.0688185846088979338000000	-63.40	-1.58	285	62.302505909260276	10090.713890291672	34
Container (Max)	941362.6493990050638138000000	32947.69	10090.713890291672	-22856.9788386735052334830000000	-41.18	-2.43	285	62.302505909260276	10090.713890291672	34
Container (Base)	325144.4059090184446534320000	11380.05	18954.09427354049	7574.0400667248444371298800000	42.93	2.33	286	0.5571191920092424	18954.09427354049	36
ODD Cubes Basic	420000.00	14700.00	18954.09427354049	4254.09427354049	98.73	1.01	286	0.5571191920092424	18954.09427354049	36
Container (Max)	583236.3191696132063821200000	20413.27	18954.09427354049	-1459.1768973959722233742000000	-399.70	-0.25	286	0.5571191920092424	18954.09427354049	36
Traditional Housing	708000.00	21240.00	18954.09427354049	-2285.90572645951	-309.72	-0.32	286	0.5571191920092424	18954.09427354049	36
Container (Base)	329260.0170975434056134000000	11524.10	15972.23312351153	4448.1325250975108035310000000	74.02	1.35	287	1.82995057803738	15972.23312351153	34
ODD Cubes Basic	420000.00	14700.00	15972.23312351153	1272.23312351153	330.13	0.30	287	1.82995057803738	15972.23312351153	34
Traditional Housing	708000.00	21240.00	15972.23312351153	-5267.76687648847	-134.40	-0.74	287	1.82995057803738	15972.23312351153	34
Container (Max)	590618.8048501457058690000000	20671.66	15972.23312351153	-4699.4250462435697054150000000	-125.68	-0.80	287	1.82995057803738	15972.23312351153	34
Container (Base)	263786.8294177957997630100000	9232.54	14898.65403480468	5666.1150051818270082946500000	46.56	2.15	288	-18.418883533029693	14898.65403480468	30
ODD Cubes Basic	420000.00	14700.00	14898.65403480468	198.65403480468	2114.23	0.05	288	-18.418883533029693	14898.65403480468	30
Container (Max)	473174.5545642511291153500000	16561.11	14898.65403480468	-1662.4553749441095190372500000	-284.62	-0.35	288	-18.418883533029693	14898.65403480468	30
Traditional Housing	708000.00	21240.00	14898.65403480468	-6341.34596519532	-111.65	-0.90	288	-18.418883533029693	14898.65403480468	30
ODD Cubes Basic	420000.00	14700.00	9757.265685497689	-4942.734314502311	-84.97	-1.18	289	40.48705902998634	9757.265685497689	37
Container (Base)	454255.0712793287313462000000	15898.93	9757.265685497689	-6141.6618092788165971170000000	-73.96	-1.35	289	40.48705902998634	9757.265685497689	37
Traditional Housing	708000.00	21240.00	9757.265685497689	-11482.734314502311	-61.66	-1.62	289	40.48705902998634	9757.265685497689	37
Container (Max)	814831.9667268722713170000000	28519.12	9757.265685497689	-18761.8531499428404960950000000	-43.43	-2.30	289	40.48705902998634	9757.265685497689	37
ODD Cubes Basic	420000.00	14700.00	10796.83467815115	-3903.16532184885	-107.60	-0.93	290	30.472707093767028	10796.83467815115	17
Container (Base)	421874.3652981991213460400000	14765.60	10796.83467815115	-3968.7681072858192471114000000	-106.30	-0.94	290	30.472707093767028	10796.83467815115	17
Traditional Housing	708000.00	21240.00	10796.83467815115	-10443.16532184885	-67.80	-1.48	290	30.472707093767028	10796.83467815115	17
Container (Max)	756748.2247792034507514000000	26486.19	10796.83467815115	-15689.3531891209707762990000000	-48.23	-2.07	290	30.472707093767028	10796.83467815115	17
Container (Base)	253758.4968002099153552100000	8881.55	17084.18239333173	8202.6350053243829625676500000	30.94	3.23	291	-21.520336979551153	17084.18239333173	20
ODD Cubes Basic	420000.00	14700.00	17084.18239333173	2384.18239333173	176.16	0.57	291	-21.520336979551153	17084.18239333173	20
Container (Max)	455185.9695017543350423500000	15931.51	17084.18239333173	1152.6734607703282735177500000	394.90	0.25	291	-21.520336979551153	17084.18239333173	20
Traditional Housing	708000.00	21240.00	17084.18239333173	-4155.81760666827	-170.36	-0.59	291	-21.520336979551153	17084.18239333173	20
Container (Base)	399217.7750873931477725400000	13972.62	16932.1303343604	2959.5082063016398279611000000	134.89	0.74	292	23.465723732195578	16932.1303343604	34
ODD Cubes Basic	420000.00	14700.00	16932.1303343604	2232.1303343604	188.16	0.53	292	23.465723732195578	16932.1303343604	34
Traditional Housing	708000.00	21240.00	16932.1303343604	-4307.8696656396	-164.35	-0.61	292	23.465723732195578	16932.1303343604	34
Container (Max)	716107.3709329209621789000000	25063.76	16932.1303343604	-8131.6276482918336762615000000	-88.06	-1.14	292	23.465723732195578	16932.1303343604	34
Container (Base)	331733.5958100196497604320000	11610.68	16799.587424267254	5188.9115709165662583848800000	63.93	1.56	293	2.5949520509241424	16799.587424267254	20
ODD Cubes Basic	420000.00	14700.00	16799.587424267254	2099.587424267254	200.04	0.50	293	2.5949520509241424	16799.587424267254	20
Traditional Housing	708000.00	21240.00	16799.587424267254	-4440.412575732746	-159.44	-0.63	293	2.5949520509241424	16799.587424267254	20
Container (Max)	595055.8516429625721271200000	20826.95	16799.587424267254	-4027.3673832364360244492000000	-147.75	-0.68	293	2.5949520509241424	16799.587424267254	20
Container (Base)	293119.4642817833815927500000	10259.18	16022.362110994964	5763.1808611325456442537500000	50.86	1.97	294	-9.347205821130075	16022.362110994964	29
ODD Cubes Basic	420000.00	14700.00	16022.362110994964	1322.362110994964	317.61	0.31	294	-9.347205821130075	16022.362110994964	29
Container (Max)	525790.7388771545084962500000	18402.68	16022.362110994964	-2380.3137497054437973687500000	-220.89	-0.45	294	-9.347205821130075	16022.362110994964	29
Traditional Housing	708000.00	21240.00	16022.362110994964	-5217.637889005036	-135.69	-0.74	294	-9.347205821130075	16022.362110994964	29
ODD Cubes Basic	420000.00	14700.00	16226.0883218116	1526.0883218116	275.21	0.36	295	64.20579916648529	16226.0883218116	20
Container (Base)	530947.9571988885312447000000	18583.18	16226.0883218116	-2357.0901801494985935645000000	-225.26	-0.44	295	64.20579916648529	16226.0883218116	20
Traditional Housing	708000.00	21240.00	16226.0883218116	-5013.9116781884	-141.21	-0.71	295	64.20579916648529	16226.0883218116	20
Container (Max)	952401.8454555730062645000000	33334.06	16226.0883218116	-17107.9762691334552192575000000	-55.67	-1.80	295	64.20579916648529	16226.0883218116	20
ODD Cubes Basic	420000.00	14700.00	14623.08079855423	-76.91920144577	-5460.28	-0.02	296	65.28493894550715	14623.08079855423	19
Container (Base)	534437.2801345711840245000000	18705.30	14623.08079855423	-4082.2240061557614408575000000	-130.92	-0.76	296	65.28493894550715	14623.08079855423	19
Traditional Housing	708000.00	21240.00	14623.08079855423	-6616.91920144577	-107.00	-0.93	296	65.28493894550715	14623.08079855423	19
Container (Max)	958660.9101308887453575000000	33553.13	14623.08079855423	-18930.0510560268760875125000000	-50.64	-1.97	296	65.28493894550715	14623.08079855423	19
Container (Base)	257978.3625699668405235000000	9029.24	19815.849101648397	10786.6064116995575816775000000	23.92	4.18	297	-20.21526287256355	19815.849101648397	22
ODD Cubes Basic	420000.00	14700.00	19815.849101648397	5115.849101648397	82.10	1.22	297	-20.21526287256355	19815.849101648397	22
Container (Max)	462755.4645759877818225000000	16196.44	19815.849101648397	3619.4078414888246362125000000	127.85	0.78	297	-20.21526287256355	19815.849101648397	22
Traditional Housing	708000.00	21240.00	19815.849101648397	-1424.150898351603	-497.14	-0.20	297	-20.21526287256355	19815.849101648397	22
ODD Cubes Basic	420000.00	14700.00	13581.65992382286	-1118.34007617714	-375.56	-0.27	298	30.99534329959465	13581.65992382286	17
Container (Base)	423564.2728852083291495000000	14824.75	13581.65992382286	-1243.0896271594315202325000000	-340.74	-0.29	298	30.99534329959465	13581.65992382286	17
Traditional Housing	708000.00	21240.00	13581.65992382286	-7658.34007617714	-92.45	-1.08	298	30.99534329959465	13581.65992382286	17
Container (Max)	759779.5409048139497325000000	26592.28	13581.65992382286	-13010.6240078456282406375000000	-58.40	-1.71	298	30.99534329959465	13581.65992382286	17
Container (Base)	324014.7485224834267293504000	11340.52	12732.550957311145	1392.0347590242250644727360000	232.76	0.43	299	0.20775106388059328	12732.550957311145	29
ODD Cubes Basic	420000.00	14700.00	12732.550957311145	-1967.449042688855	-213.47	-0.47	299	0.20775106388059328	12732.550957311145	29
Traditional Housing	708000.00	21240.00	12732.550957311145	-8507.449042688855	-83.22	-1.20	299	0.20775106388059328	12732.550957311145	29
Container (Max)	581209.9665580606350536640000	20342.35	12732.550957311145	-7609.7978722209772268782400000	-76.38	-1.31	299	0.20775106388059328	12732.550957311145	29
ODD Cubes Basic	420000.00	14700.00	8582.685067363056	-6117.314932636944	-68.66	-1.46	300	44.90630482001647	8582.685067363056	36
Container (Base)	468544.3931941858545921000000	16399.05	8582.685067363056	-7816.3686944334489107235000000	-59.94	-1.67	300	44.90630482001647	8582.685067363056	36
Traditional Housing	708000.00	21240.00	8582.685067363056	-12657.314932636944	-55.94	-1.79	300	44.90630482001647	8582.685067363056	36
Container (Max)	840463.8132713365268235000000	29416.23	8582.685067363056	-20833.5483971337224388225000000	-40.34	-2.48	300	44.90630482001647	8582.685067363056	36
ODD Cubes Basic	420000.00	14700.00	19632.85772834126	4932.85772834126	85.14	1.17	301	36.08047604188123	19632.85772834126	24
Container (Base)	440006.6936481000255189000000	15400.23	19632.85772834126	4232.6234506577591068385000000	103.96	0.96	301	36.08047604188123	19632.85772834126	24
Traditional Housing	708000.00	21240.00	19632.85772834126	-1607.14227165874	-440.53	-0.23	301	36.08047604188123	19632.85772834126	24
Container (Max)	789273.5650667132280615000000	27624.57	19632.85772834126	-7991.7170489937029821525000000	-98.76	-1.01	301	36.08047604188123	19632.85772834126	24
ODD Cubes Basic	420000.00	14700.00	12297.546473633949	-2402.453526366051	-174.82	-0.57	302	39.316940419646215	12297.546473633949	39
Container (Base)	450471.5746610966609674500000	15766.51	12297.546473633949	-3468.9586395044341338607500000	-129.86	-0.77	302	39.316940419646215	12297.546473633949	39
Traditional Housing	708000.00	21240.00	12297.546473633949	-8942.453526366051	-79.17	-1.26	302	39.316940419646215	12297.546473633949	39
Container (Max)	808045.2202809690293107500000	28281.58	12297.546473633949	-15984.0362361999670258762500000	-50.55	-1.98	302	39.316940419646215	12297.546473633949	39
Container (Base)	367254.1979863185061292400000	12853.90	17945.09409783233	5091.1971683111822854766000000	72.14	1.39	303	13.580376871099268	17945.09409783233	16
ODD Cubes Basic	420000.00	14700.00	17945.09409783233	3245.09409783233	129.43	0.77	303	13.580376871099268	17945.09409783233	16
Traditional Housing	708000.00	21240.00	17945.09409783233	-3294.90590216767	-214.88	-0.47	303	13.580376871099268	17945.09409783233	16
Container (Max)	658771.8648712193093634000000	23057.02	17945.09409783233	-5111.9211726603458277190000000	-128.87	-0.78	303	13.580376871099268	17945.09409783233	16
Container (Base)	249923.5836405697733256000000	8747.33	13517.482231031543	4770.1568036116009336040000000	52.39	1.91	304	-22.70635713760008	13517.482231031543	23
ODD Cubes Basic	420000.00	14700.00	13517.482231031543	-1182.517768968457	-355.17	-0.28	304	-22.70635713760008	13517.482231031543	23
Container (Max)	448306.9932840626559960000000	15690.74	13517.482231031543	-2173.2625339106499598600000000	-206.28	-0.48	304	-22.70635713760008	13517.482231031543	23
Traditional Housing	708000.00	21240.00	13517.482231031543	-7722.517768968457	-91.68	-1.09	304	-22.70635713760008	13517.482231031543	23
Container (Base)	390142.6459660225492497000000	13654.99	19667.989685595698	6012.9970767849087762605000000	64.88	1.54	305	20.65906667718879	19667.989685595698	21
ODD Cubes Basic	420000.00	14700.00	19667.989685595698	4967.989685595698	84.54	1.18	305	20.65906667718879	19667.989685595698	21
Traditional Housing	708000.00	21240.00	19667.989685595698	-1572.010314404302	-450.38	-0.22	305	20.65906667718879	19667.989685595698	21
Container (Max)	699828.6196810288414395000000	24494.00	19667.989685595698	-4826.0120032403114503825000000	-145.01	-0.69	305	20.65906667718879	19667.989685595698	21
ODD Cubes Basic	420000.00	14700.00	16326.031964582673	1626.031964582673	258.30	0.39	306	30.086805145879964	16326.031964582673	37
Container (Base)	420626.5783628426519965200000	14721.93	16326.031964582673	1604.1017218831801801218000000	262.22	0.38	306	30.086805145879964	16326.031964582673	37
Traditional Housing	708000.00	21240.00	16326.031964582673	-4913.968035417327	-144.08	-0.69	306	30.086805145879964	16326.031964582673	37
Container (Max)	754509.9741863610851982000000	26407.85	16326.031964582673	-10081.8171319399649819370000000	-74.84	-1.34	306	30.086805145879964	16326.031964582673	37
ODD Cubes Basic	420000.00	14700.00	13689.641340107952	-1010.358659892048	-415.69	-0.24	307	39.5740233676446	13689.641340107952	15
Container (Base)	451302.8343776430789780000000	15795.60	13689.641340107952	-2105.9578631095557642300000000	-214.30	-0.47	307	39.5740233676446	13689.641340107952	15
Traditional Housing	708000.00	21240.00	13689.641340107952	-7550.358659892048	-93.77	-1.07	307	39.5740233676446	13689.641340107952	15
Container (Max)	809536.3142335070622300000000	28333.77	13689.641340107952	-14644.1296580647951780500000000	-55.28	-1.81	307	39.5740233676446	13689.641340107952	15
ODD Cubes Basic	420000.00	14700.00	10075.264766699884	-4624.735233300116	-90.82	-1.10	308	52.7129813455835	10075.264766699884	18
Container (Base)	493786.7352722500564050000000	17282.54	10075.264766699884	-7207.2709678288679741750000000	-68.51	-1.46	308	52.7129813455835	10075.264766699884	18
Traditional Housing	708000.00	21240.00	10075.264766699884	-11164.735233300116	-63.41	-1.58	308	52.7129813455835	10075.264766699884	18
Container (Max)	885742.9274534515791750000000	31001.00	10075.264766699884	-20925.7376941709212711250000000	-42.33	-2.36	308	52.7129813455835	10075.264766699884	18
Container (Base)	229590.8456838507103787100000	8035.68	11103.121779807041	3067.4421808722661367451500000	74.85	1.34	309	-28.994644793964703	11103.121779807041	33
Container (Max)	411834.6104627650243648500000	14414.21	11103.121779807041	-3311.0895863897348527697500000	-124.38	-0.80	309	-28.994644793964703	11103.121779807041	33
ODD Cubes Basic	420000.00	14700.00	11103.121779807041	-3596.878220192959	-116.77	-0.86	309	-28.994644793964703	11103.121779807041	33
Traditional Housing	708000.00	21240.00	11103.121779807041	-10136.878220192959	-69.84	-1.43	309	-28.994644793964703	11103.121779807041	33
Container (Base)	261005.6305990157740236900000	9135.20	17284.712143916724	8149.5150729511719091708500000	32.03	3.12	310	-19.279022400665617	17284.712143916724	28
ODD Cubes Basic	420000.00	14700.00	17284.712143916724	2584.712143916724	162.49	0.62	310	-19.279022400665617	17284.712143916724	28
Container (Max)	468185.7061250193881191500000	16386.50	17284.712143916724	898.2124295410454158297500000	521.24	0.19	310	-19.279022400665617	17284.712143916724	28
Traditional Housing	708000.00	21240.00	17284.712143916724	-3955.287856083276	-179.00	-0.56	310	-19.279022400665617	17284.712143916724	28
Container (Base)	309907.9063716301093444200000	10846.78	16706.797938849093	5860.0212158420391729453000000	52.89	1.89	311	-4.155059372978506	16706.797938849093	33
ODD Cubes Basic	420000.00	14700.00	16706.797938849093	2006.797938849093	209.29	0.48	311	-4.155059372978506	16706.797938849093	33
Container (Max)	555905.4478837560162747000000	19456.69	16706.797938849093	-2749.8927370823675696145000000	-202.16	-0.49	311	-4.155059372978506	16706.797938849093	33
Traditional Housing	708000.00	21240.00	16706.797938849093	-4533.202061150907	-156.18	-0.64	311	-4.155059372978506	16706.797938849093	33
ODD Cubes Basic	420000.00	14700.00	10995.10535073948	-3704.89464926052	-113.36	-0.88	312	38.056888374993974	10995.10535073948	21
Container (Base)	446397.2845783567653508200000	15623.90	10995.10535073948	-4628.7996095030067872787000000	-96.44	-1.04	312	38.056888374993974	10995.10535073948	21
Traditional Housing	708000.00	21240.00	10995.10535073948	-10244.89464926052	-69.11	-1.45	312	38.056888374993974	10995.10535073948	21
Container (Max)	800736.8554193837988987000000	28025.79	10995.10535073948	-17030.6845889389529614545000000	-47.02	-2.13	312	38.056888374993974	10995.10535073948	21
Container (Base)	322100.7064291604295425088000	11273.52	14884.721355138241	3611.1966301176259660121920000	89.20	1.12	313	-0.38420301996318784	14884.721355138241	31
ODD Cubes Basic	420000.00	14700.00	14884.721355138241	184.721355138241	2273.69	0.04	313	-0.38420301996318784	14884.721355138241	31
Traditional Housing	708000.00	21240.00	14884.721355138241	-6355.278644861759	-111.40	-0.90	313	-0.38420301996318784	14884.721355138241	31
Container (Max)	577776.6032740625123686080000	20222.18	14884.721355138241	-5337.4597594539469329012800000	-108.25	-0.92	313	-0.38420301996318784	14884.721355138241	31
ODD Cubes Basic	420000.00	14700.00	13477.004057409658	-1222.995942590342	-343.42	-0.29	314	36.72322255224013	13477.004057409658	18
Container (Base)	442084.9694970898035459000000	15472.97	13477.004057409658	-1995.9698749884851241065000000	-221.49	-0.45	314	36.72322255224013	13477.004057409658	18
Traditional Housing	708000.00	21240.00	13477.004057409658	-7762.995942590342	-91.20	-1.10	314	36.72322255224013	13477.004057409658	18
Container (Max)	793001.5269641203660065000000	27755.05	13477.004057409658	-14278.0493863345548102275000000	-55.54	-1.80	314	36.72322255224013	13477.004057409658	18
Container (Base)	243944.3039653625214249000000	8538.05	15723.84724893528	7185.7966101475917501285000000	33.95	2.95	315	-24.55556360726457	15723.84724893528	33
ODD Cubes Basic	420000.00	14700.00	15723.84724893528	1023.84724893528	410.22	0.24	315	-24.55556360726457	15723.84724893528	33
Container (Max)	437581.5032996851307715000000	15315.35	15723.84724893528	408.4946334463004229975000000	1071.21	0.09	315	-24.55556360726457	15723.84724893528	33
Traditional Housing	708000.00	21240.00	15723.84724893528	-5516.15275106472	-128.35	-0.78	315	-24.55556360726457	15723.84724893528	33
Container (Base)	348870.2383938493307748600000	12210.46	8666.22881617288	-3544.2295276118465771201000000	-98.43	-1.02	316	7.894786153975602	8666.22881617288	19
ODD Cubes Basic	420000.00	14700.00	8666.22881617288	-6033.77118382712	-69.61	-1.44	316	7.894786153975602	8666.22881617288	19
Traditional Housing	708000.00	21240.00	8666.22881617288	-12573.77118382712	-56.31	-1.78	316	7.894786153975602	8666.22881617288	19
Container (Max)	625795.1544323661903801000000	21902.83	8666.22881617288	-13236.6015889599366633035000000	-47.28	-2.12	316	7.894786153975602	8666.22881617288	19
Container (Base)	400447.7522219364052356000000	14015.67	13543.19469157563	-472.4766361921441832460000000	-847.55	-0.12	317	23.84611765893692	13543.19469157563	37
ODD Cubes Basic	420000.00	14700.00	13543.19469157563	-1156.80530842437	-363.07	-0.28	317	23.84611765893692	13543.19469157563	37
Traditional Housing	708000.00	21240.00	13543.19469157563	-7696.80530842437	-91.99	-1.09	317	23.84611765893692	13543.19469157563	37
Container (Max)	718313.6747277170828460000000	25140.98	13543.19469157563	-11597.7839238944678996100000000	-61.94	-1.61	317	23.84611765893692	13543.19469157563	37
Container (Base)	333200.0642438944798905600000	11662.00	19998.187818485338	8336.1855699490312038304000000	39.97	2.50	318	3.048485429990592	19998.187818485338	35
ODD Cubes Basic	420000.00	14700.00	19998.187818485338	5298.187818485338	79.27	1.26	318	3.048485429990592	19998.187818485338	35
Container (Max)	597686.3679182169331296000000	20919.02	19998.187818485338	-920.8350586522546595360000000	-649.07	-0.15	318	3.048485429990592	19998.187818485338	35
Traditional Housing	708000.00	21240.00	19998.187818485338	-1241.812181514662	-570.13	-0.18	318	3.048485429990592	19998.187818485338	35
Container (Base)	387916.2408613705653240000000	13577.07	15356.861196581673	1779.7927664337032136600000000	217.96	0.46	319	19.9705083646068	15356.861196581673	16
ODD Cubes Basic	420000.00	14700.00	15356.861196581673	656.861196581673	639.40	0.16	319	19.9705083646068	15356.861196581673	16
Traditional Housing	708000.00	21240.00	15356.861196581673	-5883.138803418327	-120.34	-0.83	319	19.9705083646068	15356.861196581673	16
Container (Max)	695834.9470401376703400000000	24354.22	15356.861196581673	-8997.3619498231454619000000000	-77.34	-1.29	319	19.9705083646068	15356.861196581673	16
ODD Cubes Basic	420000.00	14700.00	12636.610394121431	-2063.389605878569	-203.55	-0.49	320	68.65735132910717	12636.610394121431	23
Container (Base)	545341.7395080749966931000000	19086.96	12636.610394121431	-6450.3504886611938842585000000	-84.54	-1.18	320	68.65735132910717	12636.610394121431	23
Traditional Housing	708000.00	21240.00	12636.610394121431	-8603.389605878569	-82.29	-1.22	320	68.65735132910717	12636.610394121431	23
Container (Max)	978221.0705763880413585000000	34237.74	12636.610394121431	-21601.1270760521504475475000000	-45.29	-2.21	320	68.65735132910717	12636.610394121431	23
ODD Cubes Basic	420000.00	14700.00	9912.04200361511	-4787.95799638489	-87.72	-1.14	321	36.74624008168723	9912.04200361511	35
Container (Base)	442159.3950673299400989000000	15475.58	9912.04200361511	-5563.5368237414379034615000000	-79.47	-1.26	321	36.74624008168723	9912.04200361511	35
Traditional Housing	708000.00	21240.00	9912.04200361511	-11327.95799638489	-62.50	-1.60	321	36.74624008168723	9912.04200361511	35
Container (Max)	793135.0297857900183615000000	27759.73	9912.04200361511	-17847.6840388875406426525000000	-44.44	-2.25	321	36.74624008168723	9912.04200361511	35
Container (Base)	233582.0424496643746430100000	8175.37	10101.128328489016	1925.7568427507628874946500000	121.29	0.82	322	-27.760290945013693	10101.128328489016	30
ODD Cubes Basic	420000.00	14700.00	10101.128328489016	-4598.871671510984	-91.33	-1.09	322	-27.760290945013693	10101.128328489016	30
Container (Max)	418993.9245043733299153500000	14664.79	10101.128328489016	-4563.6590291640505470372500000	-91.81	-1.09	322	-27.760290945013693	10101.128328489016	30
Traditional Housing	708000.00	21240.00	10101.128328489016	-11138.871671510984	-63.56	-1.57	322	-27.760290945013693	10101.128328489016	30
ODD Cubes Basic	420000.00	14700.00	16843.7097609556	2143.7097609556	195.92	0.51	323	42.669149525473046	16843.7097609556	29
Container (Base)	461310.7081501503111277800000	16145.87	16843.7097609556	697.8349757003391105277000000	661.06	0.15	323	42.669149525473046	16843.7097609556	29
Traditional Housing	708000.00	21240.00	16843.7097609556	-4396.2902390444	-161.04	-0.62	323	42.669149525473046	16843.7097609556	29
Container (Max)	827488.2007052199404523000000	28962.09	16843.7097609556	-12118.3772637270979158305000000	-68.28	-1.46	323	42.669149525473046	16843.7097609556	29
ODD Cubes Basic	420000.00	14700.00	18161.335657227606	3461.335657227606	121.34	0.82	324	69.3475792716833	18161.335657227606	39
Container (Base)	547573.5432444389327190000000	19165.07	18161.335657227606	-1003.7383563277566451650000000	-545.53	-0.18	324	69.3475792716833	18161.335657227606	39
Traditional Housing	708000.00	21240.00	18161.335657227606	-3078.664342772394	-229.97	-0.43	324	69.3475792716833	18161.335657227606	39
Container (Max)	982224.4271547267241650000000	34377.85	18161.335657227606	-16216.5192931878293457750000000	-60.57	-1.65	324	69.3475792716833	18161.335657227606	39
ODD Cubes Basic	420000.00	14700.00	13572.207437291112	-1127.792562708888	-372.41	-0.27	325	45.90329371208634	13572.207437291112	25
Container (Base)	471768.0869874713343462000000	16511.88	13572.207437291112	-2939.6756072703847021170000000	-160.48	-0.62	325	45.90329371208634	13572.207437291112	25
Traditional Housing	708000.00	21240.00	13572.207437291112	-7667.792562708888	-92.33	-1.08	325	45.90329371208634	13572.207437291112	25
Container (Max)	846246.3986947863763170000000	29618.62	13572.207437291112	-16046.4165170264111710950000000	-52.74	-1.90	325	45.90329371208634	13572.207437291112	25
Container (Base)	304991.4825178010509309200000	10674.70	14076.952590891926	3402.2507027688892174178000000	89.64	1.12	326	-5.675557374737956	14076.952590891926	27
ODD Cubes Basic	420000.00	14700.00	14076.952590891926	-623.047409108074	-674.11	-0.15	326	-5.675557374737956	14076.952590891926	27
Container (Max)	547086.4834486511183022000000	19148.03	14076.952590891926	-5071.0743298108631405770000000	-107.88	-0.93	326	-5.675557374737956	14076.952590891926	27
Traditional Housing	708000.00	21240.00	14076.952590891926	-7163.047409108074	-98.84	-1.01	326	-5.675557374737956	14076.952590891926	27
Container (Base)	291026.3895250452618472800000	10185.92	18763.845233421533	8577.9216000449488353452000000	33.93	2.95	327	-9.994529176433304	18763.845233421533	38
ODD Cubes Basic	420000.00	14700.00	18763.845233421533	4063.845233421533	103.35	0.97	327	-9.994529176433304	18763.845233421533	38
Container (Max)	522036.2310502280151348000000	18271.27	18763.845233421533	492.5771466635524702820000000	1059.81	0.09	327	-9.994529176433304	18763.845233421533	38
Traditional Housing	708000.00	21240.00	18763.845233421533	-2476.154766578467	-285.93	-0.35	327	-9.994529176433304	18763.845233421533	38
Container (Base)	279446.9822273626706736900000	9780.64	9288.932259651938	-491.7121183057554735791500000	-568.31	-0.18	328	-13.575682100010617	9288.932259651938	18
ODD Cubes Basic	420000.00	14700.00	9288.932259651938	-5411.067740348062	-77.62	-1.29	328	-13.575682100010617	9288.932259651938	18
Container (Max)	501265.3650358334208691500000	17544.29	9288.932259651938	-8255.3555166022317304202500000	-60.72	-1.65	328	-13.575682100010617	9288.932259651938	18
Traditional Housing	708000.00	21240.00	9288.932259651938	-11951.067740348062	-59.24	-1.69	328	-13.575682100010617	9288.932259651938	18
Container (Base)	417582.3947786694477922500000	14615.38	8767.982032033788	-5847.4017852196426727287500000	-71.41	-1.40	329	29.145333215399575	8767.982032033788	16
ODD Cubes Basic	420000.00	14700.00	8767.982032033788	-5932.017967966212	-70.80	-1.41	329	29.145333215399575	8767.982032033788	16
Traditional Housing	708000.00	21240.00	8767.982032033788	-12472.017967966212	-56.77	-1.76	329	29.145333215399575	8767.982032033788	16
Container (Max)	749049.3899159783049787500000	26216.73	8767.982032033788	-17448.7466150254526742562500000	-42.93	-2.33	329	29.145333215399575	8767.982032033788	16
Container (Base)	228612.5019177188225643000000	8001.44	13072.463973036207	5071.0264059160482102495000000	45.08	2.22	330	-29.29721629423899	13072.463973036207	33
Container (Max)	410079.6806325991460505000000	14352.79	13072.463973036207	-1280.3248491047631117675000000	-320.29	-0.31	330	-29.29721629423899	13072.463973036207	33
ODD Cubes Basic	420000.00	14700.00	13072.463973036207	-1627.536026963793	-258.06	-0.39	330	-29.29721629423899	13072.463973036207	33
Traditional Housing	708000.00	21240.00	13072.463973036207	-8167.536026963793	-86.68	-1.15	330	-29.29721629423899	13072.463973036207	33
Container (Base)	257987.0797459825229901000000	9029.55	10975.332608554529	1945.7848174451406953465000000	132.59	0.75	331	-20.21256691934493	10975.332608554529	32
ODD Cubes Basic	420000.00	14700.00	10975.332608554529	-3724.667391445471	-112.76	-0.89	331	-20.21256691934493	10975.332608554529	32
Container (Max)	462771.1012394534387535000000	16196.99	10975.332608554529	-5221.6559348263413563725000000	-88.63	-1.13	331	-20.21256691934493	10975.332608554529	32
Traditional Housing	708000.00	21240.00	10975.332608554529	-10264.667391445471	-68.97	-1.45	331	-20.21256691934493	10975.332608554529	32
ODD Cubes Basic	420000.00	14700.00	18096.271651889983	3396.271651889983	123.67	0.81	332	50.60359128781427	18096.271651889983	29
Container (Base)	486966.1701777572950461000000	17043.82	18096.271651889983	1052.4556956684776733865000000	462.70	0.22	332	50.60359128781427	18096.271651889983	29
Traditional Housing	708000.00	21240.00	18096.271651889983	-3143.728348110017	-225.21	-0.44	332	50.60359128781427	18096.271651889983	29
Container (Max)	873508.3596488871567135000000	30572.79	18096.271651889983	-12476.5209358210674849725000000	-70.01	-1.43	332	50.60359128781427	18096.271651889983	29
ODD Cubes Basic	420000.00	14700.00	9713.530152885016	-4986.469847114984	-84.23	-1.19	333	37.95576327291131	9713.530152885016	19
Container (Base)	446070.3036395296170933000000	15612.46	9713.530152885016	-5898.9304744985205982655000000	-75.62	-1.32	333	37.95576327291131	9713.530152885016	19
Traditional Housing	708000.00	21240.00	9713.530152885016	-11526.469847114984	-61.42	-1.63	333	37.95576327291131	9713.530152885016	19
Container (Max)	800150.3247710492435655000000	28005.26	9713.530152885016	-18291.7312141017075247925000000	-43.74	-2.29	333	37.95576327291131	9713.530152885016	19
Container (Base)	396080.8478630133808042800000	13862.83	8390.174601206942	-5472.6550739985263281498000000	-72.37	-1.38	334	22.495569059176596	8390.174601206942	37
ODD Cubes Basic	420000.00	14700.00	8390.174601206942	-6309.825398793058	-66.56	-1.50	334	22.495569059176596	8390.174601206942	37
Traditional Housing	708000.00	21240.00	8390.174601206942	-12849.825398793058	-55.10	-1.81	334	22.495569059176596	8390.174601206942	37
Container (Max)	710480.4253216772156298000000	24866.81	8390.174601206942	-16476.6402850517605470430000000	-43.12	-2.32	334	22.495569059176596	8390.174601206942	37
ODD Cubes Basic	420000.00	14700.00	15448.123638699235	748.123638699235	561.40	0.18	335	34.45540285125094	15448.123638699235	31
Container (Base)	434752.1332413203269242000000	15216.32	15448.123638699235	231.7989752530235576530000000	1875.56	0.05	335	34.45540285125094	15448.123638699235	31
Traditional Housing	708000.00	21240.00	15448.123638699235	-5791.876361300765	-122.24	-0.82	335	34.45540285125094	15448.123638699235	31
Container (Max)	779848.0593073980145470000000	27294.68	15448.123638699235	-11846.5584370596955091450000000	-65.83	-1.52	335	34.45540285125094	15448.123638699235	31
ODD Cubes Basic	420000.00	14700.00	8819.357486994737	-5880.642513005263	-71.42	-1.40	336	34.138998970087485	8819.357486994737	31
Container (Base)	433729.0634398499766235500000	15180.52	8819.357486994737	-6361.1597334000121818242500000	-68.18	-1.47	336	34.138998970087485	8819.357486994737	31
Traditional Housing	708000.00	21240.00	8819.357486994737	-12420.642513005263	-57.00	-1.75	336	34.138998970087485	8819.357486994737	31
Container (Max)	778012.9009764559173742500000	27230.45	8819.357486994737	-18411.0940471812201080987500000	-42.26	-2.37	336	34.138998970087485	8819.357486994737	31
Container (Base)	384415.9033944915598366800000	13454.56	11609.449725816821	-1845.1068929903835942838000000	-208.34	-0.48	337	18.887962131387276	11609.449725816821	29
ODD Cubes Basic	420000.00	14700.00	11609.449725816821	-3090.550274183179	-135.90	-0.74	337	18.887962131387276	11609.449725816821	29
Traditional Housing	708000.00	21240.00	11609.449725816821	-9630.550274183179	-73.52	-1.36	337	18.887962131387276	11609.449725816821	29
Container (Max)	689556.1247601527701638000000	24134.46	11609.449725816821	-12525.0146407885259557330000000	-55.05	-1.82	337	18.887962131387276	11609.449725816821	29
ODD Cubes Basic	420000.00	14700.00	15076.817635424857	376.817635424857	1114.60	0.09	338	49.12676075740235	15076.817635424857	17
Container (Base)	482190.9420358074805605000000	16876.68	15076.817635424857	-1799.8653358284048196175000000	-267.90	-0.37	338	49.12676075740235	15076.817635424857	17
Traditional Housing	708000.00	21240.00	15076.817635424857	-6163.182364575143	-114.88	-0.87	338	49.12676075740235	15076.817635424857	17
Container (Max)	864942.6687309715001175000000	30272.99	15076.817635424857	-15196.1757701591455041125000000	-56.92	-1.76	338	49.12676075740235	15076.817635424857	17
Container (Base)	337274.0114824024236484200000	11804.59	15926.634917245867	4122.0445153617821723053000000	81.82	1.22	339	4.308431443514294	15926.634917245867	24
ODD Cubes Basic	420000.00	14700.00	15926.634917245867	1226.634917245867	342.40	0.29	339	4.308431443514294	15926.634917245867	24
Traditional Housing	708000.00	21240.00	15926.634917245867	-5313.365082754133	-133.25	-0.75	339	4.308431443514294	15926.634917245867	24
Container (Max)	604994.1177939550809147000000	21174.79	15926.634917245867	-5248.1592055425608320145000000	-115.28	-0.87	339	4.308431443514294	15926.634917245867	24
Container (Base)	334838.0221374325463117100000	11719.33	15967.657395090597	4248.3266202804578790901500000	78.82	1.27	340	3.555055200648397	15967.657395090597	25
ODD Cubes Basic	420000.00	14700.00	15967.657395090597	1267.657395090597	331.32	0.30	340	3.555055200648397	15967.657395090597	25
Traditional Housing	708000.00	21240.00	15967.657395090597	-5272.342604909403	-134.29	-0.74	340	3.555055200648397	15967.657395090597	25
Container (Max)	600624.4979165207350198500000	21021.86	15967.657395090597	-5054.2000319876287256947500000	-118.84	-0.84	340	3.555055200648397	15967.657395090597	25
ODD Cubes Basic	420000.00	14700.00	15641.862292249736	941.862292249736	445.93	0.22	341	64.31636487578152	15641.862292249736	35
Container (Base)	531305.4636802982402136000000	18595.69	15641.862292249736	-2953.8289365607024074760000000	-179.87	-0.56	341	64.31636487578152	15641.862292249736	35
Traditional Housing	708000.00	21240.00	15641.862292249736	-5598.137707750264	-126.47	-0.79	341	64.31636487578152	15641.862292249736	35
Container (Max)	953043.1320977766050760000000	33356.51	15641.862292249736	-17714.6473311724451776600000000	-53.80	-1.86	341	64.31636487578152	15641.862292249736	35
Container (Base)	270093.9951416697529960800000	9453.29	19576.36607845108	10123.0762484926386451372000000	26.68	3.75	342	-16.468272038773144	19576.36607845108	17
ODD Cubes Basic	420000.00	14700.00	19576.36607845108	4876.36607845108	86.13	1.16	342	-16.468272038773144	19576.36607845108	17
Container (Max)	484488.1987615138261428000000	16957.09	19576.36607845108	2619.2791217980960850020000000	184.97	0.54	342	-16.468272038773144	19576.36607845108	17
Traditional Housing	708000.00	21240.00	19576.36607845108	-1663.63392154892	-425.57	-0.23	342	-16.468272038773144	19576.36607845108	17
ODD Cubes Basic	420000.00	14700.00	12334.050917795543	-2365.949082204457	-177.52	-0.56	343	40.4349772413408	12334.050917795543	39
Container (Base)	454086.6684614685829440000000	15893.03	12334.050917795543	-3558.9824783558574030400000000	-127.59	-0.78	343	40.4349772413408	12334.050917795543	39
Traditional Housing	708000.00	21240.00	12334.050917795543	-8905.949082204457	-79.50	-1.26	343	40.4349772413408	12334.050917795543	39
Container (Max)	814529.8897486387070400000000	28508.55	12334.050917795543	-16174.4952234068117464000000000	-50.36	-1.99	343	40.4349772413408	12334.050917795543	39
Container (Base)	284149.1358974837078082000000	9945.22	15648.553312146089	5703.3335557341592267130000000	49.82	2.01	344	-12.12145124605026	15648.553312146089	32
ODD Cubes Basic	420000.00	14700.00	15648.553312146089	948.553312146089	442.78	0.23	344	-12.12145124605026	15648.553312146089	32
Container (Max)	509699.9767003461894870000000	17839.50	15648.553312146089	-2190.9458723660276320450000000	-232.64	-0.43	344	-12.12145124605026	15648.553312146089	32
Traditional Housing	708000.00	21240.00	15648.553312146089	-5591.446687853911	-126.62	-0.79	344	-12.12145124605026	15648.553312146089	32
Container (Base)	239184.5929618850010850500000	8371.46	15651.267118435791	7279.8063647698159620232500000	32.86	3.04	345	-26.027595166159465	15651.267118435791	32
ODD Cubes Basic	420000.00	14700.00	15651.267118435791	951.267118435791	441.52	0.23	345	-26.027595166159465	15651.267118435791	32
Container (Max)	429043.6466565167950267500000	15016.53	15651.267118435791	634.7394854577031740637500000	675.94	0.15	345	-26.027595166159465	15651.267118435791	32
Traditional Housing	708000.00	21240.00	15651.267118435791	-5588.732881564209	-126.68	-0.79	345	-26.027595166159465	15651.267118435791	32
Container (Base)	415404.4230083844428211000000	14539.15	18944.9048403437	4405.7500350502445012615000000	94.29	1.06	346	28.47175383675677	18944.9048403437	23
ODD Cubes Basic	420000.00	14700.00	18944.9048403437	4244.9048403437	98.94	1.01	346	28.47175383675677	18944.9048403437	23
Traditional Housing	708000.00	21240.00	18944.9048403437	-2295.0951596563	-308.48	-0.32	346	28.47175383675677	18944.9048403437	23
Container (Max)	745142.5958408811038385000000	26079.99	18944.9048403437	-7135.0860140871386343475000000	-104.43	-0.96	346	28.47175383675677	18944.9048403437	23
Container (Base)	377035.6399269211600622100000	13196.25	15452.887789059067	2256.6403916168263978226500000	167.08	0.60	347	16.605474659083747	15452.887789059067	26
ODD Cubes Basic	420000.00	14700.00	15452.887789059067	752.887789059067	557.85	0.18	347	16.605474659083747	15452.887789059067	26
Traditional Housing	708000.00	21240.00	15452.887789059067	-5787.112210940933	-122.34	-0.82	347	16.605474659083747	15452.887789059067	26
Container (Max)	676317.5832964186867873500000	23671.12	15452.887789059067	-8218.2276263155870375572500000	-82.29	-1.22	347	16.605474659083747	15452.887789059067	26
ODD Cubes Basic	420000.00	14700.00	12755.387519538886	-1944.612480461114	-215.98	-0.46	348	47.95355363847575	12755.387519538886	18
Container (Base)	478397.4589412566443225000000	16743.91	12755.387519538886	-3988.5235434050965512875000000	-119.94	-0.83	348	47.95355363847575	12755.387519538886	18
Traditional Housing	708000.00	21240.00	12755.387519538886	-8484.612480461114	-83.45	-1.20	348	47.95355363847575	12755.387519538886	18
Container (Max)	858138.0087808412737875000000	30034.83	12755.387519538886	-17279.4427877905585825625000000	-49.66	-2.01	348	47.95355363847575	12755.387519538886	18
ODD Cubes Basic	420000.00	14700.00	14650.923952173991	-49.076047826009	-8558.15	-0.01	349	47.65720162362841	14650.923952173991	22
Container (Base)	477439.2254458888097463000000	16710.37	14650.923952173991	-2059.4489384321173411205000000	-231.83	-0.43	349	47.65720162362841	14650.923952173991	22
Traditional Housing	708000.00	21240.00	14650.923952173991	-6589.076047826009	-107.45	-0.93	349	47.65720162362841	14650.923952173991	22
Container (Max)	856419.1522771259594205000000	29974.67	14650.923952173991	-15323.7463775254175797175000000	-55.89	-1.79	349	47.65720162362841	14650.923952173991	22
ODD Cubes Basic	420000.00	14700.00	8314.458179632316	-6385.541820367684	-65.77	-1.52	350	37.25235335225881	8314.458179632316	23
Container (Base)	443795.8768997942040183000000	15532.86	8314.458179632316	-7218.3975118604811406405000000	-61.48	-1.63	350	37.25235335225881	8314.458179632316	23
Traditional Housing	708000.00	21240.00	8314.458179632316	-12925.541820367684	-54.78	-1.83	350	37.25235335225881	8314.458179632316	23
Container (Max)	796070.5120607687109405000000	27862.47	8314.458179632316	-19548.0097424945888829175000000	-40.72	-2.46	350	37.25235335225881	8314.458179632316	23
Container (Base)	264492.1705454990451228600000	9257.23	8417.357983277088	-839.8679858153785793001000000	-314.92	-0.32	351	-18.200743314220798	8417.357983277088	28
ODD Cubes Basic	420000.00	14700.00	8417.357983277088	-6282.642016722912	-66.85	-1.50	351	-18.200743314220798	8417.357983277088	28
Container (Max)	474439.7787403536605601000000	16605.39	8417.357983277088	-8188.0342726352901196035000000	-57.94	-1.73	351	-18.200743314220798	8417.357983277088	28
Traditional Housing	708000.00	21240.00	8417.357983277088	-12822.642016722912	-55.21	-1.81	351	-18.200743314220798	8417.357983277088	28
ODD Cubes Basic	420000.00	14700.00	19649.36201186121	4949.36201186121	84.86	1.18	352	36.0648161176546	19649.36201186121	36
Container (Base)	439956.0583793079132780000000	15398.46	19649.36201186121	4250.8999685854330352700000000	103.50	0.97	352	36.0648161176546	19649.36201186121	36
Traditional Housing	708000.00	21240.00	19649.36201186121	-1590.63798813879	-445.10	-0.22	352	36.0648161176546	19649.36201186121	36
Container (Max)	789182.7367232025627300000000	27621.40	19649.36201186121	-7972.0337734508796955500000000	-98.99	-1.01	352	36.0648161176546	19649.36201186121	36
Container (Base)	351432.5773861996751439000000	12300.14	15507.998845539089	3207.8586370221003699635000000	109.55	0.91	353	8.68723843911873	15507.998845539089	39
ODD Cubes Basic	420000.00	14700.00	15507.998845539089	807.998845539089	519.80	0.19	353	8.68723843911873	15507.998845539089	39
Traditional Housing	708000.00	21240.00	15507.998845539089	-5732.001154460911	-123.52	-0.81	353	8.68723843911873	15507.998845539089	39
Container (Max)	630391.4173088105899365000000	22063.70	15507.998845539089	-6555.7007602692816477775000000	-96.16	-1.04	353	8.68723843911873	15507.998845539089	39
Container (Base)	350511.6176691742552045500000	12267.91	10530.9236412559	-1736.9829771651989321592500000	-201.79	-0.50	354	8.402414052314185	10530.9236412559	23
ODD Cubes Basic	420000.00	14700.00	10530.9236412559	-4169.0763587441	-100.74	-0.99	354	8.402414052314185	10530.9236412559	23
Traditional Housing	708000.00	21240.00	10530.9236412559	-10709.0763587441	-66.11	-1.51	354	8.402414052314185	10530.9236412559	23
Container (Max)	628739.4216241248887092500000	22005.88	10530.9236412559	-11474.9561155884711048237500000	-54.79	-1.83	354	8.402414052314185	10530.9236412559	23
Container (Base)	311535.9848982138070348800000	10903.76	9616.206816752643	-1287.5526546848402462208000000	-241.96	-0.41	355	-3.651544985289984	9616.206816752643	29
ODD Cubes Basic	420000.00	14700.00	9616.206816752643	-5083.793183247357	-82.62	-1.21	355	-3.651544985289984	9616.206816752643	29
Traditional Housing	708000.00	21240.00	9616.206816752643	-11623.793183247357	-60.91	-1.64	355	-3.651544985289984	9616.206816752643	29
Container (Max)	558825.8565080688283008000000	19558.90	9616.206816752643	-9942.6981610297659905280000000	-56.20	-1.78	355	-3.651544985289984	9616.206816752643	29
ODD Cubes Basic	420000.00	14700.00	14685.827783099652	-14.172216900348	-29635.45	0.00	356	61.39838984139173	14685.827783099652	19
Container (Base)	521870.3956648512615339000000	18265.46	14685.827783099652	-3579.6360651701421536865000000	-145.79	-0.69	356	61.39838984139173	14685.827783099652	19
Traditional Housing	708000.00	21240.00	14685.827783099652	-6554.172216900348	-108.02	-0.93	356	61.39838984139173	14685.827783099652	19
Container (Max)	936118.7309995641035865000000	32764.16	14685.827783099652	-18078.3278018850916255275000000	-51.78	-1.93	356	61.39838984139173	14685.827783099652	19
ODD Cubes Basic	420000.00	14700.00	13279.847771429064	-1420.152228570936	-295.74	-0.34	357	34.232366807204215	13279.847771429064	21
Container (Base)	434030.9618054183249074500000	15191.08	13279.847771429064	-1911.2358917605773717607500000	-227.09	-0.44	357	34.232366807204215	13279.847771429064	21
Traditional Housing	708000.00	21240.00	13279.847771429064	-7960.152228570936	-88.94	-1.12	357	34.232366807204215	13279.847771429064	21
Container (Max)	778554.4391001248072107500000	27249.41	13279.847771429064	-13969.5575970753042523762500000	-55.73	-1.79	357	34.232366807204215	13279.847771429064	21
Container (Base)	297724.2026591604617870400000	10420.35	14152.28653163586	3731.9394385652438374536000000	79.78	1.25	358	-7.923102507504272	14152.28653163586	16
ODD Cubes Basic	420000.00	14700.00	14152.28653163586	-547.71346836414	-766.82	-0.13	358	-7.923102507504272	14152.28653163586	16
Container (Max)	534050.6093013498471864000000	18691.77	14152.28653163586	-4539.4847939113846515240000000	-117.65	-0.85	358	-7.923102507504272	14152.28653163586	16
Traditional Housing	708000.00	21240.00	14152.28653163586	-7087.71346836414	-99.89	-1.00	358	-7.923102507504272	14152.28653163586	16
Container (Base)	401824.9023111632345083200000	14063.87	8137.773000664491	-5926.0985802262222077912000000	-67.81	-1.47	359	24.272027633554224	8137.773000664491	22
ODD Cubes Basic	420000.00	14700.00	8137.773000664491	-6562.226999335509	-64.00	-1.56	359	24.272027633554224	8137.773000664491	22
Traditional Housing	708000.00	21240.00	8137.773000664491	-13102.226999335509	-54.04	-1.85	359	24.272027633554224	8137.773000664491	22
Container (Max)	720783.9738759961769112000000	25227.44	8137.773000664491	-17089.6660849953751918920000000	-42.18	-2.37	359	24.272027633554224	8137.773000664491	22
Container (Base)	300836.7383429544496800300000	10529.29	16328.4608931896	5799.1750511861942611989500000	51.88	1.93	360	-6.960491384395379	16328.4608931896	26
ODD Cubes Basic	420000.00	14700.00	16328.4608931896	1628.4608931896	257.91	0.39	360	-6.960491384395379	16328.4608931896	26
Container (Max)	539633.8019459375820310500000	18887.18	16328.4608931896	-2558.7221749182153710867500000	-210.90	-0.47	360	-6.960491384395379	16328.4608931896	26
Traditional Housing	708000.00	21240.00	16328.4608931896	-4911.5391068104	-144.15	-0.69	360	-6.960491384395379	16328.4608931896	26
Container (Base)	229494.6236238665583366000000	8032.31	15816.770667899891	7784.4588410645614582190000000	29.48	3.39	361	-29.02440330427238	15816.770667899891	30
Container (Max)	411662.0096150549823810000000	14408.17	15816.770667899891	1408.6003313729666166650000000	292.25	0.34	361	-29.02440330427238	15816.770667899891	30
ODD Cubes Basic	420000.00	14700.00	15816.770667899891	1116.770667899891	376.08	0.27	361	-29.02440330427238	15816.770667899891	30
Traditional Housing	708000.00	21240.00	15816.770667899891	-5423.229332100109	-130.55	-0.77	361	-29.02440330427238	15816.770667899891	30
Container (Base)	235012.7897355377201355000000	8225.45	14328.372649000443	6102.9250082566227952575000000	38.51	2.60	362	-27.31780501339515	14328.372649000443	23
ODD Cubes Basic	420000.00	14700.00	14328.372649000443	-371.627350999557	-1130.16	-0.09	362	-27.31780501339515	14328.372649000443	23
Container (Max)	421560.3650320574602425000000	14754.61	14328.372649000443	-426.2401271215681084875000000	-989.02	-0.10	362	-27.31780501339515	14328.372649000443	23
Traditional Housing	708000.00	21240.00	14328.372649000443	-6911.627350999557	-102.44	-0.98	362	-27.31780501339515	14328.372649000443	23
Container (Base)	401526.1030091679532885500000	14053.41	10533.39376534277	-3520.0198399781083650992500000	-114.07	-0.88	363	24.179618241052985	10533.39376534277	21
ODD Cubes Basic	420000.00	14700.00	10533.39376534277	-4166.60623465723	-100.80	-0.99	363	24.179618241052985	10533.39376534277	21
Traditional Housing	708000.00	21240.00	10533.39376534277	-10706.60623465723	-66.13	-1.51	363	24.179618241052985	10533.39376534277	21
Container (Max)	720247.9947790193656492500000	25208.68	10533.39376534277	-14675.2860519229077977237500000	-49.08	-2.04	363	24.179618241052985	10533.39376534277	21
Container (Base)	234303.9749861733098172000000	8200.64	18487.664854472623	10287.0257299565571563980000000	22.78	4.39	364	-27.53701951606396	18487.664854472623	23
ODD Cubes Basic	420000.00	14700.00	18487.664854472623	3787.664854472623	110.89	0.90	364	-27.53701951606396	18487.664854472623	23
Container (Max)	420288.9099558532288020000000	14710.11	18487.664854472623	3777.5530060177599919300000000	111.26	0.90	364	-27.53701951606396	18487.664854472623	23
Traditional Housing	708000.00	21240.00	18487.664854472623	-2752.335145527377	-257.24	-0.39	364	-27.53701951606396	18487.664854472623	23
Container (Base)	275795.3283778548651623400000	9652.84	10263.719845722104	610.8833524971837193181000000	451.47	0.22	365	-14.705025815355562	10263.719845722104	23
ODD Cubes Basic	420000.00	14700.00	10263.719845722104	-4436.280154277896	-94.67	-1.06	365	-14.705025815355562	10263.719845722104	23
Container (Max)	494715.1150196469726219000000	17315.03	10263.719845722104	-7051.3091799655400417665000000	-70.16	-1.43	365	-14.705025815355562	10263.719845722104	23
Traditional Housing	708000.00	21240.00	10263.719845722104	-10976.280154277896	-64.50	-1.55	365	-14.705025815355562	10263.719845722104	23
Container (Base)	392923.2727243255360248000000	13752.31	12854.495695902438	-897.8188494489557608680000000	-437.64	-0.23	366	21.51902862419336	12854.495695902438	28
ODD Cubes Basic	420000.00	14700.00	12854.495695902438	-1845.504304097562	-227.58	-0.44	366	21.51902862419336	12854.495695902438	28
Traditional Housing	708000.00	21240.00	12854.495695902438	-8385.504304097562	-84.43	-1.18	366	21.51902862419336	12854.495695902438	28
Container (Max)	704816.4419717526976680000000	24668.58	12854.495695902438	-11814.0797731089064183800000000	-59.66	-1.68	366	21.51902862419336	12854.495695902438	28
Container (Base)	348386.9099721754113687600000	12193.54	18328.312690187635	6134.7708411614956020934000000	56.79	1.76	367	7.745307605909332	18328.312690187635	23
ODD Cubes Basic	420000.00	14700.00	18328.312690187635	3628.312690187635	115.76	0.86	367	7.745307605909332	18328.312690187635	23
Traditional Housing	708000.00	21240.00	18328.312690187635	-2911.687309812365	-243.16	-0.41	367	7.745307605909332	18328.312690187635	23
Container (Max)	624928.1713796544210666000000	21872.49	18328.312690187635	-3544.1733081002697373310000000	-176.33	-0.57	367	7.745307605909332	18328.312690187635	23
Container (Base)	266348.6477589499276504500000	9322.20	11709.430519272355	2387.2278477091075322342500000	111.57	0.90	368	-17.626592269215685	11709.430519272355	29
ODD Cubes Basic	420000.00	14700.00	11709.430519272355	-2990.569480727645	-140.44	-0.71	368	-17.626592269215685	11709.430519272355	29
Container (Max)	477769.8835089355662157500000	16721.95	11709.430519272355	-5012.5154035403898175512500000	-95.32	-1.05	368	-17.626592269215685	11709.430519272355	29
Traditional Housing	708000.00	21240.00	11709.430519272355	-9530.569480727645	-74.29	-1.35	368	-17.626592269215685	11709.430519272355	29
Container (Base)	302825.3822750771724212100000	10598.89	14771.076219559534	4172.1878399318329652576500000	72.58	1.38	369	-6.345465256684953	14771.076219559534	22
ODD Cubes Basic	420000.00	14700.00	14771.076219559534	71.076219559534	5909.15	0.02	369	-6.345465256684953	14771.076219559534	22
Container (Max)	543200.9842379644383523500000	19012.03	14771.076219559534	-4240.9582287692213423322500000	-128.08	-0.78	369	-6.345465256684953	14771.076219559534	22
Traditional Housing	708000.00	21240.00	14771.076219559534	-6468.923780440466	-109.45	-0.91	369	-6.345465256684953	14771.076219559534	22
Container (Base)	414755.3151787591366464600000	14516.44	8971.936887031334	-5544.4991442252357826261000000	-74.80	-1.34	370	28.271004839677722	8971.936887031334	16
ODD Cubes Basic	420000.00	14700.00	8971.936887031334	-5728.063112968666	-73.32	-1.36	370	28.271004839677722	8971.936887031334	16
Traditional Housing	708000.00	21240.00	8971.936887031334	-12268.063112968666	-57.71	-1.73	370	28.271004839677722	8971.936887031334	16
Container (Max)	743978.2416203727714861000000	26039.24	8971.936887031334	-17067.3015696817130020135000000	-43.59	-2.29	370	28.271004839677722	8971.936887031334	16
Container (Base)	301841.8098400807646740200000	10564.46	15959.881130702444	5395.4177862996172364093000000	55.94	1.79	371	-6.649653822695786	15959.881130702444	26
ODD Cubes Basic	420000.00	14700.00	15959.881130702444	1259.881130702444	333.36	0.30	371	-6.649653822695786	15959.881130702444	26
Container (Max)	541436.6753456733064107000000	18950.28	15959.881130702444	-2990.4025063961217243745000000	-181.06	-0.55	371	-6.649653822695786	15959.881130702444	26
Traditional Housing	708000.00	21240.00	15959.881130702444	-5280.118869297556	-134.09	-0.75	371	-6.649653822695786	15959.881130702444	26
Container (Base)	265872.4778359154912908500000	9305.54	13886.931240999153	4581.3945167421108048202500000	58.03	1.72	372	-17.773856914819405	13886.931240999153	31
ODD Cubes Basic	420000.00	14700.00	13886.931240999153	-813.068759000847	-516.56	-0.19	372	-17.773856914819405	13886.931240999153	31
Container (Max)	476915.7412012017100297500000	16692.05	13886.931240999153	-2805.1197010429068510412500000	-170.02	-0.59	372	-17.773856914819405	13886.931240999153	31
Traditional Housing	708000.00	21240.00	13886.931240999153	-7353.068759000847	-96.29	-1.04	372	-17.773856914819405	13886.931240999153	31
Container (Base)	231788.2183996224918141000000	8112.59	10867.430542506574	2754.8428985197867865065000000	84.14	1.19	373	-28.31506530228813	10867.430542506574	30
Container (Max)	415776.2054934637315935000000	14552.17	10867.430542506574	-3684.7366497646566057725000000	-112.84	-0.89	373	-28.31506530228813	10867.430542506574	30
ODD Cubes Basic	420000.00	14700.00	10867.430542506574	-3832.569457493426	-109.59	-0.91	373	-28.31506530228813	10867.430542506574	30
Traditional Housing	708000.00	21240.00	10867.430542506574	-10372.569457493426	-68.26	-1.47	373	-28.31506530228813	10867.430542506574	30
Container (Base)	290260.7546665157471412900000	10159.13	12810.745198373088	2651.6187850450368500548500000	109.47	0.91	374	-10.231316383371297	12810.745198373088	15
ODD Cubes Basic	420000.00	14700.00	12810.745198373088	-1889.254801626912	-222.31	-0.45	374	-10.231316383371297	12810.745198373088	15
Container (Max)	520662.8534106273088351500000	18223.20	12810.745198373088	-5412.4546709988678092302500000	-96.20	-1.04	374	-10.231316383371297	12810.745198373088	15
Traditional Housing	708000.00	21240.00	12810.745198373088	-8429.254801626912	-83.99	-1.19	374	-10.231316383371297	12810.745198373088	15
Container (Base)	305531.3910714840933494400000	10693.60	10585.152847055131	-108.4458404468122672304000000	-2817.36	-0.04	375	-5.508580339922592	10585.152847055131	19
ODD Cubes Basic	420000.00	14700.00	10585.152847055131	-4114.847152944869	-102.07	-0.98	375	-5.508580339922592	10585.152847055131	19
Traditional Housing	708000.00	21240.00	10585.152847055131	-10654.847152944869	-66.45	-1.50	375	-5.508580339922592	10585.152847055131	19
Container (Max)	548054.9585994319702704000000	19181.92	10585.152847055131	-8596.7707039249879594640000000	-63.75	-1.57	375	-5.508580339922592	10585.152847055131	19
ODD Cubes Basic	420000.00	14700.00	17290.08160460137	2590.08160460137	162.16	0.62	376	36.246026343841095	17290.08160460137	24
Container (Base)	440541.9889609661118058500000	15418.97	17290.08160460137	1871.1119909675560867952500000	235.44	0.42	376	36.246026343841095	17290.08160460137	24
Traditional Housing	708000.00	21240.00	17290.08160460137	-3949.91839539863	-179.24	-0.56	376	36.246026343841095	17290.08160460137	24
Container (Max)	790233.7650955955430547500000	27658.18	17290.08160460137	-10368.1001737444740069162500000	-76.22	-1.31	376	36.246026343841095	17290.08160460137	24
Container (Base)	397801.4952123507926426400000	13923.05	18064.400306159278	4141.3479737270002575076000000	96.06	1.04	377	23.027712123766648	18064.400306159278	16
ODD Cubes Basic	420000.00	14700.00	18064.400306159278	3364.400306159278	124.84	0.80	377	23.027712123766648	18064.400306159278	16
Traditional Housing	708000.00	21240.00	18064.400306159278	-3175.599693840722	-222.95	-0.45	377	23.027712123766648	18064.400306159278	16
Container (Max)	713566.8817034527467324000000	24974.84	18064.400306159278	-6910.4405534615681356340000000	-103.26	-0.97	377	23.027712123766648	18064.400306159278	16
ODD Cubes Basic	420000.00	14700.00	13749.883816295693	-950.116183704307	-442.05	-0.23	378	46.763113864095104	13749.883816295693	19
Container (Base)	474548.2552615810321267200000	16609.19	13749.883816295693	-2859.3051178596431244352000000	-165.97	-0.60	378	46.763113864095104	13749.883816295693	19
Traditional Housing	708000.00	21240.00	13749.883816295693	-7490.116183704307	-94.52	-1.06	378	46.763113864095104	13749.883816295693	19
Container (Max)	851233.3985674448079552000000	29793.17	13749.883816295693	-16043.2851335648752784320000000	-53.06	-1.88	378	46.763113864095104	13749.883816295693	19
Container (Base)	272505.8236422160060501500000	9537.70	9547.081233036835	9.3774055592747882447500000	29059.83	0.00	379	-15.722367998621895	9547.081233036835	32
ODD Cubes Basic	420000.00	14700.00	9547.081233036835	-5152.918766963165	-81.51	-1.23	379	-15.722367998621895	9547.081233036835	32
Container (Max)	488814.4794895930779052500000	17108.51	9547.081233036835	-7561.4255490989227266837500000	-64.65	-1.55	379	-15.722367998621895	9547.081233036835	32
Traditional Housing	708000.00	21240.00	9547.081233036835	-11692.918766963165	-60.55	-1.65	379	-15.722367998621895	9547.081233036835	32
ODD Cubes Basic	420000.00	14700.00	17773.217967266683	3073.217967266683	136.66	0.73	380	55.29418590264871	17773.217967266683	17
Container (Base)	502132.8795232014183753000000	17574.65	17773.217967266683	198.5671839546333568645000000	2528.78	0.04	380	55.29418590264871	17773.217967266683	17
Traditional Housing	708000.00	21240.00	17773.217967266683	-3466.782032733317	-204.22	-0.49	380	55.29418590264871	17773.217967266683	17
Container (Max)	900714.0429446576504355000000	31524.99	17773.217967266683	-13751.7735357963347652425000000	-65.50	-1.53	380	55.29418590264871	17773.217967266683	17
Container (Base)	373812.5871015903267141600000	13083.44	10104.111589196587	-2979.3289593590744349956000000	-125.47	-0.80	381	15.608683998599112	10104.111589196587	27
ODD Cubes Basic	420000.00	14700.00	10104.111589196587	-4595.888410803413	-91.39	-1.09	381	15.608683998599112	10104.111589196587	27
Traditional Housing	708000.00	21240.00	10104.111589196587	-11135.888410803413	-63.58	-1.57	381	15.608683998599112	10104.111589196587	27
Container (Max)	670536.1476260747795556000000	23468.77	10104.111589196587	-13364.6535777160302844460000000	-50.17	-1.99	381	15.608683998599112	10104.111589196587	27
ODD Cubes Basic	420000.00	14700.00	19055.17370476848	4355.17370476848	96.44	1.04	382	31.49051434396997	19055.17370476848	21
Container (Base)	425165.3737952228200971000000	14880.79	19055.17370476848	4174.3856219356812966015000000	101.85	0.98	382	31.49051434396997	19055.17370476848	21
Traditional Housing	708000.00	21240.00	19055.17370476848	-2184.82629523152	-324.05	-0.31	382	31.49051434396997	19055.17370476848	21
Container (Max)	762651.5577207430244985000000	26692.80	19055.17370476848	-7637.6308154575258574475000000	-99.85	-1.00	382	31.49051434396997	19055.17370476848	21
ODD Cubes Basic	420000.00	14700.00	11974.13998080799	-2725.86001919201	-154.08	-0.65	383	34.75396534079427	11974.13998080799	34
Container (Base)	435717.5141518844164461000000	15250.11	11974.13998080799	-3275.9730145079645756135000000	-133.00	-0.75	383	34.75396534079427	11974.13998080799	34
Traditional Housing	708000.00	21240.00	11974.13998080799	-9265.86001919201	-76.41	-1.31	383	34.75396534079427	11974.13998080799	34
Container (Max)	781579.7366748738057135000000	27355.29	11974.13998080799	-15381.1508028125931999725000000	-50.81	-1.97	383	34.75396534079427	11974.13998080799	34
ODD Cubes Basic	420000.00	14700.00	8893.91672014359	-5806.08327985641	-72.34	-1.38	384	68.7557456158497	8893.91672014359	18
Traditional Housing	708000.00	21240.00	8893.91672014359	-12346.08327985641	-57.35	-1.74	384	68.7557456158497	8893.91672014359	18
Container (Base)	545659.8905466568954710000000	19098.10	8893.91672014359	-10204.1794489894013414850000000	-53.47	-1.87	384	68.7557456158497	8893.91672014359	18
Container (Max)	978791.7623592090524850000000	34257.71	8893.91672014359	-25363.7949624287268369750000000	-38.59	-2.59	384	68.7557456158497	8893.91672014359	18
Container (Base)	341443.4444875287193047300000	11950.52	19087.62331093448	7137.1027538709748243344500000	47.84	2.09	385	5.597908254555911	19087.62331093448	22
ODD Cubes Basic	420000.00	14700.00	19087.62331093448	4387.62331093448	95.72	1.04	385	5.597908254555911	19087.62331093448	22
Traditional Housing	708000.00	21240.00	19087.62331093448	-2152.37668906552	-328.94	-0.30	385	5.597908254555911	19087.62331093448	22
Container (Max)	612473.1477718370115955500000	21436.56	19087.62331093448	-2348.9368610798154058442500000	-260.74	-0.38	385	5.597908254555911	19087.62331093448	22
ODD Cubes Basic	420000.00	14700.00	10862.951767909803	-3837.048232090197	-109.46	-0.91	386	57.75729881443273	10862.951767909803	15
Container (Base)	510097.1827055512221639000000	17853.40	10862.951767909803	-6990.4496267844897757365000000	-72.97	-1.37	386	57.75729881443273	10862.951767909803	15
Traditional Housing	708000.00	21240.00	10862.951767909803	-10377.048232090197	-68.23	-1.47	386	57.75729881443273	10862.951767909803	15
Container (Max)	915000.2209886505556365000000	32025.01	10862.951767909803	-21162.0559666929664472775000000	-43.24	-2.31	386	57.75729881443273	10862.951767909803	15
Container (Base)	382624.6835524053242268000000	13391.86	15853.171749951704	2461.3078256175176520620000000	155.46	0.64	387	18.33399317517476	15853.171749951704	18
ODD Cubes Basic	420000.00	14700.00	15853.171749951704	1153.171749951704	364.21	0.27	387	18.33399317517476	15853.171749951704	18
Traditional Housing	708000.00	21240.00	15853.171749951704	-5386.828250048296	-131.43	-0.76	387	18.33399317517476	15853.171749951704	18
Container (Max)	686343.0771156723667380000000	24022.01	15853.171749951704	-8168.8359490968288358300000000	-84.02	-1.19	387	18.33399317517476	15853.171749951704	18
Container (Base)	257200.1965039974290820000000	9002.01	11793.985775591304	2791.9788979513939821300000000	92.12	1.09	388	-20.4559255948026	11793.985775591304	23
ODD Cubes Basic	420000.00	14700.00	11793.985775591304	-2906.014224408696	-144.53	-0.69	388	-20.4559255948026	11793.985775591304	23
Container (Max)	461359.6087538651798700000000	16147.59	11793.985775591304	-4353.6005307939772954500000000	-105.97	-0.94	388	-20.4559255948026	11793.985775591304	23
Traditional Housing	708000.00	21240.00	11793.985775591304	-9446.014224408696	-74.95	-1.33	388	-20.4559255948026	11793.985775591304	23
ODD Cubes Basic	420000.00	14700.00	15088.240890433062	388.240890433062	1081.80	0.09	389	58.06477597925672	15088.240890433062	26
Container (Base)	511091.3885946080561496000000	17888.20	15088.240890433062	-2799.9577103782199652360000000	-182.54	-0.55	389	58.06477597925672	15088.240890433062	26
Traditional Housing	708000.00	21240.00	15088.240890433062	-6151.759109566938	-115.09	-0.87	389	58.06477597925672	15088.240890433062	26
Container (Max)	916783.6039184879388360000000	32087.43	15088.240890433062	-16999.1852467140158592600000000	-53.93	-1.85	389	58.06477597925672	15088.240890433062	26
Container (Base)	408479.0835604610617884900000	14296.77	13448.897444258444	-847.8704803576931625971500000	-481.77	-0.21	390	26.329960308545743	13448.897444258444	19
ODD Cubes Basic	420000.00	14700.00	13448.897444258444	-1251.102555741556	-335.70	-0.30	390	26.329960308545743	13448.897444258444	19
Traditional Housing	708000.00	21240.00	13448.897444258444	-7791.102555741556	-90.87	-1.10	390	26.329960308545743	13448.897444258444	19
Container (Max)	732720.0862875807366871500000	25645.20	13448.897444258444	-12196.3055758068817840502500000	-60.08	-1.66	390	26.329960308545743	13448.897444258444	19
Container (Base)	231231.3947466704064788400000	8093.10	9291.128020813541	1198.0292046800767732406000000	193.01	0.52	391	-28.487273654704012	9291.128020813541	16
Container (Max)	414777.3884390339951994000000	14517.21	9291.128020813541	-5226.0805745526488319790000000	-79.37	-1.26	391	-28.487273654704012	9291.128020813541	16
ODD Cubes Basic	420000.00	14700.00	9291.128020813541	-5408.871979186459	-77.65	-1.29	391	-28.487273654704012	9291.128020813541	16
Traditional Housing	708000.00	21240.00	9291.128020813541	-11948.871979186459	-59.25	-1.69	391	-28.487273654704012	9291.128020813541	16
ODD Cubes Basic	420000.00	14700.00	15332.118875562715	632.118875562715	664.43	0.15	392	31.040293917715736	15332.118875562715	30
Container (Base)	423709.6175623595922544800000	14829.84	15332.118875562715	502.2822608801292710932000000	843.57	0.12	392	31.040293917715736	15332.118875562715	30
Traditional Housing	708000.00	21240.00	15332.118875562715	-5907.881124437285	-119.84	-0.83	392	31.040293917715736	15332.118875562715	30
Container (Max)	760040.2567374471545868000000	26601.41	15332.118875562715	-11269.2901102479354105380000000	-67.44	-1.48	392	31.040293917715736	15332.118875562715	30
Container (Base)	360204.9703807075896195000000	12607.17	15493.844214485696	2886.6702511609303633175000000	124.78	0.80	393	11.40026856332365	15493.844214485696	19
ODD Cubes Basic	420000.00	14700.00	15493.844214485696	793.844214485696	529.07	0.19	393	11.40026856332365	15493.844214485696	19
Traditional Housing	708000.00	21240.00	15493.844214485696	-5746.155785514304	-123.21	-0.81	393	11.40026856332365	15493.844214485696	19
Container (Max)	646127.1276807053361825000000	22614.45	15493.844214485696	-7120.6052543389907663875000000	-90.74	-1.10	393	11.40026856332365	15493.844214485696	19
ODD Cubes Basic	420000.00	14700.00	8053.986150219986	-6646.013849780014	-63.20	-1.58	394	48.145827652955546	8053.986150219986	22
Container (Base)	479019.1635078960511027800000	16765.67	8053.986150219986	-8711.6845725563757885973000000	-54.99	-1.82	394	48.145827652955546	8053.986150219986	22
Traditional Housing	708000.00	21240.00	8053.986150219986	-13186.013849780014	-53.69	-1.86	394	48.145827652955546	8053.986150219986	22
Container (Max)	859253.2076785248145773000000	30073.86	8053.986150219986	-22019.8761185283825102055000000	-39.02	-2.56	394	48.145827652955546	8053.986150219986	22
Container (Base)	241715.1163543123115484000000	8460.03	11568.683677909929	3108.6546055089980958060000000	77.76	1.29	395	-25.24498246310812	11568.683677909929	19
ODD Cubes Basic	420000.00	14700.00	11568.683677909929	-3131.316322090071	-134.13	-0.75	395	-25.24498246310812	11568.683677909929	19
Container (Max)	433582.8394648497485940000000	15175.40	11568.683677909929	-3606.7157033598122007900000000	-120.22	-0.83	395	-25.24498246310812	11568.683677909929	19
Traditional Housing	708000.00	21240.00	11568.683677909929	-9671.316322090071	-73.21	-1.37	395	-25.24498246310812	11568.683677909929	19
Container (Base)	391760.4623245578694665000000	13711.62	8714.909174345126	-4996.7070070143994313275000000	-78.40	-1.28	396	21.15940729335655	8714.909174345126	18
ODD Cubes Basic	420000.00	14700.00	8714.909174345126	-5985.090825654874	-70.17	-1.43	396	21.15940729335655	8714.909174345126	18
Traditional Housing	708000.00	21240.00	8714.909174345126	-12525.090825654874	-56.53	-1.77	396	21.15940729335655	8714.909174345126	18
Container (Max)	702730.6202718326578275000000	24595.57	8714.909174345126	-15880.6625351690170239625000000	-44.25	-2.26	396	21.15940729335655	8714.909174345126	18
Container (Base)	396071.2559169876263121000000	13862.49	13993.388480325732	130.8945232311650790765000000	3025.88	0.03	397	22.49260256662047	13993.388480325732	33
ODD Cubes Basic	420000.00	14700.00	13993.388480325732	-706.611519674268	-594.39	-0.17	397	22.49260256662047	13993.388480325732	33
Traditional Housing	708000.00	21240.00	13993.388480325732	-7246.611519674268	-97.70	-1.02	397	22.49260256662047	13993.388480325732	33
Container (Max)	710463.2195165270570235000000	24866.21	13993.388480325732	-10872.8242027527149958225000000	-65.34	-1.53	397	22.49260256662047	13993.388480325732	33
ODD Cubes Basic	420000.00	14700.00	15146.92626277505	446.92626277505	939.75	0.11	398	45.002846304101695	15146.92626277505	30
Container (Base)	468856.5533250715436638500000	16409.98	15146.92626277505	-1263.0531036024540282347500000	-371.21	-0.27	398	45.002846304101695	15146.92626277505	30
Traditional Housing	708000.00	21240.00	15146.92626277505	-6093.07373722495	-116.20	-0.86	398	45.002846304101695	15146.92626277505	30
Container (Max)	841023.7587061050360847500000	29435.83	15146.92626277505	-14288.9052919386262629662500000	-58.86	-1.70	398	45.002846304101695	15146.92626277505	30
ODD Cubes Basic	420000.00	14700.00	14965.829409371461	265.829409371461	1579.96	0.06	399	36.330197709221764	14965.829409371461	32
Container (Base)	440814.1511789289283705200000	15428.50	14965.829409371461	-462.6658818910514929682000000	-952.77	-0.10	399	36.330197709221764	14965.829409371461	32
Traditional Housing	708000.00	21240.00	14965.829409371461	-6274.170590628539	-112.84	-0.89	399	36.330197709221764	14965.829409371461	32
Container (Max)	790721.9632233716922882000000	27675.27	14965.829409371461	-12709.4393034465482300870000000	-62.22	-1.61	399	36.330197709221764	14965.829409371461	32
Container (Base)	327595.8646494016319838780000	11465.86	9565.961282159458	-1899.8939805695991194357300000	-172.43	-0.58	400	1.3152796409390746	9565.961282159458	17
ODD Cubes Basic	420000.00	14700.00	9565.961282159458	-5134.038717840542	-81.81	-1.22	400	1.3152796409390746	9565.961282159458	17
Traditional Housing	708000.00	21240.00	9565.961282159458	-11674.038717840542	-60.65	-1.65	400	1.3152796409390746	9565.961282159458	17
Container (Max)	587633.6876814286796337300000	20567.18	9565.961282159458	-11001.2177866905457871805500000	-53.42	-1.87	400	1.3152796409390746	9565.961282159458	17
Container (Base)	291324.1320099200370852000000	10196.34	15093.742701672549	4897.3980813253477020180000000	59.49	1.68	401	-9.90244662481636	15093.742701672549	20
ODD Cubes Basic	420000.00	14700.00	15093.742701672549	393.742701672549	1066.69	0.09	401	-9.90244662481636	15093.742701672549	20
Container (Max)	522570.3144537338711820000000	18289.96	15093.742701672549	-3196.2183042081364913700000000	-163.50	-0.61	401	-9.90244662481636	15093.742701672549	20
Traditional Housing	708000.00	21240.00	15093.742701672549	-6146.257298327451	-115.19	-0.87	401	-9.90244662481636	15093.742701672549	20
Container (Base)	236407.4607837535941103200000	8274.26	12350.995310969936	4076.7341835385602061388000000	57.99	1.72	402	-26.886476347484376	12350.995310969936	35
ODD Cubes Basic	420000.00	14700.00	12350.995310969936	-2349.004689030064	-178.80	-0.56	402	-26.886476347484376	12350.995310969936	35
Container (Max)	424062.0928607732449812000000	14842.17	12350.995310969936	-2491.1779391571275743420000000	-170.23	-0.59	402	-26.886476347484376	12350.995310969936	35
Traditional Housing	708000.00	21240.00	12350.995310969936	-8889.004689030064	-79.65	-1.26	402	-26.886476347484376	12350.995310969936	35
ODD Cubes Basic	420000.00	14700.00	14698.331671846703	-1.668328153297	-251749.03	0.00	403	56.30047585182979	14698.331671846703	18
Container (Base)	505386.6476335819978797000000	17688.53	14698.331671846703	-2990.2009953286669257895000000	-169.01	-0.59	403	56.30047585182979	14698.331671846703	18
Traditional Housing	708000.00	21240.00	14698.331671846703	-6541.668328153297	-108.23	-0.92	403	56.30047585182979	14698.331671846703	18
Container (Max)	906550.5749644053734895000000	31729.27	14698.331671846703	-17030.9384519074850721325000000	-53.23	-1.88	403	56.30047585182979	14698.331671846703	18
Container (Base)	379312.4708389182253977900000	13275.94	14984.025535310306	1708.0890559481681110773500000	222.07	0.45	404	17.309628115938253	14984.025535310306	29
ODD Cubes Basic	420000.00	14700.00	14984.025535310306	284.025535310306	1478.74	0.07	404	17.309628115938253	14984.025535310306	29
Traditional Housing	708000.00	21240.00	14984.025535310306	-6255.974464689694	-113.17	-0.88	404	17.309628115938253	14984.025535310306	29
Container (Max)	680401.7085538476643126500000	23814.06	14984.025535310306	-8830.0342640743622509427500000	-77.06	-1.30	404	17.309628115938253	14984.025535310306	29
Container (Base)	354335.5046373660970779600000	12401.74	15701.715479864753	3299.9728175569396022714000000	107.38	0.93	405	9.585024150009772	15701.715479864753	18
ODD Cubes Basic	420000.00	14700.00	15701.715479864753	1001.715479864753	419.28	0.24	405	9.585024150009772	15701.715479864753	18
Traditional Housing	708000.00	21240.00	15701.715479864753	-5538.284520135247	-127.84	-0.78	405	9.585024150009772	15701.715479864753	18
Container (Max)	635598.6193212641780886000000	22245.95	15701.715479864753	-6544.2361963794932331010000000	-97.12	-1.03	405	9.585024150009772	15701.715479864753	18
ODD Cubes Basic	420000.00	14700.00	18876.06327661919	4176.06327661919	100.57	0.99	406	45.60416197970844	18876.06327661919	37
Container (Base)	470800.8654700486611492000000	16478.03	18876.06327661919	2398.0329851674868597780000000	196.33	0.51	406	45.60416197970844	18876.06327661919	37
Traditional Housing	708000.00	21240.00	18876.06327661919	-2363.93672338081	-299.50	-0.33	406	45.60416197970844	18876.06327661919	37
Container (Max)	844511.4196904079374220000000	29557.90	18876.06327661919	-10681.8364125450878097700000000	-79.06	-1.26	406	45.60416197970844	18876.06327661919	37
Container (Base)	245715.0241712964716587500000	8600.03	11549.490624509406	2949.4647785140294919437500000	83.31	1.20	407	-24.007934555163875	11549.490624509406	37
ODD Cubes Basic	420000.00	14700.00	11549.490624509406	-3150.509375490594	-133.31	-0.75	407	-24.007934555163875	11549.490624509406	37
Container (Max)	440757.7791833217668062500000	15426.52	11549.490624509406	-3877.0316469068558382187500000	-113.68	-0.88	407	-24.007934555163875	11549.490624509406	37
Traditional Housing	708000.00	21240.00	11549.490624509406	-9690.509375490594	-73.06	-1.37	407	-24.007934555163875	11549.490624509406	37
Container (Base)	377572.1848455212156393100000	13215.03	17427.77941979948	4212.7529502062374526241500000	89.63	1.12	408	16.771411425489717	17427.77941979948	24
ODD Cubes Basic	420000.00	14700.00	17427.77941979948	2727.77941979948	153.97	0.65	408	16.771411425489717	17427.77941979948	24
Traditional Housing	708000.00	21240.00	17427.77941979948	-3812.22058020052	-185.72	-0.54	408	16.771411425489717	17427.77941979948	24
Container (Max)	677280.0248384116330858500000	23704.80	17427.77941979948	-6277.0214495449271580047500000	-107.90	-0.93	408	16.771411425489717	17427.77941979948	24
ODD Cubes Basic	420000.00	14700.00	11272.28480157754	-3427.71519842246	-122.53	-0.82	409	38.63208589177749	11272.28480157754	23
Container (Base)	448257.1454850500894907000000	15689.00	11272.28480157754	-4416.7152903992131321745000000	-101.49	-0.99	409	38.63208589177749	11272.28480157754	23
Traditional Housing	708000.00	21240.00	11272.28480157754	-9967.71519842246	-71.03	-1.41	409	38.63208589177749	11272.28480157754	23
Container (Max)	804073.0297766040308745000000	28142.56	11272.28480157754	-16870.2712406036010806075000000	-47.66	-2.10	409	38.63208589177749	11272.28480157754	23
Container (Base)	373961.1925340197078004100000	13088.64	16301.57792431327	3212.9361856225802269856500000	116.39	0.86	410	15.654643067584487	16301.57792431327	38
ODD Cubes Basic	420000.00	14700.00	16301.57792431327	1601.57792431327	262.24	0.38	410	15.654643067584487	16301.57792431327	38
Traditional Housing	708000.00	21240.00	16301.57792431327	-4938.42207568673	-143.37	-0.70	410	15.654643067584487	16301.57792431327	38
Container (Max)	670802.7125241434038243500000	23478.09	16301.57792431327	-7176.5170140317491338522500000	-93.47	-1.07	410	15.654643067584487	16301.57792431327	38
Container (Base)	400941.8193393843418952100000	14032.96	18048.977210811805	4016.0135339333530336676500000	99.84	1.00	411	23.998917353826847	18048.977210811805	37
ODD Cubes Basic	420000.00	14700.00	18048.977210811805	3348.977210811805	125.41	0.80	411	23.998917353826847	18048.977210811805	37
Traditional Housing	708000.00	21240.00	18048.977210811805	-3191.022789188195	-221.87	-0.45	411	23.998917353826847	18048.977210811805	37
Container (Max)	719199.9205980634039423500000	25172.00	18048.977210811805	-7123.0200101204141379822500000	-100.97	-0.99	411	23.998917353826847	18048.977210811805	37
Container (Base)	362753.4846538825337852100000	12696.37	12557.948331440362	-138.4236314455266824823500000	-2620.60	-0.04	412	12.188445289949847	12557.948331440362	22
ODD Cubes Basic	420000.00	14700.00	12557.948331440362	-2142.051668559638	-196.07	-0.51	412	12.188445289949847	12557.948331440362	22
Traditional Housing	708000.00	21240.00	12557.948331440362	-8682.051668559638	-81.55	-1.23	412	12.188445289949847	12557.948331440362	22
Container (Max)	650698.5921039736100923500000	22774.45	12557.948331440362	-10216.5023921987143532322500000	-63.69	-1.57	412	12.188445289949847	12557.948331440362	22
ODD Cubes Basic	420000.00	14700.00	18216.70143535301	3516.70143535301	119.43	0.84	413	34.830349298962076	18216.70143535301	20
Container (Base)	435964.4963337429454006800000	15258.76	18216.70143535301	2957.9440636720069109762000000	147.39	0.68	413	34.830349298962076	18216.70143535301	20
Traditional Housing	708000.00	21240.00	18216.70143535301	-3023.29856464699	-234.18	-0.43	413	34.830349298962076	18216.70143535301	20
Container (Max)	782022.7674514449889038000000	27370.80	18216.70143535301	-9154.0954254475646116330000000	-85.43	-1.17	413	34.830349298962076	18216.70143535301	20
Container (Base)	369297.0363082612457517300000	12925.40	19413.044962893575	6487.6486921044313986894500000	56.92	1.76	414	14.212163649208811	19413.044962893575	18
ODD Cubes Basic	420000.00	14700.00	19413.044962893575	4713.044962893575	89.11	1.12	414	14.212163649208811	19413.044962893575	18
Traditional Housing	708000.00	21240.00	19413.044962893575	-1826.955037106425	-387.53	-0.26	414	14.212163649208811	19413.044962893575	18
Container (Max)	662436.2597735935642405500000	23185.27	19413.044962893575	-3772.2241291821997484192500000	-175.61	-0.57	414	14.212163649208811	19413.044962893575	18
ODD Cubes Basic	420000.00	14700.00	18836.444629611484	4136.444629611484	101.54	0.98	415	45.45834368401245	18836.444629611484	21
Container (Base)	470329.3722181963762035000000	16461.53	18836.444629611484	2374.9166019746108328775000000	198.04	0.50	415	45.45834368401245	18836.444629611484	21
Traditional Housing	708000.00	21240.00	18836.444629611484	-2403.555370388516	-294.56	-0.34	415	45.45834368401245	18836.444629611484	21
Container (Max)	843665.6662844564106225000000	29528.30	18836.444629611484	-10691.8536903444903717875000000	-78.91	-1.27	415	45.45834368401245	18836.444629611484	21
ODD Cubes Basic	420000.00	14700.00	11889.383799002957	-2810.616200997043	-149.43	-0.67	416	62.92408451010718	11889.383799002957	33
Container (Base)	526803.6225775158590274000000	18438.13	11889.383799002957	-6548.7429912100980659590000000	-80.44	-1.24	416	62.92408451010718	11889.383799002957	33
Traditional Housing	708000.00	21240.00	11889.383799002957	-9350.616200997043	-75.72	-1.32	416	62.92408451010718	11889.383799002957	33
Container (Max)	944967.8363628471493590000000	33073.87	11889.383799002957	-21184.4904736966932275650000000	-44.61	-2.24	416	62.92408451010718	11889.383799002957	33
Container (Base)	323890.3551351504028267818000	11336.16	17221.46918446708	5885.3067547368159010626370000	55.03	1.82	417	0.16928003239606326	17221.46918446708	20
ODD Cubes Basic	420000.00	14700.00	17221.46918446708	2521.46918446708	166.57	0.60	417	0.16928003239606326	17221.46918446708	20
Container (Max)	580986.8326518987867111630000	20334.54	17221.46918446708	-3113.0699583493775348907050000	-186.63	-0.54	417	0.16928003239606326	17221.46918446708	20
Traditional Housing	708000.00	21240.00	17221.46918446708	-4018.53081553292	-176.18	-0.57	417	0.16928003239606326	17221.46918446708	20
Container (Base)	284707.9842459725883791700000	9964.78	15693.542118375233	5728.7626697661924067290500000	49.70	2.01	418	-11.948616717859181	15693.542118375233	26
ODD Cubes Basic	420000.00	14700.00	15693.542118375233	993.542118375233	422.73	0.24	418	-11.948616717859181	15693.542118375233	26
Container (Max)	510702.4256055808572409500000	17874.58	15693.542118375233	-2181.0427778200970034332500000	-234.16	-0.43	418	-11.948616717859181	15693.542118375233	26
Traditional Housing	708000.00	21240.00	15693.542118375233	-5546.457881624767	-127.65	-0.78	418	-11.948616717859181	15693.542118375233	26
Container (Base)	230632.2609614047693737000000	8072.13	12730.593834239999	4658.4647005908320719205000000	49.51	2.02	419	-28.67256722384441	12730.593834239999	26
Container (Max)	413702.6764733412297795000000	14479.59	12730.593834239999	-1748.9998423269440422825000000	-236.54	-0.42	419	-28.67256722384441	12730.593834239999	26
ODD Cubes Basic	420000.00	14700.00	12730.593834239999	-1969.406165760001	-213.26	-0.47	419	-28.67256722384441	12730.593834239999	26
Traditional Housing	708000.00	21240.00	12730.593834239999	-8509.406165760001	-83.20	-1.20	419	-28.67256722384441	12730.593834239999	26
ODD Cubes Basic	420000.00	14700.00	17724.319789530982	3024.319789530982	138.87	0.72	420	54.5081993105872	17724.319789530982	15
Container (Base)	499591.4468968319700960000000	17485.70	17724.319789530982	238.6191481418630466400000000	2093.68	0.05	420	54.5081993105872	17724.319789530982	15
Traditional Housing	708000.00	21240.00	17724.319789530982	-3515.680210469018	-201.38	-0.50	420	54.5081993105872	17724.319789530982	15
Container (Max)	896155.2814113712893600000000	31365.43	17724.319789530982	-13641.1150598670131276000000000	-65.70	-1.52	420	54.5081993105872	17724.319789530982	15
Container (Base)	257657.2771192372862715600000	9018.00	12128.50925137895	3110.5045522056449804954000000	82.83	1.21	421	-20.314564682322708	12128.50925137895	34
ODD Cubes Basic	420000.00	14700.00	12128.50925137895	-2571.49074862105	-163.33	-0.61	421	-20.314564682322708	12128.50925137895	34
Container (Max)	462179.5091142941774646000000	16176.28	12128.50925137895	-4047.7735676213462112610000000	-114.18	-0.88	421	-20.314564682322708	12128.50925137895	34
Traditional Housing	708000.00	21240.00	12128.50925137895	-9111.49074862105	-77.70	-1.29	421	-20.314564682322708	12128.50925137895	34
Container (Base)	235262.9970954311374637100000	8234.20	10802.171443371351	2567.9665450312611887701500000	91.61	1.09	422	-27.240423607305203	10802.171443371351	33
ODD Cubes Basic	420000.00	14700.00	10802.171443371351	-3897.828556628649	-107.75	-0.93	422	-27.240423607305203	10802.171443371351	33
Container (Max)	422009.1810564494573398500000	14770.32	10802.171443371351	-3968.1498936043800068947500000	-106.35	-0.94	422	-27.240423607305203	10802.171443371351	33
Traditional Housing	708000.00	21240.00	10802.171443371351	-10437.828556628649	-67.83	-1.47	422	-27.240423607305203	10802.171443371351	33
ODD Cubes Basic	420000.00	14700.00	13690.452769590942	-1009.547230409058	-416.03	-0.24	423	64.3458966015578	13690.452769590942	33
Container (Base)	531400.9524483750372540000000	18599.03	13690.452769590942	-4908.5805661021843038900000000	-108.26	-0.92	423	64.3458966015578	13690.452769590942	33
Traditional Housing	708000.00	21240.00	13690.452769590942	-7549.547230409058	-93.78	-1.07	423	64.3458966015578	13690.452769590942	33
Container (Max)	953214.4175838653178900000000	33362.50	13690.452769590942	-19672.0518458443441261500000000	-48.46	-2.06	423	64.3458966015578	13690.452769590942	33
ODD Cubes Basic	420000.00	14700.00	10958.642442408394	-3741.357557591606	-112.26	-0.89	424	65.455857418781	10958.642442408394	34
Traditional Housing	708000.00	21240.00	10958.642442408394	-10281.357557591606	-68.86	-1.45	424	65.455857418781	10958.642442408394	34
Container (Base)	534989.9330536090488300000000	18724.65	10958.642442408394	-7766.0052144679227090500000000	-68.89	-1.45	424	65.455857418781	10958.642442408394	34
Container (Max)	959652.2458218007390500000000	33587.83	10958.642442408394	-22629.1861613546318667500000000	-42.41	-2.36	424	65.455857418781	10958.642442408394	34
ODD Cubes Basic	420000.00	14700.00	9049.197972065533	-5650.802027934467	-74.33	-1.35	425	53.618987152042905	9049.197972065533	28
Container (Base)	496716.2416270300903141500000	17385.07	9049.197972065533	-8335.8704848805201609952500000	-59.59	-1.68	425	53.618987152042905	9049.197972065533	28
Traditional Housing	708000.00	21240.00	9049.197972065533	-12190.802027934467	-58.08	-1.72	425	53.618987152042905	9049.197972065533	28
Container (Max)	890997.8064312064511452500000	31184.92	9049.197972065533	-22135.7252530266927900837500000	-40.25	-2.48	425	53.618987152042905	9049.197972065533	28
Container (Base)	328385.7333850004163966870000	11493.50	11390.695719189884	-102.8049492851305738840450000	-3194.26	-0.03	426	1.5595616373326209	11390.695719189884	23
ODD Cubes Basic	420000.00	14700.00	11390.695719189884	-3309.304280810116	-126.91	-0.79	426	1.5595616373326209	11390.695719189884	23
Traditional Housing	708000.00	21240.00	11390.695719189884	-9849.304280810116	-71.88	-1.39	426	1.5595616373326209	11390.695719189884	23
Container (Max)	589050.5354746110678510450000	20616.77	11390.695719189884	-9226.0730224215033747865750000	-63.85	-1.57	426	1.5595616373326209	11390.695719189884	23
ODD Cubes Basic	420000.00	14700.00	15743.20517367906	1043.20517367906	402.61	0.25	427	37.924937274512715	15743.20517367906	33
Container (Base)	445970.6299315276480624500000	15608.97	15743.20517367906	134.2331260755923178142500000	3322.36	0.03	427	37.924937274512715	15743.20517367906	33
Traditional Housing	708000.00	21240.00	15743.20517367906	-5496.79482632094	-128.80	-0.78	427	37.924937274512715	15743.20517367906	33
Container (Max)	799971.5324390374726357500000	27999.00	15743.20517367906	-12255.7984616872515422512500000	-65.27	-1.53	427	37.924937274512715	15743.20517367906	33
Container (Base)	353771.7165547120672569000000	12382.01	10611.393878819033	-1770.6162005958893539915000000	-199.80	-0.50	428	9.41066191465783	10611.393878819033	33
ODD Cubes Basic	420000.00	14700.00	10611.393878819033	-4088.606121180967	-102.72	-0.97	428	9.41066191465783	10611.393878819033	33
Traditional Housing	708000.00	21240.00	10611.393878819033	-10628.606121180967	-66.61	-1.50	428	9.41066191465783	10611.393878819033	33
Container (Max)	634587.3096381111468915000000	22210.56	10611.393878819033	-11599.1619585148571412025000000	-54.71	-1.83	428	9.41066191465783	10611.393878819033	33
Container (Base)	345558.0066876105188191200000	12094.53	17569.034979651275	5474.5047455849068413308000000	63.12	1.58	429	6.870415220867784	17569.034979651275	18
ODD Cubes Basic	420000.00	14700.00	17569.034979651275	2869.034979651275	146.39	0.68	429	6.870415220867784	17569.034979651275	18
Traditional Housing	708000.00	21240.00	17569.034979651275	-3670.965020348725	-192.86	-0.52	429	6.870415220867784	17569.034979651275	18
Container (Max)	619853.7518017941905892000000	21694.88	17569.034979651275	-4125.8463334115216706220000000	-150.24	-0.67	429	6.870415220867784	17569.034979651275	18
Container (Base)	256187.0269507442754924000000	8966.55	17527.84350248934	8561.2975592132903577660000000	29.92	3.34	430	-20.76926763506732	17527.84350248934	36
ODD Cubes Basic	420000.00	14700.00	17527.84350248934	2827.84350248934	148.52	0.67	430	-20.76926763506732	17527.84350248934	36
Container (Max)	459542.2092532277906340000000	16083.98	17527.84350248934	1443.8661786263673278100000000	318.27	0.31	430	-20.76926763506732	17527.84350248934	36
Traditional Housing	708000.00	21240.00	17527.84350248934	-3712.15649751066	-190.72	-0.52	430	-20.76926763506732	17527.84350248934	36
Container (Base)	276051.0705791451102908100000	9661.79	15037.126793601059	5375.3393233309801398216500000	51.36	1.95	431	-14.625932653824233	15037.126793601059	35
ODD Cubes Basic	420000.00	14700.00	15037.126793601059	337.126793601059	1245.82	0.08	431	-14.625932653824233	15037.126793601059	35
Container (Max)	495173.8593111867573883500000	17331.09	15037.126793601059	-2293.9582822904775085922500000	-215.86	-0.46	431	-14.625932653824233	15037.126793601059	35
Traditional Housing	708000.00	21240.00	15037.126793601059	-6202.873206398941	-114.14	-0.88	431	-14.625932653824233	15037.126793601059	35
ODD Cubes Basic	420000.00	14700.00	19965.633416079603	5265.633416079603	79.76	1.25	432	34.87902743908663	19965.633416079603	28
Container (Base)	436121.8936923658820409000000	15264.27	19965.633416079603	4701.3671368467971285685000000	92.76	1.08	432	34.87902743908663	19965.633416079603	28
Traditional Housing	708000.00	21240.00	19965.633416079603	-1274.366583920397	-555.57	-0.18	432	34.87902743908663	19965.633416079603	28
Container (Max)	782305.1030980744083315000000	27380.68	19965.633416079603	-7415.0451923530012916025000000	-105.50	-0.95	432	34.87902743908663	19965.633416079603	28
Container (Base)	255284.5446389031446419200000	8934.96	16337.051949682957	7402.0928873213469375328000000	34.49	2.90	433	-21.048377531320256	16337.051949682957	29
ODD Cubes Basic	420000.00	14700.00	16337.051949682957	1637.051949682957	256.56	0.39	433	-21.048377531320256	16337.051949682957	29
Container (Max)	457923.3578994659491872000000	16027.32	16337.051949682957	309.7344232016487784480000000	1478.44	0.07	433	-21.048377531320256	16337.051949682957	29
Traditional Housing	708000.00	21240.00	16337.051949682957	-4902.948050317043	-144.40	-0.69	433	-21.048377531320256	16337.051949682957	29
Container (Base)	376189.8223215941161927200000	13166.64	14774.60252881774	1607.9587475619459332548000000	233.95	0.43	434	16.343889405861304	14774.60252881774	24
ODD Cubes Basic	420000.00	14700.00	14774.60252881774	74.60252881774	5629.84	0.02	434	16.343889405861304	14774.60252881774	24
Traditional Housing	708000.00	21240.00	14774.60252881774	-6465.39747118226	-109.51	-0.91	434	16.343889405861304	14774.60252881774	24
Container (Max)	674800.3757484658562652000000	23618.01	14774.60252881774	-8843.4106223785649692820000000	-76.31	-1.31	434	16.343889405861304	14774.60252881774	24
Container (Base)	297774.6507748193970538980000	10422.11	15008.601271074971	4586.4884939562921031135700000	64.92	1.54	435	-7.9075004639595114	15008.601271074971	22
ODD Cubes Basic	420000.00	14700.00	15008.601271074971	308.601271074971	1360.98	0.07	435	-7.9075004639595114	15008.601271074971	22
Container (Max)	534141.1019340116359044300000	18694.94	15008.601271074971	-3686.3372966154362566550500000	-144.90	-0.69	435	-7.9075004639595114	15008.601271074971	22
Traditional Housing	708000.00	21240.00	15008.601271074971	-6231.398728925029	-113.62	-0.88	435	-7.9075004639595114	15008.601271074971	22
ODD Cubes Basic	420000.00	14700.00	11398.799499141152	-3301.200500858848	-127.23	-0.79	436	69.43318680392072	11398.799499141152	37
Traditional Housing	708000.00	21240.00	11398.799499141152	-9841.200500858848	-71.94	-1.39	436	69.43318680392072	11398.799499141152	37
Container (Base)	547850.3492074013736696000000	19174.76	11398.799499141152	-7775.9627231178960784360000000	-70.45	-1.42	436	69.43318680392072	11398.799499141152	37
Container (Max)	982720.9551220803720360000000	34395.23	11398.799499141152	-22996.4339301316610212600000000	-42.73	-2.34	436	69.43318680392072	11398.799499141152	37
Container (Base)	286382.2678993738255943700000	10023.38	9431.001098425606	-592.3782780524778958029500000	-483.44	-0.21	437	-11.430812511984541	9431.001098425606	21
ODD Cubes Basic	420000.00	14700.00	9431.001098425606	-5268.998901574394	-79.71	-1.25	437	-11.430812511984541	9431.001098425606	21
Container (Max)	513705.7158898640629729500000	17979.70	9431.001098425606	-8548.6989577196362040532500000	-60.09	-1.66	437	-11.430812511984541	9431.001098425606	21
Traditional Housing	708000.00	21240.00	9431.001098425606	-11808.998901574394	-59.95	-1.67	437	-11.430812511984541	9431.001098425606	21
ODD Cubes Basic	420000.00	14700.00	19263.00221599982	4563.00221599982	92.04	1.09	438	45.20290991773312	19263.00221599982	28
Container (Base)	469503.4450152958022016000000	16432.62	19263.00221599982	2830.3816404644669229440000000	165.88	0.60	438	45.20290991773312	19263.00221599982	28
Traditional Housing	708000.00	21240.00	19263.00221599982	-1976.99778400018	-358.12	-0.28	438	45.20290991773312	19263.00221599982	28
Container (Max)	842184.1376683479826560000000	29476.44	19263.00221599982	-10213.4426023923593929600000000	-82.46	-1.21	438	45.20290991773312	19263.00221599982	28
ODD Cubes Basic	420000.00	14700.00	15195.454840027185	495.454840027185	847.71	0.12	439	53.783282315004385	15195.454840027185	30
Container (Base)	497247.4785358046285905500000	17403.66	15195.454840027185	-2208.2069087259770006692500000	-225.18	-0.44	439	53.783282315004385	15195.454840027185	30
Traditional Housing	708000.00	21240.00	15195.454840027185	-6044.545159972815	-117.13	-0.85	439	53.783282315004385	15195.454840027185	30
Container (Max)	891950.7265911411832192500000	31218.28	15195.454840027185	-16022.8205906627564126737500000	-55.67	-1.80	439	53.783282315004385	15195.454840027185	30
ODD Cubes Basic	420000.00	14700.00	15312.250611915286	612.250611915286	685.99	0.15	440	38.60109138419503	15312.250611915286	29
Container (Base)	448156.9269143977358529000000	15685.49	15312.250611915286	-373.2418300886347548515000000	-1200.71	-0.08	440	38.60109138419503	15312.250611915286	29
Traditional Housing	708000.00	21240.00	15312.250611915286	-5927.749388084714	-119.44	-0.84	440	38.60109138419503	15312.250611915286	29
Container (Max)	803893.2600829003837515000000	28136.26	15312.250611915286	-12824.0134909862274313025000000	-62.69	-1.60	440	38.60109138419503	15312.250611915286	29
Container (Base)	236874.1399687409592664800000	8290.59	10872.052101257656	2581.4572023517224256732000000	91.76	1.09	441	-26.742146893935864	10872.052101257656	18
ODD Cubes Basic	420000.00	14700.00	10872.052101257656	-3827.947898742344	-109.72	-0.91	441	-26.742146893935864	10872.052101257656	18
Container (Max)	424899.2109078272920068000000	14871.47	10872.052101257656	-3999.4202805162992202380000000	-106.24	-0.94	441	-26.742146893935864	10872.052101257656	18
Traditional Housing	708000.00	21240.00	10872.052101257656	-10367.947898742344	-68.29	-1.46	441	-26.742146893935864	10872.052101257656	18
ODD Cubes Basic	420000.00	14700.00	8419.102862444448	-6280.897137555552	-66.87	-1.50	442	56.374658834678826	8419.102862444448	23
Traditional Housing	708000.00	21240.00	8419.102862444448	-12820.897137555552	-55.22	-1.81	442	56.374658834678826	8419.102862444448	23
Container (Base)	505626.5131158155563531800000	17696.93	8419.102862444448	-9277.8250966090964723613000000	-54.50	-1.83	442	56.374658834678826	8419.102862444448	23
Container (Max)	906980.8399740789247413000000	31744.33	8419.102862444448	-23325.2265366483143659455000000	-38.88	-2.57	442	56.374658834678826	8419.102862444448	23
Container (Base)	418411.4175518263918821000000	14644.40	18000.951808050024	3356.5521937361002841265000000	124.66	0.80	443	29.40172434591947	18000.951808050024	30
ODD Cubes Basic	420000.00	14700.00	18000.951808050024	3300.951808050024	127.24	0.79	443	29.40172434591947	18000.951808050024	30
Traditional Housing	708000.00	21240.00	18000.951808050024	-3239.048191949976	-218.58	-0.46	443	29.40172434591947	18000.951808050024	30
Container (Max)	750536.4712925502219735000000	26268.78	18000.951808050024	-8267.8246871892337690725000000	-90.78	-1.10	443	29.40172434591947	18000.951808050024	30
ODD Cubes Basic	420000.00	14700.00	13026.38418671455	-1673.61581328545	-250.95	-0.40	444	54.74757586572001	13026.38418671455	27
Container (Base)	500365.4542314950519343000000	17512.79	13026.38418671455	-4486.4067113877768177005000000	-111.53	-0.90	444	54.74757586572001	13026.38418671455	27
Traditional Housing	708000.00	21240.00	13026.38418671455	-8213.61581328545	-86.20	-1.16	444	54.74757586572001	13026.38418671455	27
Container (Max)	897543.6773999693440005000000	31414.03	13026.38418671455	-18387.6445222843770400175000000	-48.81	-2.05	444	54.74757586572001	13026.38418671455	27
Container (Base)	364715.7135888848122063800000	12765.05	12969.982714493399	204.9327388824305727767000000	1779.68	0.06	445	12.795302075160066	12969.982714493399	32
ODD Cubes Basic	420000.00	14700.00	12969.982714493399	-1730.017285506601	-242.77	-0.41	445	12.795302075160066	12969.982714493399	32
Traditional Housing	708000.00	21240.00	12969.982714493399	-8270.017285506601	-85.61	-1.17	445	12.795302075160066	12969.982714493399	32
Container (Max)	654218.3918010321408033000000	22897.64	12969.982714493399	-9927.6609985427259281155000000	-65.90	-1.52	445	12.795302075160066	12969.982714493399	32
ODD Cubes Basic	420000.00	14700.00	17998.515048600784	3298.515048600784	127.33	0.79	446	54.15152252347718	17998.515048600784	27
Container (Base)	498438.1574730868181274000000	17445.34	17998.515048600784	553.1795370427453655410000000	901.04	0.11	446	54.15152252347718	17998.515048600784	27
Traditional Housing	708000.00	21240.00	17998.515048600784	-3241.484951399216	-218.42	-0.46	446	54.15152252347718	17998.515048600784	27
Container (Max)	894086.5382122938178590000000	31293.03	17998.515048600784	-13294.5137888294996250650000000	-67.25	-1.49	446	54.15152252347718	17998.515048600784	27
ODD Cubes Basic	420000.00	14700.00	16403.488279478835	1703.488279478835	246.55	0.41	447	30.649578732427457	16403.488279478835	38
Container (Base)	422446.2673607929122875100000	14785.62	16403.488279478835	1617.8689218510830699371500000	261.11	0.38	447	30.649578732427457	16403.488279478835	38
Traditional Housing	708000.00	21240.00	16403.488279478835	-4836.511720521165	-146.39	-0.68	447	30.649578732427457	16403.488279478835	38
Container (Max)	757774.0891270158719728500000	26522.09	16403.488279478835	-10118.6048399667205190497500000	-74.89	-1.34	447	30.649578732427457	16403.488279478835	38
ODD Cubes Basic	420000.00	14700.00	14007.834338854827	-692.165661145173	-606.79	-0.16	448	62.0420112454255	14007.834338854827	27
Container (Base)	523951.5004212961744650000000	18338.30	14007.834338854827	-4330.4681758905391062750000000	-120.99	-0.83	448	62.0420112454255	14007.834338854827	27
Traditional Housing	708000.00	21240.00	14007.834338854827	-7232.165661145173	-97.90	-1.02	448	62.0420112454255	14007.834338854827	27
Container (Max)	939851.7673240301712750000000	32894.81	14007.834338854827	-18886.9775174862289946250000000	-49.76	-2.01	448	62.0420112454255	14007.834338854827	27
ODD Cubes Basic	420000.00	14700.00	16615.642727213526	1915.642727213526	219.25	0.46	449	39.940348876832715	16615.642727213526	30
Container (Base)	452487.3222688172056624500000	15837.06	16615.642727213526	778.5864478049238018142500000	581.17	0.17	449	39.940348876832715	16615.642727213526	30
Traditional Housing	708000.00	21240.00	16615.642727213526	-4624.357272786474	-153.10	-0.65	449	39.940348876832715	16615.642727213526	30
Container (Max)	811661.0205030735886357500000	28408.14	16615.642727213526	-11792.4929903940496022512500000	-68.83	-1.45	449	39.940348876832715	16615.642727213526	30
Container (Base)	295624.0452891206368048500000	10346.84	8696.025364969595	-1650.8162201496272881697500000	-179.08	-0.56	450	-8.572616296279605	8696.025364969595	32
ODD Cubes Basic	420000.00	14700.00	8696.025364969595	-6003.974635030405	-69.95	-1.43	450	-8.572616296279605	8696.025364969595	32
Traditional Housing	708000.00	21240.00	8696.025364969595	-12543.974635030405	-56.44	-1.77	450	-8.572616296279605	8696.025364969595	32
Container (Max)	530283.3968507634770197500000	18559.92	8696.025364969595	-9863.8935248071266956912500000	-53.76	-1.86	450	-8.572616296279605	8696.025364969595	32
Container (Base)	261970.4957843816005982400000	9168.97	17757.79701796367	8588.8296655103139790616000000	30.50	3.28	451	-18.980619408992432	17757.79701796367	26
ODD Cubes Basic	420000.00	14700.00	17757.79701796367	3057.79701796367	137.35	0.73	451	-18.980619408992432	17757.79701796367	26
Container (Max)	469916.4583968734447784000000	16447.08	17757.79701796367	1310.7209740730994327560000000	358.52	0.28	451	-18.980619408992432	17757.79701796367	26
Traditional Housing	708000.00	21240.00	17757.79701796367	-3482.20298203633	-203.32	-0.49	451	-18.980619408992432	17757.79701796367	26
Container (Base)	254296.3269700304754328800000	8900.37	13397.872834592574	4497.5013906415073598492000000	56.54	1.77	452	-21.354002724651384	13397.872834592574	21
ODD Cubes Basic	420000.00	14700.00	13397.872834592574	-1302.127165407426	-322.55	-0.31	452	-21.354002724651384	13397.872834592574	21
Container (Max)	456150.7164968857402308000000	15965.28	13397.872834592574	-2567.4022427984269080780000000	-177.67	-0.56	452	-21.354002724651384	13397.872834592574	21
Traditional Housing	708000.00	21240.00	13397.872834592574	-7842.127165407426	-90.28	-1.11	452	-21.354002724651384	13397.872834592574	21
ODD Cubes Basic	420000.00	14700.00	13972.594352533555	-727.405647466445	-577.39	-0.17	453	67.9009993266017	13972.594352533555	16
Container (Base)	542896.1282526137348310000000	19001.36	13972.594352533555	-5028.7701363079257190850000000	-107.96	-0.93	453	67.9009993266017	13972.594352533555	16
Traditional Housing	708000.00	21240.00	13972.594352533555	-7267.405647466445	-97.42	-1.03	453	67.9009993266017	13972.594352533555	16
Container (Max)	973834.1911442561900850000000	34084.20	13972.594352533555	-20111.6023375154116529750000000	-48.42	-2.07	453	67.9009993266017	13972.594352533555	16
ODD Cubes Basic	420000.00	14700.00	9408.615502172812	-5291.384497827188	-79.37	-1.26	454	57.76754680959573	9408.615502172812	39
Container (Base)	510130.3188805511212539000000	17854.56	9408.615502172812	-8445.9456586464772438865000000	-60.40	-1.66	454	57.76754680959573	9408.615502172812	39
Traditional Housing	708000.00	21240.00	9408.615502172812	-11831.384497827188	-59.84	-1.67	454	57.76754680959573	9408.615502172812	39
Container (Max)	915059.6598729957137865000000	32027.09	9408.615502172812	-22618.4725933820379825275000000	-40.46	-2.47	454	57.76754680959573	9408.615502172812	39
ODD Cubes Basic	420000.00	14700.00	14414.417997811135	-285.582002188865	-1470.68	-0.07	455	55.55228794773319	14414.417997811135	16
Container (Base)	502967.4344188389285417000000	17603.86	14414.417997811135	-3189.4422068482274989595000000	-157.70	-0.63	455	55.55228794773319	14414.417997811135	16
Traditional Housing	708000.00	21240.00	14414.417997811135	-6825.582002188865	-103.73	-0.96	455	55.55228794773319	14414.417997811135	16
Container (Max)	902211.0477112498886595000000	31577.39	14414.417997811135	-17162.9686720826111030825000000	-52.57	-1.90	455	55.55228794773319	14414.417997811135	16
ODD Cubes Basic	420000.00	14700.00	10823.868131083282	-3876.131868916718	-108.36	-0.92	456	62.73126870035128	10823.868131083282	16
Container (Base)	526180.1661537768392904000000	18416.31	10823.868131083282	-7592.4376842989073751640000000	-69.30	-1.44	456	62.73126870035128	10823.868131083282	16
Traditional Housing	708000.00	21240.00	10823.868131083282	-10416.131868916718	-67.97	-1.47	456	62.73126870035128	10823.868131083282	16
Container (Max)	943849.4950254724415640000000	33034.73	10823.868131083282	-22210.8641948082534547400000000	-42.49	-2.35	456	62.73126870035128	10823.868131083282	16
ODD Cubes Basic	420000.00	14700.00	10802.79215161497	-3897.20784838503	-107.77	-0.93	457	31.17133735561088	10802.79215161497	17
Container (Base)	424133.3373457528877184000000	14844.67	10802.79215161497	-4041.8746554863810701440000000	-104.93	-0.95	457	31.17133735561088	10802.79215161497	17
Traditional Housing	708000.00	21240.00	10802.79215161497	-10437.20784838503	-67.83	-1.47	457	31.17133735561088	10802.79215161497	17
Container (Max)	760800.3152294108845440000000	26628.01	10802.79215161497	-15825.2188814144109590400000000	-48.08	-2.08	457	31.17133735561088	10802.79215161497	17
Container (Base)	376907.4261006110423352000000	13191.76	12584.948348797021	-606.8115647243654817320000000	-621.13	-0.16	458	16.56582208385864	12584.948348797021	20
ODD Cubes Basic	420000.00	14700.00	12584.948348797021	-2115.051651202979	-198.58	-0.50	458	16.56582208385864	12584.948348797021	20
Traditional Housing	708000.00	21240.00	12584.948348797021	-8655.051651202979	-81.80	-1.22	458	16.56582208385864	12584.948348797021	20
Container (Max)	676087.5963774843049320000000	23663.07	12584.948348797021	-11078.1175244149296726200000000	-61.03	-1.64	458	16.56582208385864	12584.948348797021	20
Container (Base)	413909.8502356068864200100000	14486.84	17511.231039328763	3024.3862810825219752996500000	136.86	0.73	459	28.009528653970207	17511.231039328763	15
ODD Cubes Basic	420000.00	14700.00	17511.231039328763	2811.231039328763	149.40	0.67	459	28.009528653970207	17511.231039328763	15
Traditional Housing	708000.00	21240.00	17511.231039328763	-3728.768960671237	-189.87	-0.53	459	28.009528653970207	17511.231039328763	15
Container (Max)	742461.6666694598991103500000	25986.16	17511.231039328763	-8474.9272941023334688622500000	-87.61	-1.14	459	28.009528653970207	17511.231039328763	15
Container (Base)	254777.7174931071307054800000	8917.22	10354.756042861954	1437.5359306032044253082000000	177.23	0.56	460	-21.205123508748564	10354.756042861954	30
ODD Cubes Basic	420000.00	14700.00	10354.756042861954	-4345.243957138046	-96.66	-1.03	460	-21.205123508748564	10354.756042861954	30
Container (Max)	457014.2233930828913718000000	15995.50	10354.756042861954	-5640.7417758959471980130000000	-81.02	-1.23	460	-21.205123508748564	10354.756042861954	30
Traditional Housing	708000.00	21240.00	10354.756042861954	-10885.243957138046	-65.04	-1.54	460	-21.205123508748564	10354.756042861954	30
ODD Cubes Basic	420000.00	14700.00	18592.7209271795	3892.7209271795	107.89	0.93	461	45.59474521449255	18592.7209271795	29
Container (Base)	470770.4170188966459465000000	16476.96	18592.7209271795	2115.7563315181173918725000000	222.51	0.45	461	45.59474521449255	18592.7209271795	29
Traditional Housing	708000.00	21240.00	18592.7209271795	-2647.2790728205	-267.44	-0.37	461	45.59474521449255	18592.7209271795	29
Container (Max)	844456.8019813175146275000000	29555.99	18592.7209271795	-10963.2671421666130119625000000	-77.03	-1.30	461	45.59474521449255	18592.7209271795	29
Container (Base)	302012.3272459384719251100000	10570.43	16754.20262612334	6183.7711725154934826211500000	48.84	2.05	462	-6.596918057314223	16754.20262612334	35
ODD Cubes Basic	420000.00	14700.00	16754.20262612334	2054.20262612334	204.46	0.49	462	-6.596918057314223	16754.20262612334	35
Container (Max)	541742.5454216746408888500000	18960.99	16754.20262612334	-2206.7864636352724311097500000	-245.49	-0.41	462	-6.596918057314223	16754.20262612334	35
Traditional Housing	708000.00	21240.00	16754.20262612334	-4485.79737387666	-157.83	-0.63	462	-6.596918057314223	16754.20262612334	35
Container (Base)	416058.6130420143219435900000	14562.05	19129.7216799126	4567.6702234420987319743500000	91.09	1.10	463	28.674074602516313	19129.7216799126	38
ODD Cubes Basic	420000.00	14700.00	19129.7216799126	4429.7216799126	94.81	1.05	463	28.674074602516313	19129.7216799126	38
Traditional Housing	708000.00	21240.00	19129.7216799126	-2110.2783200874	-335.50	-0.30	463	28.674074602516313	19129.7216799126	38
Container (Max)	746316.0663983247412156500000	26121.06	19129.7216799126	-6991.3406440287659425477500000	-106.75	-0.94	463	28.674074602516313	19129.7216799126	38
Container (Base)	283497.1803343753817472000000	9922.40	13579.049460877497	3656.6481491743586388480000000	77.53	1.29	464	-12.32308095911296	13579.049460877497	35
ODD Cubes Basic	420000.00	14700.00	13579.049460877497	-1120.950539122503	-374.68	-0.27	464	-12.32308095911296	13579.049460877497	35
Container (Max)	508530.5142830968763520000000	17798.57	13579.049460877497	-4219.5185390308936723200000000	-120.52	-0.83	464	-12.32308095911296	13579.049460877497	35
Traditional Housing	708000.00	21240.00	13579.049460877497	-7660.950539122503	-92.42	-1.08	464	-12.32308095911296	13579.049460877497	35
Container (Base)	237728.8443848564747460600000	8320.51	9638.46988458969	1317.9603311197133838879000000	180.38	0.55	465	-26.477813224700558	9638.46988458969	37
ODD Cubes Basic	420000.00	14700.00	9638.46988458969	-5061.53011541031	-82.98	-1.21	465	-26.477813224700558	9638.46988458969	37
Container (Max)	426432.3594060755285721000000	14925.13	9638.46988458969	-5286.6626946229535000235000000	-80.66	-1.24	465	-26.477813224700558	9638.46988458969	37
Traditional Housing	708000.00	21240.00	9638.46988458969	-11601.53011541031	-61.03	-1.64	465	-26.477813224700558	9638.46988458969	37
Container (Base)	413380.4695680140257517100000	14468.32	15610.627378599134	1142.3109437186430986901500000	361.88	0.28	466	27.845807569056397	15610.627378599134	19
ODD Cubes Basic	420000.00	14700.00	15610.627378599134	910.627378599134	461.22	0.22	466	27.845807569056397	15610.627378599134	19
Traditional Housing	708000.00	21240.00	15610.627378599134	-5629.372621400866	-125.77	-0.80	466	27.845807569056397	15610.627378599134	19
Container (Max)	741512.0761909055554198500000	25952.92	15610.627378599134	-10342.2952880825604396947500000	-71.70	-1.39	466	27.845807569056397	15610.627378599134	19
Container (Base)	307565.3303577703027089900000	10764.79	19778.240161272326	9013.4535987503654051853500000	34.12	2.93	467	-4.879545758599907	19778.240161272326	27
ODD Cubes Basic	420000.00	14700.00	19778.240161272326	5078.240161272326	82.71	1.21	467	-4.879545758599907	19778.240161272326	27
Container (Max)	551703.3906228326094046500000	19309.62	19778.240161272326	468.6214894731846708372500000	1177.29	0.08	467	-4.879545758599907	19778.240161272326	27
Traditional Housing	708000.00	21240.00	19778.240161272326	-1461.759838727674	-484.35	-0.21	467	-4.879545758599907	19778.240161272326	27
Container (Base)	255840.2629069119414804000000	8954.41	12276.863260862317	3322.4540591203990481860000000	77.00	1.30	468	-20.87651104031572	12276.863260862317	29
ODD Cubes Basic	420000.00	14700.00	12276.863260862317	-2423.136739137683	-173.33	-0.58	468	-20.87651104031572	12276.863260862317	29
Container (Max)	458920.1921406168082140000000	16062.21	12276.863260862317	-3785.3434640592712874900000000	-121.24	-0.82	468	-20.87651104031572	12276.863260862317	29
Traditional Housing	708000.00	21240.00	12276.863260862317	-8963.136739137683	-78.99	-1.27	468	-20.87651104031572	12276.863260862317	29
Container (Base)	330056.9621010652711084380000	11551.99	8496.573441655244	-3055.4202318820404887953300000	-108.02	-0.93	469	2.0764210454734666	8496.573441655244	36
ODD Cubes Basic	420000.00	14700.00	8496.573441655244	-6203.426558344756	-67.70	-1.48	469	2.0764210454734666	8496.573441655244	36
Traditional Housing	708000.00	21240.00	8496.573441655244	-12743.426558344756	-55.56	-1.80	469	2.0764210454734666	8496.573441655244	36
Container (Max)	592048.3458847983799533300000	20721.69	8496.573441655244	-12225.1186643126992983665500000	-48.43	-2.06	469	2.0764210454734666	8496.573441655244	36
Container (Base)	360841.5315964640336182200000	12629.45	18354.727582231684	5725.2739763554428233623000000	63.03	1.59	470	11.597137280369154	18354.727582231684	19
ODD Cubes Basic	420000.00	14700.00	18354.727582231684	3654.727582231684	114.92	0.87	470	11.597137280369154	18354.727582231684	19
Traditional Housing	708000.00	21240.00	18354.727582231684	-2885.272417768316	-245.38	-0.41	470	11.597137280369154	18354.727582231684	19
Container (Max)	647268.9760830051116577000000	22654.41	18354.727582231684	-4299.6865806734949080195000000	-150.54	-0.66	470	11.597137280369154	18354.727582231684	19
Container (Base)	264632.3370433773627355800000	9262.13	13304.172892096769	4042.0410955785613042547000000	65.47	1.53	471	-18.157394146965494	13304.172892096769	38
ODD Cubes Basic	420000.00	14700.00	13304.172892096769	-1395.827107903231	-300.90	-0.33	471	-18.157394146965494	13304.172892096769	38
Container (Max)	474691.2060778927865253000000	16614.19	13304.172892096769	-3310.0193206294785283855000000	-143.41	-0.70	471	-18.157394146965494	13304.172892096769	38
Traditional Housing	708000.00	21240.00	13304.172892096769	-7935.827107903231	-89.22	-1.12	471	-18.157394146965494	13304.172892096769	38
Container (Base)	350707.0768928790024839400000	12274.75	18427.562554823875	6152.8148635731099130621000000	57.00	1.75	472	8.462863551361558	18427.562554823875	37
ODD Cubes Basic	420000.00	14700.00	18427.562554823875	3727.562554823875	112.67	0.89	472	8.462863551361558	18427.562554823875	37
Traditional Housing	708000.00	21240.00	18427.562554823875	-2812.437445176125	-251.74	-0.40	472	8.462863551361558	18427.562554823875	37
Container (Max)	629090.0317410746044779000000	22018.15	18427.562554823875	-3590.5885561137361567265000000	-175.21	-0.57	472	8.462863551361558	18427.562554823875	37
ODD Cubes Basic	420000.00	14700.00	17609.114752216352	2909.114752216352	144.37	0.69	473	37.62933959279252	17609.114752216352	22
Container (Base)	445014.8355195231179436000000	15575.52	17609.114752216352	2033.5955090330428719740000000	218.83	0.46	473	37.62933959279252	17609.114752216352	22
Traditional Housing	708000.00	21240.00	17609.114752216352	-3630.885247783648	-194.99	-0.51	473	37.62933959279252	17609.114752216352	22
Container (Max)	798257.0511051762556260000000	27939.00	17609.114752216352	-10329.8820364648169469100000000	-77.28	-1.29	473	37.62933959279252	17609.114752216352	22
Container (Base)	401454.5005862406351810000000	14050.91	10890.307666455214	-3160.5998540632082313350000000	-127.02	-0.79	474	24.1574738238467	10890.307666455214	29
ODD Cubes Basic	420000.00	14700.00	10890.307666455214	-3809.692333544786	-110.25	-0.91	474	24.1574738238467	10890.307666455214	29
Traditional Housing	708000.00	21240.00	10890.307666455214	-10349.692333544786	-68.41	-1.46	474	24.1574738238467	10890.307666455214	29
Container (Max)	720119.5560520020523350000000	25204.18	10890.307666455214	-14313.8767953648578317250000000	-50.31	-1.99	474	24.1574738238467	10890.307666455214	29
ODD Cubes Basic	420000.00	14700.00	16564.23892061056	1864.23892061056	225.29	0.44	475	47.99849310485915	16564.23892061056	17
Container (Base)	478542.7675600447213845000000	16749.00	16564.23892061056	-184.7579439910052484575000000	-2590.11	-0.04	475	47.99849310485915	16564.23892061056	17
Traditional Housing	708000.00	21240.00	16564.23892061056	-4675.76107938944	-151.42	-0.66	475	47.99849310485915	16564.23892061056	17
Container (Max)	858398.6599328383129575000000	30043.95	16564.23892061056	-13479.7141770387809535125000000	-63.68	-1.57	475	47.99849310485915	16564.23892061056	17
ODD Cubes Basic	420000.00	14700.00	10068.823621898951	-4631.176378101049	-90.69	-1.10	476	49.03521224316448	10068.823621898951	17
Container (Base)	481894.9263234153245664000000	16866.32	10068.823621898951	-6797.4987994205853598240000000	-70.89	-1.41	476	49.03521224316448	10068.823621898951	17
Traditional Housing	708000.00	21240.00	10068.823621898951	-11171.176378101049	-63.38	-1.58	476	49.03521224316448	10068.823621898951	17
Container (Max)	864411.6827709661422240000000	30254.41	10068.823621898951	-20185.5852750848639778400000000	-42.82	-2.34	476	49.03521224316448	10068.823621898951	17
ODD Cubes Basic	420000.00	14700.00	16760.752619542065	2060.752619542065	203.81	0.49	477	62.95928422479497	16760.752619542065	15
Container (Base)	526917.4383909787998471000000	18442.11	16760.752619542065	-1681.3577241421929946485000000	-313.39	-0.32	477	62.95928422479497	16760.752619542065	15
Traditional Housing	708000.00	21240.00	16760.752619542065	-4479.247380457935	-158.06	-0.63	477	62.95928422479497	16760.752619542065	15
Container (Max)	945171.9964680220657485000000	33081.02	16760.752619542065	-16320.2672568387073011975000000	-57.91	-1.73	477	62.95928422479497	16760.752619542065	15
ODD Cubes Basic	420000.00	14700.00	15388.86502246352	688.86502246352	609.70	0.16	478	43.90955335904259	15388.86502246352	30
Container (Base)	465321.4671177290817837000000	16286.25	15388.86502246352	-897.3863266569978624295000000	-518.53	-0.19	478	43.90955335904259	15388.86502246352	30
Traditional Housing	708000.00	21240.00	15388.86502246352	-5851.13497753648	-121.00	-0.83	478	43.90955335904259	15388.86502246352	30
Container (Max)	834682.6049601149741295000000	29213.89	15388.86502246352	-13825.0261511405040945325000000	-60.37	-1.66	478	43.90955335904259	15388.86502246352	30
ODD Cubes Basic	420000.00	14700.00	17941.443211458296	3241.443211458296	129.57	0.77	479	48.96464787736302	17941.443211458296	21
Container (Base)	481666.7613861019097586000000	16858.34	17941.443211458296	1083.1065629447291584490000000	444.71	0.22	479	48.96464787736302	17941.443211458296	21
Traditional Housing	708000.00	21240.00	17941.443211458296	-3298.556788541704	-214.64	-0.47	479	48.96464787736302	17941.443211458296	21
Container (Max)	864002.4059210993841510000000	30240.08	17941.443211458296	-12298.6409957801824452850000000	-70.25	-1.42	479	48.96464787736302	17941.443211458296	21
Container (Base)	281221.5584209452866589600000	9842.75	8006.797711601957	-1835.9568331311280330636000000	-153.17	-0.65	480	-13.026860510063528	8006.797711601957	36
ODD Cubes Basic	420000.00	14700.00	8006.797711601957	-6693.202288398043	-62.75	-1.59	480	-13.026860510063528	8006.797711601957	36
Traditional Housing	708000.00	21240.00	8006.797711601957	-13233.202288398043	-53.50	-1.87	480	-13.026860510063528	8006.797711601957	36
Container (Max)	504448.5576986060344236000000	17655.70	8006.797711601957	-9648.9018078492542048260000000	-52.28	-1.91	480	-13.026860510063528	8006.797711601957	36
Container (Base)	350012.2916354881969251000000	12250.43	17030.571472504034	4780.1412652619471076215000000	73.22	1.37	481	8.24798793710957	17030.571472504034	29
ODD Cubes Basic	420000.00	14700.00	17030.571472504034	2330.571472504034	180.21	0.55	481	8.24798793710957	17030.571472504034	29
Traditional Housing	708000.00	21240.00	17030.571472504034	-4209.428527495966	-168.19	-0.59	481	8.24798793710957	17030.571472504034	29
Container (Max)	627843.7424346323614785000000	21974.53	17030.571472504034	-4943.9595127080986517475000000	-126.99	-0.79	481	8.24798793710957	17030.571472504034	29
Container (Base)	243928.7512170386095107000000	8537.51	14483.105918701076	5945.5996261047246671255000000	41.03	2.44	482	-24.56037359180851	14483.105918701076	21
ODD Cubes Basic	420000.00	14700.00	14483.105918701076	-216.894081298924	-1936.43	-0.05	482	-24.56037359180851	14483.105918701076	21
Container (Max)	437553.6051488310515745000000	15314.38	14483.105918701076	-831.2702615080108051075000000	-526.37	-0.19	482	-24.56037359180851	14483.105918701076	21
Traditional Housing	708000.00	21240.00	14483.105918701076	-6756.894081298924	-104.78	-0.95	482	-24.56037359180851	14483.105918701076	21
Container (Base)	291651.3477391138542284400000	10207.80	13578.993249688014	3371.1960788190291020046000000	86.51	1.16	483	-9.801248909327292	13578.993249688014	28
ODD Cubes Basic	420000.00	14700.00	13578.993249688014	-1121.006750311986	-374.66	-0.27	483	-9.801248909327292	13578.993249688014	28
Container (Max)	523157.2662634562400354000000	18310.50	13578.993249688014	-4731.5110695329544012390000000	-110.57	-0.90	483	-9.801248909327292	13578.993249688014	28
Traditional Housing	708000.00	21240.00	13578.993249688014	-7661.006750311986	-92.42	-1.08	483	-9.801248909327292	13578.993249688014	28
Container (Base)	247975.7104458990692514000000	8679.15	12948.587075624953	4269.4372100184855762010000000	58.08	1.72	484	-23.30877413585602	12948.587075624953	17
ODD Cubes Basic	420000.00	14700.00	12948.587075624953	-1751.412924375047	-239.81	-0.42	484	-23.30877413585602	12948.587075624953	17
Container (Max)	444812.9445733282911990000000	15568.45	12948.587075624953	-2619.8659844415371919650000000	-169.78	-0.59	484	-23.30877413585602	12948.587075624953	17
Traditional Housing	708000.00	21240.00	12948.587075624953	-8291.412924375047	-85.39	-1.17	484	-23.30877413585602	12948.587075624953	17
Container (Base)	246569.6246724744311708100000	8629.94	13957.436686463332	5327.4998229267269090216500000	46.28	2.16	485	-23.743633023608233	13957.436686463332	19
ODD Cubes Basic	420000.00	14700.00	13957.436686463332	-742.563313536668	-565.61	-0.18	485	-23.743633023608233	13957.436686463332	19
Container (Max)	442290.7412814210681883500000	15480.18	13957.436686463332	-1522.7392583864053865922500000	-290.46	-0.34	485	-23.743633023608233	13957.436686463332	19
Traditional Housing	708000.00	21240.00	13957.436686463332	-7282.563313536668	-97.22	-1.03	485	-23.743633023608233	13957.436686463332	19
Container (Base)	264966.1366002266877440400000	9273.81	14320.901203621721	5047.0864226137869289586000000	52.50	1.90	486	-18.054160256994372	14320.901203621721	33
ODD Cubes Basic	420000.00	14700.00	14320.901203621721	-379.098796378279	-1107.89	-0.09	486	-18.054160256994372	14320.901203621721	33
Container (Max)	475289.9678014197926814000000	16635.15	14320.901203621721	-2314.2476694279717438490000000	-205.38	-0.49	486	-18.054160256994372	14320.901203621721	33
Traditional Housing	708000.00	21240.00	14320.901203621721	-6919.098796378279	-102.33	-0.98	486	-18.054160256994372	14320.901203621721	33
ODD Cubes Basic	420000.00	14700.00	8261.627415716182	-6438.372584283818	-65.23	-1.53	487	58.71123333343989	8261.627415716182	28
Traditional Housing	708000.00	21240.00	8261.627415716182	-12978.372584283818	-54.55	-1.83	487	58.71123333343989	8261.627415716182	28
Container (Base)	513181.6631973445435227000000	17961.36	8261.627415716182	-9699.7307961908770232945000000	-52.91	-1.89	487	58.71123333343989	8261.627415716182	28
Container (Max)	920533.0888956180339945000000	32218.66	8261.627415716182	-23957.0306956304491898075000000	-38.42	-2.60	487	58.71123333343989	8261.627415716182	28
Container (Base)	255433.0235357983044325500000	8940.16	16755.016729646733	7814.8609058937923448607500000	32.69	3.06	488	-21.002457595866215	16755.016729646733	20
ODD Cubes Basic	420000.00	14700.00	16755.016729646733	2055.016729646733	204.38	0.49	488	-21.002457595866215	16755.016729646733	20
Container (Max)	458189.6958210961596892500000	16036.64	16755.016729646733	718.3773759083674108762500000	637.81	0.16	488	-21.002457595866215	16755.016729646733	20
Traditional Housing	708000.00	21240.00	16755.016729646733	-4484.983270353267	-157.86	-0.63	488	-21.002457595866215	16755.016729646733	20
Container (Base)	283008.1422788584060230000000	9905.28	15320.193101315943	5414.9081215558987891950000000	52.26	1.91	489	-12.4743253205239	15320.193101315943	28
ODD Cubes Basic	420000.00	14700.00	15320.193101315943	620.193101315943	677.21	0.15	489	-12.4743253205239	15320.193101315943	28
Container (Max)	507653.2894246953538050000000	17767.87	15320.193101315943	-2447.6720285483943831750000000	-207.40	-0.48	489	-12.4743253205239	15320.193101315943	28
Traditional Housing	708000.00	21240.00	15320.193101315943	-5919.806898684057	-119.60	-0.84	489	-12.4743253205239	15320.193101315943	28
ODD Cubes Basic	420000.00	14700.00	11154.062764970447	-3545.937235029553	-118.45	-0.84	490	29.57470877368901	11154.062764970447	26
Container (Base)	418970.7505901092556043000000	14663.98	11154.062764970447	-3509.9135056833769461505000000	-119.37	-0.84	490	29.57470877368901	11154.062764970447	26
Traditional Housing	708000.00	21240.00	11154.062764970447	-10085.937235029553	-70.20	-1.42	490	29.57470877368901	11154.062764970447	26
Container (Max)	751539.7896228349424505000000	26303.89	11154.062764970447	-15149.8298718287759857675000000	-49.61	-2.02	490	29.57470877368901	11154.062764970447	26
Container (Base)	298807.8524061681499097400000	10458.27	16142.136243663113	5683.8614094472277531591000000	52.57	1.90	491	-7.587963120844382	16142.136243663113	34
ODD Cubes Basic	420000.00	14700.00	16142.136243663113	1442.136243663113	291.23	0.34	491	-7.587963120844382	16142.136243663113	34
Container (Max)	535994.4345009465421809000000	18759.81	16142.136243663113	-2617.6689638700159763315000000	-204.76	-0.49	491	-7.587963120844382	16142.136243663113	34
Traditional Housing	708000.00	21240.00	16142.136243663113	-5097.863756336887	-138.88	-0.72	491	-7.587963120844382	16142.136243663113	34
ODD Cubes Basic	420000.00	14700.00	10052.583541326696	-4647.416458673304	-90.37	-1.11	492	55.58380027713008	10052.583541326696	20
Container (Base)	503069.3273300807145744000000	17607.43	10052.583541326696	-7554.8429152261290101040000000	-66.59	-1.50	492	55.58380027713008	10052.583541326696	20
Traditional Housing	708000.00	21240.00	10052.583541326696	-11187.416458673304	-63.29	-1.58	492	55.58380027713008	10052.583541326696	20
Container (Max)	902393.8207973683205040000000	31583.78	10052.583541326696	-21531.2001865811952176400000000	-41.91	-2.39	492	55.58380027713008	10052.583541326696	20
Container (Base)	328501.0097830760727464820000	11497.54	10911.154111068567	-586.3812313390955461268700000	-560.22	-0.18	493	1.5952130657153774	10911.154111068567	32
ODD Cubes Basic	420000.00	14700.00	10911.154111068567	-3788.845888931433	-110.85	-0.90	493	1.5952130657153774	10911.154111068567	32
Traditional Housing	708000.00	21240.00	10911.154111068567	-10328.845888931433	-68.55	-1.46	493	1.5952130657153774	10911.154111068567	32
Container (Max)	589257.3155418024746888700000	20624.01	10911.154111068567	-9712.8519328945196141104500000	-60.67	-1.65	493	1.5952130657153774	10911.154111068567	32
ODD Cubes Basic	420000.00	14700.00	13440.101616596745	-1259.898383403255	-333.36	-0.30	494	68.63824822470478	13440.101616596745	39
Container (Base)	545279.9709572071767954000000	19084.80	13440.101616596745	-5644.6973669055061878390000000	-96.60	-1.04	494	68.63824822470478	13440.101616596745	39
Traditional Housing	708000.00	21240.00	13440.101616596745	-7799.898383403255	-90.77	-1.10	494	68.63824822470478	13440.101616596745	39
Container (Max)	978110.2716156989592390000000	34233.86	13440.101616596745	-20793.7578899527185733650000000	-47.04	-2.13	494	68.63824822470478	13440.101616596745	39
Container (Base)	351790.4826190346771738700000	12312.67	19189.408723497723	6876.7418318315092989145500000	51.16	1.95	495	8.797927469911109	19189.408723497723	30
ODD Cubes Basic	420000.00	14700.00	19189.408723497723	4489.408723497723	93.55	1.07	495	8.797927469911109	19189.408723497723	30
Traditional Housing	708000.00	21240.00	19189.408723497723	-2050.591276502277	-345.27	-0.29	495	8.797927469911109	19189.408723497723	30
Container (Max)	631033.4192218579277554500000	22086.17	19189.408723497723	-2896.7609492673044714407500000	-217.84	-0.46	495	8.797927469911109	19189.408723497723	30
Container (Base)	378975.8723712921250173000000	13264.16	14562.908574010096	1298.7530410148716243945000000	291.80	0.34	496	17.20552860933811	14562.908574010096	31
ODD Cubes Basic	420000.00	14700.00	14562.908574010096	-137.091425989904	-3063.65	-0.03	496	17.20552860933811	14562.908574010096	31
Traditional Housing	708000.00	21240.00	14562.908574010096	-6677.091425989904	-106.03	-0.94	496	17.20552860933811	14562.908574010096	31
Container (Max)	679797.9262105915049055000000	23792.93	14562.908574010096	-9230.0188433606066716925000000	-73.65	-1.36	496	17.20552860933811	14562.908574010096	31
Container (Base)	226455.7610228411492832600000	7925.95	8507.903167250835	581.9515314513947750859000000	389.13	0.26	497	-29.964229619060518	8507.903167250835	20
Container (Max)	406210.9699979680425741000000	14217.38	8507.903167250835	-5709.4807826780464900935000000	-71.15	-1.41	497	-29.964229619060518	8507.903167250835	20
ODD Cubes Basic	420000.00	14700.00	8507.903167250835	-6192.096832749165	-67.83	-1.47	497	-29.964229619060518	8507.903167250835	20
Traditional Housing	708000.00	21240.00	8507.903167250835	-12732.096832749165	-55.61	-1.80	497	-29.964229619060518	8507.903167250835	20
Container (Base)	295559.2673890953119478000000	10344.57	19605.918281032762	9261.3439224144260818270000000	31.91	3.13	498	-8.59265009940054	19605.918281032762	17
ODD Cubes Basic	420000.00	14700.00	19605.918281032762	4905.918281032762	85.61	1.17	498	-8.59265009940054	19605.918281032762	17
Container (Max)	530167.1997909718979730000000	18555.85	19605.918281032762	1050.0662883487455709450000000	504.89	0.20	498	-8.59265009940054	19605.918281032762	17
Traditional Housing	708000.00	21240.00	19605.918281032762	-1634.081718967238	-433.27	-0.23	498	-8.59265009940054	19605.918281032762	17
Container (Base)	351691.8287937780785835600000	12309.21	10091.160694130253	-2218.0533136519797504246000000	-158.56	-0.63	499	8.767416889735692	10091.160694130253	16
ODD Cubes Basic	420000.00	14700.00	10091.160694130253	-4608.839305869747	-91.13	-1.10	499	8.767416889735692	10091.160694130253	16
Traditional Housing	708000.00	21240.00	10091.160694130253	-11148.839305869747	-63.50	-1.57	499	8.767416889735692	10091.160694130253	16
Container (Max)	630856.4563313115003846000000	22079.98	10091.160694130253	-11988.8152774656495134610000000	-52.62	-1.90	499	8.767416889735692	10091.160694130253	16
\.


--
-- Data for Name: sensitivity_model_summary; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_model_summary (model_name, annual_roi_percentage_mean, annual_roi_percentage_std, annual_roi_percentage_min, annual_roi_percentage_max, payback_years_mean, payback_years_std, payback_years_min, payback_years_max) FROM stdin;
Container (Base)	0.39058	1.3606197248575156	-2.03	4.77	-113.38092	3936.1834753738763	-74177.41	29059.83
Container (Max)	-1.3311199999999999	0.7585874078249795	-2.68	1.11	4.11756	1561.7260324776175	-2871.00	34406.37
ODD Cubes Basic	-0.14744	0.8102981009633738	-1.59	1.26	-1203.71872	17906.857854300197	-309048.24	11438.78
Traditional Housing	-1.011	0.4807857213142244	-1.87	-0.18	-140.16816	104.17089312934365	-570.13	-53.50
\.


--
-- Data for Name: sensitivity_optimal_scenarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sensitivity_optimal_scenarios (model_name, adjusted_investment, annual_maintenance, annual_rental_income, annual_net_income, payback_years, annual_roi_percentage, iteration, container_price_increase, rental_income, expected_lifespan) FROM stdin;
\.


--
-- Data for Name: shipping_container_prices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shipping_container_prices (id, ship_date, freight_index, base_price, calculated_date) FROM stdin;
181	2017-01-01	954.27	1420.15	2025-03-18 16:22:01.091463
182	2017-02-01	815.10	1509.99	2025-03-18 16:22:01.091463
183	2017-03-01	830.02	1765.18	2025-03-18 16:22:01.091463
184	2017-04-01	909.25	1892.92	2025-03-18 16:22:01.091463
185	2017-05-01	853.43	1853.51	2025-03-18 16:22:01.091463
186	2017-06-01	918.83	1838.11	2025-03-18 16:22:01.091463
187	2017-07-01	925.45	1947.89	2025-03-18 16:22:01.091463
188	2017-08-01	715.97	2070.80	2025-03-18 16:22:01.091463
189	2017-09-01	806.81	2384.88	2025-03-18 16:22:01.091463
190	2017-10-01	705.19	2152.64	2025-03-18 16:22:01.091463
191	2017-11-01	824.18	2173.18	2025-03-18 16:22:01.091463
192	2017-12-01	824.18	2456.76	2025-03-18 16:22:01.091463
193	2018-01-01	858.60	2420.84	2025-03-18 16:22:01.091463
194	2018-02-01	854.19	2335.61	2025-03-18 16:22:01.091463
195	2018-03-01	658.68	2331.98	2025-03-18 16:22:01.091463
196	2018-04-01	760.67	2392.02	2025-03-18 16:22:01.091463
197	2018-05-01	764.34	2444.68	2025-03-18 16:22:01.091463
198	2018-06-01	821.18	2534.68	2025-03-18 16:22:01.091463
199	2018-07-01	868.59	2306.63	2025-03-18 16:22:01.091463
200	2018-08-01	939.48	2223.22	2025-03-18 16:22:01.091463
201	2018-09-01	870.58	2271.45	2025-03-18 16:22:01.091463
202	2018-10-01	956.63	2397.73	2025-03-18 16:22:01.091463
203	2018-11-01	890.41	2394.04	2025-03-18 16:22:01.091463
204	2018-12-01	910.81	2545.57	2025-03-18 16:22:01.091463
205	2019-01-01	945.44	2442.95	2025-03-18 16:22:01.091463
206	2019-02-01	847.75	2355.88	2025-03-18 16:22:01.091463
207	2019-03-01	793.49	2307.86	2025-03-18 16:22:01.091463
208	2019-04-01	778.00	2315.46	2025-03-18 16:22:01.091463
209	2019-05-01	782.12	2411.14	2025-03-18 16:22:01.091463
210	2019-06-01	829.70	2143.90	2025-03-18 16:22:01.091463
211	2019-07-01	788.93	2247.81	2025-03-18 16:22:01.091463
212	2019-08-01	819.65	2168.15	2025-03-18 16:22:01.091463
213	2019-09-01	722.90	2114.81	2025-03-18 16:22:01.091463
214	2019-10-01	705.28	2042.28	2025-03-18 16:22:01.091463
215	2019-11-01	819.63	1990.81	2025-03-18 16:22:01.091463
216	2019-12-01	958.57	1976.95	2025-03-18 16:22:01.091463
217	2020-01-01	981.19	1735.97	2025-03-18 16:22:01.091463
218	2020-02-01	875.76	1898.27	2025-03-18 16:22:01.091463
219	2020-03-01	889.18	2074.10	2025-03-18 16:22:01.091463
220	2020-04-01	852.27	1973.70	2025-03-18 16:22:01.091463
221	2020-05-01	920.38	2037.92	2025-03-18 16:22:01.091463
222	2020-06-01	1001.30	2065.78	2025-03-18 16:22:01.091463
223	2020-07-01	1103.50	1973.78	2025-03-18 16:22:01.091463
224	2020-08-01	1263.30	2387.25	2025-03-18 16:22:01.091463
225	2020-09-01	1443.00	2312.53	2025-03-18 16:22:01.091463
226	2020-10-01	1530.00	2314.33	2025-03-18 16:22:01.091463
227	2020-11-01	2048.30	2473.81	2025-03-18 16:22:01.091463
228	2020-12-01	2641.90	3008.21	2025-03-18 16:22:01.091463
229	2021-01-01	2861.70	4071.73	2025-03-18 16:22:01.091463
230	2021-02-01	2775.30	3935.67	2025-03-18 16:22:01.091463
231	2021-03-01	2570.70	4307.26	2025-03-18 16:22:01.091463
232	2021-04-01	3100.70	4560.04	2025-03-18 16:22:01.091463
233	2021-05-01	3495.80	5142.27	2025-03-18 16:22:01.091463
234	2021-06-01	3785.40	6615.43	2025-03-18 16:22:01.091463
235	2021-07-01	4196.20	4735.52	2025-03-18 16:22:01.091463
236	2021-08-01	4385.60	4915.50	2025-03-18 16:22:01.091463
237	2021-09-01	4643.80	4209.95	2025-03-18 16:22:01.091463
238	2021-10-01	4567.30	4720.62	2025-03-18 16:22:01.091463
239	2021-11-01	4602.00	4284.20	2025-03-18 16:22:01.091463
240	2021-12-01	5046.70	3533.33	2025-03-18 16:22:01.091463
241	2022-01-01	5010.40	3423.21	2025-03-18 16:22:01.091463
242	2022-02-01	4818.50	3284.18	2025-03-18 16:22:01.091463
243	2022-03-01	4434.10	3508.14	2025-03-18 16:22:01.091463
244	2022-04-01	4177.30	3445.58	2025-03-18 16:22:01.091463
245	2022-05-01	4175.40	3388.88	2025-03-18 16:22:01.091463
246	2022-06-01	4216.10	3375.52	2025-03-18 16:22:01.091463
247	2022-07-01	3887.80	3278.26	2025-03-18 16:22:01.091463
248	2022-08-01	3154.30	3168.62	2025-03-18 16:22:01.091463
249	2022-09-01	1923.00	2656.75	2025-03-18 16:22:01.091463
250	2022-10-01	1663.75	2640.37	2025-03-18 16:22:01.091463
251	2022-11-01	1397.15	2637.31	2025-03-18 16:22:01.091463
252	2022-12-01	1107.50	2619.72	2025-03-18 16:22:01.091463
253	2023-01-01	1029.80	2627.46	2025-03-18 16:22:01.091463
254	2023-02-01	946.68	2613.53	2025-03-18 16:22:01.091463
255	2023-03-01	923.78	2590.85	2025-03-18 16:22:01.091463
256	2023-04-01	999.73	2596.26	2025-03-18 16:22:01.091463
257	2023-05-01	983.46	2586.56	2025-03-18 16:22:01.091463
258	2023-06-01	953.60	2583.17	2025-03-18 16:22:01.091463
259	2023-07-01	1029.20	2568.65	2025-03-18 16:22:01.091463
260	2023-08-01	1013.80	2565.52	2025-03-18 16:22:01.091463
261	2023-09-01	886.85	2548.18	2025-03-18 16:22:01.091463
262	2023-10-01	1012.60	2550.05	2025-03-18 16:22:01.091463
263	2023-11-01	993.21	2552.08	2025-03-18 16:22:01.091463
264	2023-12-01	1759.60	2560.14	2025-03-18 16:22:01.091463
\.


--
-- Data for Name: shipping_container_raw; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shipping_container_raw (id, container_id, ship_date, delivery_date, producer, producer_type, container_type, container_qty, origin, destination, freight_index, base_price, priority, status, import_date) FROM stdin;
401	CS17_001	2017-01-15	2017-01-20	ShipEasy	Forwarder	40 ft HC CW	3.0	Shanghai	Los Angeles	921.96	1372.06	HIGH	in_transit	2025-03-18 16:22:01.091463
402	CS17_002	2017-01-16	2017-01-22	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	976.38	1453.05	Medium	delivered	2025-03-18 16:22:01.091463
403	CS17_003	2017-01-16	2017-01-25	Ocean Wave	Broker	40 ft HC CW	5.0	Dubai	Hamburg	964.47	1435.34	Low	completed	2025-03-18 16:22:01.091463
404	CS17_004	2017-02-12	2017-02-17	Cargo Masters	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	798.80	1501.24	HIGH	processing	2025-03-18 16:22:01.091463
405	CS17_005	2017-02-15	2017-02-20	Sea Transit	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	831.40	1518.74	Medium	delivered	2025-03-18 16:22:01.091463
406	CS17_006	2017-03-10	2017-03-15	ShipEasy	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	815.42	1723.88	Low	completed	2025-03-18 16:22:01.091463
407	CS17_007	2017-03-15	2017-03-20	Global Shipping	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	844.62	1806.48	HIGH	in_transit	2025-03-18 16:22:01.091463
408	CS17_008	2017-04-05	2017-04-10	Ocean Wave	Broker	40 ft HC CW	4.0	Rotterdam	Singapore	927.44	1930.78	Medium	in_transit	2025-03-18 16:22:01.091463
409	CS17_009	2017-04-12	2017-04-17	Cargo Masters	Agent	40 ft HC CW	6.0	Dubai	Hamburg	891.06	1855.06	Low	processing	2025-03-18 16:22:01.091463
410	CS17_010	2017-05-05	2017-05-10	Sea Transit	Direct	40 ft HC CW	5.0	Shanghai	Los Angeles	836.36	1816.44	HIGH	completed	2025-03-18 16:22:01.091463
411	CS17_011	2017-05-15	2017-05-20	ShipEasy	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	870.50	1890.58	Medium	in_transit	2025-03-18 16:22:01.091463
412	CS17_012	2017-05-25	2017-05-30	Global Shipping	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	853.43	1853.51	Low	delivered	2025-03-18 16:22:01.091463
413	CS17_013	2017-06-08	2017-06-13	Ocean Wave	Forwarder	40 ft HC CW	4.0	Shanghai	Los Angeles	900.45	1801.35	HIGH	completed	2025-03-18 16:22:01.091463
414	CS17_014	2017-06-18	2017-06-23	Cargo Masters	Broker	40 ft HC CW	2.0	Rotterdam	Singapore	937.21	1874.87	Medium	processing	2025-03-18 16:22:01.091463
415	CS17_015	2017-07-15	2017-07-20	Sea Transit	Agent	40 ft HC CW	4.0	Dubai	Hamburg	907.94	1908.93	Low	delivered	2025-03-18 16:22:01.091463
416	CS17_016	2017-07-25	2017-07-30	ShipEasy	Direct	40 ft HC CW	5.0	Shanghai	Los Angeles	942.96	1986.85	Medium	completed	2025-03-18 16:22:01.091463
417	CS17_017	2017-08-08	2017-08-13	Global Shipping	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	701.65	2029.38	HIGH	in_transit	2025-03-18 16:22:01.091463
418	CS17_018	2017-08-18	2017-08-23	Ocean Wave	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	730.29	2112.22	Low	in_transit	2025-03-18 16:22:01.091463
419	CS17_019	2017-09-05	2017-09-10	Cargo Masters	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	790.67	2336.18	Medium	processing	2025-03-18 16:22:01.091463
420	CS17_020	2017-09-15	2017-09-20	Sea Transit	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	822.95	2433.58	HIGH	completed	2025-03-18 16:22:01.091463
421	CS17_021	2017-10-18	2017-10-23	ShipEasy	Direct	40 ft HC CW	5.0	Dubai	Hamburg	691.09	2109.59	Low	in_transit	2025-03-18 16:22:01.091463
422	CS17_022	2017-10-28	2017-11-02	Global Shipping	Carrier	40 ft HC CW	4.0	Shanghai	Los Angeles	719.29	2195.69	Medium	delivered	2025-03-18 16:22:01.091463
423	CS17_023	2017-11-05	2017-11-10	Ocean Wave	Partner	40 ft HC CW	4.0	Rotterdam	Singapore	807.70	2129.72	HIGH	completed	2025-03-18 16:22:01.091463
424	CS17_024	2017-11-15	2017-11-20	Cargo Masters	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	840.66	2216.64	Low	processing	2025-03-18 16:22:01.091463
425	CS17_025	2017-12-08	2017-12-13	Sea Transit	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	807.70	2407.62	Medium	delivered	2025-03-18 16:22:01.091463
426	CS17_026	2017-12-18	2017-12-23	ShipEasy	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	840.66	2505.89	HIGH	completed	2025-03-18 16:22:01.091463
427	CS18_001	2018-01-12	2018-01-17	Global Shipping	Direct	40 ft HC CW	4.0	Dubai	Hamburg	841.43	2420.84	Low	in_transit	2025-03-18 16:22:01.091463
428	CS18_002	2018-01-22	2018-01-27	Ocean Wave	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	875.77	2420.84	Medium	in_transit	2025-03-18 16:22:01.091463
429	CS18_003	2018-02-05	2018-02-10	Cargo Masters	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	837.11	2335.61	HIGH	processing	2025-03-18 16:22:01.091463
430	CS18_004	2018-02-15	2018-02-20	Sea Transit	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	871.27	2335.61	Low	completed	2025-03-18 16:22:01.091463
431	CS18_005	2018-02-28	2018-03-05	ShipEasy	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	854.19	2335.61	HIGH	processing	2025-03-18 16:22:01.091463
432	CS18_006	2018-03-03	2018-03-08	ShipEasy	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	645.51	2331.98	Medium	in_transit	2025-03-18 16:22:01.091463
433	CS18_007	2018-03-13	2018-03-18	Global Shipping	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	671.85	2331.98	HIGH	delivered	2025-03-18 16:22:01.091463
434	CS18_008	2018-04-24	2018-04-29	Ocean Wave	Direct	40 ft HC CW	1.0	Dubai	Hamburg	745.46	2392.02	Low	completed	2025-03-18 16:22:01.091463
435	CS18_009	2018-04-12	2018-04-17	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	775.88	2392.02	HIGH	in_transit	2025-03-18 16:22:01.091463
436	CS18_010	2018-04-25	2018-04-30	Ocean Wave	Broker	40 ft HC CW	5.0	Dubai	Hamburg	760.67	2392.02	Medium	processing	2025-03-18 16:22:01.091463
437	CS18_011	2018-05-04	2018-05-09	Cargo Masters	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	749.05	2444.68	Medium	processing	2025-03-18 16:22:01.091463
438	CS18_012	2018-05-14	2018-05-19	Sea Transit	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	779.63	2444.68	HIGH	delivered	2025-03-18 16:22:01.091463
439	CS18_013	2018-06-25	2018-06-30	ShipEasy	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	804.75	2534.68	Low	completed	2025-03-18 16:22:01.091463
440	CS18_014	2018-06-18	2018-06-23	Cargo Masters	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	837.61	2534.68	Medium	in_transit	2025-03-18 16:22:01.091463
441	CS18_015	2018-06-28	2018-07-03	Sea Transit	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	821.18	2534.68	HIGH	processing	2025-03-18 16:22:01.091463
442	CS18_016	2018-07-05	2018-07-10	Global Shipping	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	851.22	2306.63	Medium	in_transit	2025-03-18 16:22:01.091463
443	CS18_017	2018-07-15	2018-07-20	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	885.96	2306.63	HIGH	in_transit	2025-03-18 16:22:01.091463
444	CS18_018	2018-08-08	2018-08-13	Cargo Masters	Direct	40 ft HC CW	3.0	Dubai	Hamburg	920.69	2223.22	Low	processing	2025-03-18 16:22:01.091463
445	CS18_019	2018-08-18	2018-08-23	Sea Transit	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	958.27	2223.22	Medium	completed	2025-03-18 16:22:01.091463
446	CS18_020	2018-08-28	2018-09-02	ShipEasy	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	939.48	2223.22	HIGH	processing	2025-03-18 16:22:01.091463
447	CS18_021	2018-09-28	2018-09-03	ShipEasy	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	853.17	2271.45	HIGH	in_transit	2025-03-18 16:22:01.091463
448	CS18_022	2018-09-15	2018-09-20	Global Shipping	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	887.99	2271.45	HIGH	in_transit	2025-03-18 16:22:01.091463
449	CS18_023	2018-10-08	2018-10-13	Global Shipping	Forwarder	40 ft HC CW	1.0	Dubai	Hamburg	937.50	2397.73	Low	delivered	2025-03-18 16:22:01.091463
450	CS18_024	2018-10-18	2018-10-23	Ocean Wave	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	975.76	2397.73	Medium	completed	2025-03-18 16:22:01.091463
451	CS18_025	2018-11-28	2018-11-03	Cargo Masters	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	872.60	2394.04	HIGH	processing	2025-03-18 16:22:01.091463
452	CS18_026	2018-11-08	2018-11-13	Sea Transit	Direct	40 ft HC CW	5.0	Dubai	Hamburg	908.22	2394.04	Low	delivered	2025-03-18 16:22:01.091463
453	CS18_027	2018-12-18	2018-12-23	ShipEasy	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	892.59	2545.57	Medium	completed	2025-03-18 16:22:01.091463
454	CS18_028	2018-12-18	2018-12-23	Global Shipping	Partner	40 ft HC CW	3.0	Dubai	Hamburg	929.03	2545.57	Medium	completed	2025-03-18 16:22:01.091463
455	CS18_029	2018-12-28	2019-01-02	Ocean Wave	Forwarder	40 ft HC CW	5.0	Shanghai	Los Angeles	910.81	2545.57	Medium	processing	2025-03-18 16:22:01.091463
456	CS19_001	2019-01-10	2019-01-15	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	926.53	2442.95	HIGH	in_transit	2025-03-18 16:22:01.091463
457	CS19_002	2019-01-20	2019-01-25	Ocean Wave	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	964.35	2442.95	Low	in_transit	2025-03-18 16:22:01.091463
458	CS19_003	2019-02-05	2019-02-10	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	830.80	2355.88	Medium	processing	2025-03-18 16:22:01.091463
459	CS19_004	2019-02-15	2019-02-20	Sea Transit	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	864.70	2355.88	HIGH	completed	2025-03-18 16:22:01.091463
460	CS19_005	2019-03-05	2019-03-10	ShipEasy	Direct	40 ft HC CW	3.0	Dubai	Hamburg	777.62	2307.86	Low	in_transit	2025-03-18 16:22:01.091463
461	CS19_006	2019-03-15	2019-03-20	Global Shipping	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	809.36	2307.86	Medium	delivered	2025-03-18 16:22:01.091463
462	CS19_007	2019-03-25	2019-03-30	Cargo Masters	Broker	40 ft HC CW	5.0	Dubai	Hamburg	793.49	2307.86	Medium	delivered	2025-03-18 16:22:01.091463
463	CS19_008	2019-04-08	2019-04-13	Ocean Wave	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	762.44	2315.46	HIGH	completed	2025-03-18 16:22:01.091463
464	CS19_009	2019-04-18	2019-04-23	Cargo Masters	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	793.56	2315.46	Low	processing	2025-03-18 16:22:01.091463
465	CS19_010	2019-05-05	2019-05-10	Sea Transit	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	766.68	2411.14	Medium	delivered	2025-03-18 16:22:01.091463
466	CS19_011	2019-05-15	2019-05-20	ShipEasy	Agent	40 ft HC CW	1.0	Rotterdam	Singapore	797.56	2411.14	Medium	completed	2025-03-18 16:22:01.091463
467	CS19_012	2019-06-28	2019-06-03	Global Shipping	Direct	40 ft HC CW	3.0	Dubai	Hamburg	813.11	2143.90	HIGH	in_transit	2025-03-18 16:22:01.091463
468	CS19_013	2019-06-08	2019-06-13	Ocean Wave	Partner	40 ft HC CW	2.0	Shanghai	Los Angeles	846.29	2143.90	Low	in_transit	2025-03-18 16:22:01.091463
469	CS19_014	2019-07-18	2019-07-23	Cargo Masters	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	773.04	2247.81	Medium	processing	2025-03-18 16:22:01.091463
470	CS19_015	2019-07-28	2019-08-02	Sea Transit	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	804.82	2247.81	HIGH	completed	2025-03-18 16:22:01.091463
471	CS19_016	2019-08-08	2019-08-13	ShipEasy	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	803.26	2168.15	Low	in_transit	2025-03-18 16:22:01.091463
472	CS19_017	2019-08-18	2019-08-23	Global Shipping	Agent	40 ft HC CW	5.0	Rotterdam	Singapore	836.04	2168.15	Medium	delivered	2025-03-18 16:22:01.091463
473	CS19_018	2019-09-15	2019-09-20	Ocean Wave	Direct	40 ft HC CW	2.0	Dubai	Hamburg	708.44	2114.81	HIGH	completed	2025-03-18 16:22:01.091463
474	CS19_019	2019-09-25	2019-09-30	Cargo Masters	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	737.36	2114.81	Low	processing	2025-03-18 16:22:01.091463
475	CS19_020	2019-10-05	2019-10-10	Sea Transit	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	691.59	2042.28	Medium	delivered	2025-03-18 16:22:01.091463
476	CS19_021	2019-10-15	2019-10-20	ShipEasy	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	718.97	2042.28	HIGH	completed	2025-03-18 16:22:01.091463
477	CS19_022	2019-11-05	2019-11-10	Sea Transit	Agent	40 ft HC CW	3.0	Dubai	Hamburg	805.82	1990.81	Medium	in_transit	2025-03-18 16:22:01.091463
478	CS19_023	2019-11-15	2019-11-20	ShipEasy	Direct	40 ft HC CW	2.0	Shanghai	Los Angeles	833.44	1990.81	HIGH	delivered	2025-03-18 16:22:01.091463
479	CS19_024	2019-12-08	2019-12-13	Global Shipping	Partner	40 ft HC CW	3.0	Rotterdam	Singapore	939.40	1976.95	HIGH	in_transit	2025-03-18 16:22:01.091463
480	CS19_025	2019-12-18	2019-12-23	Ocean Wave	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	977.74	1976.95	Medium	completed	2025-03-18 16:22:01.091463
481	CS20_001	2020-01-08	2020-01-13	Global Shipping	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	961.57	1735.97	Low	in_transit	2025-03-18 16:22:01.091463
482	CS20_002	2020-01-18	2020-01-23	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1000.81	1735.97	Medium	in_transit	2025-03-18 16:22:01.091463
483	CS20_003	2020-02-05	2020-02-10	Cargo Masters	Direct	40 ft HC CW	2.0	Dubai	Hamburg	858.24	1898.27	HIGH	processing	2025-03-18 16:22:01.091463
484	CS20_004	2020-02-15	2020-02-20	Sea Transit	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	893.28	1898.27	Low	completed	2025-03-18 16:22:01.091463
485	CS20_005	2020-03-08	2020-03-13	ShipEasy	Carrier	40 ft HC CW	2.0	Rotterdam	Singapore	871.40	2074.10	Medium	in_transit	2025-03-18 16:22:01.091463
486	CS20_006	2020-03-18	2020-03-23	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	906.96	2074.10	HIGH	delivered	2025-03-18 16:22:01.091463
487	CS20_007	2020-04-08	2020-04-13	Ocean Wave	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	835.22	1973.70	Low	completed	2025-03-18 16:22:01.091463
488	CS20_008	2020-04-18	2020-04-23	Cargo Masters	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	869.32	1973.70	Medium	processing	2025-03-18 16:22:01.091463
489	CS20_009	2020-05-08	2020-05-13	Sea Transit	Direct	40 ft HC CW	4.0	Dubai	Hamburg	902.17	2037.92	HIGH	delivered	2025-03-18 16:22:01.091463
490	CS20_010	2020-05-18	2020-05-23	ShipEasy	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	938.59	2037.92	Low	completed	2025-03-18 16:22:01.091463
491	CS20_011	2020-06-08	2020-06-13	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	981.27	2065.78	Medium	in_transit	2025-03-18 16:22:01.091463
492	CS20_012	2020-06-18	2020-06-23	Ocean Wave	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	1021.33	2065.78	HIGH	in_transit	2025-03-18 16:22:01.091463
493	CS20_013	2020-07-08	2020-07-13	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	1081.43	1973.78	Low	processing	2025-03-18 16:22:01.091463
494	CS20_014	2020-07-18	2020-07-23	Sea Transit	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	1125.57	1973.78	Medium	completed	2025-03-18 16:22:01.091463
495	CS20_015	2020-08-08	2020-08-13	ShipEasy	Direct	40 ft HC CW	1.0	Dubai	Hamburg	1238.03	2387.25	HIGH	in_transit	2025-03-18 16:22:01.091463
496	CS20_016	2020-08-18	2020-08-23	Global Shipping	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	1288.57	2387.25	Low	delivered	2025-03-18 16:22:01.091463
497	CS20_017	2020-09-08	2020-09-13	Ocean Wave	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	1414.14	2312.53	Medium	completed	2025-03-18 16:22:01.091463
498	CS20_018	2020-09-18	2020-09-23	Cargo Masters	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	1471.86	2312.53	HIGH	processing	2025-03-18 16:22:01.091463
499	CS20_019	2020-10-08	2020-10-13	Sea Transit	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	1499.40	2314.33	Low	delivered	2025-03-18 16:22:01.091463
500	CS20_020	2020-10-18	2020-10-23	ShipEasy	Agent	40 ft HC CW	3.0	Rotterdam	Singapore	1560.60	2314.33	Medium	completed	2025-03-18 16:22:01.091463
501	CS20_021	2020-11-05	2020-11-10	Cargo Masters	Forwarder	40 ft HC CW	5.0	Rotterdam	Singapore	2007.33	2473.81	Medium	in_transit	2025-03-18 16:22:01.091463
502	CS20_022	2020-11-15	2020-11-20	Sea Transit	Broker	40 ft HC CW	2.0	Dubai	Hamburg	2089.27	2473.81	HIGH	delivered	2025-03-18 16:22:01.091463
503	CS20_023	2020-12-08	2020-12-13	ShipEasy	Agent	40 ft HC CW	3.0	Shanghai	Los Angeles	2589.06	3008.21	HIGH	in_transit	2025-03-18 16:22:01.091463
504	CS20_024	2020-12-18	2020-12-23	Global Shipping	Direct	40 ft HC CW	4.0	Rotterdam	Singapore	2694.74	3008.21	Medium	completed	2025-03-18 16:22:01.091463
505	CS21_001	2021-01-10	2021-01-15	Global Shipping	Direct	40 ft HC CW	4.0	Dubai	Hamburg	2804.47	4071.73	HIGH	in_transit	2025-03-18 16:22:01.091463
506	CS21_002	2021-01-20	2021-01-25	Ocean Wave	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	2918.93	4071.73	Low	in_transit	2025-03-18 16:22:01.091463
507	CS21_003	2021-02-05	2021-02-10	Cargo Masters	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	2719.79	3935.67	Medium	processing	2025-03-18 16:22:01.091463
508	CS21_004	2021-02-15	2021-02-20	Sea Transit	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	2830.81	3935.67	HIGH	completed	2025-03-18 16:22:01.091463
509	CS21_005	2021-03-05	2021-03-10	ShipEasy	Broker	40 ft HC CW	2.0	Shanghai	Los Angeles	2519.29	4307.26	Low	in_transit	2025-03-18 16:22:01.091463
510	CS21_006	2021-03-15	2021-03-20	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	2622.11	4307.26	Medium	delivered	2025-03-18 16:22:01.091463
511	CS21_007	2021-04-08	2021-04-13	Ocean Wave	Direct	40 ft HC CW	3.0	Dubai	Hamburg	3038.69	4560.04	HIGH	completed	2025-03-18 16:22:01.091463
512	CS21_008	2021-04-18	2021-04-23	Cargo Masters	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	3162.71	4560.04	Low	processing	2025-03-18 16:22:01.091463
513	CS21_009	2021-05-05	2021-05-10	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	3425.88	5142.27	Medium	delivered	2025-03-18 16:22:01.091463
514	CS21_010	2021-05-15	2021-05-20	ShipEasy	Forwarder	40 ft HC CW	4.0	Dubai	Hamburg	3565.72	5142.27	HIGH	completed	2025-03-18 16:22:01.091463
515	CS21_011	2021-06-08	2021-06-13	Global Shipping	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	3709.69	6615.43	Low	in_transit	2025-03-18 16:22:01.091463
516	CS21_012	2021-06-18	2021-06-23	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	3861.11	6615.43	Medium	in_transit	2025-03-18 16:22:01.091463
517	CS21_013	2021-07-08	2021-07-13	Cargo Masters	Direct	40 ft HC CW	5.0	Dubai	Hamburg	4112.27	4735.52	HIGH	processing	2025-03-18 16:22:01.091463
518	CS21_014	2021-07-18	2021-07-23	Sea Transit	Partner	40 ft HC CW	5.0	Shanghai	Los Angeles	4280.13	4735.52	Low	completed	2025-03-18 16:22:01.091463
519	CS21_015	2021-08-08	2021-08-13	ShipEasy	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	4297.89	4915.50	Medium	in_transit	2025-03-18 16:22:01.091463
520	CS21_016	2021-08-18	2021-08-23	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	4473.31	4915.50	HIGH	delivered	2025-03-18 16:22:01.091463
521	CS21_017	2021-09-08	2021-09-13	Ocean Wave	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	4550.92	4209.95	Low	completed	2025-03-18 16:22:01.091463
522	CS21_018	2021-09-18	2021-09-23	Cargo Masters	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	4736.68	4209.95	Medium	processing	2025-03-18 16:22:01.091463
523	CS21_019	2021-10-08	2021-10-13	Sea Transit	Direct	40 ft HC CW	3.0	Dubai	Hamburg	4475.95	4720.62	HIGH	delivered	2025-03-18 16:22:01.091463
524	CS21_020	2021-10-18	2021-10-23	ShipEasy	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	4658.65	4720.62	Low	completed	2025-03-18 16:22:01.091463
525	CS21_021	2021-11-05	2021-11-10	Ocean Wave	Partner	40 ft HC CW	2.0	Rotterdam	Singapore	4509.96	4284.20	Medium	in_transit	2025-03-18 16:22:01.091463
526	CS21_022	2021-11-15	2021-11-20	Cargo Masters	Carrier	40 ft HC CW	4.0	Dubai	Hamburg	4694.04	4284.20	HIGH	delivered	2025-03-18 16:22:01.091463
527	CS21_023	2021-12-08	2021-12-13	Sea Transit	Forwarder	40 ft HC CW	1.0	Shanghai	Los Angeles	4945.77	3533.33	HIGH	in_transit	2025-03-18 16:22:01.091463
528	CS21_024	2021-12-18	2021-12-23	ShipEasy	Broker	40 ft HC CW	3.0	Rotterdam	Singapore	5147.63	3533.33	Medium	completed	2025-03-18 16:22:01.091463
529	CS22_001	2022-01-06	2022-01-11	Global Shipping	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	4910.19	3423.21	Medium	in_transit	2025-03-18 16:22:01.091463
530	CS22_002	2022-01-16	2022-01-21	Ocean Wave	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	5110.61	3423.21	HIGH	in_transit	2025-03-18 16:22:01.091463
531	CS22_003	2022-02-04	2022-02-09	Cargo Masters	Broker	40 ft HC CW	1.0	Shanghai	Los Angeles	4722.13	3284.18	Low	processing	2025-03-18 16:22:01.091463
532	CS22_004	2022-02-14	2022-02-19	Sea Transit	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	4914.87	3284.18	Medium	completed	2025-03-18 16:22:01.091463
533	CS22_005	2022-03-04	2022-03-09	ShipEasy	Direct	40 ft HC CW	4.0	Dubai	Hamburg	4345.42	3508.14	HIGH	in_transit	2025-03-18 16:22:01.091463
534	CS22_006	2022-03-14	2022-03-19	Global Shipping	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	4522.78	3508.14	Low	delivered	2025-03-18 16:22:01.091463
535	CS22_007	2022-04-07	2022-04-12	Ocean Wave	Carrier	40 ft HC CW	1.0	Rotterdam	Singapore	4093.75	3445.58	Medium	completed	2025-03-18 16:22:01.091463
536	CS22_008	2022-04-17	2022-04-22	Cargo Masters	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	4260.85	3445.58	HIGH	processing	2025-03-18 16:22:01.091463
537	CS22_009	2022-05-05	2022-05-10	Sea Transit	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	4091.89	3388.88	Low	delivered	2025-03-18 16:22:01.091463
538	CS22_010	2022-05-15	2022-05-20	ShipEasy	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	4258.91	3388.88	Medium	completed	2025-03-18 16:22:01.091463
539	CS22_011	2022-06-05	2022-06-10	Global Shipping	Direct	40 ft HC CW	5.0	Dubai	Hamburg	4131.78	3375.52	HIGH	in_transit	2025-03-18 16:22:01.091463
540	CS22_012	2022-06-15	2022-06-20	Ocean Wave	Partner	40 ft HC CW	1.0	Shanghai	Los Angeles	4300.42	3375.52	Low	in_transit	2025-03-18 16:22:01.091463
541	CS22_013	2022-07-07	2022-07-12	Cargo Masters	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	3810.04	3278.26	Medium	processing	2025-03-18 16:22:01.091463
542	CS22_014	2022-07-17	2022-07-22	Sea Transit	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	3965.56	3278.26	HIGH	completed	2025-03-18 16:22:01.091463
543	CS22_015	2022-08-05	2022-08-10	ShipEasy	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	3091.21	3168.62	Low	in_transit	2025-03-18 16:22:01.091463
544	CS22_016	2022-08-15	2022-08-20	Global Shipping	Agent	40 ft HC CW	2.0	Rotterdam	Singapore	3217.39	3168.62	Medium	delivered	2025-03-18 16:22:01.091463
545	CS22_017	2022-09-05	2022-09-10	Ocean Wave	Direct	40 ft HC CW	5.0	Dubai	Hamburg	1884.54	2656.75	HIGH	completed	2025-03-18 16:22:01.091463
546	CS22_018	2022-09-15	2022-09-20	Cargo Masters	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	1961.46	2656.75	Low	processing	2025-03-18 16:22:01.091463
547	CS22_019	2022-10-08	2022-10-13	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	1663.75	2640.37	Medium	delivered	2025-03-18 16:22:01.091463
548	CS22_020	2022-11-18	2022-10-23	ShipEasy	Forwarder	40 ft HC CW	1.0	Dubai	Hamburg	1731.65	2640.37	HIGH	completed	2025-03-18 16:22:01.091463
549	CS22_021	2022-11-05	2022-11-10	Global Shipping	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1205.30	2635.78	Medium	in_transit	2025-03-18 16:22:01.091463
550	CS22_022	2022-11-15	2022-11-20	Ocean Wave	Direct	40 ft HC CW	2.0	Dubai	Hamburg	1254.50	2635.78	HIGH	delivered	2025-03-18 16:22:01.091463
551	CS22_023	2022-12-08	2022-12-13	Cargo Masters	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	1085.35	2619.72	HIGH	in_transit	2025-03-18 16:22:01.091463
552	CS22_024	2022-12-18	2022-12-23	Sea Transit	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	1129.65	2619.72	Medium	completed	2025-03-18 16:22:01.091463
553	CS23_001	2023-01-06	2023-01-11	Global Shipping	Broker	40 ft HC CW	3.0	Shanghai	Los Angeles	1009.20	2627.46	Low	in_transit	2025-03-18 16:22:01.091463
554	CS23_002	2023-01-16	2023-01-21	Ocean Wave	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1050.40	2627.46	Medium	in_transit	2025-03-18 16:22:01.091463
555	CS23_003	2023-02-05	2023-02-10	Cargo Masters	Direct	40 ft HC CW	2.0	Dubai	Hamburg	927.75	2613.53	HIGH	processing	2025-03-18 16:22:01.091463
556	CS23_004	2023-02-15	2023-02-20	Sea Transit	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	965.61	2613.53	Low	completed	2025-03-18 16:22:01.091463
557	CS23_005	2023-03-05	2023-03-10	ShipEasy	Carrier	40 ft HC CW	3.0	Rotterdam	Singapore	905.30	2590.85	Medium	in_transit	2025-03-18 16:22:01.091463
558	CS23_006	2023-03-15	2023-03-20	Global Shipping	Forwarder	40 ft HC CW	5.0	Dubai	Hamburg	942.26	2590.85	HIGH	delivered	2025-03-18 16:22:01.091463
559	CS23_007	2023-04-06	2023-04-11	Ocean Wave	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	979.74	2596.26	Low	completed	2025-03-18 16:22:01.091463
560	CS23_008	2023-04-16	2023-04-21	Cargo Masters	Agent	40 ft HC CW	6.0	Rotterdam	Singapore	1019.72	2596.26	Medium	processing	2025-03-18 16:22:01.091463
561	CS23_009	2023-05-06	2023-05-11	Sea Transit	Direct	40 ft HC CW	5.0	Dubai	Hamburg	963.79	2586.56	HIGH	delivered	2025-03-18 16:22:01.091463
562	CS23_010	2023-05-16	2023-05-21	ShipEasy	Partner	40 ft HC CW	3.0	Shanghai	Los Angeles	1003.13	2586.56	Low	completed	2025-03-18 16:22:01.091463
563	CS23_011	2023-06-06	2023-06-11	Global Shipping	Carrier	40 ft HC CW	4.0	Rotterdam	Singapore	934.53	2583.17	Medium	in_transit	2025-03-18 16:22:01.091463
564	CS23_012	2023-06-16	2023-06-21	Ocean Wave	Forwarder	40 ft HC CW	2.0	Dubai	Hamburg	972.67	2583.17	HIGH	in_transit	2025-03-18 16:22:01.091463
565	CS23_013	2023-07-06	2023-07-11	Cargo Masters	Broker	40 ft HC CW	4.0	Shanghai	Los Angeles	1008.62	2568.65	Low	processing	2025-03-18 16:22:01.091463
566	CS23_014	2023-07-16	2023-07-21	Sea Transit	Agent	40 ft HC CW	5.0	Rotterdam	Singapore	1049.78	2568.65	Medium	completed	2025-03-18 16:22:01.091463
567	CS23_015	2023-08-06	2023-08-11	ShipEasy	Direct	40 ft HC CW	3.0	Dubai	Hamburg	993.52	2565.52	HIGH	in_transit	2025-03-18 16:22:01.091463
568	CS23_016	2023-08-16	2023-08-21	Global Shipping	Partner	40 ft HC CW	4.0	Shanghai	Los Angeles	1034.08	2565.52	Low	delivered	2025-03-18 16:22:01.091463
569	CS23_017	2023-09-06	2023-09-11	Ocean Wave	Carrier	40 ft HC CW	5.0	Rotterdam	Singapore	869.11	2548.18	Medium	completed	2025-03-18 16:22:01.091463
570	CS23_018	2023-09-16	2023-09-21	Cargo Masters	Forwarder	40 ft HC CW	3.0	Dubai	Hamburg	904.59	2548.18	HIGH	processing	2025-03-18 16:22:01.091463
571	CS23_019	2023-10-07	2023-10-12	Sea Transit	Broker	40 ft HC CW	5.0	Shanghai	Los Angeles	992.35	2550.05	Low	delivered	2025-03-18 16:22:01.091463
572	CS23_020	2023-10-17	2023-10-22	ShipEasy	Agent	40 ft HC CW	4.0	Rotterdam	Singapore	1032.85	2550.05	Medium	completed	2025-03-18 16:22:01.091463
573	CS23_021	2023-11-05	2023-11-10	ShipEasy	Forwarder	40 ft HC CW	4.0	Rotterdam	Singapore	973.35	2552.08	Medium	in_transit	2025-03-18 16:22:01.091463
574	CS23_022	2023-11-15	2023-11-20	Global Shipping	Broker	40 ft HC CW	3.0	Dubai	Hamburg	1013.07	2552.08	HIGH	delivered	2025-03-18 16:22:01.091463
575	CS23_023	2023-12-08	2023-12-13	Ocean Wave	Agent	40 ft HC CW	3.0	Shanghai	Los Angeles	1724.41	2560.14	HIGH	in_transit	2025-03-18 16:22:01.091463
576	CS23_024	2023-12-18	2023-12-23	Cargo Masters	Direct	40 ft HC CW	4.0	Rotterdam	Singapore	1794.79	2560.14	Medium	completed	2025-03-18 16:22:01.091463
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

SELECT pg_catalog.setval('public.shipping_container_prices_id_seq', 264, true);


--
-- Name: shipping_container_raw_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shipping_container_raw_id_seq', 576, true);


--
-- Name: total_cost_comparison_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.total_cost_comparison_id_seq', 24, true);


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


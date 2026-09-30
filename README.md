# Billboard Hot 100 SQL Analysis (1966–2017)

A pure-SQL data analysis project exploring 50+ years of Billboard Hot 100 chart
history, enriched with Spotify audio features, to answer: **how has hit music
actually changed over the decades?**

Built entirely in PostgreSQL 18 — no pandas, no notebooks, no BI tool. Every
insight in this project comes from a `.sql` file, and every result is
independently verifiable against the live [Billboard Hot 100
archive](https://www.billboard.com/charts/hot-100/).

---

## Table of Contents
- [Project Overview](#project-overview)
- [Data Sources](#data-sources)
- [Database Schema](#database-schema)
- [Data Cleaning & ETL](#data-cleaning--etl)
- [Analysis Questions](#analysis-questions)
- [SQL Skills Demonstrated](#sql-skills-demonstrated)
- [Key Findings](#key-findings)
- [Repo Structure](#repo-structure)
- [How to Run This Project](#how-to-run-this-project)
- [Tools Used](#tools-used)

---

## Project Overview

This project takes two raw, messy CSV exports — one of weekly Billboard Hot
100 chart data, one of Spotify audio features for those same songs — and
turns them into a clean, normalized, indexed relational database. From there,
it answers 10 analytical questions using progressively more advanced SQL,
covering everything from basic aggregation to window functions and CTEs.

The goal was to demonstrate real, end-to-end SQL fluency: not just writing
`SELECT` statements against clean data, but handling the kind of messiness
that shows up in real datasets — encoding errors, malformed CSV quoting,
type mismatches, and incomplete referential data — the way you'd actually
have to on the job.

## Data Sources

| File | Rows | Description |
|---|---|---|
| `Hot_Stuff.csv` | 327,895 | Every song's weekly Billboard Hot 100 chart position, Jan 1966 – Sep 2017 |
| `Hot_100_Audio_Features.csv` | 29,503 | Spotify audio features (danceability, energy, tempo, key, mode, etc.) for unique charted songs |

Both are widely used, publicly available datasets. Every result in this
project can be spot-checked directly against Billboard's own chart archive.

## Database Schema

Two tables, joined on `song_id`, modeling a classic fact/dimension
relationship:

**`songs`** (dimension — one row per unique song)
- `song_id` (PK), `performer`, `song`, `spotify_genre`
- Audio features: `danceability`, `energy`, `key`, `loudness`, `mode`,
  `speechiness`, `acousticness`, `instrumentalness`, `liveness`, `valence`,
  `tempo`, `time_signature`, `popularity`, `duration_ms`, `is_explicit`

**`chart_entries`** (fact — one row per song, per chart week)
- `song_id` (FK → songs), `week_id`, `week_position`, `peak_position`,
  `previous_week_position`, `weeks_on_chart`, `instance`, `url`

```
songs (1) ────< (many) chart_entries
```

This structure is what makes the project a genuine "pure SQL" showcase — a
single flat file would only support `GROUP BY`/`WHERE`; this schema supports
real `JOIN`s, referential integrity, and multi-table analysis.

## Data Cleaning & ETL

The raw CSVs were not analysis-ready. Problems encountered and resolved:

- **Character encoding** — the audio features file contained byte sequences
  undefined in Windows-1252, causing `COPY` to fail outright. Fixed by
  scanning and replacing the specific undefined bytes before import.
- **Malformed CSV quoting** — song titles containing apostrophes (e.g.
  *"Baby, I Need Your Lovin'"*) broke Postgres's default `COPY` escape
  handling, throwing "unterminated CSV quoted field" errors. Fixed by
  explicitly setting `QUOTE '"'` with the escape character defaulted to
  match, instead of a stray single-quote escape.
- **Type coercion** — several numeric columns (duration, key, mode,
  popularity) were stored as floats (e.g. `"166106.0"`) in the source data.
  Direct `::INTEGER` casts failed; resolved by casting through `::NUMERIC`
  first.
- **Referential gaps** — roughly 0.4% of charted songs had no matching
  Spotify audio-features record (older or unmatched titles). Rather than
  dropping valid chart history to satisfy the foreign key constraint,
  minimal stub rows were inserted into `songs` for these IDs.
- **Duplicate keys** — the audio-features source contained duplicate
  `song_id`s; resolved with `SELECT DISTINCT ON` during the load.
- **Staged loading** — both files were loaded into `VARCHAR`-only staging
  tables first, then cast and inserted into properly typed final tables.
  This kept the raw import resilient to unexpected data while still
  producing a strictly typed final schema (`INTEGER`, `NUMERIC`, `BOOLEAN`,
  `DATE`).

## Analysis Questions

All 10 questions and their SQL live in [`analysis.sql`](./analysis.sql):

1. Which 10 artists have the most Hot 100 entries of all time?
2. Which artists have had the most #1 hits?
3. How have average danceability, energy, and tempo changed by decade?
4. Do higher-energy or higher-danceability songs tend to peak higher on the chart?
5. What share of #1 hits are in a major vs minor key, and has that shifted over time?
6. What is the longest consecutive streak at #1 for any single song?
7. Which songs had the single biggest week-over-week jump in chart position?
8. Which songs ranked highest within their debut chart year (top 5 per year)?
9. Which "comeback songs" dropped off the chart and later re-entered?
10. Which artists charted across the most distinct decades, and what share of their output was explicit?

## SQL Skills Demonstrated

| Category | Where |
|---|---|
| Aggregation (`GROUP BY`, `COUNT`, `AVG`, `HAVING`) | Q1, Q2, Q3 |
| `JOIN`s (inner, left) | Q3, Q4, Q5, Q10 |
| Conditional aggregation (`FILTER`, `CASE`) | Q5, Q10 |
| Statistical aggregates (`CORR`) | Q4 |
| Window functions (`LAG`, `RANK`, `ROW_NUMBER`) | Q6, Q7, Q8, Q9 |
| Gaps-and-islands / streak detection | Q6, Q9 |
| CTEs (`WITH`) | Q6–Q10 |
| Subqueries | Q10 |
| Date/time functions (`EXTRACT`, date arithmetic) | Q3, Q5, Q6, Q8, Q9, Q10 |
| Schema design, staging tables, type casting | `billboard_setup.sql` |
| Referential integrity handling (FK constraints, stub rows) | `billboard_setup.sql` |

## Key Findings

*(Fill this section in with your actual results once you've run the
queries — this is the part that turns a script into a story for anyone
reading your repo. A few sentences per finding is plenty, e.g.:)*

- **Most charted artist:** ...
- **Most #1 hits:** ...
- **Tempo/energy trend:** has hit music gotten more energetic/danceable
  over 50 years, or has it stayed flat?
- **Longest #1 streak:** which song, and for how long?
- **Biggest chart jump:** which song made the largest single-week leap?
- **Career longevity:** which artists charted across the most decades?

## Repo Structure

```
billboard-hot-100-sql/
├── raw/
│   ├── Hot_Stuff.csv
│   └── Hot_100_Audio_Features.csv
├── billboard_setup.sql     -- schema creation, cleaning, loading
├── analysis.sql            -- all 10 analysis queries
└── README.md
```

## How to Run This Project

1. Create a PostgreSQL database: `CREATE DATABASE billboard;`
2. Run `billboard_setup.sql` in full (edit the two CSV file paths near the
   top to match your local file locations first).
3. Verify the row counts printed at the end match the expected totals.
4. Run the queries in `analysis.sql`, one at a time or all at once.

## Tools Used

- **PostgreSQL 18** — database and all analysis
- **pgAdmin** — schema design, data import, query execution
- **VS Code** — script editing and version control

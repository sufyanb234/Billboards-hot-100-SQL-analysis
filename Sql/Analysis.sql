

-- Q1: Which 10 artists have the most Hot 100 entries of all time?
SELECT
    performer,
    COUNT(*) AS total_entries
FROM chart_entries
GROUP BY performer
ORDER BY total_entries DESC
LIMIT 10;


-- Q2: Which artists have had the most #1 hits (distinct songs)?
SELECT
    performer,
    COUNT(DISTINCT song) AS number_one_hits
FROM chart_entries
WHERE peak_position = 1
GROUP BY performer
HAVING COUNT(DISTINCT song) > 1
ORDER BY number_one_hits DESC
LIMIT 10;


-- Q3: How have avg danceability, energy, and tempo changed by decade?
SELECT
    (EXTRACT(DECADE FROM c.week_id) * 10) AS decade,
    ROUND(AVG(s.danceability), 3) AS avg_danceability,
    ROUND(AVG(s.energy), 3)       AS avg_energy,
    ROUND(AVG(s.tempo), 1)        AS avg_tempo
FROM chart_entries c
JOIN songs s ON c.song_id = s.song_id
WHERE s.danceability IS NOT NULL
GROUP BY decade
ORDER BY decade;


-- Q4: Do higher-energy/danceability songs tend to peak higher?
SELECT
    ROUND(CORR(s.danceability, c.peak_position)::NUMERIC, 3) AS corr_danceability_vs_peak,
    ROUND(CORR(s.energy, c.peak_position)::NUMERIC, 3)       AS corr_energy_vs_peak
FROM chart_entries c
JOIN songs s ON c.song_id = s.song_id
WHERE s.danceability IS NOT NULL;


-- Q5: Major vs minor key share of #1 hits, by decade.
SELECT
    (EXTRACT(DECADE FROM c.week_id) * 10) AS decade,
    COUNT(*) FILTER (WHERE s.mode = 1) AS major_key_hits,
    COUNT(*) FILTER (WHERE s.mode = 0) AS minor_key_hits,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.mode = 1) / NULLIF(COUNT(*), 0), 1) AS pct_major
FROM chart_entries c
JOIN songs s ON c.song_id = s.song_id
WHERE c.peak_position = 1 AND s.mode IS NOT NULL
GROUP BY decade
ORDER BY decade;


-- Q6: Longest consecutive streak at #1 (gaps-and-islands).
WITH number_ones AS (
    SELECT
        song_id,
        week_id,
        week_id - (ROW_NUMBER() OVER (PARTITION BY song_id ORDER BY week_id))::INT * INTERVAL '7 day' AS grp
    FROM chart_entries
    WHERE week_position = 1
),
streaks AS (
    SELECT
        song_id, grp,
        COUNT(*)      AS weeks_at_number_one,
        MIN(week_id)  AS streak_start,
        MAX(week_id)  AS streak_end
    FROM number_ones
    GROUP BY song_id, grp
)
SELECT
    ce.song, ce.performer,
    st.weeks_at_number_one, st.streak_start, st.streak_end
FROM streaks st
JOIN chart_entries ce
    ON ce.song_id = st.song_id AND ce.week_id = st.streak_start
ORDER BY st.weeks_at_number_one DESC
LIMIT 10;


-- Q7: Biggest week-over-week jump in chart position.
WITH position_changes AS (
    SELECT
        song, performer, song_id, week_id, week_position,
        LAG(week_position) OVER (PARTITION BY song_id ORDER BY week_id) AS prev_position
    FROM chart_entries
)
SELECT
    song, performer, week_id, prev_position, week_position,
    (prev_position - week_position) AS positions_gained
FROM position_changes
WHERE prev_position IS NOT NULL
ORDER BY positions_gained DESC
LIMIT 10;


-- Q8: Rank each song's peak position within its first chart year (top 5/yr).
WITH first_chart_year AS (
    SELECT song_id, MIN(EXTRACT(YEAR FROM week_id)) AS chart_year
    FROM chart_entries
    GROUP BY song_id
),
song_best AS (
    SELECT
        c.song_id, c.song, c.performer,
        MIN(c.peak_position) AS peak_position,
        f.chart_year
    FROM chart_entries c
    JOIN first_chart_year f ON c.song_id = f.song_id
    GROUP BY c.song_id, c.song, c.performer, f.chart_year
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY chart_year ORDER BY peak_position) AS year_rank
    FROM song_best
)
SELECT chart_year, year_rank, song, performer, peak_position
FROM ranked
WHERE year_rank <= 5
ORDER BY chart_year, year_rank;


-- Q9: "Comeback songs" — dropped off and re-entered later.
WITH ordered AS (
    SELECT
        song_id, song, performer, week_id,
        LAG(week_id) OVER (PARTITION BY song_id ORDER BY week_id) AS prev_week
    FROM chart_entries
)
SELECT DISTINCT song, performer
FROM ordered
WHERE week_id - prev_week > 7
ORDER BY song;


-- Q10: Artists charted in the most distinct decades, and % explicit entries.
WITH artist_decades AS (
    SELECT
        performer,
        COUNT(DISTINCT EXTRACT(DECADE FROM week_id)) AS distinct_decades
    FROM chart_entries
    GROUP BY performer
),
top_longevity AS (
    SELECT performer, distinct_decades
    FROM artist_decades
    ORDER BY distinct_decades DESC
    LIMIT 10
)
SELECT
    t.performer, t.distinct_decades,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_explicit) / NULLIF(COUNT(*), 0), 1) AS pct_explicit_entries
FROM top_longevity t
JOIN chart_entries c ON c.performer = t.performer
LEFT JOIN songs s ON c.song_id = s.song_id
GROUP BY t.performer, t.distinct_decades
ORDER BY t.distinct_decades DESC;
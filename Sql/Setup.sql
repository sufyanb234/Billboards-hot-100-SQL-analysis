
--1. Staging tables (raw import, everything as text)
CREATE TABLE staging_chart_entries (
    idx                     VARCHAR(50),
    url                     VARCHAR(500),
    week_id                 VARCHAR(50),
    week_position           VARCHAR(50),
    song                    VARCHAR(500),
    performer               VARCHAR(500),
    song_id                 VARCHAR(500),
    instance                VARCHAR(50),
    previous_week_position  VARCHAR(50),
    peak_position           VARCHAR(50),
    weeks_on_chart          VARCHAR(50)
);

CREATE TABLE staging_songs (
    idx                         VARCHAR(50),
    song_id                     VARCHAR(500),
    performer                   VARCHAR(500),
    song                        VARCHAR(500),
    spotify_genre               VARCHAR(2000),
    spotify_track_id            VARCHAR(100),
    spotify_track_preview_url   VARCHAR(1000),
    spotify_track_duration_ms   VARCHAR(50),
    spotify_track_explicit      VARCHAR(50),
    spotify_track_album         TEXT,
    danceability                VARCHAR(50),
    energy                      VARCHAR(50),
    key                         VARCHAR(50),
    loudness                    VARCHAR(50),
    mode                        VARCHAR(50),
    speechiness                 VARCHAR(50),
    acousticness                VARCHAR(50),
    instrumentalness            VARCHAR(50),
    liveness                    VARCHAR(50),
    valence                     VARCHAR(50),
    tempo                       VARCHAR(50),
    time_signature              VARCHAR(50),
    spotify_track_popularity    VARCHAR(50)
);

-- 2. Load the CSVs

COPY staging_chart_entries
FROM 'C:\Users\Sufya\Desktop\Personal projects\SQL project\Billboards hot 100\raw\Hot_Stuff_final.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"');

COPY staging_songs
FROM 'C:\Users\Sufya\Desktop\Personal projects\SQL project\Billboards hot 100\raw\Hot_100_Audio_Features_final.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"');

-- Sanity check — expect 327895 and 29503
SELECT COUNT(*) FROM staging_chart_entries;
SELECT COUNT(*) FROM staging_songs;

--3. Final, properly-typed tables
CREATE TABLE songs (
    song_id                     VARCHAR(500) PRIMARY KEY,
    performer                   VARCHAR(500),
    song                        VARCHAR(500),
    spotify_genre               VARCHAR(2000),
    spotify_track_id            VARCHAR(100),
    spotify_track_preview_url   VARCHAR(1000),
    spotify_track_album         TEXT,
    duration_ms                 INTEGER,
    is_explicit                 BOOLEAN,
    danceability                NUMERIC(5,3),
    energy                      NUMERIC(5,3),
    key                         INTEGER,
    loudness                    NUMERIC(6,3),
    mode                        INTEGER,
    speechiness                 NUMERIC(5,3),
    acousticness                NUMERIC(5,3),
    instrumentalness            NUMERIC(6,5),
    liveness                    NUMERIC(5,3),
    valence                     NUMERIC(5,3),
    tempo                       NUMERIC(6,3),
    time_signature              INTEGER,
    popularity                  INTEGER
);

CREATE TABLE chart_entries (
    url                       VARCHAR(500),
    week_id                   DATE,
    week_position             INTEGER,
    song                      VARCHAR(500),
    performer                 VARCHAR(500),
    song_id                   VARCHAR(500) REFERENCES songs(song_id),
    instance                  INTEGER,
    previous_week_position    INTEGER,
    peak_position             INTEGER,
    weeks_on_chart            INTEGER
);

--4. Populate final tables from staging, with type casts
INSERT INTO songs
SELECT DISTINCT ON (song_id)
    song_id,
    performer,
    song,
    spotify_genre,
    spotify_track_id,
    spotify_track_preview_url,
    spotify_track_album,
    NULLIF(spotify_track_duration_ms, '')::NUMERIC::INTEGER,
    (spotify_track_explicit = 'True'),
    NULLIF(danceability, '')::NUMERIC,
    NULLIF(energy, '')::NUMERIC,
    NULLIF(key, '')::NUMERIC::INTEGER,
    NULLIF(loudness, '')::NUMERIC,
    NULLIF(mode, '')::NUMERIC::INTEGER,
    NULLIF(speechiness, '')::NUMERIC,
    NULLIF(acousticness, '')::NUMERIC,
    NULLIF(instrumentalness, '')::NUMERIC,
    NULLIF(liveness, '')::NUMERIC,
    NULLIF(valence, '')::NUMERIC,
    NULLIF(tempo, '')::NUMERIC,
    NULLIF(time_signature, '')::NUMERIC::INTEGER,
    NULLIF(spotify_track_popularity, '')::NUMERIC::INTEGER
FROM staging_songs
ORDER BY song_id, spotify_track_id NULLS LAST;

-- Some songs that charted have no matching Spotify audio-features record
-- (common for older/less common tracks). Add minimal stub rows for these
-- so we don't lose valid chart history to the foreign key constraint.
INSERT INTO songs (song_id, performer, song)
SELECT DISTINCT sc.song_id, sc.performer, sc.song
FROM staging_chart_entries sc
LEFT JOIN songs s ON sc.song_id = s.song_id
WHERE s.song_id IS NULL;

INSERT INTO chart_entries
SELECT
    url,
    TO_DATE(week_id, 'MM/DD/YYYY'),
    NULLIF(week_position, '')::NUMERIC::INTEGER,
    song,
    performer,
    song_id,
    NULLIF(instance, '')::NUMERIC::INTEGER,
    NULLIF(previous_week_position, '')::NUMERIC::INTEGER,
    NULLIF(peak_position, '')::NUMERIC::INTEGER,
    NULLIF(weeks_on_chart, '')::NUMERIC::INTEGER
FROM staging_chart_entries;

--5. Indexes
CREATE INDEX idx_chart_song_id ON chart_entries(song_id);
CREATE INDEX idx_chart_week_id ON chart_entries(week_id);

--6. Final verification
SELECT COUNT(*) FROM songs;          -- expect ~29,386 base
SELECT COUNT(*) FROM chart_entries;  -- expect 327,895

SELECT COUNT(*) FROM songs WHERE danceability IS NULL;




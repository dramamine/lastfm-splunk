require "sqlite3"


class DBFunctions

  def initialize
    @db = SQLite3::Database.new "measuredincm.db"
  end

  def create_all_tables
      # Create a database
    @db.execute <<-SQL
      CREATE TABLE track_history (
        time_utc bigint,
        artist_mbid varchar(36),
        artist_name varchar(50),
        track_mbid varchar(36),
        track_name varchar(50),
        album_mbid varchar(36),
        album_name varchar(50)
      );
    SQL

    @db.execute <<-SQL
    CREATE TABLE artist (
        id integer primary key,
        artist_mbid varchar(36),
        artist_name varchar(100),
        listeners integer,
        playcount integer,
        placeformed varchar(100),
        yearformed integer,
        yearfrom integer,
        yearto integer,
        image varchar(100),
        created_date timestamp DEFAULT CURRENT_TIMESTAMP,
        is_metal boolean DEFAULT false
        );
    SQL


    @db.execute <<-SQL
    CREATE TABLE artist_tags (
        id integer primary key,
        artist_mbid varchar(36),
        artist_name varchar(100),
        tag varchar(100),
        score integer,
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL

    @db.execute <<-SQL
    CREATE TABLE similar_artists (
        id integer primary key,
        artist_mbid varchar(36),
        artist_name varchar(100),
        similar_artist_name varchar(100),
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL

    @db.execute <<-SQL
    CREATE TABLE xref_similar_tags (
        xref_similar_tags_id integer primary key,
        tag_a varchar(100),
        tag_b varchar(100),
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL

    # source:
    # 0: has 'metal' in it
    # 1: is similar to a 'metal' tag
    # 2: a 'metal' tag is similar to it
    # 3: manual
    @db.execute <<-SQL
    CREATE TABLE metal_tags (
        id integer primary key,
        tag varchar(100),
        source integer,
        active boolean default true,
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL

    @db.execute <<-SQL
    CREATE TABLE track_details (
        id integer primary key,
        track_mbid varchar(36),
        track_name varchar(100),
        artist_name varchar(100),
        duration integer,
        listeners integer,
        playcount integer,
        my_playcount integer,
        my_listen_duration integer,
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL


    @db.execute <<-SQL
    CREATE TABLE artist_top_tracks (
        id integer primary key,
        artist_mbid varchar(36),
        artist_name varchar(100),
        rank integer,
        playcount integer,
        created_date timestamp DEFAULT CURRENT_TIMESTAMP
        );
    SQL

  end

  # works
  def dedupe_track_history

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS track_history_deduped  (
            time_utc bigint,
            artist_mbid varchar(36),
            artist_name varchar(50),
            track_mbid varchar(36),
            track_name varchar(50),
            album_mbid varchar(36),
            album_name varchar(50)
          );
        SQL

        @db.execute <<-SQL
        INSERT INTO track_history_deduped
        (time_utc,artist_mbid,artist_name,track_mbid,track_name,album_mbid,album_name)
            SELECT DISTINCT * FROM track_history ;
        SQL

        @db.execute <<-SQL
        DROP TABLE track_history;
        SQL

        @db.execute <<-SQL
        ALTER TABLE track_history_deduped
        RENAME TO track_history;
        SQL
  end

  def setup_metal_tags
    @db.execute <<-SQL
INSERT INTO metal_tags (tag, source)
SELECT DISTINCT tag, 0 FROM artist_tags
 WHERE tag like '%metal%';
    SQL

    @db.execute <<-SQL
INSERT INTO metal_tags (tag, source)
SELECT DISTINCT a.tag, 1 FROM artist_tags a
  JOIN artist_tags b ON ( a.artist_mbid = b.artist_mbid
    OR a.artist_name = b.artist_name )
  JOIN metal_tags m ON b.tag = m.tag
WHERE a.tag != b.tag
AND a.tag != m.tag
AND m.source = 0;
    SQL

    @db.execute <<-SQL
INSERT INTO metal_tags (tag, source, active)
SELECT DISTINCT a.tag, 2, false FROM artist_tags a
  JOIN artist_tags b ON ( a.artist_mbid = b.artist_mbid
    OR a.artist_name = b.artist_name )
  JOIN metal_tags m ON b.tag = m.tag
  LEFT JOIN metal_tags d ON (a.tag = d.tag)
WHERE a.tag != b.tag
AND a.tag != m.tag
AND d.tag IS NULL;
    SQL
end

#!/bin/bash
/usr/bin/sqlite3 ../db/measuredincm.db <<!
select
  datetime(h.time_utc, 'unixepoch') ||
  ' time_utc=' || h.time_utc ||
  ' artist_mbid=' || IFNULL( h.artist_mbid, '') ||
  ' artist_name="' || IFNULL( h.artist_name, '') ||
  '" track_mbid=' || IFNULL( h.track_mbid, '') ||
  ' track_name="' || IFNULL( h.track_name, '') ||
  '" album_mbid=' || IFNULL( h.album_mbid, '') ||
  ' album_name="' || IFNULL( h.album_name, '') ||
  '" duration=' || IFNULL( t.duration, '')
FROM track_history h
LEFT JOIN track_details t USING(track_mbid)
WHERE time_utc IS NOT NULL
ORDER BY time_utc DESC
;
!

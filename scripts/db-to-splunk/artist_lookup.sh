#!/bin/bash
/usr/bin/sqlite3 ../db/measuredincm.db <<!
.headers on
.mode csv
select * from artist;
!
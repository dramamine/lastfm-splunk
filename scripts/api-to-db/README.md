README

1/11/2014:

Splunk:

when importing data, set this in props.conf:
MAX_DAYS_AGO=5000

-- count by month
sourcetype=lastfm | timechart span=month count

-- metalness by month
sourcetype=lastfm | bucket _time span=month |  eventstats count as "totalcount" by _time | eventstats count as "metalcount" by is_metal, _time | eval metalness=100*metalcount/totalcount | search is_metal=true | timechart values(metalness)

-- top songs each month?
-- this graph is boss
-- http://imgur.com/f2dIbjN
sourcetype=lastfm | bucket _time span=month | top limit=1 track_name, artist_name by _time | table track_name, artist_name, _time

-- deleting stuff from the db
sqlite3 measuredincm.db

SELECT * FROM track_history ORDER BY time_utc DESC LIMIT 100;

DELETE FROM track_history WHERE time_utc >= 1372469860;

splunk query:
SELECT th.time_utc, th.artist_name, th.album_name,
GROUP_CONCAT(at.tag),
td.duration, td.listeners, td.track_name,
a.is_metal
FROM track_history th
LEFT JOIN artist a ON (th.artist_mbid = a.artist_mbid)
LEFT JOIN artist_tags at ON (th.artist_mbid = at.artist_mbid)
LEFT JOIN track_details td ON (th.track_mbid = td.track_mbid)
WHERE th.time_utc > 1372469860
GROUP BY
th.time_utc, th.artist_name, th.album_name,
td.duration, td.listeners, td.track_name


This is some shit I tried when working with the proxy server; I got fucking annoyed with it so I'm giving up for now.
{
	ssh -D 12345 root@162.243.141.19

	-- trying this
	162.243.141.19
	--proxy-server="socks5://myproxy:12345"
	--host-resolver-rules="MAP * 0.0.0.0 , EXCLUDE myproxy"

	http://www.chromium.org/developers/design-documents/network-stack/socks-proxy
}




1/4/2014: oh boy, this is dusty as fuck!
Currently I just wanna plug this data into Splunk and see what I can come up with in terms of awesome dashboards. As a stretch goal, it would be cool to API that and create an interactive website with nice graphs.

Splunk on DigitalOcean diary

ssh into DigitalOcean droplet "dramamine" (see .aliases for credentials)
downloaded .tgz for Ubuntu 32-bit using wget
un-tarred it to /opt, so the binary's in /opt/splunk/bin
"./splunk start" to start the instance
vi /opt/splunk/etc/system/local/server.conf

installed locally
export SPLUNK_HOME="/opt/splunk"
in /etc/: export SPLUNK_HOME="/opt/splunk"
sudo /opt/splunk/bin/splunk start
http://sleek:8000/
admin/admin


USAGE NOTES

-- make sure everything's working
rvm use ruby-1.9.3-p385
gem install sqlite3

# write track listens to a log file for Splunk
ruby splunk_writer.rb

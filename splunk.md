## USING SPLUNK
To install Splunk, grab the latest package from the Splunk website. Move it to /opt and un-tar it.

sudo /opt/splunk/bin/splunk restart
sudo /opt/splunk/bin/splunk start
sudo /opt/splunk/bin/splunk stop

Make sure OpenJDK Java 7 Runtime is installed. (for dbconnect)

Settings -> Server Settings -> change max free space from 5000mb to 500mb


# in case you wanted this to be more local...
sudo cp /home/marten/Dropbox/lastfm-stats-js/db/measuredincm.db /opt/splunk/var/dbx

# change MAX_DAYS_AGO to 9999
sudo vi etc/system/default/props.conf

# pop this in here so we can be more git-ty
cd ~/Dropbox/lastfm-stats-js/splunk
mkdir views
ln -s /opt/splunk/etc/apps/lastfm/local/data/ui/views/* views/

# set this in etc/apps/lastfm/local/props.conf
MAX_DAYS_AGO = 9999


| dbquery lastfm "select * from track_history where time_utc IS NOT NULL" limit=100
| convert auto(time_utc) AS _time
| lookup artist artist_mbid


| dbquery lastfm "select * from track_history where time_utc IS NOT NULL"
| convert auto(time_utc) AS _time
| lookup artist artist_mbid
| search is_metal=*
| timechart count by is_metal span=M

| dbquery lastfm "select * from track_history where time_utc IS NOT NULL"
| convert auto(time_utc) AS _time
| bucket _time span=mon
| stats count by artist_mbid, _time
| lookup artist artist_mbid
| search is_metal=*
| timechart count by is_metal span=mon
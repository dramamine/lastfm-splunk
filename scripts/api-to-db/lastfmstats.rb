=begin
/**
 * LastFmStats class
 *
 * use with
 * require_relative 'lastfmstats'
 * o.LastfmStats.new
 *
 *
 */
=end

require 'lastfm'
require 'sqlite3'

require '../../config/config'

# token = lastfm.auth.get_token

# open 'http://www.last.fm/api/auth/?api_key=xxxxxxxxxxx&token=xxxxxxxx' and grant the application

#lastfm.session = lastfm.auth.get_session(:token => token)['key']

#lastfm.track.love(:artist => 'Hujiko Pro', :track => 'acid acid 7riddim')
#lastfm.track.scrobble(:artist => 'Hujiko Pro', :track => 'acid acid 7riddim')
#lastfm.track.update_now_playing(:artist => 'Hujiko Pro', :track => 'acid acid 7riddim')

# deprecated style
#lastfm.track.love('Hujiko Pro', 'acid acid 7riddim')



class LastfmStats

	# get our DB object and our LastFM API setup
	def initialize
		puts "loading LastfmStats class"
		@lastfm = Lastfm.new(API_KEY, "")
		@username = "measuredincm"
		@db = SQLite3::Database.new("../../db/" + @username + ".db")
	end

	def init_performances
		update_performances(0)
	end

	# gets the most recent time, then
	def update_performances(utc_offset = nil, also_get_metadata = true, page_size = 200, page_limit = 0)
		if utc_offset.nil?
			utc_offset = @db.get_first_value("SELECT MAX(time_utc) FROM track_history")
		end

		puts "Grabbing all the performances after " + utc_offset.to_s + ": " +  Time.at(utc_offset).getlocal.to_s

		page = 1
		while page != page_limit
			puts "Processing page " + page.to_s
			tracks = @lastfm.user.get_recent_tracks(
				:user => @username,
				:from => utc_offset,
				:limit => page_size,
				:page => page
				)

			break if tracks.nil?
			tracks.each do |t|

				# for the most recent result
				t["date"] = {:uts => Time.now.utc, :content => "now playing"} unless t.has_key?("date")
				#, t.artist.mbid, t.artist.content, t.mbid, t.name, t.album.mbid, t.album.content ]
				begin
					puts "running queries..."
					@db.execute( "INSERT INTO track_history (time_utc, artist_mbid, artist_name, track_mbid, track_name, album_mbid, album_name) VALUES (?,?,?,?,?,?,?)", t["date"]["uts"], t["artist"]["mbid"], t["artist"]["content"], t["mbid"], t["name"], t["album"]["mbid"], t["album"]["content"] )
				rescue
					puts "DB error"
				end

			end

			page = page + 1

		end
		update_metadata if also_get_metadata

		splunk_writer('measuredincm.log', utc_offset)


	end

	def update_metadata
		artist_research
		track_research
	end


  def artist_research
  	puts "researching artists..."
  	get_unresearched_artists.each do |artist|
  		lookup_artist_info(artist[0], artist[1])

  	end
  end

  def track_research
  	get_unresearched_tracks.each do |track|
  		lookup_track_info(track[0], track[1], track[2])
  	end
  end

  def get_unresearched_tracks
  	return @db.execute( "SELECT DISTINCT track_mbid, artist_name, track_name FROM track_history t
  											 WHERE NOT EXISTS (select 1 from track_details d WHERE t.track_mbid = d.track_mbid)
  											 AND track_mbid IS NOT NULL")
  end

	def get_unresearched_artists
	  return @db.execute("SELECT DISTINCT artist_mbid, artist_name FROM track_history t
	                      WHERE NOT EXISTS (select 1 from artist a where t.artist_mbid = a.artist_mbid)
	                      AND NOT EXISTS (select 1 from artist a where t.artist_name = a.artist_name)")
	end

	# gets info for related tags
	def get_related_tags(tag)
		similar_tags = lastfm.tag.get_similar(tag)
		puts tag + " had these similar tags: " + similar_tags
		similar_tags.each do |st|
			@db.execute "INSERT INTO xref_tag_relations (tag_a, tag_b) VALUES (?,?)", tag, st
		end

	end

	# gets info for track_details table
	def lookup_track_info(track_mbid, artist_name, track_name)
		puts "looking up info for " + artist_name + "|" + track_name
		begin
			track = @lastfm.track.get_info(:track_mbid => track_mbid, :artist => artist_name, :track => track_name, :username => @username)

			puts track
			@db.execute( "INSERT INTO track_history (time_utc, artist_mbid, artist_name, track_mbid, track_name, album_mbid, album_name) VALUES (?,?,?,?,?,?,?)", t["date"]["uts"], t["artist"]["mbid"], t["artist"]["content"], t["mbid"], t["name"], t["album"]["mbid"], t["album"]["content"] )
		rescue
			#  (Lastfm::ApiError)
      #  Track not found
      puts "Track not found or something - " + track_mbid + " " + track_name

		end


	end

	# looks up artist data, and plugs it into the artist tables.
	# also adds stuff to artist_tags and similar artists
	def lookup_artist_info(artist_mbid, artist_name)
		puts "looking up info for " + artist_mbid + "|" + artist_name
	  begin
	    artist = @lastfm.artist.get_info(:artist_mbid => artist_mbid, :artist => artist_name)

	    stmt = @db.prepare( "INSERT INTO artist( artist_mbid, artist_name, listeners, playcount, placeformed, yearformed, yearfrom, yearto, image ) VALUES (?,?,?,?,?,?,?,?,?)")
			puts artist
			mbid = artist["mbid"] if artist.has_key?("mbid") && artist["mbid"].kind_of?(String)

			stmt.bind_param 1, mbid
			stmt.bind_param 2, artist["name"].kind_of?(String) ? artist["name"] : nil
			stmt.bind_param 3, artist["stats"]["listeners"].kind_of?(String) ? artist["stats"]["listeners"] : nil
			stmt.bind_param 4, artist["stats"]["playcount"].kind_of?(String) ? artist["stats"]["playcount"] : nil
			stmt.bind_param 5, artist["bio"]["placeformed"].kind_of?(String) ? artist["bio"]["placeformed"] : nil
			stmt.bind_param 6, artist["bio"]["yearformed"].kind_of?(String) ? artist["bio"]["yearformed"] : nil
			year_from = nil
			year_from = artist["bio"]["formationlist"]["yearfrom"] if artist.has_key?("bio") && artist["bio"].has_key?("formationlist") && artist["bio"]["formationlist"].has_key?("yearfrom")
			stmt.bind_param 7, year_from
			year_to = nil
			year_to = artist["bio"]["formationlist"]["yearto"] if artist.has_key?("bio") && artist["bio"].has_key?("formationlist") && artist["bio"]["formationlist"].has_key?("yearto")
			stmt.bind_param 8, year_to

			# puts artist["image"]
		  img = artist["image"].select { |img| img["size"] == "large" }.first

			stmt.bind_param 9, !img.nil? && img["content"].kind_of?(String) ? img["content"] : nil
			stmt.execute

			# update the artist_mbid in the track history table if we need to
			if artist_mbid.nil? && !mbid.nil?
				puts "Updating " + artist_name + " to id " + mbid
				@db.execute "UPDATE track_history SET artist_mbid = ? WHERE artist_name = ? AND artist_mbid IS NULL", mbid, artist_name
			end

			unless artist["tags"]["tag"].nil?
				artist["tags"]["tag"].each do |tag|
		    	@db.execute "INSERT INTO artist_tags (artist_mbid, artist_name, tag) VALUES (?,?,?)", artist_mbid, artist_name, tag["name"]
		    end
			end

			unless artist["similar"]["artist"].nil?
		    artist["similar"]["artist"].each do |a|
		    	begin
			    	@db.execute "INSERT INTO similar_artists (artist_mbid, artist_name, similar_artist_name) VALUES (?,?,?)", artist_mbid, artist_name, a["name"]
			    rescue
			    end
		    end
	  		end

	  rescue
	   puts "error looking up tag for that artist :("
	  	puts @db.errmsg
	  end

	end

	def lookup_album_info(album_mbid, artist_name, album_name)
	end

	# def get_artist_top_tracks(artist, artist_mbid)
	# 	top_tracks = @lastfm.artist.get_top_tracks(:artist = artist, :artist_mbid = artist_mbid)
	# 	top_tracks.each do |track|
	# 		db.execute "INSERT INTO artist_top_tracks (artist, artist_mbid, rank, playcount) VALUES (?,?,?,?)", artist, artist_mbid, track["rank"], track["playcount"]
	# end

	# writes splunkable stuff to a log file.
	def splunk_writer(logfile = 'measuredincm.log', utc_minimum = 0)

		sql = "SELECT th.time_utc, th.artist_name, th.album_name,
			GROUP_CONCAT(at.tag),
			td.duration, td.listeners, td.track_name,
			a.is_metal
			FROM track_history th
			LEFT JOIN artist a ON (th.artist_mbid = a.artist_mbid)
			LEFT JOIN artist_tags at ON (th.artist_mbid = at.artist_mbid)
			LEFT JOIN track_details td ON (th.track_mbid = td.track_mbid)
			WHERE th.time_utc > " + utc_minimum.to_s + "
			GROUP BY
			th.time_utc, th.artist_name, th.album_name,
			td.duration, td.listeners, td.track_name"
		puts sql
		tracks = @db.execute sql
		puts "Got " + tracks.count.to_s + "tracks."

		log = File.open( logfile, 'w' )

		tracks.each do |t|
			begin
				string = t[0].to_s + ' artist_name="' + t[1] + '" album_name="' + t[2].to_s + '" tags="' + t[3].to_s + '" duration=' + t[4].to_s + ' listeners=' + t[5].to_s + ' track_name="' + t[6] + '" is_metal=' + t[7].to_s
				log.write(string + "\n")
				puts string
			rescue
				puts "Something went wrong with these results...", t.to_s + "\n"
			end

		end
		log.close
	end


end


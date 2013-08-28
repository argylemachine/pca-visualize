http	= require "http"
url	= require "url"
async	= require "async"

class echonest
	constructor: ( @api_key ) ->
		
	_get: ( _url, args, cb ) ->

		# Check the current query limit 
		
		difference = ( @query_limit_zero_time + 60000 ) - new Date( ).getTime( )

		if difference < 0
			# Valid time.. 
		else
			# We should not execute.. so for now just use setTimeout..
			return setTimeout ( ) ->
				@_get _url, args, cb
			, difference
			

		# Parse the URL and arguments..
		opts = url.parse _url
		for key, val of args
			opts.query[key] = val
		delete opts['search']
		
		# Make the actual request.
		req = http.get url.format( opts ), ( res ) ->
			res.setEncoding "utf8"

			_res = ""

			res.on "error", ( err ) ->
				return cb err
			
			res.on "data", ( chunk ) ->
				_res += chunk
			
			res.on "end", ( ) ->

				if res.haders["x-ratelimit-remaining"] is 0
					_d = new Date( )
					@query_limit_zero_time = _d.getTime( )

				try
					_o = JSON.parse _res
					return cb null, _o.response
				catch err
					return cb err

		req.on "error", ( err ) ->
			return cb err


	song_search: ( artist, title, cb ) ->
		
	song_profile: ( song_id, cb ) ->
		

exports.echonest = echonest

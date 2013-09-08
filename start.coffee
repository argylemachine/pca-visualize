log		= require( "logging" ).from __filename
fs		= require "fs"
async		= require "async"
util		= require "util"
http		= require "http"
express		= require "express"
sylvester	= require "sylvester"
path		= require "path"

required_options = [ "port" ]

class server
	constructor: ( @options ) ->
		
		for required_option in required_options
			if not @options[required_option]?
				throw "Required option '#{required_option}' missing."

		# Setup the initial application ( just express ).
		@app = express( )

		# Basic express middleware.
		@app.use express.logger( )
		@app.use express.static path.join __dirname, "static"
		
	_error_out: ( res, err ) ->
		# Helper function for sending an error back.
		res.json { "error": err }

	start: ( cb ) ->
		if @server?
			return cb "Already started"
		
		@server = http.createServer @app
		@server.listen @options['port'], ( ) ->
			return cb null

	stop: ( cb ) ->
		if not @server?
			return cb "Not started"

		@server.close ( ) ->
			return cb null


###

	app.param "id", ( req, res, cb, id ) ->
		runtime['db'].get id, ( err, doc ) ->
			if err
				return cb "not_found"
			req.doc = doc
			cb null

	app.get "/songs", ( req, res ) ->
		runtime['db'].view "songs/by-artist-and-title", ( err, docs ) ->
			if err
				return _error_out res, err

			res.json (doc.value for doc in docs)

	app.get "/artists", ( req, res ) ->
		runtime['db'].view "songs/null-by-artist", { group: true, reduce: true }, ( err, docs ) ->
			if err
				return _error_out res, err

			res.json ( doc.key for doc in docs )

	app.get "/pca/basic", ( req, res ) ->
		# This returns a list of objects.
		# The objects contain track information, such as title, artist, as well
		# as x and y which are computed using PCA on the features that are specified.

		# The 'pca' keyword is used to specify what attributes we want to perform the PCA on.
		attrs = req.query.pca

		# Force at least a single attribute to be specified.
		if not attrs
			return _error_out res, "No pca specified."
		
		# This just gets a list of documents from the CouchDB server. The view isn't important at this point.
		runtime['db'].view "songs/by-artist-and-title", ( err, docs ) ->

			# Error out if we get an error back from CouchDB.
			if err
				return _error_out res, err

			valid_docs = [ ]

			# Iterate over all the documents we got back. Ensure the attributes
			# that we're looking for exist. Populate the valid_docs array.
			for doc in (doc.value for doc in docs)
				# Sanity check on each doc. Make sure it has the attributes requested..
				skip = false
				for attr in attrs
					if not doc[attr]?
						skip = true
						break

				# If we should skip this document, continue with the next doc.
				if skip
					continue

				valid_docs.push doc

			# Go through each attribute that was specified.
			for attr in attrs

				# Calculate the mean of the attribute for all docs in valid_docs.
				sum = 0
				for doc in valid_docs
					sum += doc[attr]
				mean = ( sum / valid_docs.length )
				
				# Calculate the standard deviation.
				squared_diff_sum = 0
				for doc in valid_docs
					squared_diff_sum += Math.pow( ( doc[attr] - mean ), 2 )
				standard_deviation = Math.sqrt( squared_diff_sum / valid_docs.length )

				# Now that we have the mean and standard deviation for the attribute, run through 
				# each doc in valid_docs and compute the normalized attribute.
				for doc in valid_docs
					doc["normalized_" + attr] = doc[attr] - mean
					doc["normalized_" + attr] = doc["normalized_" + attr] / standard_deviation

			# We've normalized the data at this point, so each doc contains ["normalized_"+attr] for
			# each attr in attrs. At this point, generate a quick matrix using arrays so that we
			# can use the sylvester module to compute the PCA.

			matrix = [ ]
			for doc in valid_docs
				_i = [ ]
				for attr in attrs
					_i.push doc["normalized_"+attr]
				matrix.push _i

			# Project into 2 dimensions..
			svd	= sylvester.Matrix.create matrix
			k	= svd.pcaProject 2

			for i in [0..valid_docs.length-1]
				valid_docs[i].x = k.Z.elements[i][0]
				valid_docs[i].y = k.Z.elements[i][1]
			
			res.json valid_docs

	app.get "/song/:id", ( req, res ) ->
		res.sendfile req.doc.path
			
	app.get "/", ( req, res ) ->
		res.redirect "/index.html"
	
	web_server = http.createServer app

	web_server.listen config['port'], ( ) ->
		log "Started the web server.."
		return cb null


async.series [ ( cb ) ->
		log "Parsing config.."
		fs.readFile "config.json", ( err, data ) ->
			if err
				return cb err
			try
				config = JSON.parse data
				return cb null
			catch err
				return cb err
	, ( cb ) ->
		log "Validating config.."
		async.map required_config, ( req, cb ) ->
			if not config[req]?
				return cb "Configuration value #{req} not found."
			cb null
		, ( err, res ) ->
			if err
				return cb err
			cb null

	, start_webserver

	], ( err, res ) ->
		if err
			log "Unable to startup: #{err}"
			process.exit 1
		log "Startup complete!"



###

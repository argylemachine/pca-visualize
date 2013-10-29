log		= require( "logging" ).from __filename
fs		= require "fs"
async		= require "async"
util		= require "util"
http		= require "http"
express		= require "express"
sylvester	= require "sylvester"
path		= require "path"

# Only a port is required as far as configuration goes.
required_options = [ "port" ]

class server
	constructor: ( @options, @data ) ->
		
		# Force particular options to be specified.
		for required_option in required_options
			if not @options[required_option]?
				throw "Required option '#{required_option}' missing."


		# Setup the initial application ( just express ).
		@app = express( )

		# Some middleware functions to help out express.
		logged_in = ( req, res, cb ) ->
			if not req.session.username?
				return res.json { "error": "Permission Denied" }
			cb null

		# Basic express middleware.
		@app.use express.logger( )
		@app.use express.compress( )
		@app.use express.cookieParser "pca"
		@app.use express.cookieSession( )
		@app.use express.json( )
		@app.use express.urlencoded( )

		# Handle errors.
		@app.use ( err, req, res, cb ) ->
			log err.stack
			res.send 500, "Error! Sorry bout this."
		
		# Force all /api calls to be from an authenticated user.
		@app.all "/api/*", logged_in
		
		@app.get "/", logged_in, ( req, res ) ->
			res.redirect "/main.html"

		# Simple login message
		@app.get "/login", ( req, res ) ->
			if req.query.username is "guest" and req.query.password is "guest"
				req.session.username = req.query.username
				return res.json true
			res.json false

		@app.get "/logout", ( req, res ) ->

			# If someone isn't already logged in..
			if not req.session.username?
				return res.json false
			
			# Kill the session.
			req.session = null

			# Return true :)
			res.json true

		# Simple query for user information.
		@app.get "/api/user", ( req, res ) ->
			res.json { "username": req.session.username }

		# Get the attributes that are available.
		@app.get "/api/attributes", ( req, res ) =>
			@get_attributes ( err, attributes ) ->
				if err
					res.json false
				res.json attributes

		# Set the attributes we want to use.
		@app.post "/api/attributes", ( req, res ) ->
			req.session.attributes = req.body.attributes
			res.json true

		# Get PCA data.
		# Note that we make use of req.session.filters,
		# req.session.attributes, and req.session.includes
		@app.get "/api/data", ( req, res ) =>

			# hack right now to get rid of filters and includes.
			req.session.filters	= { }
			req.session.includes	= { }

			@get_data req.session.filters, req.session.attributes, req.session.includes, ( err, docs ) =>
				if err
					res.json false
					return

				# Define holder objects for the means and standard deviations.
				means			= { }
				standard_deviations	= { }

				# Go through all the attributes.
				for attr in req.query.attributes

					# Calculate the mean.
					sum = 0
					_length = docs.length
					for doc in docs
						if not doc[attr]?
							_length--
							continue

						sum += doc[attr]
					means[attr] = sum / _length
					
					# Calculate the standard deviation.
					squared_diff_sum = 0
					for doc in docs
						if not doc[attr]?
							continue
						squared_diff_sum += Math.pow( ( doc[attr] - means[attr] ), 2 )

					standard_deviations[attr] = Math.sqrt( squared_diff_sum / _length )

					# Normalize the attribute, shoving the new value into doc["normalized_"+attr]
					for doc in docs

						if not doc[attr]?
							continue
					
						# Edge case that the standard div is 0. As in, all the values
						# are the same. We don't want to return NaN.
						if standard_deviations[attr] is 0
							doc["normalized_" + attr] = doc[attr]
							continue

						doc["normalized_" + attr] = doc[attr] - means[attr]
						doc["normalized_" + attr] = doc["normalized_" + attr] / standard_deviations[attr]

				# Create a valid_docs array, ones that contain all the normalized values we're going to use.
				valid_docs = [ ]
				for doc in docs
					_valid_doc = true
					for attr in req.query.attributes
						if not doc["normalized_"+attr]?
							_valid_doc = false
					if _valid_doc
						valid_docs.push doc

				# Create matrix.
				matrix = [ ]
				for doc in valid_docs
					_i = [ ]
					for attr in req.query.attributes
						_i.push doc["normalized_" + attr]
					matrix.push _i

				# Project into 2 dimensions..
				svd	= sylvester.Matrix.create matrix
				k	= svd.pcaProject 2
			
				# Shove the x and y attributes into the docs..
				for i in [0..valid_docs.length-1]
					valid_docs[i].x = k.Z.elements[i][0]
					valid_docs[i].y = k.Z.elements[i][1]

				_r = [ ]
				for doc in valid_docs
					if not doc.x or not doc.y
						continue
					_r.push doc
				res.json _r
		
		@app.use express.static path.join __dirname, "static"

	get_attributes: ( cb ) ->
		# Helper function so that code makes logical sense
		# when reading.
		@get_data null, null, null, cb

	get_data: ( filters, attributes, includes, cb ) ->

		# Sanity check on the type of the attributes argument.
		if attributes and ( typeof attributes is "string" or attributes.length < 2 )
			return cb "More than one attribute must be specified."

		# Santiy check on the type of include.. if it is a string then shove it into an
		# array so that the code works for 1 or many..
		if typeof includes is "string"
			includes = [ includes ]

		# If the data that has been specified is a function, simply
		# pass off to it.
		if typeof @data is "function"
			return @data filter, attributes, cb

		# TODO add logic here regarding checking the type of
		# the attributes that have been specified. Force 'number'.

		# If both filter and attributes are null,
		# return a list of attributes.
		if not filters and not attributes
			_r = [ ]
			for data_obj in @data
				_r.push key for key, val of data_obj when _r.indexOf( key ) < 0
			return cb null, _r

		# If we've gotten here, there is at least a set of filters and attributes.
		# As well we're dealing with an array of objects in @options['data'].
		_r = [ ]
		for data_obj in @data

			# Skip any document not matching filters..
			skip = false
			for key, val of filters
				if data_obj[key] isnt val
					skip = true
					break
			if skip
				continue

			log "Using data object #{util.inspect data_obj}"

			# Create a new object that only contains the attributes we
			# care about. Push that to the return.
			_o = { }
			for attr in attributes
				_o[attr] = data_obj[attr]

			# Because there may be other values of the object that should
			# be included, iterate through them and include them as well.
			for include in includes
				_o[include] = data_obj[include]
			_r.push _o

		cb null, _r

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

exports.server = server

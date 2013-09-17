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
	constructor: ( @options, @data ) ->
		
		# Force particular options to be specified.
		for required_option in required_options
			if not @options[required_option]?
				throw "Required option '#{required_option}' missing."

		# Setup the initial application ( just express ).
		@app = express( )

		# Basic express middleware.
		@app.use express.logger( )
		@app.use express.static path.join __dirname, "static"

		# Handle when we get a request for a list of attributes.
		@app.get "/attributes", ( req, res ) =>
			@get_attributes ( err, attributes ) ->
				if err
					return _error_out res, err
				res.json attributes

		# Handle when we're asked for PCA data.
		# Note that the arguments 'filter' and 'attributes' are
		# required, otherwise an error is returned.
		@app.get "/pca", ( req, res ) =>

			if not req.query["attributes"]?
				return @_error_out res, "Required field 'attributes' not specified."

			# Optionally no filter or include.
			if not req.query["filter"]?
				req.query["filter"] = { }

			if not req.query["attributes"]?
				req.query["attributes"] = { }

			@get_data req.query.filter, req.query.attributes, req.query.includes, ( err, docs ) =>
				if err
					return @_error_out res, "Unable to obtain documents containing attributes. Query: #{util.inspect req.query}"

				# Define holder objects for the means and standard deviations.
				means			= { }
				standard_deviations	= { }

				# Go through all the attributes.
				for attr in req.query.attributes

					# Calculate the mean.
					sum = 0
					for doc in docs
						sum += doc[attr]
					means[attr] = sum / docs.length

					# Calculate the standard deviation.
					squared_diff_sum = 0
					for doc in docs
						squared_diff_sum += Math.pow( ( doc[attr] - means[attr] ), 2 )
					standard_deviations[attr] = Math.sqrt( squared_diff_sum / docs.length )

					# Normalize the attribute, shoving the new value into doc["normalized_"+attr]
					for doc in docs
						doc["normalized_" + attr] = doc[attr] - means[attr]
						doc["normalized_" + attr] = doc["normalized_" + attr] / standard_deviations[attr]
					
				# Create matrix.
				matrix = [ ]
				for doc in docs
					_i = [ ]
					for attr in req.query.attributes
						_i.push doc["normalized_" + attr]
					matrix.push _i
				
				# Project into 2 dimensions..
				svd	= sylvester.Matrix.create matrix
				k	= svd.pcaProject 2
			
				# Shove the x and y attributes into the docs..
				for i in [0..docs.length-1]
					docs[i].x = k.Z.elements[i][0]
					docs[i].y = k.Z.elements[i][1]
				
				_r = [ ]
				for doc in docs
					if not doc.x or not doc.y
						continue
					_r.push doc
				res.json _r

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

		# At this point we know we're dealing with a finite set of data.

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

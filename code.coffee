log		= require( "logging" ).from __filename
async		= require "async"
find		= require "find"
util		= require "util"
fs		= require "fs"
coffee_script	= require "coffee-script"
visualize	= require "./pca-visualize.coffee"

directories = [ "/home/robert/src/music-player" ]

async.map directories, ( directory, cb ) ->
	find.file /\.coffee/, directory, ( files ) ->
		async.map files, ( file, cb ) ->
			fs.readFile file, { encoding: "utf8" }, ( err, data ) ->
				if err
					return cb err

				_r = { "file": file }
				recursive_populate = ( node ) ->
					node.eachChild recursive_populate

					_op = node.constructor.name
					if not _r[_op]?
						_r[_op] = 1
					else
						_r[_op] += 1

				recursive_populate coffee_script.nodes data
				
				return cb null, _r

		, cb

, ( err, res ) ->

	_r = [ ]
	for _a in res
		for _o in _a
			_r.push _o

	server = new visualize.server { "port": 1339 }, _r

	server.start ( err ) ->
		if err
			log "Unable to start server: #{err}"
			process.exit 1

		log "Started server.."

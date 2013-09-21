log		= require( "logging" ).from __filename
visualize	= require "./pca-visualize.coffee"

data = [ 	{ "type": "Person", age: 22, height: 178, weight: 140, name: "Rob" },
		{ "type": "Person", age: 14, height: 143, weight: 140, name: "Joe" },
		{ "type": "Animal", age: 1, height: 36, weight: 140, name: "Dog" },
		{ "type": "Animal", age: 3, height: 20, weight: 140, name: "Cat" } ]

server = new visualize.server { "port": 1339 }, data

server.start ( err ) ->
	if err
		log "Unable to start server: #{err}"
		process.exit 1

	log "Started server.."

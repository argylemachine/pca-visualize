log		= require( "logging" ).from __filename
visualize	= require "./pca-visualize.coffee"

data = [ 	{ "type": "Person", age: 22, height: 178, name: "Rob" },
		{ "type": "Person", age: 14, height: 143, name: "Joe" },
		{ "type": "Animal", age: 1, height: 36, name: "Dog" },
		{ "type": "Animal", age: 3, height: 20, name: "Cat" } ]

# Example: /pca?filter[type]=Person&attributes=age&attributes=height&include=name
# Example: /pca?filter[type]=Animal&attributes=age&attributes=height&include=name

server = new visualize.server { "port": 1339 }, data

server.start ( err ) ->
	if err
		log "Unable to start server: #{err}"
		process.exit 1

	log "Started server.."

## About
[pca-visualize](https://github.com/argylemachine/pca-visualize) is a web based visualization library. It is designed as a library, and is not useful on its own.

## Usage

For a known finite set of data that aren't too big.
```coffeescript
log        = require( "logging" ).from __filename
visualize  = require "pca-visualize"

data = [ { "type": "Person", age: 22, height: 178, name: "Robert" },
         { "type": "Person", age: 14, height: 130, name: "Rob" } ]

server = new visualize.server { "port": 80, data: data }
server.start ( err ) ->
	if err
		log "Unable to start: #{err}"
		process.exit 1
	log "Listening."
```

For dynamic or large sets of data
```coffeescript
log        = require( "logging" ).from __filename
visualize  = require "pca-visualize"

server = new visualize.server { "port": 80 }

# Every time the system needs to find data objects, or a list of attributes
# this function is executed. 
server.data = ( filter, attributes, cb ) ->
	# Toy implementation. Really you would want to do an 
	# async call or some such to obtain data and filter.
	data = [ { "type": "Person", age: 22, height: 178, name: "Robert" },
             { "type": "Person", age: 14, height: 130, name: "Rob" } ]

	# If no filter and attributes were specified, return a list of attributes.
	if not filter and not attributes
		_r = [ ]
		for data_obj in data
			_r.push key for key, val of data_obj when _r.indexOf( key ) < 0
		return res.json _r

	valid_docs = [ ]
	for data_obj in data
		for key,val of filter
			if data_obj[key] is val
				_o = { }
				for attr in attributes
					_o[attr] = data_obj[attr]
				valid_docs.push _o
	cb null, valid_docs

server.start ( err ) ->
	if err
		log "Unable to start: #{err}"
		process.exit 1
	log "Listening."
```
## Installation
 * `npm install pca-visualize`.

## License
The code in this project is under the MIT license, unless otherwise stated.

## Credits
A quick note that inspiration came from [music box](http://thesis.flyingpudding.com) by [Anita Lillie](http://flyingpudding.com/).

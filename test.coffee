log         = require( "logging" ).from __filename
visualize   = require "./pca-visualize.coffee"

data    = [     { "type": "Person": age: 22, height: 178, weight: 170, name: "Rob" },
                { "type": "Person": age: 14, height: 143, weight: 143, name: "Joe" },
                { "type": "Animal": age: 2, height: 32, weight: 12, name: "Dog" },
                { "type": "Animal": age: 3, height: 15, weight: 5, name: "Cat" } ]

server = new visualize.server { "port": 1339 }, data

server.start ( err ) ->
    if err
        log "Unable to start the server: #{err}"
        process.exit 1

    log "Started the server"

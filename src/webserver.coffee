express = require 'express'
http = require 'http'
require('pkginfo')(module, 'name', 'version')

config = require 'nconf'
logger = require './logger'

###*
 * The webserver class.
###
class WebServer
  constructor: ->
    @app = express()

    @app.use express.bodyParser()
    @app.use @errorHandler
    @setup_routing()
    @srv = http.createServer(@app)
    @srv.listen(config.get('port'))
    logger.info "Webserver is up at: http://0.0.0.0:#{config.get('port')}"

  errorHandler: (err, req, res, next) ->
    res.status 500
    res.render 'error', error: err

  # Sets up the webserver routing.
  setup_routing: =>

    # Returns the base name and version of the app.
    @app.get '/', (req, res, next) =>
      res.json 200, 
        name: exports.name,
        version: exports.version

    # Silence favicon requests.
    @app.get '/favicon.ico', (req, res, next) =>
      res.setHeader 'Content-Type', 'image/x-icon'
      res.setHeader 'Cache-Control', 'public, max-age=864000'
      res.end()

module.exports = WebServer

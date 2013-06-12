config = require 'nconf'
logger = require './logger'
CLI = require './cli'
Gmond = require './gmond'
WebServer = require './webserver'

###*
 * The base application class.
###
class Application
  constructor: ->
    @cli = new CLI()
    @gmond = new Gmond()
    @ws = new WebServer()

  ###*
   * Aborts the application with a message.
   * @param {String} (msg) The message to abort the application with
  ###
  abort: (msg) =>
    logger.info(''.concat('Aborting Application: ', msg, '...'))
    process.exit(1)

module.exports = Application

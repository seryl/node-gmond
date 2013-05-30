optimist = require 'optimist'
logger = require './logger'
config = require 'nconf'
require('pkginfo')(module, 'name')

###
The command line interface class.
###
class CLI
  constructor: ->
    @argv = optimist
      .usage("Usage: " + exports.name)

      # configuration
      .alias('c', 'config')
      .describe('c', 'The configuration file to use')
      .default('c', "/etc/node-gmond.json")

      # ganglia gmetric gmond host
      .alias('g', 'listen_address')
      .describe('g', 'The gmond address to listen on')
      .default('g', '127.0.0.1')

      # ganglia gmetric gmond port
      .alias('t', 'gmond_tcp_port')
      .describe('t', 'The gmond TCP port to listen on')
      .default('t', 8649)

      # ganglia gmetric gmond TCP port
      .alias('u', 'gmond_udp_port')
      .describe('u', 'The gmond UDP port to listen on (for XML requests)')
      .default('u', 8649)

      # ganglia host dmax
      .alias('D', 'dmax')
      .describe('D', 'The dmax of a ganglia host (host TTL for cleanup)')
      .default('D', 3600)

      # ganglia default tmax
      .alias('m', 'tmax')
      .describe('m', 'The tmax of a ganglia metric (metric TTL for cleanup)')
      .default('m', 60)

      # cleanup threshold in seconds
      .alias('T', 'cleanup_threshold')
      .describe('T', 'The interval in seconds for checking dmax expiration')
      .default('T', 300)

      # default cluster name
      .alias('C', 'cluster')
      .describe('C', 'The default ganglia cluster name')
      .default('C', 'main')

      # default cluster owner
      .alias('O', 'owner')
      .describe('O', 'The default ganglia cluster owner')
      .default('O', 'unspecified')

      # default cluster latlong
      .alias('L', 'latlong')
      .describe('L', 'The default ganglia cluster latlong')
      .default('L', 'unspecified')

      # default cluster url
      .alias('U', 'url')
      .describe('U', 'The default ganglia cluster url')
      .default('U', '127.0.0.1')

      # default ganglia metadata interval
      .alias('M', 'metadata_interval')
      .describe('M', 'The default ganglia send metadata interval')
      .default('M', 20)

      # logging
      .alias('l', 'loglevel')
      .describe('l', 'Set the log level (debug, info, warn, error, fatal)')
      .default('l', 'warn')

      # port
      .alias('p', 'port')
      .describe('p', 'Run the api server on the given port')
      .default('p', 3000)

      # help
      .alias('h', 'help')
      .describe('h', 'Shows this message')
      .default('h', false)

      # append the argv from the cli
      .argv

    @configure()

    if config.get('help').toString() is "true"
      optimist.showHelp()
      process.exit(0)

  # Configures the nconf mapping where the priority matches the order
  configure: =>
    @set_overrides()
    @set_argv()
    @set_env()
    @set_file()
    @set_defaults()

  # Sets up forceful override values
  set_overrides: =>
    config.overrides({
      })

  # Sets up the configuration for cli arguments
  set_argv: =>
    config.add('optimist_args', {type: 'literal', store: @argv})

  # Sets up the environment configuration
  set_env: =>
    config.env({
      whitelist: []
      })

  # Sets up the file configuration
  set_file: =>
    config.file({ file: config.get('c') })

  # Sets up the default configuration
  set_defaults: =>
    config.defaults({
      })

module.exports = new CLI()

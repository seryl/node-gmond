Gmetric = require 'gmetric'
net = require 'net'

builder = require 'xmlbuilder'

Logger = require './logger'
CLI = require './cli'
Config = require './config'
WebServer = require './webserver'

###*
 * The ganglia gmond class.
###
class Gmond
  constructor: ->
    @config = Config.get()
    @logger = Logger.get()
    # start_udp_service()
    @start_xml_service()

    @clusters = {
      "analytics"
    }

    root = @get_gmond_xml_root()

    console.log root.end({ pretty: true, indent: '  ', newline: "\n" })

  ###*
   * Starts up the xml service.
  ###
  start_xml_service: =>
    @logger.info 'Starting xml service'
    server = net.createServer (sock) =>
      # srv_msg = "XML Server Started: #{sock.remoteAddress}:#{sock.remotePort}"
      # @logger.info srv_msg
      sock.end("done done done")

      sock.on 'data', (data) =>
        @logger.info "Received TCP Data: #{data}"

      sock.on 'close', (data) =>
        @logger.info "Closing TCP Socket"

    server.listen(8649, "127.0.0.1")


  get_gmond_xml_root: ->
    root = builder.create 'GANGLIA_XML', { version: '1.0', 'encoding': 'ISO-8859-1', standalone: 'yes' }, 'ext': """[
  <!ELEMENT GANGLIA_XML (GRID|CLUSTER|HOST)*>
    <!ATTLIST GANGLIA_XML VERSION CDATA #REQUIRED>
    <!ATTLIST GANGLIA_XML SOURCE CDATA #REQUIRED>
  <!ELEMENT GRID (CLUSTER | GRID | HOSTS | METRICS)*>
    <!ATTLIST GRID NAME CDATA #REQUIRED>
    <!ATTLIST GRID AUTHORITY CDATA #REQUIRED>
    <!ATTLIST GRID LOCALTIME CDATA #IMPLIED>
  <!ELEMENT CLUSTER (HOST | HOSTS | METRICS)*>
    <!ATTLIST CLUSTER NAME CDATA #REQUIRED>
    <!ATTLIST CLUSTER OWNER CDATA #IMPLIED>
    <!ATTLIST CLUSTER LATLONG CDATA #IMPLIED>
    <!ATTLIST CLUSTER URL CDATA #IMPLIED>
    <!ATTLIST CLUSTER LOCALTIME CDATA #REQUIRED>
  <!ELEMENT HOST (METRIC)*>
    <!ATTLIST HOST NAME CDATA #REQUIRED>
    <!ATTLIST HOST IP CDATA #REQUIRED>
    <!ATTLIST HOST LOCATION CDATA #IMPLIED>
    <!ATTLIST HOST TAGS CDATA #IMPLIED>
    <!ATTLIST HOST REPORTED CDATA #REQUIRED>
    <!ATTLIST HOST TN CDATA #IMPLIED>
    <!ATTLIST HOST TMAX CDATA #IMPLIED>
    <!ATTLIST HOST DMAX CDATA #IMPLIED>
    <!ATTLIST HOST GMOND_STARTED CDATA #IMPLIED>
  <!ELEMENT METRIC (EXTRA_DATA*)>
    <!ATTLIST METRIC NAME CDATA #REQUIRED>
    <!ATTLIST METRIC VAL CDATA #REQUIRED>
    <!ATTLIST METRIC TYPE (string | int8 | uint8 | int16 | uint16 | int32 | uint32 | float | double | timestamp) #REQUIRED>
    <!ATTLIST METRIC UNITS CDATA #IMPLIED>
    <!ATTLIST METRIC TN CDATA #IMPLIED>
    <!ATTLIST METRIC TMAX CDATA #IMPLIED>
    <!ATTLIST METRIC DMAX CDATA #IMPLIED>
    <!ATTLIST METRIC SLOPE (zero | positive | negative | both | unspecified) #IMPLIED>
    <!ATTLIST METRIC SOURCE (gmond) 'gmond'>
  <!ELEMENT EXTRA_DATA (EXTRA_ELEMENT*)>
  <!ELEMENT EXTRA_ELEMENT EMPTY>
    <!ATTLIST EXTRA_ELEMENT NAME CDATA #REQUIRED>
    <!ATTLIST EXTRA_ELEMENT VAL CDATA #REQUIRED>
  <!ELEMENT HOSTS EMPTY>
    <!ATTLIST HOSTS UP CDATA #REQUIRED>
    <!ATTLIST HOSTS DOWN CDATA #REQUIRED>
    <!ATTLIST HOSTS SOURCE (gmond | gmetad) #REQUIRED>
  <!ELEMENT METRICS (EXTRA_DATA*)>
    <!ATTLIST METRICS NAME CDATA #REQUIRED>
    <!ATTLIST METRICS SUM CDATA #REQUIRED>
    <!ATTLIST METRICS NUM CDATA #REQUIRED>
    <!ATTLIST METRICS TYPE (string | int8 | uint8 | int16 | uint16 | int32 | uint32 | float | double | timestamp) #REQUIRED>
    <!ATTLIST METRICS UNITS CDATA #IMPLIED>
    <!ATTLIST METRICS SLOPE (zero | positive | negative | both | unspecified) #IMPLIED>
    <!ATTLIST METRICS SOURCE (gmond) 'gmond'>
]"""
    return root


module.exports = Gmond

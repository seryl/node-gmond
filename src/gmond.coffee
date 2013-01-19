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
    @gmetric = new Gmetric()
    @gmond_started = unix_time()

    # start_udp_service()
    @start_xml_service()

    @clusters = new Object()

  ###*
   * Starts up the xml service.
  ###
  start_xml_service: =>
    @logger.info 'Starting xml service'
    server = net.createServer (sock) =>
      sock.end(@generate_xml_snapshot())
    server.listen(@config.get('gmond_tcp_port'), @config.get('listen_address'))

  ###*
   * Returns the current unix timestamp.
  ###
  unix_time: ->
    new Date().getTime()

  ###*
   * Adds a new metric automatically determining the cluster or using defaults.
   * @param {Object} (metric)
  ###
  add_metric: (metric) =>
    hmet = @gmetric.parse
    hmet = hashify_metric(metric)
    cluster = @determine_cluster_from_metric(hmet)
    @clusters[hmet.cluster] ||= new Object()

  determine_cluster_from_metric: (metric) =>
    return "analytics"

  ###*
   * Generates a hashmap reference of a gmetric object.
  ###
  hashify_metric: (metric) =>
    hmet = @gmetric.
    return

  ###*
   * Generates an xml snapshot of the gmond state.
  ###
  generate_xml_snapshot: =>
    root = @get_gmond_xml_root()
    for cluster in Object.keys(@clusters)
      root = generate_cluster_element(root, cluster)
    return root.end({ pretty: true, indent: '  ', newline: "\n" })

  ###*
   * Appends the cluster_xml for a single cluster to the 
  ###
  generate_cluster_element: (root, cluster) =>
    if Object.keys(@clusters[cluster].hosts).length == 0
      delete_cluster(cluster)
    ce = root.ele('CLUSTER')
    ce.att('NAME', @clusters[cluster].name || @config.get('cluster'))
    ce.att('LOCALTIME', new Date().getTime())
    ce.att('OWNER', @clusters[cluster].owner || @config.get('owner'))
    ce.att('LATLONG', @clusters[cluster].latlong || @config.get('latlong'))
    ce.att('URL', @clusters[cluster].url || @config.get('url'))

    if @clusters[cluster].hosts == undefined
      return root

    hostlist = Object.keys(@clusters[cluster].hosts)
    if hostlist.length == 0
      return root

    for h in hostlist
      ce = generate_host_element(ce, @clusters[cluster]['hosts'][h])
    return root

  ###*
   * Generates a host element for a given host and attaches to the parent.
  ###
  generate_host_element: (parent, host) ->
    he = parent.ele('HOST')
    he.att('NAME', h)
    he.att('IP', host['ip'])
    he.att('TAGS', (host['tags'] or []).join(','))
    he.att('REPORTED', host['reported'])
    he.att('TN', @unix_time() - host.tmax)
    he.att('TMAX', host.tmax || @config.get('tmax'))
    he.att('DMAX', host.dmax || @config.get('dmax'))
    he.att('LOCATION', host.location || @config.get('latlong'))
    he.att('GMOND_STARTED', @gmond_started)
    for m in host.metrics
      he = generate_metric_element(he, m)
    return parent

  ###*
   * Generates the metric element and attaches to the parent.
  ###
  generate_metric_element: (parent, metric) ->
    me = parent.ele('METRIC')
    me.att('NAME', m.name)
    me.att('VAL', m.value)
    me.att('TYPE', m.type)
    me.att('UNITS', m.units)
    me.att('TN', @unix_time())
    me.att('TMAX', m.tmax || @config.get('tmax'))
    me.att('DMAX', m.dmax || @config.get('dmax'))
    me.att('SLOPE', m.slope)
    me = generate_elements(me, metric)
    return parent

  ###*
   * Generates the extra elems for a metric and attaches to the parent.
  ###
  generate_extra_elements: (parent, metric) ->
    extras = @gmetric.extra_elements(metric)
    if extras.length < 1
      return parent

    ed = parent.ele('EXTRA_DATA')
    for extra in extras
      ee = ed.ele('EXTRA_ELEMENT')
      ee.att('NAME', extra)
      ee.att('VAL', metric[extra])
    return parent

  ###*
   * Returns the gmond_xml root node to build upon.
   * @return {Object} The root gmond xmlbuilder
  ###
  get_gmond_xml_root: ->
    root = builder.create 'GANGLIA_XML'
    , { version: '1.0', encoding: 'ISO-8859-1'
    , standalone: 'yes' }, ext: """[
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
    <!ATTLIST METRIC TYPE (string | int8 | uint8 | int16 | uint16 | int32 | uint32 | int64 | uint64 | float | double | timestamp) #REQUIRED>
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
    <!ATTLIST METRICS TYPE (string | int8 | uint8 | int16 | uint16 | int32 | uint32 | int64 | uint64 | float | double | timestamp) #REQUIRED>
    <!ATTLIST METRICS UNITS CDATA #IMPLIED>
    <!ATTLIST METRICS SLOPE (zero | positive | negative | both | unspecified) #IMPLIED>
    <!ATTLIST METRICS SOURCE (gmond) 'gmond'>
  <GANGLIA_XML VERSION="3.3.0" SOURCE="gmond">
]"""
    return root

module.exports = Gmond

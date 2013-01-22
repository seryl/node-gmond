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

    @gmond_started = @unix_time()
    @host_timers = new Object()
    @hosts = new Object()
    @clusters = new Object()

    @udp_server = null
    @xml_server = null

    # start_udp_service()
    @start_xml_service()

  ###*
   * Starts up the xml service.
  ###
  start_xml_service: =>
    @xml_server = net.createServer (sock) =>
      sock.end(@generate_xml_snapshot())
    @xml_server.listen @config.get('gmond_tcp_port')
      , @config.get('listen_address')

  ###*
   * Stops the xml service.
   * @param {Function} (fn) The callback function
  ###
  stop_xml_service: (fn) =>
    @xml_server.close(fn)

  ###*
   * Returns the current unix timestamp.
   * @return {Integer} The unix timestamp integer
  ###
  unix_time: ->
    new Date().getTime()

  ###*
   * Adds a new metric automatically determining the cluster or using defaults.
   * @param {Object} (metric)
  ###
  add_metric: (metric) =>
    msg_type = metric.readInt32BE(0)
    hmet = @gmetric.unpack(metric)
    @hosts[hmet.hostname] ||= new Object()
    if msg_type == 128
      cluster = @determine_cluster_from_metric(hmet)
      @hosts[hmet.hostname].cluster ||= cluster
      @clusters[cluster] ||= new Object()
      @clusters[cluster][hmet.hostname] = true
    @merge_metric @hosts[hmet.hostname], hmet

  ###*
   * Merges a metric with the hosts object.
   * @param {Object} (target) The target hosts object to modify
   * @param {Object} (gmetric) The host information to merge
  ###
  merge_metric: (target, hmetric) =>
    now = @unix_time()
    target['host_reported'] = now
    target['info'] ||= new Object()
    target['reported'] ||= new Object()
    target['tags'] ||= new Array()
    target['ip'] ||= hmetric.hostname
    target['metrics'] ||= new Object()
    target['metrics'][hmetric.name] ||= new Object()
    for key in Object.keys(hmetric)
      target['metrics'][hmetric.name][key] = hmetric[key]
    target['reported'][hmetric.name] = now

  ###*
   * Returns the cluster of the metric or assumes the default.
   * @param {H}
  ###
  determine_cluster_from_metric: (hmetric) =>
    cluster = hmetric['cluster']
    if cluster == undefined
      cluster = @config.get('cluster')
    delete hmetric['cluster']
    return cluster

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

    # if @clusters[cluster].hosts == undefined
    #   return root

    # hostlist = Object.keys(@clusters[cluster].hosts)
    # if hostlist.length == 0
    #   return root

    # for h in hostlist
    #   ce = generate_host_element(ce, @clusters[cluster]['hosts'][h], h)
    return root

  ###*
   * Generates a host element for a given host and attaches to the parent.
  ###
  generate_host_element: (parent, host, hostname) ->
    he = parent.ele('HOST')
    he.att('NAME', hostname)
    he.att('IP', host['ip'])
    he.att('TAGS', (host['tags'] || []).join(','))
    he.att('REPORTED', host['host_reported'])
    he.att('TN', @unix_time() - host['host_reported'])
    he.att('TMAX', host.tmax || @config.get('tmax'))
    he.att('DMAX', host.dmax || @config.get('dmax'))
    he.att('LOCATION', host.location || @config.get('latlong'))
    he.att('GMOND_STARTED', @gmond_started)
    for m in Object.keys(host.metrics)
      he = @generate_metric_element(he, host, host.metrics[m])
    return parent

  ###*
   * Generates the metric element and attaches to the parent.
  ###
  generate_metric_element: (parent, host, metric) ->
    me = parent.ele('METRIC')
    me.att('NAME', metric.name)
    me.att('VAL', metric.value)
    me.att('TYPE', metric.type)
    me.att('UNITS', metric.units)
    me.att('TN', @unix_time() - host['reported'][metric.name])
    me.att('TMAX', metric.tmax || @config.get('tmax'))
    me.att('DMAX', metric.dmax || @config.get('dmax'))
    me.att('SLOPE', metric.slope)
    me = @generate_extra_elements(me, metric)
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

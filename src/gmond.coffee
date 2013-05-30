net = require 'net'
dgram = require 'dgram'
Gmetric = require 'gmetric'
builder = require 'xmlbuilder'
async = require 'async'

logger = require './logger'
cli = require './cli'
config = require 'nconf'
WebServer = require './webserver'

###
The ganglia gmond class.
###
class Gmond
  constructor: ->
    @gmetric = new Gmetric()
    @socket = dgram.createSocket('udp4')

    @gmond_started = @unix_time()
    @host_timers = new Object()
    @metric_timers = new Object()
    @hosts = new Object()
    @clusters = new Object()

    @udp_server = null
    @xml_server = null

    @start_udp_service()
    @start_xml_service()

  ###
  Starts the udp gmond service.
  ###
  start_udp_service: =>
    @socket.on 'message', (msg, rinfo) =>
      @add_metric(msg)

    @socket.on 'error', (err) =>
      logger.error err

    @socket.bind(config.get('gmond_udp_port'))
    logger.info "Started udp service #{config.get('gmond_udp_port')}"

  ###
  Stops the udp gmond service.
  ###
  stop_udp_service: =>
    @socket.close()

  ###
  Starts up the xml service.
  ###
  start_xml_service: =>
    @xml_server = net.createServer (sock) =>
      sock.end(@generate_xml_snapshot())
    @xml_server.listen config.get('gmond_tcp_port')
      , config.get('listen_address')

  ###
  Stops the xml service.
  @param {Function} (fn) The callback function
  ###
  stop_xml_service: (fn) =>
    @xml_server.close(fn)

  ###
  Stops all external services.
  @param {Function} (fn) The callback function
  ###
  stop_services: (fn) =>
    @stop_udp_service()
    @stop_xml_service(fn)

  ###
  Stop all timers.
  ###
  stop_timers: (fn) =>
    htimers = Object.keys(@host_timers)
    mtimers = Object.keys(@metric_timers)
    for ht in htimers
      clearInterval(@host_timers[ht])
      delete(@host_timers[ht])

    for mt in mtimers
      clearInterval(@metric_timers[mt])
      delete(@metric_timers[mt])

    fn()

  ###
  Returns the current unix timestamp.
  @return {Integer} The unix timestamp integer
  ###
  unix_time: ->
    Math.floor(new Date().getTime() / 1000)

  ###
  Adds a new metric automatically determining the cluster or using defaults.
  @param {Object} (metric) The raw metric packet to add
  ###
  add_metric: (metric) =>
    msg_type = metric.readInt32BE(0)
    if (msg_type == 128) || (msg_type == 133)
      hmet = @gmetric.unpack(metric)
      @hosts[hmet.hostname] ||= new Object()
      if msg_type == 128
        cluster = @determine_cluster_from_metric(hmet)
        @hosts[hmet.hostname].cluster ||= cluster
        @clusters[cluster] ||= new Object()
        @clusters[cluster].hosts ||= new Object()
        @clusters[cluster].hosts[hmet.hostname] = true
      @set_metric_timer(hmet)
      @set_host_timer(hmet)
      @merge_metric @hosts[hmet.hostname], hmet

  ###
  Sets up the host DMAX timer for host cleanup.
  @param {Object} (hmetric) The host metric information
  ###
  set_host_timer: (hmetric) =>
    @host_timers[hmetric.hostname] ||= setInterval () =>
      try
        timeout = @hosts[hmetric.hostname].dmax || config.get('dmax')
        tn = @unix_time() - @hosts[hmetric.hostname]['host_reported']
        if tn > timeout
          cluster = hmetric.cluster
          delete @hosts[hmetric.hostname]
          if @clusters[cluster] and @clusters[cluster].hasOwnProperty('hosts')
            delete @clusters[cluster].hosts[hmetric.hostname]
          clearInterval(@host_timers[hmetric.hostname])
          delete @host_timers[hmetric.hostname]
      catch e
        null
    , config.get('cleanup_threshold')

  ###
  Sets up the metric DMAX timer for metric cleanup.
  @param {Object} (hmetric) The host metric information
  ###
  set_metric_timer: (hmetric) =>
    metric_key = [hmetric.hostname, hmetric.name].join('|')
    @metric_timers[metric_key] ||= setInterval () =>
      try
        timeout = hmetric.dmax || config.get('dmax')
        tn = @unix_time() - @hosts[hmetric.hostname]['reported'][hmetric.name]
        if tn > timeout
          if @hosts[gmetric.hostname] and @hosts[hmetric.hostname]['metrics']
            delete @hosts[hmetric.hostname]['metrics'][hmetric.name]
          clearInterval(@metric_timers[metric_key])
          delete @metric_timers[metric_key]
      catch e
        null
    , config.get('cleanup_threshold')

  ###
  Merges a metric with the hosts object.
  @param {Object} (target) The target hosts object to modify
  @param {Object} (hgmetric) The host information to merge
  ###
  merge_metric: (target, hmetric) =>
    now = @unix_time()
    target['host_reported'] = now
    target['reported'] ||= new Object()
    target['tags'] ||= new Array()
    target['ip'] ||= hmetric.hostname
    target['metrics'] ||= new Object()
    target['metrics'][hmetric.name] ||= new Object()
    for key in Object.keys(hmetric)
      target['metrics'][hmetric.name][key] = hmetric[key]
    target['reported'][hmetric.name] = now

  ###
  Returns the cluster of the metric or assumes the default.
  @param  {Object} (hgmetric) The host information to merge
  @return {String} The name of the cluster for the metric
  ###
  determine_cluster_from_metric: (hmetric) =>
    cluster = hmetric['cluster'] || config.get('cluster')
    delete hmetric['cluster']
    return cluster

  ###
  Generates an xml snapshot of the gmond state.
  @return {String} The ganglia xml snapshot pretty-printed
  ###
  generate_xml_snapshot: =>
    @generate_ganglia_xml().end({ pretty: true, indent: '  ', newline: "\n" })

  ###
  Generates the xml builder for a ganglia xml view.
  @return {Object} The root node of the full ganglia xml view
  ###
  generate_ganglia_xml: =>
    root = @get_gmond_xml_root()
    for cluster in Object.keys(@clusters)
      root = @generate_cluster_element(root, cluster)
    return root

  ###
  Appends the cluster_xml for a single cluster to the a given node.
  @param  {Object} (root) The root node to create the cluster element on
  @param  {String} (cluster) The cluster to generate elements for
  @return {Object} The root node with the newly attached cluster
  ###
  generate_cluster_element: (root, cluster) =>
    if Object.keys(@clusters[cluster].hosts).length == 0
      delete_cluster(cluster)
    ce = root.ele('CLUSTER')
    ce.att('NAME', cluster || config.get('cluster'))
    ce.att('LOCALTIME', @unix_time())
    ce.att('OWNER', @clusters[cluster].owner || config.get('owner'))
    ce.att('LATLONG', @clusters[cluster].latlong || config.get('latlong'))
    ce.att('URL', @clusters[cluster].url || config.get('url'))

    if @clusters[cluster] == undefined
      return root

    hostlist = Object.keys(@clusters[cluster].hosts)
    if hostlist.length == 0
      return root

    for h in hostlist
      ce = @generate_host_element(ce, @hosts[h], h)
    return root

  ###
  Generates a host element for a given host and attaches to the parent.
  @param  {Object} (parent)   The parent node to append the host elem to
  @param  {Object} (hostinfo) The host information for the given host
  @param  {String} (hostname) The hostname of the current host
  @return {Object} The parent node with host elements attached
  ###
  generate_host_element: (parent, hostinfo, hostname) ->
    if hostinfo == undefined
      return parent
    he = parent.ele('HOST')
    he.att('NAME', hostname)
    he.att('IP', hostinfo['ip'])
    he.att('TAGS', (hostinfo['tags'] || []).join(','))
    he.att('REPORTED', hostinfo['host_reported'])
    he.att('TN', @unix_time() - hostinfo['host_reported'])
    he.att('TMAX', hostinfo.tmax || config.get('tmax'))
    he.att('DMAX', hostinfo.dmax || config.get('dmax'))
    he.att('LOCATION', hostinfo.location || config.get('latlong'))
    he.att('GMOND_STARTED', 0)
    for m in Object.keys(hostinfo.metrics)
      he = @generate_metric_element(he, hostinfo, hostinfo.metrics[m])
    return parent

  ###
  Generates the metric element and attaches to the parent.
  @param  {Object} (parent) The parent node to append the metric elem to
  @param  {Object} (host)   The host information for the given metric
  @param  {Object} (metric) The metric to generate metric xml from
  @return {Object} The parent node with metric elements attached
  ###
  generate_metric_element: (parent, hostinfo, metric) ->
    me = parent.ele('METRIC')
    me.att('NAME', metric.name)
    me.att('VAL', metric.value || 0)
    me.att('TYPE', metric.type)
    me.att('UNITS', metric.units)
    me.att('TN', @unix_time() - hostinfo['reported'][metric.name])
    me.att('TMAX', metric.tmax || config.get('tmax'))
    me.att('DMAX', metric.dmax || config.get('dmax'))
    me.att('SLOPE', metric.slope)
    me = @generate_extra_elements(me, metric)
    return parent

  ###
  Generates the extra elems for a metric and attaches to the parent.
  @param  {Object} (parent) The parent node to append the extra data to
  @param  {Object} (metric) The metric to generate extra_elements from
  @return {Object} The parent node with extra elements attached
  ###
  generate_extra_elements: (parent, metric) ->
    extras = @gmetric.extra_elements(metric)
    if extras.length < 1
      return parent

    ed = parent.ele('EXTRA_DATA')
    for extra in extras
      ee = ed.ele('EXTRA_ELEMENT')
      ee.att('NAME', extra.toUpperCase())
      ee.att('VAL', metric[extra])
    return parent

  ###
  Returns the gmond_xml root node to build upon.
  @return {Object} The root gmond xmlbuilder
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
      <!ATTLIST METRICS TYPE (string | int8 | uint8 | int16 | uint16 | int32 | uint32 | int64| uint64 | float | double | timestamp) #REQUIRED>
      <!ATTLIST METRICS UNITS CDATA #IMPLIED>
      <!ATTLIST METRICS SLOPE (zero | positive | negative | both | unspecified) #IMPLIED>
      <!ATTLIST METRICS SOURCE (gmond) 'gmond'>
]"""
    root.att('VERSION', '3.5.0')
    root.att('SOURCE',  'gmond')
    return root

module.exports = Gmond

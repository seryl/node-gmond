dgram = require 'dgram'
Gmond = require '../src/gmond'

Gmetric = require 'gmetric'
async = require 'async'

describe 'Gmond', ->
  gmetric = new Gmetric()
  gmond = null
  metric = {}

  beforeEach (done) ->
    logger.clear()
    gmond = new Gmond()
    metric =
      hostname: 'awesomehost.mydomain.com'
      cluster: 'myexamplecluster'
      group: 'testgroup'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric'
      value: 10
      type: 'int32'
    done()

  afterEach (done) =>
    metric = {}
    config.overrides({})
    gmond.stop_services () =>
      gmond.stop_timers () =>
        gmond = null
        done()

  it "should have a default cluster configuration", (done) =>
    config.get('dmax').should.equal 3600
    config.get('cleanup_threshold').should.equal 300
    config.get('cluster').should.equal 'main'
    config.get('owner').should.equal 'unspecified'
    config.get('latlong').should.equal 'unspecified'
    config.get('url').should.equal '127.0.0.1'
    done()

  it "should be able to add a host with proper packet ordering", (done) =>
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].metrics[metric.name]
      .spoof.should.equal metric.spoof
    parseInt(gmond.hosts[metric.hostname].metrics[metric.name].value)
      .should.equal metric.value
    done()

  it "should be able to add a host with improper ordering", (done) =>
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.data)
    gmond.add_metric(pmetric.meta)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal 'myexamplecluster'
    parseInt(gmond.hosts[metric.hostname].metrics[metric.name].value)
      .should.equal metric.value
    done()

  it "should be able to add a host with no cluster (default)", (done) =>
    delete metric.cluster
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal 'main'
    parseInt(gmond.hosts[metric.hostname].metrics[metric.name].value)
      .should.equal metric.value
    done()

  it "should be able to add a host with a config'd cluster", (done) =>
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal metric.cluster
    parseInt(gmond.hosts[metric.hostname].metrics[metric.name].value)
      .should.equal metric.value
    done()

  it "should be able to generate an xml root", (done) =>
    root = gmond.get_gmond_xml_root()
    root.isRoot.should.equal true
    root.name.should.equal 'GANGLIA_XML'
    done()

  it "shoudle be able to generate extra xml elements", (done) =>
    root = gmond.get_gmond_xml_root()
    gmond.generate_extra_elements(root, metric)
    extra = root.children[0]
    extra.isRoot.should.equal false
    extra.name.should.equal 'EXTRA_DATA'
    extra_elem = extra.children[0]
    extra_elem.name.should.equal 'EXTRA_ELEMENT'
    extra_elem.attributes['NAME'].should.equal 'CLUSTER'
    extra_elem.attributes['VAL'].should.equal 'myexamplecluster'
    done()

  it "should be able to generate a single metric element", (done) =>
    host = new Object()
    now = Math.floor(new Date().getTime() / 1000)
    host['host_reported'] = now
    host['metrics'] = new Object()
    host['metrics']['bestmetric'] = metric
    host['reported'] = new Object()
    host['reported']['bestmetric'] = now

    root = gmond.get_gmond_xml_root()
    gmond.generate_metric_element(root, host, metric)
    metric_elem = root.children[0]
    metric_elem.isRoot.should.equal false
    metric_elem.name.should.equal 'METRIC'
    metric_elem.attributes['NAME'].should.equal 'bestmetric'
    metric_elem.attributes['VAL'].should.equal '10'
    metric_elem.attributes['TYPE'].should.equal 'int32'
    metric_elem.attributes['UNITS'].should.equal 'widgets/sec'
    tn = parseInt(metric_elem.attributes['TN'])
    (tn <= Math.floor(new Date().getTime() / 1000)).should.equal true
    metric_elem.attributes['TMAX'].should.equal '60'
    metric_elem.attributes['DMAX'].should.equal '3600'
    metric_elem.attributes['SLOPE'].should.equal 'positive'
    extra = metric_elem.children[0]
    extra.name.should.equal 'EXTRA_DATA'
    done()

  it "should be able to generate a host xml element", (done) =>
    root = gmond.get_gmond_xml_root()
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    now = Math.floor(new Date().getTime() / 1000)
    hostname = Object.keys(gmond.hosts)[0]
    host = gmond.hosts[hostname]
    gmond.generate_host_element(root, host, hostname)
    host_elem = root.children[0]
    host_elem.name.should.equal 'HOST'
    host_elem.attributes['NAME'].should.equal hostname
    host_elem.attributes['IP'].should.equal hostname
    host_elem.attributes['TAGS'].should.equal ''
    (parseInt(host_elem.attributes['REPORTED']) <= now).should.equal true
    (parseInt(host_elem.attributes['TN']) >= 0).should.equal true
    host_elem.attributes['TMAX'].should.equal '60'
    host_elem.attributes['DMAX'].should.equal '3600'
    host_elem.attributes['LOCATION'].should.equal 'unspecified'
    (parseInt(host_elem.attributes['GMOND_STARTED']) <= now).should.equal true
    m_elem = host_elem.children[0]
    m_elem.name.should.equal 'METRIC'
    done()

  it "should generate location and cluster info", (done) =>
    root = gmond.get_gmond_xml_root()
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    gmond.generate_cluster_element(root, Object.keys(gmond.clusters)[0])
    cluster_elem = root.children[0]
    cluster_elem.name.should.equal 'CLUSTER'
    cluster_elem.attributes['NAME'].should.equal 'myexamplecluster'
    localtime = parseInt(cluster_elem.attributes['LOCALTIME'])
    (localtime <= Math.floor(new Date().getTime() / 1000)).should.equal true
    cluster_elem.attributes['OWNER'].should.equal 'unspecified'
    cluster_elem.attributes['LATLONG'].should.equal 'unspecified'
    cluster_elem.attributes['URL'].should.equal '127.0.0.1'
    host_elem = cluster_elem.children[0]
    host_elem.name.should.equal 'HOST'
    done()

  it "should generate one cluster element per cluster", (done) =>
    metric2 =
      hostname: 'awesomehost2.mydomain.com'
      cluster: 'blehcluster'
      group: 'testgroup2'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric2'
      value: 10
      type: 'int32'

    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    pmetric2 = gmetric.pack(metric2)
    gmond.add_metric(pmetric2.meta)
    gmond.add_metric(pmetric2.data)
    root = gmond.generate_ganglia_xml()
    root.children.length.should.equal 2
    done()

  it "should be able to return an xml cluster for metrics", (done) =>
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    snapshot = gmond.generate_xml_snapshot()
    snapshot.match(/GANGLIA_XML/).should.not.equal null
    done()

  it "should be able to obtain metrics via udp", (done) =>
    sock = dgram.createSocket('udp4')
    monitor = null

    check_complete = () =>
      hosts = Object.keys(gmond.hosts)
      hosts[0].should.equal metric.hostname
      if monitor then clearInterval(monitor)
      done()

    monitor = setInterval(check_complete, 5)
    gmetric.send('127.0.0.1', config.get('gmond_udp_port'), metric)

  it "should be able to cleanup a host when the DMAX has expired", (done) =>
    config.overrides({ 'dmax': 0.1, 'cleanup_threshold': 1 })
    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)

    setTimeout () =>
      Object.keys(gmond.hosts).length.should.equal 0
      done()
    , 1000

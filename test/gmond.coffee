dgram = require 'dgram'
Gmetric = require 'gmetric'
Gmond = require '../lib/gmond'

describe 'Gmond', ->
  gmetric = new Gmetric()
  gmond = null

  beforeEach (done) ->
    gmond = new Gmond()
    done()

  afterEach (done) ->
    gmond.stop_xml_service () =>
      gmond = null
      done()

  it "should have a default cluster configuration", (done) =>
    @config.get('dmax').should.equal 3600
    @config.get('cleanup_threshold').should.equal 300
    @config.get('cluster').should.equal 'main'
    @config.get('owner').should.equal 'unspecified'
    @config.get('latlong').should.equal 'unspecified'
    @config.get('url').should.equal '127.0.0.1'
    done()

  it "should be able to add a host with proper packet ordering", (done) =>
    metric =
      hostname: 'awesomehost.mydomain.com',
      group: 'testgroup'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric'
      value: 10
      type: 'int32'

    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].info.spoof.should.equal metric.spoof
    parseInt(gmond.hosts[metric.hostname].info.value).should.equal metric.value
    done()

  it "should be able to add a host with improper ordering", (done) =>
    metric =
      hostname: 'awesomehost.mydomain.com',
      group: 'testgroup'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric'
      value: 10
      type: 'int32'

    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.data)
    gmond.add_metric(pmetric.meta)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal 'main'
    parseInt(gmond.hosts[metric.hostname].info.value).should.equal metric.value
    done()

  it "should be able to add a host with no cluster (default)", (done) =>
    metric =
      hostname: 'awesomehost.mydomain.com',
      group: 'testgroup'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric'
      value: 10
      type: 'int32'

    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal 'main'
    parseInt(gmond.hosts[metric.hostname].info.value).should.equal metric.value
    done()

  it "should be able to add a host with a config'd cluster", (done) =>
    metric =
      hostname: 'awesomehost.mydomain.com',
      cluster: 'myexamplecluster'
      group: 'testgroup'
      spoof: true
      units: 'widgets/sec'
      slope: 'positive'
      name: 'bestmetric'
      value: 10
      type: 'int32'

    pmetric = gmetric.pack(metric)
    gmond.add_metric(pmetric.meta)
    gmond.add_metric(pmetric.data)
    host = Object.keys(gmond.hosts)[0]
    host.should.equal metric.hostname
    gmond.hosts[metric.hostname].cluster.should.equal metric.cluster
    parseInt(gmond.hosts[metric.hostname].info.value).should.equal metric.value
    done()

  it "should be able to generate a host xml element", (done) =>
    done()

  it "should be able to generate an extra_elem xml element", (done) =>
    done()

  it "should be to generate location and cluster info", (done) =>
    done()

  it "should be able to return an xml cluster for metrics", (done) =>
    done()

  it "should generate one cluster element per cluster", (done) =>
    done()

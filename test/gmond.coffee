dgram = require 'dgram'
Gmetric = require 'gmetric'

describe 'Gmond', ->
  gmetric = new Gmetric()

  beforeEach (done) ->
    done()

  afterEach (done) ->
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
    done()

  it "should be able to add a host with improper ordering", (done) =>
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

    console.log gmetric.pack(metric)
    done()

  it "should be able to add a host with a config'd cluster", (done) =>
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

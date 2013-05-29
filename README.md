node-gmond [![build status](https://secure.travis-ci.org/seryl/node-gmond.png)](https://travis-ci.org/seryl/node-gmond)
============

A node ganglia-gmond service with support for dynamic ganglia clusters

Configuration
-------------

Default options:

```bash
josh@atla: src/node-gmond> ./bin/node-gmond --help
Usage: gmond

Options:
  -c, --config             The configuration file to use                          [default: "/etc/node-gmond.json"]
  -g, --listen_address     The gmond address to listen on                         [default: "127.0.0.1"]
  -t, --gmond_tcp_port     The gmond TCP port to listen on                        [default: 8649]
  -u, --gmond_udp_port     The gmond UDP port to listen on (for XML requests)     [default: 8649]
  -D, --dmax               The dmax of a ganglia host (host TTL for cleanup)      [default: 3600]
  -m, --tmax               The tmax of a ganglia metric (metric TTL for cleanup)  [default: 60]
  -T, --cleanup_threshold  The interval in seconds for checking dmax expiration   [default: 300]
  -C, --cluster            The default ganglia cluster name                       [default: "main"]
  -O, --owner              The default ganglia cluster owner                      [default: "unspecified"]
  -L, --latlong            The default ganglia cluster latlong                    [default: "unspecified"]
  -U, --url                The default ganglia cluster url                        [default: "127.0.0.1"]
  -M, --metadata_interval  The default ganglia send metadata interval             [default: 20]
  -l, --loglevel           Set the log level (debug, info, warn, error, fatal)    [default: "warn"]
  -p, --port               Run the api server on the given port                   [default: 3000]
  -h, --help               Shows this message                                     [default: false]
```

REST Interface
--------------

Currently only returning the version is implemented.

Getting the version
```
curl -sL localhost:3000
```

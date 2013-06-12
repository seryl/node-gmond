global.path = require 'path'
global.os = require 'os'

global.chai = require 'chai'
global.assert = chai.assert

chai.should()

config = require 'nconf'
CLI = require '../../src/cli'

global.cli = new CLI()
global.config = config
global.logger = require '../../src/logger'

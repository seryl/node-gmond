global.path = require 'path'
global.os = require 'os'

global.chai = require 'chai'
global.assert = chai.assert

chai.should()

Config = require '../../src/config'
CLI = require '../../src/cli'

global.cli = new CLI()
global.config = Config.get()

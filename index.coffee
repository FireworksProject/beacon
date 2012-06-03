FS = require 'fs'
PATH = require 'path'
EventEmitter = require('events').EventEmitter

MON = require './lib/monitor'


exports.createService = (args, callback) ->
    service = new EventEmitter()
    args.conf = loadConf(args.confpath)

    service.monitor = MON.createMonitor args, (err, info) ->
        callback(err, info)
        return
    service.monitor.on 'error', (err) ->
        service.emit('error', err)
        return
    service.monitor.on 'log', (msg) ->
        service.emit('log', msg)
        return

    service.close = (callback) ->
        monitor.close(callback)
        return

    return service


loadConf = (confpath) ->
    if not confpath
        throw new Error("missing confpath argument")

    if typeof confpath isnt 'string'
        throw new Error("confpath argument should be a string")

    abspath = PATH.resolve(process.cwd(), confpath)
    try
        text = FS.readFileSync(abspath, 'utf8')
    catch readError
        if readError.code is 'ENOENT'
            throw new Error("cannot find conf file at #{abspath}")
        throw readError

    try
        conf = JSON.parse(text)
    catch jsonError
        msg = "syntax error in config file #{abspath} : #{jsonError.message}"
        throw new Error(msg)

    return conf

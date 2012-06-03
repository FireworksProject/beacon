FS = require 'fs'
PATH = require 'path'
EventEmitter = require('events').EventEmitter

MON = require './lib/monitor'
NOTE = require './lib/notifications'
CSRV = require './lib/confserver'


exports.createService = (args, aCallback) ->
    service = new EventEmitter()
    args.conf = loadConf(args.confpath)

    notifications = NOTE.notifications(args)
    service.notifications = args.notifications = notifications

    notifications.on 'error', (err) ->
        return service.emit('error', err)

    notifications.on 'log', (msg) ->
        return service.emit('log', msg)

    monitor = MON.createMonitor args, (err, info) ->
        confserver = CSRV.createServer args, (addr) ->
            service.close = (callback) ->
                confserver.close ->
                    monitor.close ->
                        notifications.close(callback)
                        return
                    return
                return
            aCallback(err, info)
            return
        return
    service.montitor = args.monitor = monitor

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

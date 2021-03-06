HTTP = require 'http'
EventEmitter = require('events').EventEmitter

exports.createServer = (aOpts, aCallback) ->
    port = aOpts.port or 8080
    hostname = aOpts.hostname or 'localhost'
    restartTimeout = if typeof aOpts.restartTimeout is 'number'
        aOpts.restartTimeout
    else 7000
    monitor = aOpts.monitor
    webappChannel = monitor.createChannel('webapp_conf')
    emitter = new EventEmitter()

    requestHandler = (req, res) ->
        # TODO: Handle 404, route handlers, and all that other stuff a real
        # web service should be doing

        # TODO
        # req.on 'error', (err) ->
        # res.on 'error', (err) ->

        body = ''
        req.setEncoding('utf8')
        req.on 'data', (chunk) ->
            body += chunk
            return

        req.on 'end', ->
            try
                conf = JSON.parse(body)
            catch jsonError
                resbody = JSON.stringify({
                    result: "invalid JSON: #{jsonError.message}"
                })
                res.writeHead(400, headers(resbody))
                res.end(resbody)
                return
            return commitAppChanges(conf, res)
        return

    commitAppChanges = (conf, res) ->
        # TODO: handle conf validation errors
        appname = conf.name
        timeout = null

        onAppRestart = (msg) ->
            if msg isnt appname then return
            emitter.removeListener('webapp_restart', onAppRestart)
            clearTimeout(timeout)
            respondOK()
            return

        respondOK = ->
            if timeout is null then return
            resbody = JSON.stringify({
                result: "#{appname} restarted"
            })
            res.writeHead(201, headers(resbody))
            res.end(resbody)
            return

        respondFail = ->
            timeout = null
            resbody = JSON.stringify({
                result: "#{appname} did not restart"
            })
            res.writeHead(504, headers(resbody))
            res.end(resbody)
            return

        emitter.on('webapp_restart', onAppRestart)
        timeout = setTimeout(respondFail, restartTimeout)
        webappChannel.publish(appname)
        return

    monitor.subscribe 'webapp_restart', (msg) ->
        return emitter.emit('webapp_restart', msg)

    server = HTTP.createServer(requestHandler)

    serverClose = server.close
    server.close = (callback) ->
        onclose = ->
            server.removeListener('close', onclose)
            if typeof callback is 'function' then return callback()
            return
        server.on('close', onclose)
        serverClose.call(server)
        return

    server.listen port, hostname, ->
        return aCallback(server.address())

    return server


headers = (body) ->
    rv =
        'content-type': 'application/json'
        'content-length': Buffer.byteLength(body)
    return rv

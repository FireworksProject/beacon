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

        req.on 'error', (err) ->
            localError = new Error('confserver request error')
            localError.stack += err.stack
            return server.emit('error', localError)

        res.on 'error', (err) ->
            localError = new Error('confserver response error')
            localError.stack += err.stack
            return server.emit('error', localError)

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
                res.writeHead(400, {
                    'content-type': 'application/json'
                    'content-length': Buffer.byteLength(resbody)
                })
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
            res.writeHead(201, {
                'content-type': 'application/json'
                'content-length': Buffer.byteLength(resbody)
            })
            res.end(resbody)
            return

        respondFail = ->
            timeout = null
            resbody = JSON.stringify({
                result: "#{appname} did not restart"
            })
            res.writeHead(504, {
                'content-type': 'application/json'
                'content-length': Buffer.byteLength(resbody)
            })
            res.end(resbody)
            return

        emitter.on('webapp_restart', onAppRestart)
        timeout = setTimeout(respondFail, restartTimeout)
        webappChannel.publish(appname)
        return

    monitor.subscribe 'webapp_restart', (msg) ->
        return emitter.emit('webapp_restart', msg)

    server = HTTP.createServer(requestHandler)

    server.listen port, hostname, ->
        return aCallback(server.address())

    return server

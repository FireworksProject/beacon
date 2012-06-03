REQ = require 'request'

describe 'mocked tests', ->
    SRV = require '../dist/lib/confserver'

    gServer = null


    class MockedMonitor

        createChannel: (name) ->
            return new MockedChannel(name)

        subscribe: (name, listener) ->
            return


    class MockedChannel

        publish: (message) ->
            return


    createServer = (aMonitor, aOpts, aCallback) ->
        opts =
            port: null # Defaults to 8080
            hostname: null # Defaults to 'localhost'
            webappMonitor: aMonitor

        if typeof aOpts is 'object'
            for own p, v of aOpts
                opts[p] = v
        else aCallback = aOpts

        gServer = SRV.createServer(opts, aCallback)
        return gServer


    afterEach (done) ->
        gServer.on 'close', ->
            return done()
        gServer.close()
        return


    it 'should start on default port and hostname', (done) ->
        createServer new MockedMonitor(), (addr) ->
            expect(addr.port).toBe(8080)
            expect(addr.address).toBe('127.0.0.1')
            done()
            return
        return


    it 'should catch JSON errors', (done) ->
        test = ->
            opts =
                uri: 'http://localhost:8080'
                body: ''
            REQ.post opts, (err, res, body) ->
                expect(res.statusCode).toBe(400)
                body = JSON.parse(body)
                expect(body.result).toBe("invalid JSON: Unexpected end of input")
                return done()
            return

        createServer(new MockedMonitor(), test)
        return


    it 'should timeout if the webapp server does not respond to a restart', (done) ->
        test = ->
            opts =
                uri: 'http://localhost:8080'
                body: JSON.stringify({name: 'myapp'})
            REQ.post opts, (err, res, body) ->
                expect(res.statusCode).toBe(504)
                body = JSON.parse(body)
                expect(body.result).toBe('myapp did not restart')
                return done()
            return

        createServer(new MockedMonitor(), {restartTimeout: 0}, test)
        return

    return

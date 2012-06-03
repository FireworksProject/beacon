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


    createServer = (monitor, callback) ->
        opts =
            port: null # Defaults to 8080
            hostname: null # Defaults to 'localhost'
            webappMonitor: monitor
        gServer = SRV.createServer(opts, callback)
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

    return

REQ = require 'request'

describe 'mocked tests', ->
    SRV = require '../dist/lib/confserver'

    APPNAME = 'myapp'
    gServer = null


    class MockedMonitor
        createChannel: (name) ->
            return new MockedChannel(name)

        subscribe: (name, listener) ->
            setTimeout(->
                return listener(APPNAME)
            , 20)
            return


    class MockedChannel

        publish: (message) ->
            return


    createServer = (aMonitor, aOpts, aCallback) ->
        opts =
            port: null # Defaults to 8080
            hostname: null # Defaults to 'localhost'
            monitor: aMonitor

        if typeof aOpts is 'object'
            for own p, v of aOpts
                opts[p] = v
        else aCallback = aOpts

        gServer = SRV.createServer(opts, aCallback)
        return gServer


    afterEach (done) ->
        if gServer is null then return done()
        gServer.close ->
            gServer = null
            return done()
        return


    it 'should start on default port and hostname', (done) ->
        @expectCount(2)
        createServer new MockedMonitor(), (addr) ->
            expect(addr.port).toBe(8080)
            expect(addr.address).toBe('127.0.0.1')
            done()
            return
        return


    it 'should catch JSON errors', (done) ->
        @expectCount(3)
        test = ->
            opts =
                uri: 'http://localhost:8080'
                body: ''
            REQ.post opts, (err, res, body) ->
                expect(res.statusCode).toBe(400)
                expect(res.headers['content-type']).toBe('application/json')
                body = JSON.parse(body)
                expect(body.result).toBe("invalid JSON: Unexpected end of input")
                return done()
            return

        createServer(new MockedMonitor(), test)
        return


    it 'should timeout if the webapp server does not respond to a restart', (done) ->
        @expectCount(3)
        test = ->
            opts =
                uri: 'http://localhost:8080'
                body: JSON.stringify({name: 'myapp'})
            REQ.post opts, (err, res, body) ->
                expect(res.statusCode).toBe(504)
                expect(res.headers['content-type']).toBe('application/json')
                body = JSON.parse(body)
                expect(body.result).toBe('myapp did not restart')
                return done()
            return

        createServer(new MockedMonitor(), {restartTimeout: 0}, test)
        return


    it 'should confirm application restart', (done) ->
        @expectCount(3)
        test = ->
            opts =
                uri: 'http://localhost:8080'
                body: JSON.stringify({name: APPNAME})
            REQ.post opts, (err, res, body) ->
                expect(res.statusCode).toBe(201)
                expect(res.headers['content-type']).toBe('application/json')
                body = JSON.parse(body)
                expect(body.result).toBe("#{APPNAME} restarted")
                return done()
            return

        createServer(new MockedMonitor(), test)
        return


    it 'should close and emit a close event', (done) ->
        @expectCount(2)
        gotEvent = no
        gotCallback = no

        maybeDone = ->
            if gotEvent and gotCallback then return done()
            return

        opts =
            port: null # Defaults to 8080
            hostname: null # Defaults to 'localhost'
            monitor: new MockedMonitor()
        server = SRV.createServer opts, (addr) ->
            server.close ->
                gotCallback = yes
                expect('close callback').toExecute()
                return maybeDone()
            return

        server.on 'close', ->
            gotEvent = yes
            expect('close event').toExecute()
            return maybeDone()

        return

    return

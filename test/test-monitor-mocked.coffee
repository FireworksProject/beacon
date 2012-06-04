EventEmitter = require('events').EventEmitter

DEFAULT_TEST_CONF =
    hostname: 'localhost'
    port: 7272


describe 'mock functionality', ->
    TEL = require '../dist/node_modules/telegram'
    MON = require '../dist/lib/monitor'

    gMonitor = null

    startMonitor = (notifications, callback) ->
        args =
            notifications: notifications
            conf: DEFAULT_TEST_CONF
        gMonitor = MON.createMonitor args, (err, monitor) ->
            return callback(gMonitor)
        return

    afterEach (done) ->
        if gMonitor is null then return done()
        gMonitor.close ->
            gMonitor = null
            done()
            return
        return


    it 'should raise an exception for invalid port conf', (done) ->
        @expectCount(2)
        try
            MON.createMonitor({conf: {hostname: 'localhost'}})
        catch err
            expect(err.message).toBe('invalid conf.port')
        try
            MON.createMonitor({conf: {hostname: 'localhost', port: 'foobar'}})
        catch err
            expect(err.message).toBe('invalid conf.port')
        return done()


    it 'should raise an exception for invalid hostname conf', (done) ->
        @expectCount(2)
        try
            MON.createMonitor({conf: {port: 80}})
        catch err
            expect(err.message).toBe('invalid conf.hostname')
        try
            MON.createMonitor({conf: {hostname: true, port: 80}})
        catch err
            expect(err.message).toBe('invalid conf.hostname')
        return done()


    it 'should send out warning emails', (done) ->
        @expectCount(2)
        warningMessage = "This is a warning message"

        notes =
            sendMail: (subject, body) ->
                expect(subject).toBe('WARNING from webserver')
                expect(body).toBe(warningMessage)
                return done()

        startMonitor notes, (monitor) ->
            {port, hostname} = DEFAULT_TEST_CONF
            connection = TEL.connect port, hostname, ->
                channel = connection.createChannel('warning')
                process.nextTick ->
                    channel.publish(JSON.stringify({stack: warningMessage}))
                    return
                return
            return
        return


    it 'should send out failure email and SMS', (done) ->
        @expectCount(3)
        failureStack = "This is an error stack trace"
        failureMessage = "This is an error message"
        smscount = 0

        notes =
            sendMail: (subject, body) ->
                expect(subject).toBe('FAILURE from webserver')
                expect(body).toBe(failureStack)
                return done()
            sendSMS: (message) ->
                expect(message).toBe(failureMessage)
                smscount += 1
                if smscount is 2 then return done()
                return

        startMonitor notes, (monitor) ->
            {port, hostname} = DEFAULT_TEST_CONF
            connection = TEL.connect port, hostname, ->
                channel = connection.createChannel('failure')
                process.nextTick ->
                    msg = {stack: failureStack, message: failureMessage}
                    channel.publish(JSON.stringify(msg))
                    return
                return
            return
        return


    it 'should send heartbeat timeout email and SMS', (done) ->
        @expectCount(3)
        failureMessage = 'heartbeat timeout'
        smscount = 0

        notes =
            sendMail: (subject, body) ->
                expect(subject).toBe('TIMEOUT from webserver')
                expect(body).toBe(failureMessage)
                return done()
            sendSMS: (message) ->
                expect(message).toBe(failureMessage)
                smscount += 1
                if smscount is 2 then return done()
                return

        startMonitor notes, (monitor) ->
            {port, hostname} = DEFAULT_TEST_CONF
            connection = TEL.connect port, hostname, ->
                channel = connection.createChannel('heartbeat')
                process.nextTick ->
                    channel.publish('ok')
                    return
                return
            return
        return


    return

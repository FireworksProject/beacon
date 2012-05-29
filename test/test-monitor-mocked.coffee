describe 'init errors', ->
    BEACON = require '../dist'

    it 'should throw an error for missing mailUsername', (done) ->
        @expectCount(1)

        args =
            mailUsername: null
            mailPassword: 'anystring'
            smsUsername: 'anystring'
            smsPassword: 'anystring'
            conf:
                hostname: 'localhost'
                port: 7272
                mail_list: ["foo@example.com", "bar@example.com"]
                sms_address: "5555555555"
                sms_list: ["5555555555", "5555555555"]
                heartbeat_timeout: 1

        try
            BEACON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing mail username argument')

        return done()


    it 'should throw an error for missing mailPassword', (done) ->
        @expectCount(1)

        args =
            mailUsername: 'anystring'
            mailPassword: null
            smsUsername: 'anystring'
            smsPassword: 'anystring'
            conf:
                hostname: 'localhost'
                port: 7272
                mail_list: ["foo@example.com", "bar@example.com"]
                sms_address: "5555555555"
                sms_list: ["5555555555", "5555555555"]
                heartbeat_timeout: 1

        try
            BEACON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing mail password argument')

        return done()


    it 'should throw an error for missing smsUsername', (done) ->
        @expectCount(1)

        args =
            mailUsername: 'anystring'
            mailPassword: 'anystring'
            smsUsername: null
            smsPassword: 'anystring'
            conf:
                hostname: 'localhost'
                port: 7272
                mail_list: ["foo@example.com", "bar@example.com"]
                sms_address: "5555555555"
                sms_list: ["5555555555", "5555555555"]
                heartbeat_timeout: 1

        try
            BEACON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing SMS username argument')

        return done()


    it 'should throw an error for missing smsPassword', (done) ->
        @expectCount(1)

        args =
            mailUsername: 'anystring'
            mailPassword: 'anystring'
            smsUsername: 'anystring'
            smsPassword: null
            conf:
                hostname: 'localhost'
                port: 7272
                mail_list: ["foo@example.com", "bar@example.com"]
                sms_address: "5555555555"
                sms_list: ["5555555555", "5555555555"]
                heartbeat_timeout: 1

        try
            BEACON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing SMS password argument')

        return done()

    return


describe 'mock functionality', ->
    Q = require 'q'

    TEL = require '../dist/node_modules/telegram'
    MAIL = require '../dist/node_modules/nodemailer'
    SMS = require '../dist/node_modules/q-smsified'
    BEACON = require '../dist'

    gMailCreateTransport = MAIL.createTransport
    gSMSSession = SMS.Session
    gMonitor = null
    gFromEmail = "SAKS Monitor <#{TESTARGV.mail_username}>"
    gToEmail = 'foo@example.com, bar@example.com'

    startMonitor = (callback) ->
        args =
            mailUsername: TESTARGV.mail_username
            mailPassword: TESTARGV.mail_password
            smsUsername: TESTARGV.sms_username
            smsPassword: TESTARGV.sms_password
            conf:
                hostname: 'localhost'
                port: 7272
                mail_list: ["foo@example.com", "bar@example.com"]
                sms_address: "5555555555"
                sms_list: ["5555555555", "5555555555"]
                heartbeat_timeout: 1
        gMonitor = BEACON.createMonitor args, (err, monitor) ->
            return callback(gMonitor)
        return

    afterEach (done) ->
        MAIL.createTransport = gMailCreateTransport
        SMS.Session = gSMSSession

        if gMonitor is null then return done()
        gMonitor.close ->
            gMonitor = null
            done()
            return
        return


    it 'should create an SMS session', (done) ->
        @expectCount(3)

        SMS.Session = (spec) ->
            expect(spec.username).toBe(TESTARGV.sms_username)
            expect(spec.password).toBe(TESTARGV.sms_password)
            expect(spec.address).toBe(TESTARGV.sms_sender)
            return

        startMonitor (monitor) -> return done()
        return


    it 'should create a mail transport', (done) ->
        @expectCount(4)

        MAIL.createTransport = (type, opts) ->
            expect(type).toBe('SMTP')
            expect(opts.service).toBe('Gmail')
            expect(opts.auth.user).toBe(TESTARGV.mail_username)
            expect(opts.auth.pass).toBe(TESTARGV.mail_password)

            transport = {}
            transport.close = (callback) ->
                return callback()
            return transport

        startMonitor (monitor) -> return done()
        return


    it 'should send out warning emails', (done) ->
        @expectCount(5)
        warningMessage = "This is a warning message"

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                expect(opts.from).toBe(gFromEmail)
                expect(opts.to).toBe(gToEmail)
                expect(opts.subject).toBe('WARNING from webserver')
                expect(opts.text).toBe(warningMessage)
                callback(null, {message: "sent"})
                return

            return transport

        startMonitor (monitor) ->
            monitor.on 'log', (msg) ->
                if /^Email\sMessage:/.test(msg)
                    expect(msg).toBe("Email Message: sent")
                    return done()
                return

            connection = TEL.connect 7272, 'localhost', ->
                channel = connection.createChannel('warning')
                process.nextTick ->
                    channel.publish(JSON.stringify({stack: warningMessage}))
                    return
                return
            return
        return


    it 'should send out failure email and SMS', (done) ->
        @expectCount(11)
        failureStack = "This is an error stack trace"
        failureMessage = "This is an error message"

        SMS.Session = (spec) ->
            session = {}
            session.send = (target, message) ->
                expect(target).toBe('5555555555')
                expect(message).toBe(failureMessage)

                deferred = Q.defer()
                deferred.resolve({code: 201, data: {resourceURL: "http://foo"}})
                return deferred.promise
            return session

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                expect(opts.from).toBe(gFromEmail)
                expect(opts.to).toBe(gToEmail)
                expect(opts.subject).toBe('FAILURE from webserver')
                expect(opts.text).toBe(failureStack)
                callback(null, {message: "sent"})
                return

            return transport

        startMonitor (monitor) ->
            smscount = 0
            monitor.on 'log', (msg) ->
                if /^Email\sMessage:/.test(msg)
                    expect(msg).toBe("Email Message: sent")
                if /^SMS\sMessage:/.test(msg)
                    expect(msg).toBe("SMS Message: http://foo")
                    smscount += 1
                    if smscount is 2 then return done()
                return

            connection = TEL.connect 7272, 'localhost', ->
                channel = connection.createChannel('failure')
                process.nextTick ->
                    msg = {stack: failureStack, message: failureMessage}
                    channel.publish(JSON.stringify(msg))
                    return
                return
            return
        return


    it 'should send heartbeat timeout email and SMS', (done) ->
        @expectCount(11)
        failureMessage = 'heartbeat timeout'

        SMS.Session = (spec) ->
            session = {}
            session.send = (target, message) ->
                expect(target).toBe('5555555555')
                expect(message).toBe(failureMessage)

                deferred = Q.defer()
                deferred.resolve({code: 201, data: {resourceURL: "http://foo"}})
                return deferred.promise
            return session

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                expect(opts.from).toBe(gFromEmail)
                expect(opts.to).toBe(gToEmail)
                expect(opts.subject).toBe('TIMEOUT from webserver')
                expect(opts.text).toBe(failureMessage)
                callback(null, {message: "sent"})
                return

            return transport

        startMonitor (monitor) ->
            smscount = 0

            monitor.on 'log', (msg) ->
                if /^Email\sMessage:/.test(msg)
                    expect(msg).toBe("Email Message: sent")
                if /^SMS\sMessage:/.test(msg)
                    smscount += 1
                    expect(msg).toBe("SMS Message: http://foo")
                    if smscount is 2 then return done()
                    return
                return

            connection = TEL.connect 7272, 'localhost', ->
                channel = connection.createChannel('heartbeat')
                process.nextTick ->
                    channel.publish('ok')
                    return
                return
            return
        return


    it 'should emit SMS and Email service errors', (done) ->
        @expectCount(5)

        SMS.Session = (spec) ->
            session = {}
            session.send = (target, message) ->
                deferred = Q.defer()
                serviceException =
                    errorCode: 'SVC001'
                    msg: "Unauthenticated"
                requestError = {serviceException: serviceException}
                deferred.resolve({code: 401, data: {requestError: requestError}})
                return deferred.promise
            return session

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                callback(new Error("Invalid User"))
                return

            return transport

        startMonitor (monitor) ->
            messageCount = 0
            monitor.on 'error', (err) ->
                messageCount += 1

                if /^Error\ssending\semail/.test(err.message)
                    expect(err.message).toBe("Error sending email notification: Invalid User")

                if err.err
                    expect(err.err.message).toBe('Unexpected response from SMS service')
                    expect(err.err.code).toBe(401)

                if messageCount is 3 then return done()
                return

            connection = TEL.connect 7272, 'localhost', ->
                channel = connection.createChannel('failure')
                process.nextTick ->
                    msg = {stack: 'stack', message: 'message'}
                    channel.publish(JSON.stringify(msg))
                    return
                return
            return
        return


    return

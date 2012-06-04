DEFAULT_TEST_CONF =
    hostname: 'localhost'
    port: 7272
    mail_list: ["foo@example.com", "bar@example.com"]
    sms_address: "5555555555"
    sms_list: ["5555555555", "5555555555"]
    heartbeat_timeout: 1

describe 'init errors', ->
    NOTE = require '../dist/lib/notifications'

    it 'should throw an error for missing mailUsername', (done) ->
        @expectCount(1)

        args =
            mailUsername: null
            mailPassword: 'anystring'
            smsUsername: 'anystring'
            smsPassword: 'anystring'
            conf: DEFAULT_TEST_CONF

        try
            NOTE.notifications(args)
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
            conf: DEFAULT_TEST_CONF

        try
            NOTE.notifications(args)
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
            conf: DEFAULT_TEST_CONF

        try
            NOTE.notifications(args)
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
            conf: DEFAULT_TEST_CONF

        try
            NOTE.notifications(args)
        catch err
            expect(err.message).toBe('missing SMS password argument')

        return done()

    return


describe 'mock functionality', ->
    Q = require 'q'

    NOTE = require '../dist/lib/notifications'
    SMS = require '../dist/node_modules/q-smsified'
    MAIL = require '../dist/node_modules/nodemailer'

    gMailCreateTransport = MAIL.createTransport
    gSMSSession = SMS.Session
    gService = null

    createService = ->
        args =
            mailUsername: TESTARGV.mail_username
            mailPassword: TESTARGV.mail_password
            smsUsername: TESTARGV.sms_username
            smsPassword: TESTARGV.sms_password
            conf: DEFAULT_TEST_CONF
        gService = NOTE.notifications(args)
        return gService

    afterEach (done) ->
        MAIL.createTransport = gMailCreateTransport
        SMS.Session = gSMSSession
        if gService is null then return done()
        gService.close ->
            gService = null
            return done()
        return

    it 'should create an SMS session', (done) ->
        @expectCount(3)

        SMS.Session = (spec) ->
            expect(spec.username).toBe(TESTARGV.sms_username)
            expect(spec.password).toBe(TESTARGV.sms_password)
            expect(spec.address).toBe(TESTARGV.sms_sender)
            return

        createService()
        return done()


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

        createService()
        return done()


    it 'should emit SMS and Email log events', (done) ->
        @expectCount(3)

        SMS.Session = (spec) ->
            session = {}
            session.send = (target, message) ->
                deferred = Q.defer()
                deferred.resolve({code: 201, data: {resourceURL: 'foo'}})
                return deferred.promise
            return session

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                callback(null, {message: 'sent'})
                return

            return transport

        notifications = createService()
        messageCount = 0

        notifications.on 'log', (msg) ->
            messageCount += 1

            if /^Email\sMessage:/.test(msg)
                expect(msg).toBe("Email Message: sent")

            if /^SMS\sMessage:/.test(msg)
                expect(msg).toBe('SMS Message: foo')

            if messageCount is 3 then return done()
            return

        notifications.sendMail('1', '1')
        notifications.sendSMS('1', '1')
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

        notifications = createService()
        messageCount = 0

        notifications.on 'error', (err) ->
            messageCount += 1

            if /^Error\ssending\semail/.test(err.message)
                expect(err.message).toBe("Error sending email notification: Invalid User")

            if err.err
                expect(err.err.message).toBe('Unexpected response from SMS service')
                expect(err.err.code).toBe(401)

            if messageCount is 3 then return done()
            return

        notifications.sendMail('1', '1')
        notifications.sendSMS('1', '1')
        return

    return

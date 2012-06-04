DEFAULT_TEST_CONF =
    mail_list: ["foo@example.com", "bar@example.com"]
    sms_address: "5555555555"
    sms_list: ["5555555551", "5555555552"]

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
    EMAIL_FROM_ADDR = "SAKS Monitor <#{TESTARGV.mail_username}>"

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


    it 'should send out emails', (done) ->
        @expectCount(4)

        MAIL.createTransport = ->
            transport = {}

            transport.close = (callback) ->
                return callback()

            transport.sendMail = (opts, callback) ->
                expect(opts.from).toBe(EMAIL_FROM_ADDR)
                expect(opts.to).toBe(DEFAULT_TEST_CONF.mail_list.join(', '))
                expect(opts.subject).toBe('a subject line')
                expect(opts.text).toBe('a message')
                return done()

            return transport

        notifications = createService()
        notifications.sendMail('a subject line', 'a message')
        return


    it 'should send out sms messages', (done) ->
        @expectCount(4)
        counter = 0

        SMS.Session = (spec) ->
            session = {}
            session.send = (target, message) ->
                expect(target).toBe(DEFAULT_TEST_CONF.sms_list[counter])
                expect(message).toBe('a message')

                counter += 1
                if counter is 2 then return done()
                deferred = Q.defer()
                deferred.resolve({code: 201, data: {resourceURL: 'foo'}})
                return deferred.promise
            return session

        notifications = createService()
        notifications.sendSMS('a message')
        return


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


    it 'should close and emit a close event', (done) ->
        @expectCount(2)
        gotEvent = no
        gotCallback = no

        maybeDone = ->
            if gotEvent and gotCallback then return done()
            return

        args =
            mailUsername: TESTARGV.mail_username
            mailPassword: TESTARGV.mail_password
            smsUsername: TESTARGV.sms_username
            smsPassword: TESTARGV.sms_password
            conf: DEFAULT_TEST_CONF
        notifications = NOTE.notifications(args)

        notifications.on 'close', ->
            gotEvent = yes
            expect('close event').toExecute()
            return maybeDone()

        notifications.close ->
            gotCallback = yes
            expect('got callback').toExecute()
            return maybeDone()
        return

    return

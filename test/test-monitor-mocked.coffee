describe 'init errors', ->
    MON = require '../dist/lib/monitor'

    it 'should throw an error for missing MAIL_USERNAME', (done) ->
        @expectCount(1)

        args =
            MAIL_USERNAME: null
            MAIL_PASSWORD: 'anystring'
            SMS_USERNAME: 'anystring'
            SMS_PASSWORD: 'anystring'

        try
            MON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing mail username argument')

        return done()


    it 'should throw an error for missing MAIL_PASSWORD', (done) ->
        @expectCount(1)

        args =
            MAIL_USERNAME: 'anystring'
            MAIL_PASSWORD: null
            SMS_USERNAME: 'anystring'
            SMS_PASSWORD: 'anystring'

        try
            MON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing mail password argument')

        return done()


    it 'should throw an error for missing SMS_USERNAME', (done) ->
        @expectCount(1)

        args =
            MAIL_USERNAME: 'anystring'
            MAIL_PASSWORD: 'anystring'
            SMS_USERNAME: null
            SMS_PASSWORD: 'anystring'

        try
            MON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing SMS username argument')

        return done()


    it 'should throw an error for missing SMS_PASSWORD', (done) ->
        @expectCount(1)

        args =
            MAIL_USERNAME: 'anystring'
            MAIL_PASSWORD: 'anystring'
            SMS_USERNAME: 'anystring'
            SMS_PASSWORD: null

        try
            MON.createMonitor(args)
        catch err
            expect(err.message).toBe('missing SMS password argument')

        return done()

    return


describe 'mock functionality', ->
    Q = require 'q'

    TEL = require '../dist/node_modules/telegram'
    MAIL = require '../dist/node_modules/nodemailer'
    SMS = require '../dist/node_modules/q-smsified'
    MON = require '../dist/lib/monitor'

    gMailCreateTransport = MAIL.createTransport
    gSMSSession = SMS.Session
    gMonitor = null
    gFromEmail = "SAKS Monitor <#{TESTARGV.mail_username}>"
    gToEmail = 'foo@example.com, bar@example.com'

    startMonitor = (callback) ->
        args =
            MAIL_USERNAME: TESTARGV.mail_username
            MAIL_PASSWORD: TESTARGV.mail_password
            SMS_USERNAME: TESTARGV.sms_username
            SMS_PASSWORD: TESTARGV.sms_password
        gMonitor = MON.createMonitor args, (err, monitor) ->
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

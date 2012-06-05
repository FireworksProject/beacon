BCN = require '../dist/'


DEF_TEST_ARGS =
    confpath: './test/fixtures/conf.json'
    mailUsername: TESTARGV.mail_username
    mailPassword: TESTARGV.mail_password
    smsUsername: TESTARGV.sms_username
    smsPassword: TESTARGV.sms_password
    smsSender: TESTARGV.sms_sender


describe 'invalid args', ->

    createService = (opts, callback) ->
        defaults = {}
        for own p, v of DEF_TEST_ARGS
            defaults[p] = v

        if typeof opts is 'function'
            callback = opts
        else
            for own p, v of opts
                defaults[p] = v

        return BCN.createService(defaults, callback)


    it 'should throw error if confpath is dir', (done) ->
        @expectCount(1)
        try
            service = createService {confpath: './test/fixtures/'}, (err, info) ->
                return
        catch err
            expect(/is a directory, not a file$/.test(err.message)).toBeTruthy()
        return done()


    it 'should throw error if confpath cannot be found', (done) ->
        @expectCount(1)
        try
            service = createService {confpath: './test/fixtures/foobar'}, (err, info) ->
                return
        catch err
            expect(/^cannot find conf file at/.test(err.message)).toBeTruthy()
        return done()


    it 'should throw error if conf file contains syntax error', (done) ->
        @expectCount(1)
        try
            service = createService {confpath: './test/fixtures/syntax-error.json'}, (err, info) ->
                return
        catch err
            expect(/^syntax error in conf file/.test(err.message)).toBeTruthy()
        return done()

    return


describe 'runtests', ->
    gService = null

    createService = (opts, callback) ->
        defaults = {}
        for own p, v of DEF_TEST_ARGS
            defaults[p] = v

        if typeof opts is 'function'
            callback = opts
        else
            for own p, v of opts
                defaults[p] = v

        gService = BCN.createService(defaults, callback)
        return gService

    afterEach (done) ->
        if gService is null then return done()
        gService.close ->
            gService = null
            return done()
        return


    it 'should', (done) ->
        service = createService ->
            done()
            return
        return
    return

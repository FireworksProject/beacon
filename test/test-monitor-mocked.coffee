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


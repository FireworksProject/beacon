HTTP = require 'http'
EventEmitter = require('events').EventEmitter

TEL = require 'telegram'
MAIL = require 'nodemailer'
SMS = require 'q-smsified'


exports.createServer = (aOpts, aCallback) ->
    requestHandler = (req, res) ->
        return

    server = HTTP.createServer(requestHandler)

    {host, port} = sanityCheck(aOpts)

    server.listen port, hostname, ->
        return aCallback(server.address())

    return server


exports.createMonitor = (aArgs, aCallback) ->
    self = new EventEmitter
    mArgs = aArgs
    mConf = aArgs.conf or {}
    mTelegramServer = null
    mMailTransport = null

    if not aArgs.mailUsername
        throw new Error("missing mail username argument")

    if not aArgs.mailPassword
        throw new Error("missing mail password argument")

    if not aArgs.smsUsername
        throw new Error("missing SMS username argument")

    if not aArgs.smsPassword
        throw new Error("missing SMS password argument")

    if not mConf.port or typeof mConf.port isnt 'number'
        throw new Error("invalid conf.port")

    if not mConf.hostname or typeof mConf.hostname isnt 'string'
        throw new Error("invalid conf.hostname")

    if not mConf.sms_address or parseInt(mConf.sms_address) is NaN
        throw new Error("invalid conf.sms_address")

    if not Array.isArray(mConf.mail_list)
        throw new Error("invalid conf.mail_list")

    if not Array.isArray(mConf.sms_list)
        throw new Error("invalid conf.sms_list")

    if not mConf.heartbeat_timeout or typeof mConf.heartbeat_timeout isnt 'number'
        mConf.heartbeat_timeout = 1

    mTelegramServer = TEL.createServer()

    mTelegramServer.listen mConf.port, mConf.hostname, ->
        return aCallback(null, {telegramServer: mTelegramServer})


    mTelegramServer.subscribe 'heartbeat', (message) ->
        mClearHBTimer()
        return


    mTelegramServer.subscribe 'warning', (err) ->
        err = JSON.parse(err)
        sendMail('WARNING from webserver', err.stack)
        return


    mTelegramServer.subscribe 'failure', (err) ->
        err = JSON.parse(err)
        sendSMS(err.message)
        sendMail('FAILURE from webserver', err.stack)
        return


    sendMail = (aSubject, aBody) ->
        opts =
            from: "SAKS Monitor <#{mArgs.mailUsername}>"
            to: mConf.mail_list.join(', ')
            subject: aSubject
            text: aBody

        mMailTransport.sendMail opts, (err, res) ->
            if err
                err.message = "Error sending email notification: #{err.message}"
                self.emit 'error', err
                return

            self.emit 'log', "Email Message: #{res.message}"
            return
        return


    sendSMS = (aBody) ->
        log = (res) ->
            if res.code isnt 201
                err =
                    message: "Unexpected response from SMS service"
                    code: res.code
                    stack: res.data.requestError.serviceException
                self.emit 'error', {err: err}
                return

            self.emit 'log', "SMS Message: #{res.data.resourceURL}"
            return

        for target in mConf.sms_list
            mSMSSession.send(target, aBody).then(log).fail (err) ->
                err.message = "Error sending SMS notification: #{err.message}"
                self.emit 'error', err
                return
        return


    mMailTransport = MAIL.createTransport('SMTP', {
            service: 'Gmail'
            auth: {user: mArgs.mailUsername, pass: mArgs.mailPassword}
        })


    mSMSSession = new SMS.Session({
        username: mArgs.smsUsername
        password: mArgs.smsPassword
        address: mConf.sms_address
    })


    mClearHBTimer = do ->
        timeout = null
        clear = ->
            if timeout isnt null then clearTimeout(timeout)
            timeout = setTimeout(->
                sendSMS('heartbeat timeout')
                sendMail('TIMEOUT from webserver', 'heartbeat timeout')
            , mConf.heartbeat_timeout * 1000)
            return
        return clear


    self.close = (callback) ->
        mTelegramServer.on('close', callback)
        mMailTransport.close -> mTelegramServer.close()
        return

    return self

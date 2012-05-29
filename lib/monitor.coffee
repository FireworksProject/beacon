EventEmitter = require('events').EventEmitter

Logger = require 'bunyan'
TEL = require 'telegram'
MAIL = require 'nodemailer'
SMS = require 'q-smsified'

LOG = new Logger({
    name: 'monitor'
    streams: [
        {level: 'info', stream: process.stdout}
        {level: 'error', stream: process.stderr}
    ]
})

CONFDIR = '/etc/saks-monitor'

MAIL_USERNAME = process.argv[2]
MAIL_PASSWORD = process.argv[3]
SMS_USERNAME = process.argv[4]
SMS_PASSWORD = process.argv[5]

exports.createMonitor = (aArgs, aCallback) ->
    self = new EventEmitter
    mTelegramServer = null
    mMailTransport = null

    {args, conf} = sanityCheck(aArgs, "#{CONFDIR}/conf.json")
    CONF = conf
    ARGS = args

    mTelegramServer = TEL.createServer()

    mTelegramServer.listen CONF.port, CONF.hostname, ->
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
            from: "SAKS Monitor <#{ARGS.MAIL_USERNAME}>"
            to: CONF.mail_list.join(', ')
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

        for target in CONF.sms_list
            mSMSSession.send(target, aBody).then(log).fail (err) ->
                err.message = "Error sending SMS notification: #{err.message}"
                self.emit 'error', err
                return
        return


    mMailTransport = MAIL.createTransport('SMTP', {
            service: 'Gmail'
            auth: {user: ARGS.MAIL_USERNAME, pass: ARGS.MAIL_PASSWORD}
        })


    mSMSSession = new SMS.Session({
        username: ARGS.SMS_USERNAME
        password: ARGS.SMS_PASSWORD
        address: CONF.sms_address
    })


    mClearHBTimer = do ->
        timeout = null
        clear = ->
            if timeout isnt null then clearTimeout(timeout)
            timeout = setTimeout(->
                sendSMS('heartbeat timeout')
                sendMail('TIMEOUT from webserver', 'heartbeat timeout')
            , CONF.heartbeat_timeout * 1000)
            return
        return clear


    self.close = (callback) ->
        mTelegramServer.on('close', callback)
        mMailTransport.close -> mTelegramServer.close()
        return

    return self


sanityCheck = (args, aConfpath) ->
    if not args.MAIL_USERNAME
        throw new Error("missing mail username argument")

    if not args.MAIL_PASSWORD
        throw new Error("missing mail password argument")

    if not args.SMS_USERNAME
        throw new Error("missing SMS username argument")

    if not args.SMS_PASSWORD
        throw new Error("missing SMS password argument")

    try
        conf = require aConfpath
    catch readErr
        msg = "syntax error in config file #{aConfpath} : #{readErr.message}"
        throw new Error(msg)

    if not conf.port or typeof conf.port isnt 'number'
        throw new Error("invalid conf.port")

    if not conf.hostname or typeof conf.hostname isnt 'string'
        throw new Error("invalid conf.hostname")

    if not conf.sms_address or parseInt(conf.sms_address) is NaN
        throw new Error("invalid conf.sms_address")

    if not Array.isArray(conf.mail_list)
        throw new Error("invalid conf.mail_list")

    if not Array.isArray(conf.sms_list)
        throw new Error("invalid conf.sms_list")

    if not conf.heartbeat_timeout or typeof conf.heartbeat_timeout isnt 'number'
        conf.heartbeat_timeout = 1

    return {args: args, conf: conf}


if module is require.main
    process.title = 'saks-monitor'
    args =
        MAIL_USERNAME: MAIL_USERNAME
        MAIL_PASSWORD: MAIL_PASSWORD
        SMS_USERNAME: SMS_USERNAME
        SMS_PASSWORD: SMS_PASSWORD

    monitor = exports.monitor args, (err, info) ->
        {address, port} = info.telegramServer.address()
        LOG.info "telegram server running at #{address}:#{port}"
        return

    monitor.on 'error', (err) -> LOG.error(err)
    monitor.on 'log', (msg) -> LOG.info(msg)

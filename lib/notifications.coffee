EventEmitter = require('events').EventEmitter

MAIL = require 'nodemailer'
SMS = require 'q-smsified'


exports.notifications = (aArgs) ->
    self = new EventEmitter
    mArgs = aArgs
    mConf = aArgs.conf or {}

    if not mArgs.mailUsername
        throw new Error("missing mail username argument")

    if not mArgs.mailPassword
        throw new Error("missing mail password argument")

    if not mArgs.smsUsername
        throw new Error("missing SMS username argument")

    if not mArgs.smsPassword
        throw new Error("missing SMS password argument")

    if not mConf.sms_address or parseInt(mConf.sms_address) is NaN
        throw new Error("invalid conf.sms_address")

    if not Array.isArray(mConf.mail_list)
        throw new Error("invalid conf.mail_list")

    if not Array.isArray(mConf.sms_list)
        throw new Error("invalid conf.sms_list")


    mMailTransport = MAIL.createTransport('SMTP', {
        service: 'Gmail'
        auth: {user: mArgs.mailUsername, pass: mArgs.mailPassword}
    })


    mSMSSession = new SMS.Session({
        username: mArgs.smsUsername
        password: mArgs.smsPassword
        address: mConf.sms_address
    })


    self.sendMail = (aSubject, aBody) ->
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


    self.sendSMS = (aBody) ->
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


    self.close = (callback) ->
        mMailTransport.close ->
            self.emit('close')
            if typeof callback is 'function' then return callback()
            return
        return

    return self

EventEmitter = require('events').EventEmitter

TEL = require 'telegram'


exports.createMonitor = (aArgs, aCallback) ->
    self = new EventEmitter()
    mArgs = aArgs
    mNotes = aArgs.notifications
    mConf = aArgs.conf or {}

    if not mConf.port or typeof mConf.port isnt 'number'
        throw new Error("invalid conf.port")

    if not mConf.hostname or typeof mConf.hostname isnt 'string'
        throw new Error("invalid conf.hostname")

    if not mConf.heartbeat_timeout or typeof mConf.heartbeat_timeout isnt 'number'
        mConf.heartbeat_timeout = 1

    mTelegramServer = TEL.createServer()

    # TODO
    # mTelegramServer.on 'error'

    mTelegramServer.listen mConf.port, mConf.hostname, ->
        return aCallback(null, {telegramServer: mTelegramServer})


    mTelegramServer.subscribe 'heartbeat', (message) ->
        mClearHBTimer()
        return


    mTelegramServer.subscribe 'warning', (err) ->
        err = JSON.parse(err)
        mNotes.sendMail('WARNING from webserver', err.stack)
        return


    mTelegramServer.subscribe 'failure', (err) ->
        err = JSON.parse(err)
        mNotes.sendSMS(err.message)
        mNotes.sendMail('FAILURE from webserver', err.stack)
        return


    mClearHBTimer = do ->
        timeout = null
        clear = ->
            if timeout isnt null then clearTimeout(timeout)
            timeout = setTimeout(->
                mNotes.sendSMS('heartbeat timeout')
                mNotes.sendMail('TIMEOUT from webserver', 'heartbeat timeout')
            , mConf.heartbeat_timeout * 1000)
            return
        return clear


    self.createChannel = (name) ->
        return mTelegramServer.createChannel(name)


    self.subscribe = (name, listener) ->
        return mTelegramServer.subscribe(name, listener)


    self.close = (callback) ->
        onclose = ->
            mTelegramServer.removeListener('close', onclose)
            self.emit('close')
            return callback()
        mTelegramServer.on('close', onclose)
        mTelegramServer.close()
        return

    return self

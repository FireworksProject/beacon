process.title = 'beacon'

Logger = require 'bunyan'
LOG = new Logger({
    name: 'beacon'
    streams: [
        {level: 'info', stream: process.stdout}
        {level: 'error', stream: process.stderr}
    ]
})

args =
    confpath: process.argv[2]
    mailUsername: process.argv[3]
    mailPassword: process.argv[4]
    smsUsername: process.argv[5]
    smsPassword: process.argv[6]

service = require('./index').createService args, (err, info) ->
    {address, port} = info.telegramServer.address()
    LOG.info "telegram server running at #{address}:#{port}"
    return

service.on 'error', (err) -> LOG.error(err)
service.on 'log', (msg) -> LOG.info(msg)

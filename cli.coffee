process.title = 'beacon'

Logger = require 'bunyan'
LOG = new Logger({
    name: 'monitor'
    streams: [
        {level: 'info', stream: process.stdout}
        {level: 'error', stream: process.stderr}
    ]
})

args =
    mailUsername: process.argv[2]
    mailPassword: process.argv[3]
    smsUsername: process.argv[4]
    smsPassword: process.argv[5]

monitor = require('./lib/monitor').createMonitor args, (err, info) ->
    {address, port} = info.telegramServer.address()
    LOG.info "telegram server running at #{address}:#{port}"
    return

monitor.on 'error', (err) -> LOG.error(err)
monitor.on 'log', (msg) -> LOG.info(msg)

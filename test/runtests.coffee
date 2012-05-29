FS = require 'fs'
PATH = require 'path'

TRM = require 'treadmill'

LIVE_CONF = process.argv[2]

if LIVE_CONF
    text = FS.readFileSync(LIVE_CONF, 'utf8')
    try
        {argv, conf} = JSON.parse(text)
    catch jsonError
        msg = "JSON parsing error in #{LIVE_CONF}"

    global.TESTCONF = conf
    global.TESTARGV = argv

else
    global.TESTARGV =
        mail_username: 'firechief@fireworksproject.com'
        mail_password: 'foobar'
        sms_username: 'firechief'
        sms_password: 'foobar'
        sms_sender: '5555555555'

checkTestFile = (filename) ->
    if LIVE_CONF then return /^live/.test(filename)
    return /^test/.test(filename)

resolvePath = (filename) ->
    return PATH.join(__dirname, filename)

listing = FS.readdirSync(__dirname)
filepaths = listing.filter(checkTestFile).map(resolvePath)

TRM.run filepaths, (err) ->
    if err then process.exit(2)
    process.exit()

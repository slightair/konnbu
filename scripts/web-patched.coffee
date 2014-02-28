# Description:
#   Webutility returns title of urls
#
# Dependencies:
#   "cheerio": "0.13.1"
#   "node-icu-charset-detector": "0.0.7"


#   "htmlparser": "1.7.6"
#   "soupselect": "0.2.0"
#   "jsdom": "0.2.14"
#
# Commands:
#   None
#
# Author:
#   KevinTraver

cheerio = require 'cheerio'
{CharsetMatch} = require 'node-icu-charset-detector'
{Iconv} = require 'iconv'

detectCharset = (res, body) ->
  charset = null

  # response header
  charset = RegExp.$1 if res.headers['content-type'].match /charset=(.+)$/

  # meta
  unless charset
    $ = cheerio.load(body, lowerCaseTags: true, xmlMode: true)
    charset = $('meta[charset]').attr('charset');

  unless charset
    contentType = $('meta[http-equiv="Content-Type"]').attr('content')
    charset = RegExp.$1 if contentType && contentType.match /charset=(.+)$/

  #icu
  unless charset
    buffer = new Buffer(body, 'binary')
    charsetMatch = new CharsetMatch(buffer)
    charset = charsetMatch.getName()

  return charset.toLowerCase() if charset

  null

module.exports = (robot) ->
  robot.hear /(http|ftp|https):\/\/[\w\-_]+(\.[\w\-_]+)+([\w\-\.,@?^=%&amp;:/~\+#]*[\w\-\@?^=%&amp;/~\+#])?/i, (msg) ->
    url = msg.match[0]
    httpResponse = (url) ->
      msg
        .http(url)
        .get() (err, res, body) ->
          if res.statusCode is 301 or res.statusCode is 302
            httpResponse(res.headers.location)
          else if res.statusCode is 200
            if res.headers['content-type'].indexOf('text/html') != 0
              return

            # convert character encoding
            charset = detectCharset(res, body)
            console.log charset
            return unless charset

            try
              converter = new Iconv(charset, 'UTF-8//TRANSLIT//IGNORE')
              body = converter.convert(new Buffer(body, 'binary')).toString()
            catch e
              return

            $ = cheerio.load(body, lowerCaseTags: true, xmlMode: true)

            pageTitle = $('title').text().trim().replace(/\r|\n/g, "").replace(/\s+/g, " ");
            console.log pageTitle

            msg.send pageTitle
          else
            msg.send "Error " + res.statusCode

    if url.match /https?:\/\/(mobile\.)?twitter\.com/i
      console.log "Twitter link; ignoring"
    else
      httpResponse(url)

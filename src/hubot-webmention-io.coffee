# Description
#   Handle notification of new mentions from webmention.io
#
# Commands:
#   hubot wmio follow <url> - Generate a token and start listening for notifcations from webmention.io for <url>. Notifications will go to the room you are in when you start following.
#   hubot wmio unfollow <url> - Forget all tokens for <url>
#
# Notes:
#   Your site should already be configured to receive webmentions at webmention.io.
#   You'll use HUBOT_URL/hubot/wmio/notify as your Web Hook URL.
#   Hubot will tell you the callback secret when you say "wmio follow"
#
# Author:
#   Marty McGuire <marty@martymcgui.re>

randomstring = require('randomstring')

module.exports = (robot) ->

  find_token_for_url_and_room = (tokens, url, room) ->
    matches = (t for t, props of tokens when (props.url == url) and (props.room == room))
    if matches.length > 0
      return matches[0]
    else
      return null

  robot.respond /wmio follow ?(.*)?/, (res) ->
    url = res.match[1]
    if not url
      res.reply "I need a URL to follow. try \"follow http://yourdomain.com\""
      return
    tokens = robot.brain.get('wmio_tokens') or {}
    token = find_token_for_url_and_room(tokens, url, res.envelope.room)
    if not token
      token = randomstring.generate()
      tokens[token] = { 'url': url, 'room': res.envelope.room }
      robot.brain.set('wmio_tokens', tokens)
    res.reply "OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: " + token

  robot.respond /wmio unfollow ?(.*)?/, (res) ->
    url = res.match[1]
    if not url
      res.reply "I need a URL to unfollow."
      return
    tokens = robot.brain.get('wmio_tokens') or {}
    (delete(tokens[t]) for t, props of tokens when (props.url == url))
    robot.brain.set('wmio_tokens', tokens)
    res.reply "OK! No longer following " + url

  robot.router.post "/hubot/wmio/notify", (req, res) ->
    data = req.body.payload or req.body
    if not data.secret?
      res.status(401).send('secret required')
      return
    tokens = robot.brain.get('wmio_tokens') or {}
    if not tokens[data.secret]
      res.status(400).send('Invalid secret')
      return
    params = tokens[data.secret]
    robot.emit "wmio-notify", {
      room: params.room,
      url: params.url,
      data: data
    }
    res.send('OK')

  reply_content = (post) ->
    content = ""
    if post.name? then content = post.name
    if post.content? and post.content['content-type']? and post.content['content-type'] == 'text/plain'
      content = post.content.value
    return '"' + content + '"'

  robot.on "wmio-notify", (params) ->
    if not params.data?.post?
      robot.messageRoom params.room, "New mention for " + params.url
      return
    post = params.data.post
    message = switch post['wm-property']
      when "like-of" then "" + post.author.name + " liked " + post['like-of'] + " - " + post.url
      when "repost-of" then "" + post.author.name + " reposted " + post['repost-of'] + " - " + post.url
      when "in-reply-to" then "" + post.author.name + " replied " + reply_content(post) + " to " + post['in-reply-to'] + " - " + post.url
      when "mention-of" then "" + post.author.name + " mentioned " + post['mention-of'] + " - " + reply_content(post) + " (" + post.url + ")"
      when "rsvp" then "" + post.author.name + " RSVP'd " + reply_content(post) + " to " + post.rsvp + " - " + post.url
      else "New mention for " + params.url + " - " + post.url
    robot.messageRoom params.room, message

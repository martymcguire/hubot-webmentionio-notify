request = require 'supertest'

chai = require 'chai'
expect = chai.expect

Helper = require('hubot-test-helper')
helper = new Helper('../src/hubot-webmention-io.coffee')

describe 'hubot-webmention-io', ->
  beforeEach ->
    @room = helper.createRoom()

  afterEach ->
    @room.destroy()

  it 'responds to wmio follow with needs url', ->
    @room.user.say('alice', '@hubot wmio follow').then =>
      expect(@room.messages).to.eql [
        ['alice', '@hubot wmio follow']
        ['hubot', '@alice I need a URL to follow. try "follow http://yourdomain.com"']
      ]

  it 'responds to wmio follow http://example.com/ with a notification url and token', ->
    @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
      tokens = @room.robot.brain.get('wmio_tokens')
      token = Object.keys(tokens)[0]
      expect(@room.messages).to.eql [
        ['alice', '@hubot wmio follow http://example.com/']
        ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token]
      ]

  it 'unfollows if asked', ->
    @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
      tokens = @room.robot.brain.get('wmio_tokens')
      token = Object.keys(tokens)[0]
      @room.user.say('alice', '@hubot wmio unfollow http://example.com/').then =>
        tokens = @room.robot.brain.get('wmio_tokens')
        expect(tokens).to.eql {}
        expect(@room.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token]
          ['alice', '@hubot wmio unfollow http://example.com/']
          ['hubot', '@alice OK! No longer following http://example.com/']
        ]

  it 'uses unique tokens for different follow urls', ->
    @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
      @room.user.say('alice', '@hubot wmio follow http://anotherexample.com/').then =>
        tokens = @room.robot.brain.get('wmio_tokens')
        token1 = Object.keys(tokens)[0]
        token2 = Object.keys(tokens)[1]
        expect(@room.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token1]
          ['alice', '@hubot wmio follow http://anotherexample.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token2]
        ]

  it 'uses the same token for repeated follow urls from same room', ->
    @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
      @room.user.say('bob', '@hubot wmio follow http://example.com/').then =>
        tokens = @room.robot.brain.get('wmio_tokens')
        token1 = Object.keys(tokens)[0]
        expect(@room.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token1]
          ['bob', '@hubot wmio follow http://example.com/']
          ['hubot', '@bob OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token1]
        ]

  it 'uses unique token for repeated follow urls from different rooms', ->
    @room2 = helper.createRoom({httpd: false})
    @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
      @room2.user.say('alice', '@hubot wmio follow http://example.com/').then =>
        tokens = @room.robot.brain.get('wmio_tokens')
        token1 = Object.keys(tokens)[0]
        tokens = @room2.robot.brain.get('wmio_tokens')
        token2 = Object.keys(tokens)[0]
        expect(@room.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token1]
        ]
        expect(@room2.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + token2]
        ]
        @room2.destroy()

  it 'responds with 401 when no token', ->
    request(@room.robot.router)
      .post('/hubot/wmio/notify')
      .send({ source: 'http://example.com/1', target: 'http://example.com/2' })
      .expect(401)

  it 'responds with 400 when unknown token', ->
    request(@room.robot.router)
      .post('/hubot/wmio/notify')
      .send({
        secret: 'derp'
      })
      .expect(400)

  context 'with a subscription and valid token', ->
    beforeEach ->
      @room.user.say('alice', '@hubot wmio follow http://example.com/').then =>
        @token = Object.keys(@room.robot.brain.get('wmio_tokens'))[0]
        expect(@room.messages).to.eql [
          ['alice', '@hubot wmio follow http://example.com/']
          ['hubot', '@alice OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify\nAnd use this as your callback secret: ' + @token]
        ]
        @room.messages = []

    it 'sends vague notify on no properties', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'New mention for http://example.com/' ]
          ]

    it 'sends a like notification on a like', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token,
          post: {
            author: { name: 'Alice' },
            'wm-property': 'like-of',
            'like-of': 'http://example.com/1',
            url: 'http://example.com/2'
          }
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'Alice liked http://example.com/1 - http://example.com/2']
          ]

    it 'sends a repost notification on a repost', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token,
          post: {
            author: { name: 'Alice' },
            'wm-property': 'repost-of',
            'repost-of': 'http://example.com/1',
            url: 'http://example.com/2'
          }
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'Alice reposted http://example.com/1 - http://example.com/2']
          ]

    it 'sends a in-reply-to notification on a in-reply-to', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token,
          post: {
            content: { "content-type": "text/plain", value: "WOOHOO!" },
            author: { name: 'Alice' },
            'wm-property': 'in-reply-to',
            'in-reply-to': 'http://example.com/1',
            url: 'http://example.com/2'
          }
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'Alice replied "WOOHOO!" to http://example.com/1 - http://example.com/2']
          ]

    it 'sends a rsvp notification on a rsvp', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token,
          post: {
            name: 'is attending.',
            author: { name: 'Alice' },
            'wm-property': 'rsvp',
            'rsvp': 'http://example.com/1',
            url: 'http://example.com/2'
          }
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'Alice RSVP\'d "is attending." to http://example.com/1 - http://example.com/2']
          ]

    it 'sends a mention-of notification on a mention-of', ->
      request(@room.robot.router)
        .post('/hubot/wmio/notify')
        .send({
          secret: @token,
          post: {
            name: 'Meow meow meow',
            author: { name: 'Alice' },
            'wm-property': 'mention-of',
            'mention-of': 'http://example.com/1',
            url: 'http://example.com/2'
          }
        })
        .expect(200)
        .then =>
          expect(@room.messages).to.eql [
            ['hubot', 'Alice mentioned http://example.com/1 - "Meow meow meow" (http://example.com/2)']
          ]

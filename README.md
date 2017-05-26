# hubot-webmentionio-notify

Handle notification of new [webmentions](https://www.w3.org/TR/webmention/) from [webmention.io](https://webmention.io).

See [`src/hubot-webmention-io.coffee`](src/hubot-webmention-io.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-webmentionio-notify --save`

Then add **hubot-webmentionio-notify** to your `external-scripts.json`:

```json
[
  "hubot-webmentionio-notify"
]
```

## Sample Interaction

```
user1>> hubot wmio follow mywebsite.com
hubot>> @user1 OK! Use this as your Web Hook: <HUBOT_URL>/hubot/wmio/notify
And use this as your callback secret: 1a2b3c4d5e6f7890
```

In your [webmention.io dashboard](https://webmention.io/dashboard), set the Web
Hook URL and callback secret for each domain that you are following.

Notifications will be sent to the room in which you started following. They
look like:

```
hubot>> Alice Bob liked http://mywebsite.com/a-cool-post/ - http://alicebob.com/i-like-a-cool-post.html
```

You can stop accepting notifications for a site:

```
user1>> hubot wmio unfollow mywebsite.com
hubot>> @user1 OK! No longer following mywebsite.com
```

webmention.io can currently only send one token, so if you want to change the
room in which you receive a notification, you'll have to unfollow and re-follow.

## NPM Module

https://www.npmjs.com/package/hubot-webmentionio-notify

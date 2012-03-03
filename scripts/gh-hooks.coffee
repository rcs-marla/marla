# Subscribe to github events
# Requires HUBOT_URL="...your_url..." to be set
#
# Environment Variables:
#
# PREFIX_URL  : The place where this hubot is mounted (ex "http//hubot.example.com"
# GITHUB_USER : The github user to use for the API
# GITHUB_USER : The password to use for the API

QS = require 'querystring'

module.exports = (robot) ->
  _ = require('underscore')

  room_or_user = (user) ->


  robot.respond /gh_hooks subscriptions/, (msg) ->
    msg.send JSON.stringify robot.brain.data.gh_hooks

  robot.respond /gh_hooks unsubscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    # Convenience accessors with initialization
    repos = robot.brain.data.gh_hooks[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []

    msg.send "Unsubscribing to #{repo} #{event} events on #{github_url}"

    removing_listener = ->
      if ! listeners.some((elem) ->
        _.isEqual(elem,msg.message.user)
      )
        listeners.push msg.message.user

      msg.send "Subscribed to #{repo} #{event} events on #{github_url}"

    if listeners.length == 0
      return msg.send "Can't find any subscriptions for #{repo} #{event} events"

    for i, listener in listeners
      if _.isEqual(listener,msg.message.user)
        removed = listeners.splice(i,1)

    if ! removed
      return msg.send "I don't think you're subscribed to #{repo} #{event} events"

    if listeners.length == 0
      msg.send "No listeners left, removing my subscription"
      data = QS.stringify {
        "hub.mode": 'unsubscribe',
        "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
        "hub.callback": "#{process.env.HUBOT_URL}/hubot/gh_hooks/#{github_url}/#{event}"
      }

      msg.http("https://api.#{github_url}")
        .path('/hub')
        .auth(process.env.HUBOT_GITHUB_USER,process.env.HUBOT_GITHUB_PASSWORD)
        .post(data) (err,res,body) ->
          switch res.statusCode
            when 200
              delete events[event]
              msg.send "Removed my subscription to #{repo} #{event} events"
            else
              msg.send "Failed to unsubscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"

  robot.respond /gh_hooks subscribe (.*) (.*)? (.*)?/, (msg) ->
    repo = msg.match[1]
    event = msg.match[2] || 'push'
    github_url = msg.match[3] || 'github.com'

    msg.send "Subscribing to #{repo} #{event} events on #{github_url}"

    # Convenience accessors with initialization
    repos = robot.brain.data.gh_hooks[github_url] || = {}
    events = repos[repo] ||= {}
    listeners = events[event] ||= []

    add_listener = ->
      robot.logger.debug "Adding listener"
      robot.logger.debug JSON.stringify robot.brain.data.gh_hooks
      if ! listeners.some((elem) ->
        _.isEqual(elem,msg.message.user)
      )
        robot.logger.debug "Pushing!"
        robot.logger.debug JSON.stringify listeners
        listeners.push msg.message.user
        robot.logger.debug JSON.stringify listeners

      msg.send "Subscribed to #{repo} #{event} events on #{github_url}"

    # Check to see if we have any subscriptions to this event type for the repo
    if listeners.length == 0
      msg.send "No previous listeners... listening"
      data = QS.stringify {
        "hub.mode": 'subscribe',
        "hub.topic": "https://#{github_url}/#{repo}/events/#{event}.json"
        "hub.callback": "#{process.env.HUBOT_URL}/hubot/gh_hooks/#{github_url}/#{event}"
      }

      robot.logger.debug ".auth('#{process.env.HUBOT_GITHUB_USER}','#{process.env.HUBOT_GITHUB_PASSWORD}')"
      msg.http("https://api.#{github_url}")
        .path('/hub')
        .header('Authorization', 'Basic ' + new Buffer("#{process.env.HUBOT_GITHUB_USER}:#{process.env.HUBOT_GITHUB_PASSWORD}").toString('base64'))
        #.auth(process.env.HUBOT_GITHUB_USER,process.env.HUBOT_GITHUB_PASSWORD)
        .post(data) (err,res,body) ->
          switch res.statusCode
            when 204
              robot.logger.debug "Adding listener"
              msg.send "Adding you as a listener"
              add_listener()
            else
              msg.send "Failed to subscribe to #{repo} #{event} events on #{github_url}: #{body} (Status Code: #{res.statusCode}"
    else
      msg.send "I'm already listening to these. Adding you"
      add_listener()


  robot.brain.on 'loaded', =>
    robot.brain.data.gh_hooks ||= {}


  robot.router.post '/hubot/gh_hooks/:github/push', (req, res) ->
    req.body = req.body || {}

    robot.logger.debug JSON.stringify(req.body)

    if req.body.pusher

      pusher = req.body.pusher
      head = req.body.head_commit
      repo = req.body.repository
      first = req.body.commits[0]

      branch = req.body.ref.replace(/^refs\/head\//,'')

      listeners = robot.brain.gh_hooks[req.params.github]?[repo]['push'] || []

      for listener in listeners
        robot.send listener, "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{req.body.compare}"
        for commit in req.body.commits
          robot.send listener, "#{commit.author.username}: #{commit.id.substring(0,7)} #{commit.message}"

      robot.logger.debug "#{pusher.name} pushed to #{branch} at #{repo.owner.name}/#{repo.name} #{req.body.compare}"
      robot.logger.debug "#{head.author.username}: #{head.id.substring(0,7)} #{head.message}"

      if req.body.commits.length > 1
        robot.logger.debug "#{req.body.commits.length - 1} more commits #{payload.compare}"


    res.end "ok"

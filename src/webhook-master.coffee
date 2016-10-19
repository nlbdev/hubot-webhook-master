# Description:
#   Webhook master script for delegating messages to other HuBot instances.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_SLAVE_URL_PIPELINE - the webhook URL to the Pipeline 2 server
#
# Notes:
#   This script sets up a webhook for messages coming back from the other HuBot instances,
#   and also defines a reusable function for forwarding messages out to the instances.
#
#   The webhook URLs for the other HuBot instances should be defined as environment
#   variables prefixed with `HUBOT_SLAVE_URL_` and ending with the name of the bot in uppercase.
#   The webhooks for the other HuBot instances are on the form `http://<ip>:8080/hubot/message`.
#   The other HuBot instances should use the webhook-adapter, and need to have the environment
#   variable HUBOT_MASTER_URL set to the webhook URL for this main HuBot instance.
#   The webhook URL for the main instance is also on the form `http://<ip>:8080/hubot/message`.
#
#   Remember to add documentation for the other HuBot instances in the "Commands" part of this
#   header so that they appear in the help listing. To get the help listing for the individual
#   HuBot instances, use `hubot [instance-name] help`; this will forward the message
#   `[instance-name] help` to the HuBot instance with the name `instance-name`, and the resulting
#   help listing will be returned.
#
# Author:
#   josteinaj
#
# Commands:
#   hubot pipeline - communicate with the pipeline server

{Message, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage} = require 'hubot'

forwardToSlave = (robot, res) ->
  res.message.text = res.message.text.replace /^[^\s]+\s+/, ""
  messageType = switch
    when res.message instanceof TextMessage then 'TextMessage'
    when res.message instanceof EnterMessage then 'EnterMessage'
    when res.message instanceof LeaveMessage then 'LeaveMessage'
    when res.message instanceof TopicMessage then 'TopicMessage'
    when res.message instanceof Message then 'Message'
    else 'CatchAllMessage'
  robot.http("http://localhost:8081/hubot/message")
      .header('Content-Type', 'application/json')
      .post(JSON.stringify { "type": messageType , "message": res.message }) (err, res, body) ->
        if err
          robot.logger.error "Encountered an error while sending message to slave: "+err
          return
        
        else if res.statusCode isnt 200
          robot.logger.error "Message sent to slave didn't come back with a HTTP 200"
          return
        
        else
          robot.logger.debug "Message successfully sent to slave"

module.exports = (robot) ->
  
  robot.router.post '/hubot/message', (req, res) =>
    robot.logger.info "Received response from slave"
    
    if !req.is 'json'
      res.json {status: 'failed', error: "request isn't json"}
      robot.logger.error "Error: request isn't json"
      return
    
    type = req.body.type
    botname = req.body.name || "missing bot name"
    envelope = req.body.envelope
    strings = req.body.strings
    
    if !type || !envelope || !strings
      res.json {status: 'failed', error: "bad data"}
      robot.logger.error "Error: bad data"
      return
    
    res.json {status: 'ok'}
    
    switch type
      when "emote" then robot.emote envelope, strings
      when "reply" then robot.reply envelope, strings
      else robot.send envelope, strings
  
  
  # ---------- slave connections configured below here ----------
  
  robot.respond /pipeline .*/i, (res) ->
    forwardToSlave robot, res, process.env.HUBOT_SLAVE_URL_PIPELINE
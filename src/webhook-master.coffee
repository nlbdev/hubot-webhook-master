# Description:
#   Webhook master script for delegating messages to other HuBot instances.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_SLAVE_URL_* - the webhook URLs to the other HuBot instances
#
# Notes:
#   This script sets up a webhook for messages coming back from the other HuBot instances,
#   and automatically sets up commands for communicating with the instances.
#
#   The webhook URLs for the other HuBot instances should be defined as environment
#   variables prefixed with `HUBOT_SLAVE_URL_` and ending with the name of the bot, in uppercase.
#   The webhooks for the other HuBot instances are on the form `http://<ip>:8080/hubot/message`.
#   The other HuBot instances should use the webhook-adapter, and need to have the environment
#   variable HUBOT_MASTER_URL set to the webhook URL for this main HuBot instance.
#   The webhook URL for the main instance is also on the form `http://<ip>:8080/hubot/message`.
#
#   To get the help listing for the individual
#   HuBot instances, use `hubot [instance-name] help`; this will forward the message
#   `[instance-name] help` to the HuBot instance with the name `instance-name`, and the resulting
#   help listing will be returned.
#
# Author:
#   josteinaj

{Message, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage} = require 'hubot'

forwardToSlave = (robot, res) ->
  res.message.text = res.message.text.replace /^[^\s]+\s+/, ""
  name = res.message.text.replace /\s.*$/, ""
  messageType = switch
    when res.message instanceof TextMessage then 'TextMessage'
    when res.message instanceof EnterMessage then 'EnterMessage'
    when res.message instanceof LeaveMessage then 'LeaveMessage'
    when res.message instanceof TopicMessage then 'TopicMessage'
    when res.message instanceof Message then 'Message'
    else 'CatchAllMessage'
  robot.http(process['env']['HUBOT_SLAVE_URL_'+name.toUpperCase()])
      .header('Content-Type', 'application/json')
      .post(JSON.stringify { "messageType": messageType , "message": res.message }) (err, res, body) ->
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
    messageType = req.body.messageType
    botname = req.body.name || "missing bot name"
    strings = req.body.strings
    
    if !type || !req.body.envelope || !strings
      res.json {status: 'failed', error: "bad data"}
      robot.logger.error "Error: bad data"
      return
    
    envelope = {}
    for propertyName of req.body.envelope
      propertyValue = req.body.envelope[propertyName]
      # instantiate envelope.user
      if propertyName == "user"
        user = robot.brain.userForId propertyValue.id, name: propertyValue.name, room: propertyValue.room
        for userPropertyName of propertyValue
          user[userPropertyName] = propertyValue[userPropertyName]
        envelope['user'] = user
      
      # instantiate envelope.message
      else if propertyName == "message"
        message = propertyValue
        message = switch
          when messageType == "Message" then new Message(user, message.done)
          when messageType == "TextMessage" then new TextMessage(user, message.text, message.id)
          when messageType == "EnterMessage" then new EnterMessage(user, message.text, message.id)
          when messageType == "LeaveMessage" then new LeaveMessage(user, message.text, message.id)
          when messageType == "TopicMessage" then new TopicMessage(user, message.text, message.id)
          else new CatchAllMessage(message?.message or message)
        for messagePropertyName of propertyValue
          messagePropertyValue = propertyValue[messagePropertyName]
          
          # instantiate envelope.message.user
          if messagePropertyName == "user"
            user = robot.brain.userForId messagePropertyValue.id, name: messagePropertyValue.name, room: messagePropertyValue.room
            for userPropertyName of messagePropertyValue
              user[userPropertyName] = messagePropertyValue[userPropertyName]
            message['user'] = user
          
          else
            message[messagePropertyName] = messagePropertyValue
        
        envelope['message'] = message
      
      else
        envelope[propertyName] = propertyValue
    
    res.json {status: 'ok'}
    
    switch type
      when "emote" then robot.emote envelope, strings...
      when "reply" then robot.reply envelope, strings...
      else robot.send envelope, strings...
  
  
  # ---------- slave connections configured below here ----------
  
  for varName, varValue of process.env
    if varName.match /^HUBOT_SLAVE_URL_.+/
      name = varName.replace /^HUBOT_SLAVE_URL_/, ""
      name = name.toLowerCase()
      robot.logger.info "Will forward commands starting with '"+name+"' to '"+varValue+"'"
      robot.commands.push "hubot "+name+" - Communicate with HuBot instance running on the "+name+"-server."
      robot.respond new RegExp(name+" .*", "i"), (res) ->
        forwardToSlave robot, res

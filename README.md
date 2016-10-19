hubot-webhook-master
====================

Webhook master script for delegating messages to other HuBot instances.

See [`src/webhook-master.coffee`](src/webhook-master.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install josteinaj/hubot-webhook-master --save`

Then add **hubot-webhook-master** to your `external-scripts.json`:

```json
[
  "hubot-webhook-master"
]
```

## Sample Interaction

```
user> hubot help
hubot echo <text> - Reply back with <text>
hubot help - Displays all of the help commands that Hubot knows about.
hubot help <query> - Displays all help commands that match <query>.
hubot worker - communicate with the worker server

user> hubot worker help
worker echo <text> - Reply back with <text>
worker help - Displays all of the help commands that Hubot knows about.
worker help <query> - Displays all help commands that match <query>.
```

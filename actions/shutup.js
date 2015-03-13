"use strict";

var subscriptionService = require('../services/subscriptionService.js');

var listenAction = {
    command: '!taco-shutup:',
    helpDisplayCommand: '!taco-shutup:<label>',
    description: 'Unsubscribes your group to new pull requests with label = foo.',
    perform: function (options) {
      var label = options.message.text.split("!taco-shutup:")[1].split(" ")[0];
      if(label != null && options.channel.name != null) {
        var exists = subscriptionService.getSubs().some(function(group) {
            if (group.Name == options.channel.name && group.Label == label.trim())
                return true;
        });
        if (exists) {
            subscriptionService.unregisterSub({Name: options.channel.name, Label: label.trim()});
        }
      }
      if (label !== null)
        return "Alrighty " + options.user.name + " the group: *" + options.channel.name + "* is now unsubscribed from the PR label: *" + label + "*.";
    }
}


module.exports = listenAction;

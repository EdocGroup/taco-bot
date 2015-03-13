"use strict";

var subscriptionService = require('../services/subscriptionService.js');

var getSubsAction = {
    command: '!taco-getsubs',
    helpDisplayCommand: '!taco-getsubs',
    description: 'Displays the labels that this group is currently subscribed to.',
    perform: function (options) {
        var result = subscriptionService.getSubs().filter(function (sub) {
            return sub.Name == options.channel.name;
        }).map(function (sub) {
            return sub.Label;
        });
		if(result.length > 0)
			return '```' + result.join('\n') + '```';
		else
			return '```No subs```';
    }
};


module.exports = getSubsAction;

"use strict";

var blacklistService = require('../services/blacklistService.js');

var admins = [
    'matt',
    'max.verigin'
];

var blacklistAction = {
    command: /^!taco-blacklist *([^ ]+)/,
    helpDisplayCommand: '!taco-blacklist <username>',
    description: '(Taco-Admin only) Adds or removes a user to the command blacklist.',
    perform: function (options) {
        if (admins.indexOf(options.user.name) !== -1) {
            var match = (options.message.text || '').match(blacklistAction.command);
            var target = match[1] || null;
            var targetUser = target ? options.slack.getUserByID(target) : false;
            if (targetUser) {
                var blacklisted = blacklistService.toggleUser(targetUser.name);
                if (blacklisted) {
                    return '`' + targetUser.name + ' is now banned.`';
                } else {
                    return '`' + targetUser.name + ' is no longer banned.`';
                }
            } else {
                return '`Username ' + target ' was not found.`';
            }
        }
        return '`' + options.user.name + ' is not allowed to perform the taco-blacklist command.`';
    }
};

module.exports = blacklistAction;

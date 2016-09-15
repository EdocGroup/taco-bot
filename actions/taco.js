"use strict";

const tacoService = require('../services/tacoService.js');

const tacoAction = {
    command: /^!taco( (.+))?/,
    helpDisplayCommand: '!taco <username>',
    description: 'Gives someone a taco.',
    perform: function (options) {
        const target = (options.message.text || '').match(tacoAction.command)[2] || null;
        const targetUser = target ? options.slack.getUserByName(target) : options.user;
        if(targetUser){
            const tacos = tacoService.incrementTacos(targetUser.name);
            return `\`${targetUser.name} now has ${tacos} tacos!\``;
        } else {
            return `\`No user ${target}\``;
        }
    }
};

module.exports = tacoAction;

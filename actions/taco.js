"use strict";

var tacoService = require('../services/tacoService.js');

var tacoAction = {
    command: /^!taco$/,
    helpDisplayCommand: '!taco',
    description: 'Gives you a taco.',
    perform: function (options) {
        var tacos = tacoService.incrementTacos(options.user.name);
        return '`' + options.user.name + ' now has ' + tacos + ' tacos!`';
    }
};

module.exports = tacoAction;

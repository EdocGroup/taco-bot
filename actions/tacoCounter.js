"use strict";

var tacoService = require('../services/tacoService.js');

var tacoCounterAction = {
    command: /^!taco-counter$/,
    helpDisplayCommand: '!taco-counter',
    description: 'Lists taco leaderboards.',
    perform: function (options) {
        var result = tacoService.getTacos()
			.sort(function (a,b) { return a.Count > b.Count ? -1 : a.Count < b.Count ? 1 : 0;})
            .map (function (entry, i) {
                return (i+1) + '. ' + entry.Name + ': ' + entry.Count;
            });
        return '`Taco Counter:`\n```' + result.join('\n') + '```';
    }
};

module.exports = tacoCounterAction;

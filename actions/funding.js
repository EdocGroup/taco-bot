"use strict";

var fundAction = {
    command: '!taco-funding',
    description: 'Displays who has contributed to taco-bot',
    perform: function (options) {
        var result =  [
            'taco-bot\'s funding is at *$0*; if you\'d like to contribute, give money to Matt or Max',
            'Top donators:',
            '    Chris: bought pop for Matt'
        ];

        return '```' + result.join('\n') + '```';
    }
};

module.exports = fundAction;

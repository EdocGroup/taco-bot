"use strict";

var helpAction = {
    command: '!taco-help',
    description: 'Displays this message (wow!)',
    perform: function (options) {
        var result =  ['Taco Bot Help!']
            .concat(options.actions.map(function (action) {
              if(action.helpDisplayCommand != null)
                return ('\n' + action.helpDisplayCommand || action.command) + ' - ' + action.description;
            }));

        return '```' + result.join('') + '```';
    }
};

module.exports = helpAction;

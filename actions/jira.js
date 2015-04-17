"use strict";

var config = require('../config.js');

var jiraLinkAction = {
    command: /(H([C,J,R,T]+)-([0-9]+))/ig,
    helpDisplayCommand: '<jira-issue>',
    description: 'Links JIRA issues matching the mentioned issue.',
    perform: function (options) {
        var response = '';
        var issues = options.message.text.match(jiraLinkAction.command);
        if (issues && options.message.text.indexOf('http') === -1) {
            response = issues.map(function (issue) {
                return '`' + config.jiraUrl + issue.trim().toUpperCase() + '`';
            }).join('\n') + '\n';
        }
        return response;
    }
}


module.exports = jiraLinkAction;

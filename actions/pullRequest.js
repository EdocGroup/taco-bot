"use strict";

var githubService = require('../services/githubService.js');
var config = require('../config.js');

var pullRequestAction = {
    command: '!PR:',
    helpDisplayCommand: '!PR:<label>',
    description: 'Gets you all open pull requests with label = Foo. Label = None gives pull requests with no label.',
    perform: function (options) {
        return githubService.getOpenPullRequests()
            .filter(options.message.text.indexOf(pullRequestAction.command + 'None') !== -1 ?
                function (pr) { return pr.Labels.length === 0; } :
                function (pr) {
                    return pr.Labels.some(function (label) {
                        return options.message.text.split(pullRequestAction.command)[1].split(" ")[0].trim() == label;
                    });
            }).reduce(function (result, pr) { return result += prettyPrint(pr); }, '');
    }
};

function prettyPrint(pullRequest) {
    var titleMatch = pullRequest.Title.match(/(H([C,J,R,T]+)-([0-9]+))/ig);
    var output = [
        "Name: " + pullRequest.Title,
        "User: " + pullRequest.User,
        "PR Link: https://github.com/EdocGroup/helmnext/pull/" + pullRequest.Number,
    ];
    if (titleMatch) {
        output.push("Jira Link: " + config.jiraUrl + titleMatch[0].trim().toUpperCase());
    }
    return '```' + output.join('\n') + '```\n';
}

module.exports = pullRequestAction;

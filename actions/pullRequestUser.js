"use strict";

var githubService = require('../services/githubService.js');
var config = require('../config.js');

var pullRequestUserAction = {
    command: '!PRUser:',
    helpDisplayCommand: '!PRUser:<user>',
    description: 'Gets you all open pull requests for user = Foo.',
    perform: function (options) {
        return githubService.getOpenPullRequests()
            .filter(
                function (pr) {
                        return options.message.text.split(pullRequestUserAction.command)[1].split(" ")[0].trim() == pr.User;
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

module.exports = pullRequestUserAction;

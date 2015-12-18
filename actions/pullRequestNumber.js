"use strict";

var githubService = require('../services/githubService.js');
var config = require('../config.js');



var pullRequestNumberAction = {
    command: '!PR#:',
    helpDisplayCommand: '!KickOffPR:<#>',
    description: 'Gets you the open pull requests for user = Foo.',
    perform: function (options) {
        return githubService.getOpenPullRequests()
            .filter(
                function (pr) {
                        return options.message.text.split(pullRequestNumberAction.command)[1].split(" ")[0].trim() == pr.Number;
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
		output.push("Click TO Trigger Build: " + url + pullRequest.Number);
	return '```' + output.join('\n') + '```\n';
}

module.exports = pullRequestNumberAction;

"use strict";

var githubService = require('../services/githubService.js');
var config = require('../config.js');

var url = "http://ci.edoc.ca:8080/job/PullRequest/buildWithParameters?token=" + config.JenkinsToken + "&ghprbPullId=";
var url2 = "http://ci.edoc.ca:8080/job/Selgrid(multi)/buildWithParameters?token=" + config.JenkinsToken + "&ghprbPullId=";

var pullRequestNumberAction = {
    command: '!PR#:',
    helpDisplayCommand: '!PR#:<#>',
    description: 'Gets you more info about the pr#.',
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
		output.push("Click to trigger a fresh build of : " + url + pullRequest.Number);
        output.push("Click to redeploy the latest build of : " + url2 + pullRequest.Number);
	return '```' + output.join('\n') + '```\n';
}

module.exports = pullRequestNumberAction;
 
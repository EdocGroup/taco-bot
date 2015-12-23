"use strict";

var githubService = require('../services/githubService.js');
var config = require('../config.js');
var async = true;
var url = "http://ci.edoc.ca:8080/job/SelGrid(Multi)/buildWithParameters?token=" + config.JenkinsToken + "&ghprbPullId=";

var request = require('request')

var DeployPRAction = {
    command: '!DeployPR:',
    helpDisplayCommand: '!DeployPR:<#>',
    description: 'Deploys your latest PR to SELGRID (pr branch)',
    perform: function (options) {
        return githubService.getOpenPullRequests()
            .filter(
                function (pr) {
                        return options.message.text.split(DeployPRAction.command)[1].split(" ")[0].trim() == pr.Number;
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
		output.push("Build Link: " + url + pullRequest.Number);
		output.push("Jenkins is triggering SELGRID to deploy PR: " + pullRequest.Number);
		request.get(url + pullRequest.Number);
	return '```' + output.join('\n') + '```\n';
}

module.exports = DeployPRAction;

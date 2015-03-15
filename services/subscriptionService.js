var fs = require('fs');
var config = require('../config.js');

var file = 'data/subs.json';

var subs = [];

loadSubs();

function saveSubs() {
    fs.writeFileSync(file, JSON.stringify(subs));
    return;
}

function loadSubs() {
    try {
        if (fs.existsSync(file)) {
            subs = JSON.parse(fs.readFileSync(file, 'utf8'));
        } else {
            saveSubs();
        }
    } catch (e) {
        console.log(e);
    }
    return subs;
}

function notifySubscribed(changedPullRequests) {
    subs.forEach(function(group) {
    var response = "";
    changedPullRequests.forEach(function (pr) {
        if (pr.Labels.indexOf(group.Label) > -1) {
            response += prettyPrint(pr);
        }
    });
    var channel = require('../taco-bot.js').getGroupByName(group.Name);
    if (channel != null)
        channel.send(response);
    });
}

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

module.exports = {
    getSubs: function () {
        return subs.slice();
    },
    registerSub: function (sub) {
        subs.push(sub);
        saveSubs();
    },
    unregisterSub: function (sub) {
        var i, len;
        for (i = 0, len = subs.length; i < len; i++) {
            if (subs[i].Name == sub.Name && subs[i].Label == sub.Label) {
                subs.splice(i, 1);
                saveSubs();
                break;
            }
        }
    },
    notifySubscribed: notifySubscribed
};

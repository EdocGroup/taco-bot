var GitHubApi = require('github');
var config = require('../config.js');
var subscriptionService = require('./subscriptionService.js');

var openPullRequests = [];

var github = new GitHubApi({
    // required
    version: "3.0.0",
    // optional
    timeout: 5000
});

github.authenticate({
    type: "oauth",
    token: config.githubToken
});

function getDemIssues() {
    console.log("Getting Github issues...");
    github.issues.repoIssues({
        repo: "helmnext",
        user: "EdocGroup",
        state: "open",
        per_page: "100"
    }, function(err, res) {
    var newPullRequests = [];
        if (res != null && res.length > 0) {
            res.forEach(function (pr) {
                newPullRequests.push({
                    Title: pr.title,
                    User: pr.user.login,
                    Labels: pr.labels.map(function(l) {return l.name}),
                    Number: pr.number
                });
            });
            if (openPullRequests.length == 0) {
                openPullRequests = newPullRequests;
            } else {
                compareOldToNew(newPullRequests);
            }
        }
    });
}

var started = false;
function start (list){
    if (!started) {
        getDemIssues();
        var repeater = setInterval(getDemIssues, 10000, list, function(parsedList){});
        started = true;
    }
}


function compareOldToNew(newPullRequests) {
    var pushPullRequests = [];

    newPullRequests.forEach(function(newPR) {
        var index = openPullRequests.map(function (p) { return p.Number; }).indexOf(newPR.Number);
        if (openPullRequests.length > 0 && index > -1) {
            if (openPullRequests[index].Labels.join(",") != newPR.Labels.join(",")) {
                pushPullRequests.push(newPR);
            }
        } else {
            pushPullRequests.push(newPR);
        }
    });

    if(pushPullRequests.length > 0) {
        subscriptionService.notifySubscribed(pushPullRequests);
    }
    openPullRequests = newPullRequests;
    return;
}

module.exports = {
    start: start,
    getOpenPullRequests: function () {
        return openPullRequests.slice();
    }
};

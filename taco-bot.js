var Slack = require('slack-client');
var fs = require('fs');
var config = require('./config.js');
var githubService = require('./services/githubService.js');
var spotifyService = config.spotify ? require('./services/spotifyService.js') : null;

var actions = [
    'help',
    'pullRequest',
    'pullRequestUser',
    'listen',
    'shutup',
    'getSubs',
    'jira',
    spotifyService ? 'song' : null,
    'taco',
    'tacoCounter',
    'funding'
].filter(function (action) { return action; }).map(function (action) {
    return require('./actions/' + action + '.js');
});

var slack = new Slack(config.slackToken, /*autoReconnect: */ true, /*autoMark: */ true);

slack.on('open', function() {
    var channel, channels, groups, group, id, messages, unreads;
    channels = [];
    groups = [];
    unreads = slack.getUnreadCount();
    channels = (function() {
        var _ref, _results;
        _ref = slack.channels;
        _results = [];
        for (id in _ref) {
            channel = _ref[id];
            if (channel.is_member) {
                _results.push("#" + channel.name);
            }
        }
        return _results;
    })();
    groups = (function() {
        var _ref, _results;
        _ref = slack.groups;
        _results = [];
        for (id in _ref) {
            group = _ref[id];
            if (group.is_open && !group.is_archived) {
                _results.push(group.name);
            }
        }

        return _results;
    })();
    console.log("Welcome to Slack. You are @" + slack.self.name + " of " + slack.team.name);
    console.log('You are in: ' + channels.join(', '));
    console.log('As well as: ' + groups.join(', '));
    messages = unreads === 1 ? 'message' : 'messages';
    githubService.start();
    return console.log("You have " + unreads + " unread " + messages);
});

slack.on('message', function(message) {
    var channel, channelError, errors, response, text, textError, ts, type, typeError, user;
    channel = slack.getChannelGroupOrDMByID(message.channel);
    user = slack.getUserByID(message.user);
    response = '';
    type = message.type, ts = message.ts, text = message.text;
    if (type === 'message' && (text != null) && (channel != null)) {
        actions.some(function (action) {
            try {
                if ((action.command instanceof RegExp) ? text.match(action.command) : (text.indexOf(action.command) !== -1)) {
                    var response = action.perform({
                        message: message,
                        actions: actions,
                        user: user,
                        channel: channel
                    });
                    if (response) {
                        if (response.then) {
                            // it's a promise
                            response.then(function(result) {
                                channel.send(result);
                            }).catch(function(error) {
                                console.log(error);
                            });
                        } else {
                            channel.send(response);
                        }
                    }
                }
            } catch (e) {
                // yolo
                console.log(e);
            }
        });
    } else {
        typeError = type !== 'message' ? "unexpected type " + type + "." : null;
        textError = text == null ? 'text was undefined.' : null;
        channelError = channel == null ? 'channel was undefined.' : null;
        errors = [typeError, textError, channelError].filter(function(element) {
            return element !== null;
        }).join(' ');
        return console.log("@" + slack.self.name + " could not respond. " + errors);
    }
});

slack.on('error', function(error) {
    return console.error("Error: " + error);
});

slack.login();

module.exports = slack;

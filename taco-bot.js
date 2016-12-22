const RtmClient = require('@slack/client').RtmClient;
const MemoryDataStore = require('@slack/client').MemoryDataStore;
var config = require('./config.js');
var githubService = require('./services/githubService.js');
var spotifyService = config.spotify ? require('./services/spotifyService.js') : null;
var blacklistService = require('./services/blacklistService.js');

var actions = [
    'help',
    'pullRequest',
    'pullRequestUser',
    'listen',
    'shutup',
    'getSubs',
    'jira',
    spotifyService ? 'song' : null,
    spotifyService ? 'songEnqueue' : null,
    'taco',
    'tacoCounter',
    'blacklist',
    'funding',
    'customer'
].filter(function (action) { return action; }).map(function (action) {
    return require('./actions/' + action + '.js');
});

var slack = new RtmClient(config.slackToken, { autoReconnect: true, dataStore: new MemoryDataStore(), no_unreads: true });

slack.on('authenticated', function({ channels, groups, self, team }) {
    const myChannels = channels.filter(c => c.is_member).map(c => `#${c.name}`);
    const myGroups = groups.filter(g => g.is_open && !g.is_archived).map(g => g.name);
    console.log(`Welcome to Slack. You are @${self.name} of ${team.name}`);
    console.log(`You are in: ${myChannels.join(', ')}`);
    console.log(`As well as: ${myGroups.join(', ')}`);
    githubService.start();
});

slack.on('message', function(message) {
    let { channel, user, text, type } = message;
    var channelError, errors, textError, typeError;
    channel = slack.dataStore.getGroupById(channel) || slack.dataStore.getDMById(channel) || slack.dataStore.getChannelById(channel);
    user = slack.dataStore.getUserById(user);

    if (type === 'message' && (text != null) && (channel != null)) {
        actions.some(function (action) {
            try {
                if ((action.command instanceof RegExp) ? text.match(action.command) : (text.indexOf(action.command) !== -1)) {
                    var response;
                    if (blacklistService.isBlacklisted(user && user.name)) {
                        response = "`Error: User " + user.name + " is banned from taco-bot. Please contact your local taco-administrator.`";
                    } else {
                        response = action.perform({
                            message,
                            actions,
                            user,
                            channel,
                            slack
                        });
                    }
                    if (response) {
                        if (response.then) {
                            // it's a promise
                            response.then(function(result) {
                                if(result){
                                    slack.sendMessage(result, channel.id);
                                }
                            }).catch(function(error) {
                                console.error('Error getting result from action: ', error, action);
                            });
                        } else {
                            slack.sendMessage(response, channel.id);
                        }
                    }
                }
            } catch (e) {
                // yolo
                console.error('Action error: ', e, action);
            }
        });
    } else {
        typeError = type !== 'message' ? "unexpected type " + type + "." : null;
        textError = text == null ? 'text was undefined.' : null;
        channelError = channel == null ? 'channel was undefined.' : null;
        errors = [typeError, textError, channelError].filter(function(element) {
            return element !== null;
        }).join(' ');
        return console.error("Could not respond. ", errors);
    }
});

slack.on('error', function(error) {
    return console.error("Slack error: ", error);
});

slack.start();

module.exports = slack;

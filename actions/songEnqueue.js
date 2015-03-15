"use strict";

var spotifyService = require('../services/spotifyService.js');
var events = require('../services/events.js');

var mostRecentSearched = null;
events.on('song-search-found', function (result) {
    mostRecentSearched = result;
});

var songEnqueueAction = {
    command: '!taco-song-enqueue',
    helpDisplayCommand: '!taco-song-enqueue',
    description: 'Enqueues the last searched song.',
    perform: function (options) {
        if (mostRecentSearched) {
            var sending = spotifyService.pushPlaylist(mostRecentSearched.uri);
            if (sending) {
                return sending.then(function () {
                    return '`' + mostRecentSearched.artist + ' - ' + mostRecentSearched.track +'` was added to the playlist!';
                });
            } else {
                return 'Failed to add song to playlist.';
            }
        } else {
            return 'No songs have been searched for yet; use !taco-song first.';
        }
    }
};


module.exports = songEnqueueAction;

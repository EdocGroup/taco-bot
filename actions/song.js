"use strict";

var spotifyService = require('../services/spotifyService.js');

var songAction = {
    command: '!taco-song:',
    helpDisplayCommand: '!taco-song:<Artist - Track>',
    description: 'Searches spotify for a song.',
    perform: function (options) {
        var songData = options.message.text.split(songAction.command)[1].split("-");
        var artist = songData[0].trim();
        var track = songData[1].trim();
        var result = spotifyService.query(artist, track).then(function (result) {
            if (result) {
                return 'The following song exists on spotify: `' + result.artist + ' - ' + result.track +'`';
            }
            return 'Sorry, no results for that song =[';
        });
        return result;
    }
};


module.exports = songAction;

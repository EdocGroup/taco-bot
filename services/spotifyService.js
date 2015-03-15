"use strict";

var request = require('request-promise');
var config = require('../config.js');

var access_token = null;
var user = null;

loadTokens(config.spotify.refreshToken)
    .then(getUser)
    .then(function (result) {
        user = result;
    });

function loadTokens(refresh_token) {
    var payload = config.spotify.clientID + ":" + config.spotify.clientSecret;
    var encoded = new Buffer(payload).toString("base64");
    var body = "grant_type=refresh_token"
        + "&refresh_token=" + refresh_token;
    var options = {
        url: "https://accounts.spotify.com/api/token",
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": "Basic " + encoded
        },
        body: body
    };
    return request(options).then(function (result) {
        result = JSON.parse(result);
        access_token = result.access_token;
        // if we get a new refresh token we need to save it
        if (result.refresh_token) {
            config.spotify.refreshToken = result.refresh_token;
            config.save();
        }

        setTimeout(function () {
            loadTokens(config.refreshToken);
        }, Number(result.expires_in) * 0.9 * 1000);

        return result;
    });
}

function getUser() {
    if (!access_token) {
        console.log('Error: No spotify access token loaded');
        return;
    }
    var encoded = access_token
    var options = {
        url: "https://api.spotify.com/v1/me",
        method: "GET",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": "Bearer " + encoded
        }
    };
    return request(options).then(function (result) {
        result = JSON.parse(result);
        return result;
    });
}

module.exports = {
    query: function(artist, track) {
        return request('https://api.spotify.com/v1/search?q=artist:' + artist + '+track:' + track + '&type=track&limit=1').then(function (qresult) {
            var items = JSON.parse(qresult).tracks.items;
            if (items.length > 0) {
                return {
                    uri: items[0].uri,
                    artist: items[0].artists[0].name,
                    track: items[0].name
                };
            } else {
                return null;
            }
        }).catch(function (error) {
            console.log(error);
            return null;
        });
    },

    pushPlaylist: function(trackUri) {
        if (!access_token || !user) {
            console.log('Error: Spotify access token or user was not loaded');
            return;
        }
        var encoded = access_token;
        var options = {
            url: "https://api.spotify.com/v1/users/" + user.id + "/playlists/" + config.spotify.playlistId + "/tracks?uris=" + trackUri,
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": "Bearer " + encoded
            }
        };
        return request(options).then(function (result) {
            result = JSON.parse(result);
            return result;
        });
    }
};

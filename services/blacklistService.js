var fs = require('fs');
var slack = require('../taco-bot.js');

var file = 'data/tacoBlacklist.json';

var blacklist = {};

loadBlacklist();

function saveBlacklist() {
    fs.writeFileSync(file, JSON.stringify(blacklist));
    return;
}

function loadBlacklist() {
    try {
        if (fs.existsSync(file)) {
            blacklist = JSON.parse(fs.readFileSync(file, 'utf8')) || {};
        } else {
            saveBlacklist();
        }
    } catch (e) {
        console.log(e);
    }
    return blacklist;
}

module.exports = {
    getList: function () {
        return blacklist;
    },
    isBlacklisted: function (username) {
        return !!blacklist[username];
    },
    toggleUser: function (username) {
        if (username !== undefined) {
            blacklist[username] = !blacklist[username];
            saveBlacklist();
            return !!blacklist[username];
        }
        return false;
    }
};

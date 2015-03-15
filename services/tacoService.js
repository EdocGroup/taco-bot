var fs = require('fs');
var slack = require('../taco-bot.js');

var file = 'data/tacoCount.json';

var counts = [];

loadTacos();

function saveTacos() {
    fs.writeFileSync(file, JSON.stringify(counts));
    return;
}

function loadTacos() {
    try {
        if (fs.existsSync(file)) {
            counts = JSON.parse(fs.readFileSync(file, 'utf8'));
        } else {
            saveTacos();
        }
    } catch (e) {
        console.log(e);
    }
    return counts;
}

module.exports = {
    getTacos: function () {
        return counts.slice();
    },
    getTacosForUser: function (username) {
        var data;
        if (counts.some(function (entry) {
            if (entry.Name == username) {
                data = entry;
                return true;
            }
        })) {
            return data.Count;
        } else {
            return 0;
        }
    },
    incrementTacos: function (username) {
        var data;
        var num;
        if (counts.some(function (entry) {
            if (entry.Name == username) {
                data = entry;
                return true;
            }
        })) {
            num = ++data.Count;
        } else {
            counts.push({
                Name: username,
                Count: 1
            });
            num = 1;
        }
        saveTacos();
        return num;
    }
};

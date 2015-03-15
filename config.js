"use strict";
var fs = require('fs');

var file = 'config.json';
var config = JSON.parse(fs.readFileSync(file, 'utf8'));
config.save = function save() {
    fs.writeFileSync(file, JSON.stringify(config, null, 2));
};

module.exports = config;

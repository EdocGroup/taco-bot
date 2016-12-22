"use strict";

const fs = require('fs');

const customerDataFile = `${__dirname}/customer/customers.json`;
const logDataFile = `${__dirname}/customer/logs.json`;
const customerChannels = require('../config.json').customerChannels;

const customerAction = {
    command: /.*/g,
    helpDisplayCommand: '<customer>',
    description: 'Show customer information',
    perform(options) {
        if(customerChannels.filter(c => c == options.channel.name).length > 0){
            const message = options.message.text;

            const promises = [
                readFilePromise(customerDataFile),
                readFilePromise(logDataFile)
            ];

            return Promise.all(promises).then(results => {
                const [ customerData, logData ] = results;

                const slugs = Object.keys(customerData);

                let match = null;
                slugs.some(slug => {
                    const regex = new RegExp(`.*(^|\\W)${slug}($|\\W).*`, 'i');
                    if(message.match(regex)){
                        match = slug;
                        return true;
                    }
                    return false;
                });
                if(match){
                    if(!logData[match] || logData[match].timestamp != new Date().toDateString()){
                        logData[match] = {
                            timestamp: new Date().toDateString()
                        };
                        return new Promise((resolve, reject) => {
                            fs.writeFile(logDataFile, JSON.stringify(logData, null, 2), err => {
                                if(err){
                                    reject(err);
                                    return;
                                }
                                const customer = customerData[match];
                                resolve(`\`\`\`${customer}\`\`\``);
                            });
                        });
                    }
                }
            }, err => {
                console.error(`There was an error reading the customer data: ${err}`);
            });
        }
    }
};

function readFilePromise(filename){
    return new Promise((resolve, reject) => {
        fs.readFile(filename, {encoding: 'utf8'}, (err, data) => {
            if(err){
                if(err.code == 'ENOENT'){
                    resolve(new Promise((resolve, reject) => {
                        fs.writeFile(filename, '{}', err => {
                            if(err){
                                reject(err);
                                return;
                            }
                            resolve({});
                        });
                    }));
                    return;
                }
                reject(err);
                return;
            }
            resolve(JSON.parse(data));
        });
    });
}

module.exports = customerAction;

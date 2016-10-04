"use strict";

const customerDataFile = './customer/customers.json';
const customerChannels = require('../config.json').customerChannels;

const customerAction = {
    command: /.*/g,
    helpDisplayCommand: '<customer>',
    description: 'Show customer information',
    perform(options) {
        if(customerChannels.filter(c => c == options.channel.name).length > 0){
            delete require.cache[require.resolve(customerDataFile)]
            const message = options.message.text;
            const customers = require(customerDataFile);
            const slugs = Object.keys(customers);

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
                const customer = customers[match];
                return `\`\`\`${customer}\`\`\``;
            }
        }
    }
};

module.exports = customerAction;

"use strict";

const customerDataFile = './customer/customers.json';

const customerAction = {
    command: /.*/g,
    helpDisplayCommand: '<customer>',
    description: 'Show customer information',
    perform(options) {
        delete require.cache[require.resolve(customerDataFile)]
        const message = options.message.text;
        const customers = require(customerDataFile);
        const slugs = Object.keys(customers);

        let match = null;
        slugs.some(slug => {
            if(message.indexOf(slug) != -1){
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
};

module.exports = customerAction;

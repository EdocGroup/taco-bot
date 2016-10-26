const request = require('request-promise');
const cheerio = require('cheerio');
const htmlToText = require('html-to-text');
const fs = require('fs');

const customerInfoPageId = '67141690';
const customerInfoPageUrl = `https://edocgroup.atlassian.net/wiki/rest/api/content/${customerInfoPageId}?expand=body.view`;
const urlField = 'Link';

const outputfile = 'customers.json';

const htmlToTextOptions = {
    tables: [
        '.text-table'
    ],
    ignoreHref: true
};

const headers = '<tr><td>Link</td><td>Name</td><td>NPS</td><td>Licenses</td><td>% of Vessels Active</td><td>Status</td></tr>';

request(customerInfoPageUrl, {
    auth: require('../../config.json').confluence,
    json: true
}).then((response) => {
    const $ = cheerio.load(response.body.view.value);
    $('img').remove();

    const customers = $('tr').toArray().map((e, i) => {
        return customer(e);
    }).reduce((customers, c, i) => {
        if(i == 0){
            return customers;
        }
        const urlMatch = c.split('\t')[0].match(/(.+?)\.helmconnect.com/);
        const slug = urlMatch ? urlMatch[1] : null;
        if(!slug){
            return customers;
        }
        customers[slug] = c;
        return customers;
    }, {});

    fs.writeFile(outputfile, JSON.stringify(customers, null, 2), err => {
        if(err){
            console.error(err);
            return;
        }
        console.log(`Wrote to ${outputfile}`);
    });

    function customer(e){
        return htmlToText.fromString(`<table class="text-table">${headers}${$.html(e)}</table>`, htmlToTextOptions);
    }
}, err => {
    console.error(err);
});

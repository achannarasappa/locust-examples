const AWS = require('aws-sdk');
const { Client } = require('pg')
const moment = require('moment')
const lambda = new AWS.Lambda({ apiVersion: '2015-03-31' });

const saveListing = async (listing) => {

  const client = new Client({
    host: process.env.POSTGRES_HOST || 'localhost',
    database: process.env.POSTGRES_DATABASE || 'postgres',
    user: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres',
    port: process.env.POSTGRES_PORT || 5432,
  })
  await client
    .connect();
  await client.query({
    text: [
      'INSERT INTO listing.home',
      '(title, price, "location", bedroom_count, "size", date_posted, "attributes", images, description, latitude, longitude)',
      'VALUES(',
      '$1,',
      '$2,',
      '$3,',
      '$4,',
      '$5,',
      '$6,',
      '$7,',
      '$8,',
      '$9,',
      '$10,',
      '$11',
      ');',
    ].join(' \n'),
    values: Object.values(listing),
  }, () => {
    client.end()
  });

};

const matchObjectPropertyRegexOrNull = (object, property, regex) => {

  if (!object[property])
    return null;

  if (!object[property].match(regex))
    return null;

  return object[property].match(regex)[1]

}

const transformListing = (listing) => ({
  title: listing.title,
  price: parseInt(((listing.price || '').match(/\$([0-9]*)/) || [])[1] || 0, 10),
  location: matchObjectPropertyRegexOrNull(listing, 'location', /\((.*)\)/),
  bedroom_count: matchObjectPropertyRegexOrNull(listing, 'housing', /([0-9]*)br/),
  size: matchObjectPropertyRegexOrNull(listing, 'housing', /([0-9]*)ft2/),
  date_posted: listing.datetime ? moment(listing.datetime).format('YYYY-MM-DD HH:mm:ss') : null,
  attributes: JSON.stringify(listing.attributes || []),
  images: JSON.stringify(listing.images || []),
  description: listing.description,
  latitude: matchObjectPropertyRegexOrNull(listing, 'google_maps_link', /@([0-9.-]*),/),
  longitude: matchObjectPropertyRegexOrNull(listing, 'google_maps_link', /,([0-9.-]*),/),
});

const isListingUrl = (url) => /newyork\.craigslist\.org\/(.*)\/?apa\/d\/(.*)\.html(?<!#)$/.test(url);
const isIndexUrl = (url) => /newyork\.craigslist\.org\/search\/apa\?s=([0-9]*)$/.test(url);

module.exports = {
  extract: async ($, page) => transformListing({
    'title': await $('.postingtitletext #titletextonly'),
    'price': await $('.postingtitletext .price'),
    'housing': await $('.postingtitletext .housing'),
    'location': await $('.postingtitletext small'),
    'datetime': await page.$eval('.postinginfo time', (el) => el.getAttribute('datetime')).catch(() => null),
    'images': await page.$$eval('#thumbs .thumb', (elements) => elements.map((el) => el.getAttribute('href'))).catch(() => null),
    'attributes': await page.$$eval('.mapAndAttrs p.attrgroup:nth-of-type(2) span', (elements) => elements.map((el) => el.textContent)).catch(() => null),
    'google_maps_link': await page.$eval('.mapaddress a', (el) => el.getAttribute('href')).catch(() => null),
    'description': await $('#postingbody'),
  }),
  after: async (jobResult, snapshot, stop) => {

    if (isListingUrl(jobResult.response.url)) {

      await saveListing(jobResult.data)
    }

    if (snapshot.queue.done.length >= 100)
      await stop()

    return jobResult;

  },
  start: () => lambda.invoke({
    FunctionName: 'apartment-listings',
    InvocationType: 'Event',
  }).promise()
    .catch((err) => console.log(err, err.stack)),
  url: 'https://newyork.craigslist.org/search/apa',
  config: {
    name: 'apartment-listings',
    concurrencyLimit: 2,
    depthLimit: 100,
    delay: 3000,
  },
  filter: (links) => links.filter(link => isIndexUrl(link) || isListingUrl(link)),
  connection: {
    redis: {
      port: 6379,
      host: process.env.REDIS_HOST || 'localhost'
    },
    chrome: {
      browserWSEndpoint: `ws://${process.env.CHROME_HOST || 'localhost'}:3000`,
    },
  }
};
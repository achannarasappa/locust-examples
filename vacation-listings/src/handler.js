const { execute } = require('locust');
const job = require('./job.js')

module.exports.start = () => execute(job);
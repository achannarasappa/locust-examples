const { execute } = require('@achannarasappa/locust');
const job = require('./job.js')

module.exports.start = () => execute(job);
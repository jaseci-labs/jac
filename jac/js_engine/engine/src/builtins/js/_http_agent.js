'use strict';
var http = require('http');
module.exports = {
    Agent: http.Agent,
    globalAgent: http.globalAgent
};

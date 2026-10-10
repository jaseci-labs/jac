'use strict';
var http = require('http');
module.exports = {
    Server: http.Server,
    ServerResponse: http.ServerResponse,
    kConnectionsCheckingInterval: http.kConnectionsCheckingInterval
};

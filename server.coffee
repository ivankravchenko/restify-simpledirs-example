PORT = process.env.PORT or 3000
HOST = process.env.HOST or "localhost"
HTTPS = !!process.env.HTTPS
HTTPS_CRT = process.env.HTTPS_CRT or "./ssl.crt"
HTTPS_KEY = process.env.HTTPS_KEY or "./ssl.key"
ENDPOINTS_ROOT = process.env.ENDPOINTS_ROOT or "./endpoints"

SERVER_URL = if HTTPS then 'https://' else 'http://'
SERVER_URL += HOST
unless HTTPS and PORT is 443 or not HTTPS and PORT is 80
	SERVER_URL += ':' + PORT
SERVER_URL += '/'

PACKAGE = require "./package.json"

restify = require "restify"
bunyan = require "bunyan"
fs = require "fs"
path = require "path"

logger = bunyan.createLogger
	name: PACKAGE.name

serverOptions =
	name: PACKAGE.name
	version: PACKAGE.version
	log: logger
if HTTPS
	serverOptions.certificate = fs.readFileSync HTTPS_CRT
	serverOptions.key = fs.readFileSync HTTPS_KEY

server = restify.createServer serverOptions

server.use require('restify-cookies').parse

supportedMethods = ["get", "post", "put", "del", "head"]
supportedEndpointExtensions = [".coffee", ".js"]

mapEndpoint = (localName, method, uri, fns...) ->
	name = "#{method}:#{localName}"

	server[method]
		path: uri
		name: name
	, fns...
	
	logger.info
		endpoint:
			method: method
			uri: uri
			name: name
	, "Registered endpoint"

initEndpoints = (directoryPath, uri, mapEndpoint) ->
	names = fs.readdirSync directoryPath
	for name in names
		stat = fs.statSync path.resolve(directoryPath, name)
		if stat.isFile()
			extension = path.extname name
			if extension in supportedEndpointExtensions
				endpoint = require path.resolve(directoryPath, name)
				localEntrypointName = path.basename name, extension
				endpointUri = if localEntrypointName is "index" then uri else uri + localEntrypointName
				endpointName = uri + localEntrypointName
				if typeof endpoint is "function"
					mapEndpoint endpointName, "get", endpointUri, endpoint
				else if typeof endpoint is "object"
					if endpoint.path?
						endpointUri = uri + endpoint.path
					for method in supportedMethods when typeof endpoint[method] is "function"
						mapEndpoint endpointName, method, endpointUri, endpoint[method]
		else if stat.isDirectory()
			initEndpoints path.resolve(directoryPath, name), uri + name + "/", mapEndpoint

initEndpoints ENDPOINTS_ROOT, "/", mapEndpoint

server.listen PORT, ->
	logger.info
		server:
			name: PACKAGE.name
			version: PACKAGE.version
			https: HTTPS
			url: SERVER_URL
	, "Started server"

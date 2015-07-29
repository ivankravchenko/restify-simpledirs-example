module.exports =
	path: ":id"
	get: (req, res) ->
		res.send "get user #{req.params.id}"
	post: (req, res) ->
		res.send "update user #{req.params.id}"
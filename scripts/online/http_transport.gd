## Transport HTTP réel (M16) : un `HTTPRequest` par requête, enfant d'un nœud
## hôte (`OnlineService`), non bloquant ; `timeout` court
## (`OnlineConfig.REQUEST_TIMEOUT_S`). Même code sur le Web (Godot y passe
## par `fetch`, sans cookies : ONLINE.md §1.2).
## Journaux : `OnlineRequest.describe()` seulement (jamais corps, jeton ni adresse).
class_name HttpTransport
extends OnlineTransport

var _host: Node = null
var _pending: Dictionary[HTTPRequest, OnlineRequest] = {}


func _init(host: Node = null, p_base_url: String = OnlineConfig.DEFAULT_BASE_URL) -> void:
	_host = host
	base_url = p_base_url


func send(req: OnlineRequest) -> void:
	super.send(req)
	if _host == null or not is_instance_valid(_host) or not _host.is_inside_tree():
		req.finish(0, {}, OnlineRequest.Failure.NETWORK)
		return
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = req.timeout_s
	http.use_threads = false
	http.accept_gzip = true
	_host.add_child(http)
	_pending[http] = req
	http.request_completed.connect(_on_completed.bind(http))
	var headers: PackedStringArray = ["Accept: application/json"]
	var payload: String = ""
	if req.body != null:
		headers.append("Content-Type: application/json")
		payload = JSON.stringify(req.body)
	if not req.token.is_empty():
		headers.append("Authorization: " + req.token)
	var method: HTTPClient.Method = _method_of(req.method)
	var err: Error = http.request(base_url + req.url_path(), headers, method, payload)
	if err != OK:
		_pending.erase(http)
		http.queue_free()
		req.finish(0, {}, OnlineRequest.Failure.NETWORK)


func cancel_all() -> void:
	for http: HTTPRequest in _pending.keys():
		var req: OnlineRequest = _pending[http]
		if is_instance_valid(http):
			http.cancel_request()
			http.queue_free()
		req.finish(0, {}, OnlineRequest.Failure.CANCELLED)
	_pending.clear()


func _on_completed(result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray, http: HTTPRequest) -> void:
	var req: OnlineRequest = _pending.get(http, null)
	_pending.erase(http)
	http.queue_free()
	if req == null:
		return
	if result == HTTPRequest.RESULT_TIMEOUT:
		req.finish(0, {}, OnlineRequest.Failure.TIMEOUT)
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		req.finish(0, {}, OnlineRequest.Failure.NETWORK)
		return
	var data: Dictionary = {}
	var text: String = raw.get_string_from_utf8()
	if not text.strip_edges().is_empty():
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			data = parsed
		elif code >= 200 and code < 300:
			req.finish(code, {}, OnlineRequest.Failure.PARSE)
			return
	req.finish(code, data)


static func _method_of(name: String) -> HTTPClient.Method:
	match name:
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
	return HTTPClient.METHOD_GET

append = (m) ->
  m = m.data
  m = JSON.parse(m)  if typeof m is "string"
  if m.file
    img = "<img src='" + m.file.blob + "'>"
    $("#images").append img
  return

ws = new WebSocket("ws://" + window.location.host + window.location.pathname)
ws.onmessage = append

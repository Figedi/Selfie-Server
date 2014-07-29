append = (m) ->
  m = m.data
  m = JSON.parse(m)  if typeof m is "string"
  if m.file
    img = "<img src='" + m.file.src + "'>"
    count = $('#images img').length
    w = 100/(count+1)
    w = if w < 5 then 5 else w
    $("#images").prepend img
    $('#images img').css
      "max-width": "#{w}%"
      "max-height": "#{w}%"
  return

ws = new WebSocket("ws://#{window.location.host}#{window.location.pathname}/socket")
ws.onmessage = append

opts =
  sizeRangeSuffixes:
    'lt100':''
    'lt240': ''
    'lt320':''
    'lt500':''
    'lt640':''
    'lt1024':''
  margins: 5
  rowHeight: 300

append = (m) ->
  m = m.data
  m = JSON.parse(m)  if typeof m is "string"
  if m.file
    img = "<a src='#{m.file.src}'><img src='#{m.file.src}'></a>"
    $("#images").prepend img
    $("#images").justifiedGallery(opts)
  return

ws = new WebSocket("ws://#{window.location.host}#{window.location.pathname}/")
ws.onmessage = append

$ ->
  $('#images').justifiedGallery(opts)

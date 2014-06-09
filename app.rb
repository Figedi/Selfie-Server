require 'sinatra'
require 'sinatra-websocket'
require 'data_uri'
require 'json'
require 'base64'

set :server, 'thin'
set :sockets, []
set :port, 3000

NEW_IMAGE = 0
ALL_IMAGES = 1
# index route, index template is prepoulated with all available images,
# socket connections setup the current setup
get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      ws.onopen do
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        EM.next_tick { settings.sockets.each{ |s| s.send(msg) } }
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  end
end

#fallback to get all saved images
get '/images' do
  response = []
  Dir.glob('./public/*') do |filepath|
    b64_string = Base64.encode64(File.read(filepath))
    response << { type: ALL_IMAGES, file: { b64: b64_string, name: File.basename(filepath) } }
  end
  response.to_json
  status 200
  body response
end

# upload route, can upload a file from b64 encoded strings

post '/upload' do

  if params[:file]
    img_blob = URI::Data.new(params[:file])
    #collision free filename
    filename = if params[:filename]
      params[:filename]
    else
      dir_count = Dir.glob('./public/*').length
      "image_#{dir_count}"
    end
    #extract fileending or default to jpg
    match = filename.match(/^(\w+)\.(\w+)$/)
    if match #if there is a fileending already provided:
      filename = match[1]
      ending = match[2]
    else
      ending = filename[/^\w+\.(\w+)$/, 1] || img_blob.content_type[/^\w+\/(\w+)$/, 1] || 'jpg'
    end
    #write file
    File.open("./public/#{filename}.#{ending}", 'wb') do |f|
      f.write(img_blob.data)
    end
    #create response object for websocket
    response = { type: NEW_IMAGE, file: { blob: params[:file], name: filename } }.to_json
    settings.sockets.each do |socket|
      socket.send(response)
    end
    #plain head 200 as a response for the smartphone user
    status 200
  else
    status 406
    body "No file selected"
  end


  status 200
end

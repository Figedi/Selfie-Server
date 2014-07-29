require 'sinatra/base'
require 'sinatra-websocket'
require 'data_uri'
require 'json'
require 'base64'
require 'coffee-script'
require 'sass'
require 'slim'

class SassHandler < Sinatra::Base

  set :views, File.dirname(__FILE__) + '/assets/css'

  get '/css/*.css' do
      filename = params[:splat].first
      sass filename.to_sym
  end
end

class CoffeeHandler < Sinatra::Base

  set :views, File.dirname(__FILE__) + '/assets/javascripts'

  get "/scripts/*.js" do
      filename = params[:splat].first
      if File.exist? "./assets/javascripts/#{filename}.coffee"
        coffee filename.to_sym
      else
        send_file "./assets/javascripts/#{filename}.js", disposition: 'inline'
      end
  end
end

class Selfie < Sinatra::Base
  use SassHandler
  use CoffeeHandler

  set :server, 'thin'
  set :sockets, []
  set :port, 3000

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

  NEW_IMAGE = 0
  ALL_IMAGES = 1

  def collect_images_from_public
    response = []
    Dir.glob('public/*.*') do |filepath|
      b64_string = Base64.encode64(File.read(filepath))
      #src: basename is enough since all files are in root directory of public!
      response << { type: ALL_IMAGES, file: { b64: b64_string, name: File.basename(filepath), src: File.basename(filepath) } }
    end
    response.sort_by {|e| -e[:file][:name].to_i }
  end

  # socket connections setup the current setup
  get '/socket' do
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

  # index route, index template is prepoulated with all available images,

  get '/' do
    @images = collect_images_from_public
    images_length = (_ = @images.length) == 0 ? 1 : _
    @image_width = "max-width: #{100/images_length}%; max-height: #{100/images_length}%"
    slim :index
  end

  # test, fallback to get all saved images
  # not needed later on
  get '/images.json' do
    content_type :json
    response = collect_images_from_public
    response.to_json
  end

  # upload route, can upload a file from b64 encoded strings

  post '/upload' do
    if b = request.body.read
      params.merge! JSON.parse b
    end
    if params[:b64] #b64 mode
      img_blob = URI::Data.new(params[:b64])
      ending = img_blob.content_type[/^\w+\/(\w+)$/, 1] || 'jpg'
      filename = "#{Time.now.to_i.to_s}.#{ending}"
      #write file
      File.open("./public/#{filename}", 'wb') do |f|
        f.write(img_blob.data)
      end
      response = { type: NEW_IMAGE, file: { src: filename, name: filename } }.to_json
      settings.sockets.each do |socket|
        socket.send(response)
      end
      response
    elsif params[:tempfile] #file attachment mode
      file = params[:tempfile][:tempfile]
      m = params[:tempfile][:filename].match(/\.(png|jpe?g|gif)$/)
      filename = "#{Time.now.to_i.to_s}.#{m[1]}"
      File.open("./public/#{filename}", 'wb') do |f|
        f.write(file.read)
      end
      #create response object for websocket, src is only filename since we have a file in public folder now
      response = { type: NEW_IMAGE, file: { src: filename, name: filename } }.to_json
      settings.sockets.each do |socket|
        socket.send(response)
      end
      #plain head 200 as a response for the smartphone user
      status 200
    else
      status 406
      body "No file selected"
    end
  end
end

if __FILE__ == $0
    Selfie.run! :port => 3000
end

#!/usr/bin/env ruby

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
      coffee filename.to_sym
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
    Dir.glob('public/*') do |filepath|
      b64_string = Base64.encode64(File.read(filepath))
      #src: basename is enough since all files are in root directory of public!
      response << { type: ALL_IMAGES, file: { b64: b64_string, name: File.basename(filepath), src: File.basename(filepath) } }
    end
    response
  end

  # index route, index template is prepoulated with all available images,
  # socket connections setup the current setup
  get '/' do
    if !request.websocket?
      @images = collect_images_from_public
      puts "============ images"
      puts @images
      slim :index
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

  # test, fallback to get all saved images
  # not needed later on
  get '/images.json' do
    content_type :json
    response = collect_images_from_public
    response.to_json
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
  end
end

if __FILE__ == $0
    Selfie.run! :port => 3000
end

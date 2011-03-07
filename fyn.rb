require 'open-uri'
require 'json'
require 'cgi'
require 'RMagick'
require 'sinatra/base'
require 'timeout'
require 'newrelic_rpm'

ENV['APP_ROOT'] ||= File.dirname(__FILE__)

module FuckYeahNouns

  class Application < Sinatra::Base
    
    set :public, File.dirname(__FILE__) + '/public'

    get '/' do
      headers 'Cache-Control' => 'public; max-age=36000'
      erb :home
    end 

    get '/favicon.ico' do
      headers 'Cache-Control' => 'public; max-age=36000'
      nil
    end       
    
    get '/images/:noun' do
      idx = params[:idx] || 0
      begin
        data = FuckYeahNouns.fuck_noun(params[:noun])
        headers 'Cache-Control' => 'public; max-age=36000', 'Content-Type' => 'image/jpg', 'Content-Disposition' => 'inline'
      rescue 
        data = File.open('./didntfindshit.jpg')
        headers 'Cache-Control' => 'public; max-age=30', 'Content-Type' => 'image/jpg', 'Content-Disposition' => 'inline'
      end 
      data
    end

    get '/:noun' do
      headers 'Cache-Control' => 'public; max-age=36000'
      erb :noun
    end 
    
  end

  def self.fuck_noun(noun)
    img = FuckYeahNouns.fetch_image(noun)
    FuckYeahNouns.annotate(img, noun)
  end 
  
  def self.fetch_image(noun, idx=0)
    url = "http://boss.yahooapis.com/ysearch/images/v1/#{CGI.escape noun}?appid=#{ENV['APP_ID']}"
    # url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=#{CGI.escape noun}"

    
    # seriously, seriously need to rewrite this clusterfuck. What am I thinking? 
    # It's 2:30am. That's my excuse.
    retries = 1
    begin
      res = nil
      Timeout::timeout(4) do
        res = JSON.parse(open(url).read)
      end 
    rescue Timeout::Error
      retries -= 1
      if retries >= 0
        retry
      else
        raise "omg"
      end
    end 

    set = res['ysearchresponse']['resultset_images']
    raise if set.size.zero?
    begin
      r = nil
      Timeout::timeout(4) do
        r=open(set[0]['url'])
      end 
      r
    rescue StandardError, Timeout::Error
      begin
        r = nil
        Timeout::timeout(4) do
          r=open(set[1]['url'])
        end 
        r
      rescue Timeout::Error
        raise "omg"
      end 
    end 
  end 

  def self.annotate(img, noun)
    picture = Magick::Image.from_blob(img.read).first
    width,height = picture.columns, picture.rows
    picture.resize!(600,600*(height/width.to_f))
    width,height = picture.columns, picture.rows

    overlay = Magick::Image.new(width, 100)
    picture.composite!(overlay, Magick::SouthGravity, Magick::MultiplyCompositeOp)

    caption = Magick::Draw.new
    caption.fill('white')
    caption.stroke('black')
    caption.font_stretch = Magick::ExtraCondensedStretch
    caption.font('Helvetica Neue')
    caption.stroke_width(2)
    caption.pointsize(48)
    caption.font_weight(800)
    caption.text_align(Magick::CenterAlign)

    caption.text(width/2.0, height-50, "HECK YEAH\n#{noun.upcase}")
    caption.draw(picture)

    return picture.to_blob
  end 
  
end 


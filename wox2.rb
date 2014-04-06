require 'rubygems'
require 'dm-core'
require 'sinatra'
require 'csv'
#require 'sinatra/reloader' if development?

# If you want the logs displayed you have to do this before the call to setup
# DataMapper::Logger.new($stdout, :debug)
set :port, 4003
set :environment, :production
#set :bind, 'freshwox.com'

#set :sessions, true
use Rack::Session::Pool

DataMapper.setup(:default, 'postgres://postgres:!!!fgiP@localhost/wox')


class Walk
  include DataMapper::Resource
  property :id, Serial
  property :walkname, String
  property :description, Text

  property :start, String
  property :start_lat, Float
  property :start_lng, Float
  property :waypoints, Text
  property :directions, Text
  property :distance, Integer
  
  belongs_to :login
end

class Login
  include DataMapper::Resource
  property :id, Serial
  property :name, String
  property :pass, String
  property :email, String
  
  has n, :walks
end

class Zipcode
  include DataMapper::Resource
  property :id, Serial
  property :zip, String
  property :city, String
  property :state, String
  property :lat, Float
  property :lng, Float
end

if development? 

  DataMapper.auto_migrate!


  unicorn = Login.new( :name => 'Unicorn',
                     :pass => 'unibicorn' )
  unicorn.save


  reservoir = unicorn.walks.new( :walkname => 'Reservoir',
                               :start => '132 glenville ave, allston, MA',
                               :description => 'A walk to the reservoir via Comm Ave through Allston and Brighton',
                               :start_lat => '42.3491',
                               :start_lng => '-71.1372',
                               :waypoints => '42.34666242420988;-71.14093780517578:42.342158308258924;-71.14449977874756:42.34047711186328;-71.15115165710449:42.33819315040718;-71.15316867828369',
                               :directions => '42.349130,-71.137290|42.348510,-71.137670|42.348510,-71.137670|42.348810,-71.138540|42.348910,-71.139070|42.348860,-71.139660|42.348610,-71.140240|42.348360,-71.140530|42.348040,-71.140710|42.347050,-71.140880|42.346680,-71.141020|42.346680,-71.141020|42.345820,-71.141520|42.343790,-71.142960|42.343790,-71.142960|42.343690,-71.142770|42.343690,-71.142770|42.342890,-71.143360|42.342460,-71.143840|42.342090,-71.144440|42.342090,-71.144440|42.341790,-71.145090|42.341500,-71.146330|42.341450,-71.146800|42.341490,-71.148280|42.341330,-71.149320|42.341180,-71.149760|42.340900,-71.150370|42.340430,-71.151090|42.340430,-71.151090|42.340070,-71.151520|42.339760,-71.151810|42.339350,-71.152120|42.338850,-71.152410|42.338850,-71.152410|42.338900,-71.152590|42.338900,-71.152590|42.338470,-71.152860|42.338240,-71.153210',
                               :distance => 1000)
  reservoir.save

  repository(:default).adapter.execute( "copy zipcodes from '#{Dir.pwd}/zipcodes.pg'" )
end


helpers do
  def miles( meters )
    miles_float = meters.to_f / 1609
    miles_whole = miles_float.floor
    miles_part = miles_float - miles_whole
    num_quarters = (miles_part * 4).round
    quarters_part = nil
    if num_quarters == 2
      quarters_part = "1/2"
    elsif num_quarters > 0
      quarters_part = "#{num_quarters}/4"
    end

    if miles_whole == 1 && !quarters_part
      "1 mile"
    elsif miles_whole > 0 && !quarters_part
      "#{miles_whole} miles"
    elsif miles_whole > 0 
      "#{miles_whole} and #{quarters_part} miles"
    elsif quarters_part
      "#{quarters_part} mile"
    else
      "1/4 of a mile"
    end
  end

  def map_url( walk, size )
    points = walk.directions
    style = "color:0xff2814|weight:6"
    mapUrl = "http://maps.google.com/maps/api/staticmap"

    "#{mapUrl}?path=#{style}|#{points}&size=#{size}&sensor=false"
  end
end

get '/add' do
	if !session[:login]
		redirect '/'
	end

	@message = "Nothing yet!!"
	if session[:fucked_up]
		@message4 = "You fucked up!" 
		session[:fucked_up] = nil
	end
	haml :index_add
end

post '/add' do
  if !session[:login]
    redirect '/'
  end

  new_walk = Login.get(session[:login]).walks.new( 
                    :walkname => params[:walkname],
                    :description => params[:description],
                    :start => params[:start], 
                    :start_lat => params[:start_lat],
                    :start_lng => params[:start_lng],
                    :waypoints => params[:waypoints],
                    :directions => params[:directions],
                    :distance => params[:distance])
  new_walk.save

  redirect "/walk/#{ new_walk.id }"
end	


get '/' do
  @walks = []
  haml :index
end

post '/' do
  zip = nil
  if params[:location] =~ /\d{5}/
    zip = Zipcode.first( :zip => params[:location] )
  elsif params[:location] =~ /.*,.*/
    city = params[:location].split(',')[0]
    state = params[:location].split(',')[1]
    zip = Zipcode.first( :city => city.strip.downcase, 
                         :state => state.strip.downcase )
  end
  @walks = []
  if zip
    @walks = Walk.all(:start_lat.lt => zip.lat + 0.1, :start_lat.gt => zip.lat - 0.1,
                      :start_lng.lt => zip.lng + 0.1, :start_lng.gt => zip.lng - 0.1)
  end
  haml :index
end

get '/login' do
	@logins = Login.all
	haml :index_login
end

post '/login' do
	#If the user is already logged in, go to home
	if session[:login]
		redirect '/'
	end
	
	#If the user did not provide name and password, re-render the login page
	if !(params[:name] && params[:pass])
		return (haml :index_login)
	end
	
	old_login = Login.first( :name => params[:name] )
	if !old_login
		@new_user = true
		return (haml :index_login)
	end
	
	if params[:pass] == old_login.pass
		session[:login] = old_login.id
		redirect '/'
	else
		@wrong_pass = true
		return (haml :index_login)
	end
end

get '/register' do
	haml :register
end

post '/register' do
	new_login = Login.new( :name => params[:name],
							:pass => params[:pass],
							:email => params[:email])
							
	#If the user is already logged in, go to home
	if session[:login]
		redirect '/'
	end
	
	#If the user did not provide name and password, re-render the register page
	if !(params[:name] && params[:pass] && params[:email])
		return (haml :register)
	end
	
	old_login = Login.first( :name => params[:name] )
	if old_login
		@old_user = true
		return (haml :register)
	end
	
	new_login.save
	session[:login] = new_login.id
	redirect '/'
end

get '/logout' do
	session[:login] = nil 
	redirect '/'
end

get '/register' do
	haml :register
end
	

get '/walk/:walk_id' do
	@walk  = Walk.get( params[:walk_id] )
	@login = @walk.login
	haml :walk_id
end


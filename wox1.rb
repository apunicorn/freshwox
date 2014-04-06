require 'rubygems'
require 'dm-core'

# If you want the logs displayed you have to do this before the call to setup
# DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default, 'postgres://postgres:!!!fgiP@localhost/wox')


class Walk
  include DataMapper::Resource

  property :id, Serial
  property :start, String
  property :end, String
  property :description, String
end

DataMapper.auto_migrate!

rservoir = Walk.new( :start => '132 Glenville Ave', 
                      :end => 'Chestnut Hill Reservoir',
                      :description => 'Walk up Comm Ave' )
reservoir.save


my_walks = Walk.all

my_walks.each{ |walk| printf( "Walk from %s to %s - %s\n",  walk.start, walk.end, walk.description ) }

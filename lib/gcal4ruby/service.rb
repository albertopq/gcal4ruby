require 'gcal4ruby/base' 
require 'gcal4ruby/calendar'

module GCal4Ruby

#The service class is the main handler for all direct interactions with the 
#Google Calendar API.  A service represents a single user account.  Each user
#account can have multiple calendars, so you'll need to find the calendar you
#want from the service, using the Calendar#find class method.
#=Usage
#
#1. Authenticate
#    service = Service.new
#    service.authenticate("user@gmail.com", "password")
#
#2. Get Calendar List
#    calendars = service.calendars
#

class Service < Base
  attr_accessor :account, :auth_token, :check_public, :auth_type
  
  def initialize(attributes = {})
    super()
    attributes.each do |key, value|
      self.send("#{key}=", value)
    end    
    @check_public ||= true
  end

  def authenticate(username, password)
    ret = nil
    ret = send_post(AUTH_URL, "Email=#{username}&Passwd=#{password}&source=GCal4Ruby&service=cl&accountType=HOSTED_OR_GOOGLE")
    if ret.class == Net::HTTPOK
      @auth_token = ret.read_body.to_a[2].gsub("Auth=", "").strip
      @account = username
      @auth_type = 'ClientLogin'
      return true
    else
      raise AuthenticationFailed
    end
  end
  
  # added authsub authentication.  pass in the upgraded authsub token and the username/email address
  def authsub_authenticate(authsub_token, account)
    @auth_token = authsub_token
    @account = account
    @auth_type = 'AuthSub'
    return true
  end

  #Returns an array of Calendar objects for each calendar associated with 
  #the authenticated account.
  def calendars
    unless @auth_token
      raise NotAuthenticated
    end
    ret = send_get(CALENDAR_LIST_FEED+"?max-results=10000")
    cals = []
    REXML::Document.new(ret.body).root.elements.each("entry"){}.map do |entry|
      entry.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
      entry.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
      entry.attributes["xmlns:app"] = "http://www.w3.org/2007/app"
      entry.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
      cal = Calendar.new(self)
      cal.load("<?xml version='1.0' encoding='UTF-8'?>#{entry.to_s}")
      cals << cal
    end
    return cals
  end
  
  # This is for building a composite calendar
  # I'm sure it doesn't work, needs review!
  def to_iframe(cals, params = {})
    calendar_set = case cals
      when :all then calendars
      when :first then calendars[0]
      else cals
    end

    units = calendar_set.collect do |cal|
      "src=#{cal.id}" + cal.build_options_set(params).join("&amp;")
    end
          
    "<iframe src='http://www.google.com/calendar/embed?#{units.join("&amp;")}' width='#{params[:width]}' height='#{params[:height]}' frameborder='#{params[:border]}' scrolling='no'></iframe>"
  end
end

end
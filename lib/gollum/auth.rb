require 'digest/md5'

module Gollum
  class Auth
    
    # is login valid?
    def login(username, password)
      AuthData::all.select{|f| f[:name] == username && f[:password] == Digest::MD5.hexdigest(password) }.size > 0
    end
    
  end
end

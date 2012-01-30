# class with user_data
class AuthData 
  
  def self.all 
    return [{
      :name => 'username',
      :password =>  '098f6bcd4621d373cade4e832627b4f6',
      :email => 'username@username.de',
      :realname => 'User Name'
    },{
      :name => 'sample',
      :password =>  '5e8ff9bf55ba3508199d22e984129be6',
      :email => 'sample@sample.de',
      :realname => 'Piet Sample'
    },{
      :name => 'test',
      :password =>  '098f6bcd4621d373cade4e832627b4f6',
      :email => 'test@test.de',
      :realname => 'Testodia Testen'
    },{
        :name => 'test2',
        :password =>  '098f6bcd4621d373cade4e832627b4f6',
        :email => 'test@test.de',
        :realname => 'Testodia Testen'
      }
    ]
  end
  
  def self.find_by_login username
    AuthData::all.select{ |f| f[:name] == username }.first
  end
  
end
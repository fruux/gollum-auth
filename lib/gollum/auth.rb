module Gollum
  class Auth
    def login(userid)
      [
        'userid1',
        'userid2',
      ].include?(userid)
    end
  end
end

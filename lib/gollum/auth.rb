require 'digest/md5'

module Gollum
  class Auth
    def login(username, password)
      [
        # You can generate md5 password from
        # $ echo 'YOUR_PASSWORD' | ruby -e "require 'digest/md5'; puts Digest::MD5.hexdigest(STDIN.read.chomp)"
        # ['name', 'md5 hashed password'],
        ['username', '4ef62f3ef91bfc8b0474b1bf81c5f4cb'], # YOUR_PASSWORD
        ['sample', '5e8ff9bf55ba3508199d22e984129be6'],
        # append username and md5ed password here..
      ].include?([username, Digest::MD5.hexdigest(password)])
    end
  end
end

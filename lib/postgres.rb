require 'base64'
require 'ostruct'

module Lib
  class Postgres < OpenStruct
    def self.from_hash(hash)
      new(
        username: Base64.decode64(hash["username"]),
        password: Base64.decode64(hash["password"])
      )
    end

    def to_s
      "Username: #{username}\nPassword: #{password}"
    end
  end
end
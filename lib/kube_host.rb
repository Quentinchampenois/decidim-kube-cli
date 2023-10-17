module Lib
  class KubeHost < OpenStruct
    def self.from_hash(hash)
      new(
        id: hash["metadata"]["uid"],
        decidim_name: hash["metadata"]["name"],
        namespace: hash["metadata"]["namespace"],
        status: hash["status"]["phase"],
        host: hash["spec"]["host"]
      )
    end
  end
end
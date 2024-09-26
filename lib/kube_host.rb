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

    def to_s
      "Host: #{host}\nNamespace: #{namespace}\nDecidim: #{decidim_name}\nStatus: #{status}"
    end
  end
end
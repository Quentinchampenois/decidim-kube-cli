require "open3"
require "json"
require "ostruct"

module Lib
  module Kubectl
    class Error < StandardError; end

    def self.get_hosts
      puts "Retrieving all hosts..."
      cmd = "kubectl get decidim --all-namespaces -o json"
      kubectl_exec!(cmd)
    end

    def self.get_pg_credentials_for(namespace, decidim_name)
      puts "Retrieving PG credentials for #{decidim_name}..."
      cmd = "kubectl get secret -n #{namespace} decidim-reader.#{decidim_name}--de-pg.credentials.postgresql.acid.zalan.do -o json | jq '{username: .data.username, password: .data.password}'"
      kubectl_exec!(cmd)
    end

    def self.get_pg_service(namespace, decidim_name)
      puts "Retrieving PG service for #{decidim_name}..."
      cmd = "kubectl get services -n #{namespace} --field-selector=metadata.name==#{decidim_name}--de-pg-repl-headless -o jsonpath='{.items[].metadata.name}'"
      kubectl_exec!(cmd)
    end

    def self.get_pg_credentials(namespace, decidim_name)
      puts "Retrieving PG credentials for #{decidim_name}..."
      cmd = "kubectl get secret -n #{namespace} decidim-reader.#{decidim_name}--de-pg.credentials.postgresql.acid.zalan.do -o json | jq '{username: .data.username, password: .data.password}'"
      res = kubectl_exec!(cmd)
      raise Error, res.stderr unless res.status.success?

      json = JSON.parse(res.stdout)
      return json
    end

    private

    def self.kubectl_exec!(cmd)
      stdout, stderr, status = Open3.capture3(cmd)

      OpenStruct.new(
        stdout: stdout,
        stderr: stderr,
        status: status
      )
    end
  end
end
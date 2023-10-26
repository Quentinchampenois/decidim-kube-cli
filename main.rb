#!/usr/bin/env ruby

require 'open3'
require "yaml"
require_relative "lib/kubectl"
require_relative "lib/postgres"
require_relative "lib/kube_host"
require "airbyte_ruby"

def kubectl_get_pg_service(namespace, decidim_name)
  puts "Retrieving PG service for #{decidim_name}..."
  cmd = "kubectl get services -n #{namespace} --field-selector=metadata.name==#{decidim_name}--de-pg-repl-headless -o jsonpath='{.items[].metadata.name}'"
  stdout, stderr, status = Open3.capture3(cmd)

  {
    stdout: stdout,
    stderr: stderr,
    status: status
  }
end

puts "Airbyte ruby version: #{AirbyteRuby::VERSION}"

new_hosts = YAML.load_file("config.yml")&.fetch("hosts", [])
unless new_hosts.size.positive?
  puts "No hosts requested, end of process !"
  return
end

puts "Looking for Kubernetes host..."
syscmd = Lib::Kubectl.get_hosts

unless syscmd.status.success?
  puts "kubectl failed unexpectedly!"
  puts "stderr:
#{syscmd.stderr}"
  return
end

hosts = JSON.parse(syscmd.stdout)&.fetch("items", [])
hosts = hosts.map { |host| Lib::KubeHost.from_hash(host) }
puts "Found #{hosts.count} hosts!"
targets = hosts.select { |format| new_hosts.include?(format.host) }

if targets.size != new_hosts.size
  puts "Some hosts were not found!"
  puts "Not found hosts: #{new_hosts - targets.map(&:host)}"
end

targets.each do |target|
  puts "Processing '#{target.host}'..."
  pg_credentials = Lib::Postgres.from_hash(Lib::Kubectl.get_pg_credentials(target.namespace, target.decidim_name))

  # exists_service = Lib::Kubectl.get_pg_service(target.namespace, target.decidim_name).status.success?

  AirbyteRuby::Configuration.tap do |c|
    c.endpoint = ENV.fetch("AIRBYTE_ENDPOINT", "http://localhost:8006/")
    c.basic_auth = ENV.fetch("AIRBYTE_BASIC_AUTH", "true") == "true"
    c.airbyte_username = ENV.fetch("AIRBYTE_USERNAME", "airbyte")
    c.airbyte_password = ENV.fetch("AIRBYTE_PASSWORD", "password")
  end


  db_host = ENV["DB_HOST"] || "#{target.decidim_name}--de-pg-headless-replica.#{target.namespace}.svc.cluster.local"
  db_port = ENV["DB_PORT"]&.to_i || 5432
  db_name = ENV["DB_NAME"] || "decidim"
  workspace_uuid = ENV["WORKSPACE_UUID"]

  postgres_adapter = AirbyteRuby::Adapters::Postgres.new(
    host: db_host,
    port: db_port,
    database: db_name,
    username: pg_credentials.username,
    password: pg_credentials.password,
    schema: "public",
    ssl_mode: { mode: "prefer" },
    replication_method: { method: "Xmin" },
    tunnel_method: { tunnel_method: "NO_TUNNEL" }
  )

  airbyte_source = AirbyteRuby::Resources::Source.new(
    postgres_adapter,
    name: "[Decidim] #{target.decidim_name} - #{target.host}",
    workspace_id: workspace_uuid
  )

  res = airbyte_source.new

  if res.success?
    params = JSON.parse(res.body)
    puts "
    Source successfully created!

    Action : Create
    Airbyte response : #{res.status}
    Source UUID: #{params["sourceId"]}
    Source Name: #{params["name"]}

    See more on #{ENV.fetch("AIRBYTE_BASE_URL", "http://localhost:8000/")}workspaces/#{workspace_uuid}/source/#{params["sourceId"]}
  "
  else
    puts "Something went wrong : HTTP Status: #{res.status}"
    puts "#{res.body}"
  end

  puts "Created source '#{airbyte_source.name}' !"
end
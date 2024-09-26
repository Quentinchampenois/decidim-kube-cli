require 'thor'
require_relative 'lib/kubectl'
require_relative 'lib/kube_host'
require_relative 'lib/postgres'

class ThorCli < Thor
  desc 'credentials HOST', 'Get credentials for given host'
  long_desc <<-LONGDESC
  Get credentials for given host

  Example:
    $ ruby cli.rb credentials develop.decidim-app.k8s.osp.cat -s
  LONGDESC
  option :show_pg_service, aliases: :s , type: :boolean, default: false

  def credentials(host)
    puts "Retrieving information for '#{host}'"
    target = find_host(host)
    unless target
      puts "Host not found!"
      return
    end
    puts "Processing '#{target.host}'..."

    puts "############################"
    puts target
    if options[:show_pg_service]
      pg_credentials = ::Lib::Postgres.from_hash(Lib::Kubectl.get_pg_credentials(target.namespace, target.decidim_name))
      puts pg_credentials
    end
  end

  desc 'maintenance HOST', 'Create a maintenance pod for given host'
  long_desc <<-LONGDESC
  Create a maintenance pod for given host

  Example:
    $ ruby cli.rb maintenance develop.decidim-app.k8s.osp.cat -d 30
  LONGDESC
  option :duration, aliases: :d , type: :numeric, default: 30
  def maintenance(host)
    puts "Retrieving information for '#{host}'"

    target = find_host(host)
    unless target
      puts "Host not found!"
      return
    end

    duration = options[:duration]
    puts "> Duration: #{duration} minutes"
    cmd = "kubectl annotate decidim -n #{target.namespace} #{target.decidim_name} decidim.libre.sh/maintenance=#{duration}"
    puts "> #{cmd}"

    puts 'Do you want to continue ? (y/n)'
    answer = $stdin.gets.chomp
    return OpenStruct.new(stderr: 'Aborted !') unless %w(y yes Y Yes).include?(answer)

    syscmd = Lib::Kubectl.kubectl_exec!(cmd)
    if !syscmd.stderr.nil?
      puts syscmd.stderr
      nil
    else
      puts syscmd.stdout
      puts 'Maintenance pod created !'
    end
  end

  private

  def find_host(host)
    puts "Looking for Kubernetes host..."
    syscmd = Lib::Kubectl.get_hosts

    unless syscmd.status.success?
      puts "kubectl failed unexpectedly!"
      puts "stderr:
#{syscmd.stderr}"
      return
    end

    hosts = JSON.parse(syscmd.stdout)&.fetch("items", [])
    hosts = hosts.map { |host| ::Lib::KubeHost.from_hash(host) }

    hosts.find { |format| format.host == host }
  end
end


ThorCli.start(ARGV)
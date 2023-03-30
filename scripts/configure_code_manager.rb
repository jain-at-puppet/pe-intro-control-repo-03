#!/opt/puppetlabs/puppet/bin/ruby
# Usage: ./script nc-host
require 'json'
require 'net/http'
require 'openssl'
require 'puppetclassify'

GIT_REMOTE = "git@gitea:puppet/control-repo.git"

# Hack out SSL verfication
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Kerney updates
ctx = OpenSSL::SSL::SSLContext.new
ctx.ssl_version = :TLSv1_2
ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE

@pe_host = "puppet.c.kmo-instruqt.internal"
@classifier_url =  "https://#{@pe_host}:4433/classifier-api"

def load_classifier()
  auth_info = {
    'ca_certificate_path' => '/dev/null',
    'token'               => @token,
  }
  unless @classifier
    @classifier = PuppetClassify.new(@classifier_url, auth_info)
  end
end

def get_rbac_token(host)
  url = URI("https://#{host}:4433/rbac-api/v1/auth/token")
  req = Net::HTTP::Post.new(url, 'Content-Type' => 'application/json')
  req.body = {
    login: 'admin',
    password: 'puppetlabs',
    label: 'codemgr_settings',
    description: 'This is used to configure the code manager nc settings',
    lifetime: '0'
  }.to_json
  http   = Net::HTTP.new(url.host, url.port)
  http.use_ssl     = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.ssl_version = :TLSv1_2
  res = http.request(req)
  JSON.parse(res.body)['token']
end

def update_pe_master_r10k_remote()
  @token = get_rbac_token(@pe_host)
  load_classifier
  groups    = @classifier.groups
  pe_master = groups.get_groups.select { |group| group['name'] == 'PE Master'}.first
  classes   = pe_master['classes']

  puppet_enterprise_profile_master = classes['puppet_enterprise::profile::master']

  if puppet_enterprise_profile_master['r10k_remote'] == GIT_REMOTE
    puts "Gitlab remote: #{GIT_REMOTE} is already configured for #{@pe_host}"
  else
    puts "Updating r10k remote from #{puppet_enterprise_profile_master['r10k_remote']} to #{GIT_REMOTE}"
    puppet_enterprise_profile_master.update(
      puppet_enterprise_profile_master.merge(
        'code_manager_auto_configure' => true,
        'r10k_remote'      => GIT_REMOTE,
        'r10k_private_key' => '/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa',
        'replication_mode' => 'none'
      )
    )
    # I feel like this composition is overkill if this is truly a delta
    pe_master['classes']['puppet_enterprise::profile::master'] = puppet_enterprise_profile_master
    groups.update_group(pe_master)
  end
end

update_pe_master_r10k_remote
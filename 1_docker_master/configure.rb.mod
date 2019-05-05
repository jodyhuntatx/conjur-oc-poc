bash 'install DH parameters' do
  code 'cp /etc/ssl/dh-3072-rfc3526.pem /etc/ssl/dhparam.pem'
  creates '/etc/ssl/dhparam.pem'
end

bash 'fire off generation of new DH parameters' do
  code '/etc/my_init.d/dhgen.sh'
end

%w(nginx conjur).each do |svc|
  service svc do
    action [ :nothing ]
    provider Chef::Provider::Service::RUnit
  end
end

include_recipe 'conjur::ssl_port'

if conjur_master?
  include_recipe 'conjur::master'
else
  include_recipe 'conjur::slave'
end

# All node types run nginx

# patch nginx config to disable IPV6 listening
bash 'patch nginx config' do
  code '/opt/conjur/evoke/bin/patch_nginx.sh'
end

service 'enable nginx' do
  service_name 'nginx'
  action :enable
  provider Chef::Provider::Service::RUnit
end

service 'start nginx' do
  service_name 'nginx'
  action :start
  retries 3
  provider Chef::Provider::Service::RUnit
end

include_recipe 'conjur::_cluster_service'

if conjur_master? || conjur_follower?
  include_recipe "conjur::_enable_and_start_services"

  bash 'wait until conjur is available' do
    code '/opt/conjur/evoke/bin/wait_for_conjur'
  end
end

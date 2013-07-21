include_recipe 'build-essential'
include_recipe 'git'
include_recipe 'jenkins::server'

directory "#{node['jenkins']['server']['data_dir']}/updates" do
  owner "#{node['jenkins']['server']['user']}"
  group "#{node['jenkins']['server']['user']}"
  action :create
end

execute "update jenkins update center" do
  command "wget http://updates.jenkins-ci.org/update-center.json -qO- | sed '1d;$d'  > #{node['jenkins']['server']['data_dir']}/updates/default.json"
  user "#{node['jenkins']['server']['user']}"
  group "#{node['jenkins']['server']['user']}"
  creates "#{node['jenkins']['server']['data_dir']}/updates/default.json"
end

git_plugin = jenkins_cli 'install-plugin git' do
  not_if { File.exists?("#{node['jenkins']['server']['data_dir']}/plugins/git.jpi") }
end

jenkins_cli 'safe-restart' do
  action :nothing
end

ruby_block 'restart if needed' do
  block do
    if [git_plugin].any?{|r| r.updated?}
      resources('jenkins_cli[safe-restart]').run_action(:run)
      resources('ruby_block[block_until_operational]').run_action(:create)
    end
  end
end

%w{libxml2-dev libxslt-dev}.each do |name|
  package name do
    action :upgrade
  end
end

%w{foodcritic knife-essentials}.each do |name|
  gem_package 'foodcritic' do
    action :upgrade
    gem_binary '/opt/chef/embedded/bin/gem'
  end
end

job_config = File.join(node['jenkins']['node']['home'], 'chef-example-job-config.xml')

jenkins_job 'chef-example' do
  action :nothing
  config job_config
end

template job_config do
  source 'job.xml.erb'
  notifies :update, 'jenkins_job[chef-example]', :immediately
end

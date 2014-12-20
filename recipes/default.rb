#
# Cookbook Name:: scout
# Recipe:: default

Chef::Log.info "Loading: #{cookbook_name}::#{recipe_name}"

apt_repository "scout-archive" do
  key "https://archive.scoutapp.com/scout-archive.key"
  uri "http://archive.scoutapp.com"
end

if node[:scout][:account_key]
  ENV['SCOUT_KEY'] = node[:scout][:account_key]

  package "scoutd" do
    action :install
    version node[:scout][:version]
  end

  template "/etc/scout/scoutd.yml" do
    source "scoutd.yml.erb"
    owner "scoutd"
    group "scoutd"
    variables :options => {
      :account_key => node[:scout][:account_key],
      :hostname => node[:scout][:hostname],
      :display_name => node[:scout][:display_name],
      :log_file => node[:scout][:log_file],
      :ruby_path => node[:scout][:ruby_path],
      :environment => node[:scout][:environment],
      :roles => node[:scout][:roles],
      :agent_data_file => node[:scout][:agent_data_file],
      :http_proxy => node[:scout][:http_proxy],
      :https_proxy => node[:scout][:https_proxy]
    }
    action :create
  end
else
  Chef::Log.warn "The agent will not report to scoutapp.com as a key wasn't provided. Provide a [:scout][:account_key] attribute to complete the install."
end

if node[:scout][:public_key]
  template "/var/lib/scoutd/.scout/scout_rsa.pub" do
    source "scout_rsa.pub.erb"
    mode 0440
    owner "scoutd"
    group "scoutd"
    action :create
  end
end

if node[:scout][:delete_on_shutdown]
  gem_package 'scout_api'
  template "/etc/rc0.d/scout_shutdown" do
    source "scout_shutdown.erb"
    owner "root"
    group "root"
    mode 0755
  end
else
  bash "delete_scout_shutdown" do
    user "root"
    code "rm -f /etc/rc0.d/scout_shutdown"
  end
end

(node[:scout][:plugin_gems] || []).each do |gemname|
  Scout.install_gem(node, [gemname])
end

# Create plugin lookup properties
directory "/home/#{node[:scout][:user]}/.scout" do
  owner node[:scout][:user]
  group node[:scout][:group]
  recursive true
end
template "/home/#{node[:scout][:user]}/.scout/plugins.properties" do
  source "plugins.properties.erb"
  mode 0664
  owner node[:scout][:user]
  group node[:scout][:group]
  variables lazy {
    plugin_properties = {}
    node['scout']['plugin_properties'].each do |property, lookup_hash|
      plugin_properties[property] = Chef::EncryptedDataBagItem.load(lookup_hash[:encrypted_data_bag], lookup_hash[:item])[lookup_hash[:key]]
    end
    {
      :plugin_properties => plugin_properties
    }
  }
  action :create
end
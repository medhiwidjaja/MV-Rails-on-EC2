#############################################
# mv-server::mv2app recipe
#
#   Build a server for mv2app
#############################################

# common stuff
include_recipe "mv-server::default"

# nginx and mv server config
include_recipe "mv-server::nginx"

# install percona mysql client
include_recipe "percona-install::client"

# install node js
#include_recipe "nodejs::install_from_package"
include_recipe "nodejs"

# install ruby
include_recipe "mv-server::install_ruby"

# syslog-ng
node[:syslog_ng][:source] = "syslog-ng/syslog-ng_client.conf_mv"
include_recipe "mv-server::syslog"

# initial code deploy (?)

# nginx config
node['nginx']['default_site_enabled'] = false

cookbook_file "#{node[:nginx][:dir]}/sites-available/mv2app_vhost.conf" do
   source "nginx/mv2app_vhost.conf"
   owner "root"
   group "root"
   mode 00644
   notifies :reload, "service[nginx]"
end

cookbook_file "#{node[:nginx][:dir]}/healthcheck.conf" do
   source "nginx/healthcheck.conf"
   owner "root"
   group "root"
   mode 00644
   notifies :reload, "service[nginx]"
end

cookbook_file "#{node[:nginx][:dir]}/status.conf" do
   source "nginx/status.conf"
   owner "root"
   group "root"
   mode 00644
   notifies :reload, "service[nginx]"
end

cookbook_file "#{node[:nginx][:dir]}/star_measuredvoice_com.pem" do
   source "nginx/star_measuredvoice_com.pem"
   owner "root"
   group "root"
   mode 00644
   notifies :reload, "service[nginx]"
end

execute "enable mv2app vhost" do
  command "/usr/sbin/nxensite mv2app_vhost.conf"
  action :run
end

execute "remove default.conf if it exists" do
  command "mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.orig || true"
  action :run
end

execute "disable default vhost" do
  command "/usr/sbin/nxdissite default"
  action :run
end

# logrotation script for unicorn
cookbook_file "/etc/logrotate.d/unicorn_mv2app" do
   source "logrotate.d/unicorn_mv2app"
   owner "root"
   group "root"
   mode 00640
end


# if running chef solo then assume dev and install
# percona server
if Chef::Config[:solo]
   include_recipe "percona-install::server"

   for dir in [ "/var/run/mysqld",
             "/var/log/mysql",
             "/var/log/mysql/binlogs",
             "/etc/mysql",
             "/etc/mysql/conf.d",
   ] do
      directory "#{dir}" do
         mode "0775"
         owner "mysql"
         group "mysql"
         action :create
         recursive true
      end
   end
  
   cookbook_file "/etc/mysql/my.cnf" do
      source "mysql/my.cnf"
      owner "root"
      group "root"
      mode 00640
   end

   cookbook_file "/etc/mysql/conf.d/dev_master.cnf" do
      source "mysql/conf.d/dev_master.cnf"
      owner "root"
      group "root"
      mode 00640
   end

   link "/etc/my.cnf" do
      to "/etc/mysql/my.cnf"
   end

   service "mysql" do
     supports :restart => true, :status => true
     action [ :enable, :start ]
   end

   # create users and databases 
   #include_recipe "database"
   #mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}

   #mysql_database_user 'mv' do
   #  connection mysql_connection_info
   #  password 'secret'
   #  action :create
   #end 
#
#   mysql_database_user 'mv' do
#     connection mysql_connection_info
#     password 'secret'
#     action :grant
#   end
#
#   mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}
#
#   mysql_database 'mv2_development' do
#     connection mysql_connection_info
#     action :create
#   end
end


# Class redmine::config
class redmine::config {

  if ($redmine::www_server=="apache") {
    require 'apache'
    File {
      owner => $apache::params::user,
      group => $apache::params::group,
      mode  => '0644'
    }
  } elsif ($redmine::www_server=="nginx") {
    require 'nginx'
    File {
      owner => $nginx::params::daemon_user,
      group => $nginx::params::global_group,
      mode  => '0644'
    }
  } else {
    fail("Unknown www_server #{www_server}")
  }

  file { $redmine::webroot:
    ensure => link,
    target => $redmine::install_dir
  }

  # user switching makes passenger run redmine as the owner of the startup file
  # which is config.ru or config/environment.rb depending on the Rails version
  file { "${redmine::install_dir}/config/environment.rb":
    ensure  => present,
  }

  file { "${redmine::install_dir}/config.ru":
    ensure => file,
    content => template('redmine/config.ru.erb'),
    owner => 'root',
    group => 'root',
  }

  file { [
      "${redmine::install_dir}/files",
      "${redmine::install_dir}/tmp",
      "${redmine::install_dir}/tmp/pids",
      "${redmine::install_dir}/tmp/sockets",
      "${redmine::install_dir}/tmp/thumbnails",
      "${redmine::install_dir}/tmp/cache",
      "${redmine::install_dir}/tmp/test",
      "${redmine::install_dir}/tmp/pdf",
      "${redmine::install_dir}/tmp/sessions",
      "${redmine::install_dir}/public/plugin_assets",
      "${redmine::install_dir}/log"]:
    ensure  => 'directory',
  }

  file { "${redmine::install_dir}/config/database.yml":
    ensure  => present,
    content => template('redmine/database.yml.erb'),
    owner => 'root',
    group => 'root',
  }

  file { "${redmine::install_dir}/config/configuration.yml":
    ensure  => present,
    content => template('redmine/configuration.yml.erb'),
    owner => 'root',
    group => 'root',
  }

  if $redmine::www_subdir {
    file_line { 'redmine_relative_url_root':
      path  => "${redmine::install_dir}/config/environment.rb",
      line  => "Redmine::Utils::relative_url_root = '${redmine::context_root}'",
      match => '^Redmine::Utils::relative_url_root',
    }
  } else {
    if $redmine::create_vhost {
      if ("${redmine::www_server}"=="apache") {
        apache::vhost { 'redmine':
          port            => '80',
          docroot         => "${redmine::webroot}/public",
          servername      => $redmine::vhost_servername,
          serveraliases   => $redmine::vhost_aliases,
          options         => 'Indexes FollowSymlinks ExecCGI',
          custom_fragment => "
            RailsBaseURI /
            PassengerPreStart http://${redmine::vhost_servername}
            ",
        }
      } elsif ("${redmine::www_server}"=="nginx") {
        fail("create_vhost for nginx not (yet) implemented")
      }
    }
  }

  # Log rotation
  file { '/etc/logrotate.d/redmine':
    ensure  => present,
    content => template('redmine/redmine-logrotate.erb'),
    owner   => 'root',
    group   => 'root'
  }

}

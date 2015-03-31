# == Class: cg_riak
#
# This module installs Riak to a specified server and keeps the
# configuration up to date.
# To do this it:
# - installs basho (packagecloud) GPG key
# - installs rdiff-backup so backups can be made
# - creats directories and sets settings for riak
# - applies default riak tuning after installation
#
# === Parameters
#
# [*riak_ring_size*]
#  Numeric. This sets the creation size of new rings.
#   This can not be used to resize a ring, that must be done through
#   riak-admin. Once the resize is done, this number should be updated
#   to reflect the new size. Beware, changing this value will trigger
#   a restart of each riak node.
#
# https://github.com/stdmod/puppet-modules/blob/master/Parameters_List.md
# [*module_ensure*]
#   String. Controls if the managed resources shall be <tt>present</tt> or
#   <tt>absent</tt>. If set to <tt>absent</tt>:
#   * The managed software packages are being uninstalled.
#   * Any traces of the packages will be purged as good as possible. This may
#     include existing configuration files. The exact behavior is provider
#     dependent. Q.v.:
#     * Puppet type reference: {package, "purgeable"}[http://j.mp/xbxmNP]
#     * {Puppet's package provider source code}[http://j.mp/wtVCaL]
#   * System modifications (if any) will be reverted as good as possible
#     (e.g. removal of created users, services, changed log settings, ...).
#   * This is thus destructive and should be used with care.
#   Defaults to <tt>present</tt>.
#
# === Variables
#
# hostenv, used to decide whether to use n_val 2 or default of 3.
#
# === Examples
#
# How should this class be used?
#  class { "cg_riak": riak_env => "test" }
#
# === Authors
#
# m.maki@comparegroup.eu
# m.vernimmen@comparegroup.eu
#
# === Copyright
#
# Copyright 2014-2015 Compare Group
#

class cg_riak (
  $riak_ring_size,
  $module_ensure_installed = $cg_riak::params::module_ensure_installed,
  $riak_env = $cg_riak::params::riak_env
) inherits cg_riak::params {
   class{'cg_riak::install': riak_env => $riak_env } ->
   class{'cg_riak::config':  riak_env => $riak_env } ~>
   class{'cg_riak::service': } ->
   Class["cg_riak"]

  # ensure
  if ! ($module_ensure_installed in [ 'present', 'absent' ]) {
    fail("\"${module_ensure_installed}\" is not a valid ensure parameter value")
  }
}


class cg_riak::params {
  # install or not
  $module_ensure_installed = 'present'
  # where to install to
  $cg_riak_install_path="/export/apps/riak"
  # whether services should be running by default or not
  $version="0.0.1"
  # default riak environment
  $riak_env = "test"
  $n_val = 3
}


class cg_riak::install ($riak_env)  {
  $settings_hash = hiera_hash("environments")
  $settings      = $settings_hash[$riak_env]

  case $::osfamily {
    'Redhat':{
		package {
			'riak':		ensure => installed;
			'rdiff-backup' : ensure => installed; # For riak backups. Needed both client and server.
			'perl-JSON-XS' : ensure => installed;
		}
	}
    default:{
      fail("${::operatingsystem} not supported by this module (${::module_name})")
    }
  }

  File {
      backup => false,
  }

  user { "riak":
    name       => riak,
    shell      => "/bin/bash"
  }
	
  # Riak recommends using noatime for better performance.
  mount {
    "/export":
      name    => "/export",
      device  => "/dev/mapper/VG00-LV_export",
      ensure  => mounted,
      fstype  => ext4,
      options => "defaults,noatime",
      dump    => 1,
      pass    => 2,
  }

  # Create the directory structure used by riak
  file {
    "/export/logs/riak":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak/home":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak/bitcask":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/var/lib/riak":
      ensure => link,
      target => "/export/data/riak/home"
    ;
    "/export/data/riak/leveldb":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak/ring":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak/yz":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/export/data/riak/yz_anti_entropy":
      ensure => directory,
      owner  => 'riak',
      group  => 'riak',
      mode   => '0644',
    ;
    "/etc/riak/wildcard.cgnet.nl.crt":
      source  => "puppet:///modules/beheer/secure/wildcard.cgnet.nl.crt",
      mode    => '0644',
      owner   => root,
      group   => root,
      notify  => Service["riak"],
    ;
    "/etc/riak/wildcard.cgnet.nl.pem":
      source  => "puppet:///modules/beheer/secure/wildcard.cgnet.nl.pem",
      mode    => '0644',
      owner   => root,
      group   => root,
      notify  => Service["riak"],
    ;
    "/etc/riak/wildcard.cgnet.nl.key":
      source  => "puppet:///modules/beheer/secure/wildcard.cgnet.nl.key",
      mode    => '0644',
      owner   => root,
      group   => root,
      notify  => Service["riak"],
    ;
    "/etc/security/limits.d/10-riak.conf":
      source  => "puppet:///modules/cg_riak/etc/security/limits.d/10-riak.conf",
      mode    => '0644',
      owner   => root,
      group   => root,
      # Notify to get new limits reloaded.
      notify  => Service["riak"],
    ;
    "/etc/httpd/conf.d/riak.conf":
      content => template("cg_riak/etc/httpd/conf.d/riak.conf.erb"),
      notify  => Service["httpd"],
    ;
    "/export/logs/httpd/riak-internal/":
      ensure  => directory,
      owner   => apache,
      group   => apache,
    ;
    "/export/logs/httpd/riak-external/":
      ensure  => directory,
      owner   => apache,
      group   => apache,
    ;
    "/export/logs/httpd/riak-ssl/":
      ensure  => absent,
      force   => true,
    ;
    "/etc/sudoers.d/riak_admin":
      source  => "puppet:///modules/cg_riak/etc/sudoers.d/riak_admin",
      mode    => "0440",
      owner   => root,
      group   => root
    ;
    "/usr/local/bin/riak-admin-wrapper.sh":
      source  => "puppet:///modules/cg_riak/bin/riak-admin-wrapper.sh",
      mode    => "0500",
      owner   => riak,
      group   => riak
    ;
    "/etc/rsyslog.d/44-riak.conf":
      source => "puppet:///modules/cg_riak/etc/rsyslog.d/44-riak.conf",
      notify => Service["rsyslog"],
      owner  => puppet,
      group  => puppet,
      mode   =>'0644',
    ;
    "/etc/pki/rpm-gpg/RPM-GPG-KEY-riak":
      owner  => root,
      group  => root,
      mode   => '0644',
      source => "puppet:///modules/cg_riak/RPM-GPG-KEY-riak",
    ;
  }

  # Order of things for Riak
  User["riak"] ->
  Package["rdiff-backup"] ->
  Package["perl-JSON-XS"] ->
  File["/export/data/riak"] ->
  File["/export/data/riak/home"] ->
  File["/var/lib/riak"] ->
  Package["riak"] ->
  File["/export/logs/httpd/riak-internal/"] ->
  File["/export/logs/httpd/riak-external/"] ->
  File["/export/logs/httpd/riak-ssl/"] ->
  File["/export/logs/riak"] ->
  File["/export/data/riak/bitcask"] ->
  File["/export/data/riak/leveldb"] ->
  File["/export/data/riak/ring"] ->
  File["/export/data/riak/yz"] ->
  File["/export/data/riak/yz_anti_entropy"] ->
  File["/etc/riak/wildcard.cgnet.nl.pem"] ->
  File["/etc/riak/wildcard.cgnet.nl.key"] ->
  File["/etc/sudoers.d/riak_admin"] ->
  File["/usr/local/bin/riak-admin-wrapper.sh"] ->
  File["/etc/rsyslog.d/44-riak.conf"]

  # Order of things for Apache
  Package["httpd"] ->
  Class["cg_apache::generichttpdconf"] ->
  Class["cg_apache::modrpaf_for_beheer"]
  
  # According to http://docs.basho.com/riak/latest/ops/tuning/linux/
  # the nr of requests in a disk queue should be increased
  # from the default 128 to 1024.
  # Since I (mve) don't know of a way to set this properly,
  # I'm using an execute here. This also means this section MUST NOT
  # be in the 'config' section because it would trigger riak to restart
  # on every puppet run.

  Exec {
    path => '/bin:/usr/bin'
  }

  exec { "rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-riak":
    unless    => "rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n' | grep packagecloud",
    subscribe => File["/etc/pki/rpm-gpg/RPM-GPG-KEY-riak"],
  }

  exec { "set_nrrequests" :
    command     => "echo \"1024\" > /sys/block/sda/queue/nr_requests",
    user        => root,
  }
  
}

class cg_riak::config ($riak_env) {
  # Make sure the Riak nodes adhere to the recommendations
  # (2.0.2) http://docs.basho.com/riak/latest/ops/tuning/linux/
  include sysctl::base
  sysctl {    
      'vm.swappiness': value => '0';
      #for 10gbit connections (not all hosts have this)
      #'net.core.netdev_max_backlog': value => '300000';
      'net.core.netdev_max_backlog': value => '10000';
      'net.core.somaxconn': value => '40000';
      'net.core.wmem_max': value => '8388608';
      'net.core.rmem_max': value => '8388608';
      'net.core.wmem_default': value => '8388608';
      'net.core.rmem_default': value => '8388608';
      'net.ipv4.tcp_max_syn_backlog': value => '40000';
      'net.ipv4.tcp_sack': value => '1';
      'net.ipv4.tcp_window_scaling': value => '1';
      'net.ipv4.tcp_fin_timeout': value => '15';
      'net.ipv4.tcp_keepalive_intvl': value => '30';
      'net.ipv4.tcp_tw_reuse': value => '1';
      'net.ipv4.tcp_moderate_rcvbuf': value => '1';
      'vm.dirty_bytes': value => '209715200';
      'vm.dirty_background_bytes': value => '104857600';
  }
  
  $settings_hash = hiera_hash("environments")
  $settings      = $settings_hash[$riak_env]
  $riak_cookie   = $settings['riak_cookie']
  $n_val         = $settings['n_val']
  file {
    "/etc/riak/riak.conf":
      content => template("cg_riak/riak.conf.erb"),
      notify  => Service["riak"],
      owner   => 'riak',
      group   => 'riak',
      mode    => '0600',
    ;  
  }
}

# make sure the service runs
class cg_riak::service {
  service {
    "riak":
      enable    => true,
      ensure    => running,
      hasstatus => true,
      require   => Package["riak"],
  }
}

class cg_riak::uninstall {
	package {
		'riak': ensure => absent;
		'rdiff-backup' : ensure => absent;
		'perl-JSON-XS' : ensure => absent;
	}
	
	user { "riak":
		name   => riak,
		ensure => absent,
	}
  
	File {
		backup => false,
	}
  
	file {
		"/export/logs/riak":
			ensure  => absent,
			force   => true,
		;
		"/export/data/riak":
			ensure  => absent,
			force   => true,
		;
		"/var/lib/riak":
			ensure  => absent,
			force   => true,
		;
		"/etc/riak":
			ensure  => absent,
			force   => true,
		;
		"/etc/security/limits.d/10-riak.conf":
			ensure  => absent,
			force   => true,
		;
		"/etc/httpd/conf.d/riak.conf":
			ensure  => absent,
			force   => true,
		;
		"/export/logs/httpd/riak-internal/":
			ensure  => absent,
			force   => true,
		;
		"/export/logs/httpd/riak-external/":
			ensure  => absent,
			force   => true,
		;
		"/etc/sudoers.d/riak_admin":
			ensure  => absent,
			force   => true,
		;
		"/usr/local/bin/riak-admin-wrapper.sh":
			ensure  => absent,
			force   => true,
		;
		"/etc/rsyslog.d/44-riak.conf":
			ensure  => absent,
			force   => true,
		;
		"/etc/pki/rpm-gpg/RPM-GPG-KEY-riak":
			ensure  => absent,
                        force   => true,
                ;
	}
	
	Exec {
    		path => '/bin:/usr/bin'
  	}

  	exec { "rpm -e --allmatches gpg-pubkey-d59097ab-52d46e88":
		onlyif => "rpm -q gpg-pubkey  --qf '%{version}-%{release} %{summary}\n' | grep packagecloud",
  	}

	# Order of things
	Package["riak"] ->
	Package["rdiff-backup"] ->
	Package["perl-JSON-XS"] ->
	File["/export/logs/riak"] ->
	File["/export/data/riak"] ->
	File["/var/lib/riak"] ->
	File["/etc/riak"] ->
	File["/etc/security/limits.d/10-riak.conf"] ->
	File["/etc/httpd/conf.d/riak.conf"] ->
	File["/export/logs/httpd/riak-internal/"] ->
	File["/export/logs/httpd/riak-external/"] ->
	File["/etc/sudoers.d/riak_admin"] ->
	File["/usr/local/bin/riak-admin-wrapper.sh"] ->
	File["/etc/rsyslog.d/44-riak.conf"] ->
	User["riak"]
}


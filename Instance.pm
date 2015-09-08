#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Instance;

use Moose;
use File::Spec;

use Rex::Commands::Run;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Service;
require Rex::Commands;

use Artifactory;
use Array::Diff;

BEGIN {
  use Rex::Shared::Var;
  share qw($cfg_download_count $cfg_dir);
};


has app => ( is => 'ro' );
has instance => ( is => 'ro' );
has instance_path => ( is => 'ro' );

has is_active => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    if(is_file(File::Spec->catfile($self->instance_path, "active"))) {
      return 1;
    }

    return 0;
  }
);

has service_name => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return $self->detect_service_name;
  }
);

has sleep_by_start => (is => "ro", default => sub { 0 } );

has configuration_path => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    return File::Spec->catdir($self->instance_path, "conf");
  }
);

sub activate {
  my ($self) = @_;
  my $fh = file_write(File::Spec->catfile($self->instance_path, "active"));
  $fh->close;
}

sub deactivate {
  my ($self) = @_;
  rm(File::Spec->catfile($self->instance_path, "active"));
}

sub detect_service_name { die "Must be overwritten by upper class."; }
sub kill { die "Must be overwritten by upper class."; }
sub rescue { die "Must be overwritten by upper class."; }
sub purge_work_directory { die "Must be overwritten by upper class."; }
sub deploy_app { die "Must be overwritten by upper class."; }
sub deploy_lib { die "Must be overwritten by upper class."; }

sub configure_app {
  my ($self, $configuration_source, $configuration_dest, $params) = @_;

  if(ref $configuration_source eq "CODE") {
    return $configuration_source->($self);
  }

  my $conf_dest = $self->configuration_path;

  # swap parameters, if $configuration_path is default
  if(ref $configuration_dest && ! $params) {
    $params = $configuration_dest;
    $configuration_dest = "";
  }

  if($configuration_dest !~ m/^\//) {
    # relative path
    $configuration_dest = "$conf_dest/$configuration_dest";
  }

  my $tmp_dir;

  if($configuration_source =~ m/^artifactory:/) {
    if(! $cfg_download_count) {
      $cfg_download_count = 1;
    }
    else {
      $cfg_download_count = $cfg_download_count + 1;
    }

    Rex::Commands::LOCAL {
      $tmp_dir = "tmp/configure";

      if($cfg_download_count && $cfg_download_count > 1) {
        $configuration_source = "$tmp_dir/$cfg_dir";
        return;
      }

      rmdir $tmp_dir;
      mkdir $tmp_dir;

      my ($_configuration_source, $query_string) = split(/\?/, $configuration_source);
      my @query_params = split(/\&/, $query_string);
      my %q_params = ();
      for my $qp (@query_params) {
        my ($key, $val) = split(/=/, $qp, 2);
        $q_params{$key} = $val;
      }

      $configuration_source = $_configuration_source;

      my ($repository, $package, $version) = split(/\//, substr($configuration_source, length("artifactory://")));

      my $file = Artifactory::download {
        repository => $repository,
        package    => $package,
        version    => $version,
        to         => $tmp_dir,
        %q_params,
      };

      extract $file, to => $tmp_dir;

      my @content = grep { $_ !~ m/^\./ && is_dir("$tmp_dir/$_") } list_files $tmp_dir;
      if(scalar @content == 1) {
        $cfg_dir = $content[0];
        $configuration_source = "$tmp_dir/$content[0]";
      }
      else {
        $cfg_dir = "";
        $configuration_source = $tmp_dir;
      }
    };
  }

  if(ref $params eq "CODE") {
    $params = $params->($self, $configuration_source);
  }

  my @files;

  if(-f $configuration_source) {
    @files = ($configuration_source);
  }
  elsif(-d $configuration_source) {
    Rex::Commands::LOCAL { @files = grep { is_file("$configuration_source/$_") } list_files($configuration_source); };
  }
  else {
    die "Unknown configuration_source.";
  }

  Rex::Logger::info("Found configuration files: " . join(", ", @files));

  $ENV{tomcat_instance} = substr($self->instance, 1);

  my @cluster_members = map { $_->get_servers } Rex::Group->get_group("servers");

  my @remote_files = grep { is_file("$configuration_dest/$_") } list_files($configuration_dest);

  my $diff = Array::Diff->diff(\@remote_files, \@files);
  my $deleted_files = $diff->deleted;

  sudo sub {
    # ensure that deleted files are absent
    file "$configuration_dest/$_", ensure => 'absent' for @{ $deleted_files };

    # ensure that configuration directory exists
    file $configuration_dest,
      ensure => 'directory',
      owner  => $self->owner,
      group  => $self->group,
      mode   => '0755';

    for my $file (@files) {
      Rex::Logger::info("Uploading configuration file: $configuration_dest/$file");

      file "$configuration_dest/$file",
        content => template("$configuration_source/$file",
                              cluster_members => join(", ", map { ("$_:15701", "$_:25701") } @cluster_members),
                              %{ $params },
                            ),
        mode   => 664,
        owner  => $self->owner,
        group  => $self->group;
    }
  };

}

sub restart {

  my ($self, $param) = @_;

  my $wait_timeout = $param->{wait_timeout} // Rex::Commands::get("wait_timeout");
  my $sleep_time   = $param->{sleep} // 30;

  eval {
    local $SIG{ALRM} = sub { die "timeout"; };

    alarm $wait_timeout;

    sudo sub {
      service $self->service_name => "restart";
    };

    alarm 0;

    1;
  } or do {
    Rex::Logger::info("Instance didn't stop.", "error");
    die "Instance didn't restart.";
  };

  if($self->sleep_by_start) {
    Rex::Logger::info("Sleeping $sleep_time seconds to give instance time to start...");
    sleep $sleep_time;
  }
  else {
    $self->wait_for_start;
  }
}

sub stop {

  my ($self, $param) = @_;

  my $wait_timeout = $param->{wait_timeout} // Rex::Commands::get("wait_timeout");

  eval {
    local $SIG{ALRM} = sub { die("timeout"); };
    alarm $wait_timeout;

    Rex::Logger::info("Try to stop " . $self->service_name);
    sudo sub {
      service $self->service_name => "stop";
    };

    alarm 0;
    1;
  } or do {
    Rex::Logger::info("Instance didn't stopped.", "error");
    die "Instance didn't stopped.";
  };

}

sub start {
  my ($self, $param) = @_;

  if( ! service $self->service_name => "status" ) {
    sudo sub {
      service $self->service_name => "start";
    };

#    if($self->sleep_by_start) {
#      my $sleep_time   = $param->{sleep} // 30;
#      sleep $sleep_time;
#    }
#    else {
#      $self->wait_for_start;
#    }
  }
}


### aspect:

sub wait_for_start {
  my ($self) = @_;

#  # tail the logfile
#  eval {
#    my $log_file = File::Spec->catfile($self->instance_path, "logs", "wrapper.log");
#    tail $log_file, sub {
#      my ($data) = @_;
#
#      Rex::Logger::info($data);
#
#      if($data =~ m/Server startup in (\d+) ms/gms) {
#        # 2014/08/15 16:06:29
#        my ($log_time_year,
#            $log_time_month,
#            $log_time_day,
#            $log_time_hour,
#            $log_time_minute,
#            $log_time_second) = ($data =~ m/\| (\d+)\/(\d+)\/(\d+) (\d+):(\d+):(\d+) \|/);
#
#        my $current_time = time;
#        my $log_time = timelocal( $log_time_second, $log_time_minute, $log_time_hour, $log_time_day, $log_time_month-1, $log_time_year );
#        # wenn der log zeitstempel groesser ist wie die aktuelle Zeit - 60 sekunden
#        # dann ist der log eintrag aus dem aktuellen deployment
#
#        Rex::Logger::info("Comparing time: $log_time >= $current_time");
#
#        if( $log_time >= ($current_time - 60) ) {
#          die "server startup done";
#        }
#      }
#    };
#    1;
#  } or do {
#    my $e = $@;
#    if($e =~ m/server startup done/) {
#      Rex::Logger::info("Server successfully started.");
#    }
#    else {
#      Rex::Logger::info("Error: $e", "error");
#      die "Error starting server: $e";
#    }
#  };

}


1;

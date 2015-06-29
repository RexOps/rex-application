#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Tomcat::Instance;

use Moose;

use common::sense;

use File::Spec;
use XML::Simple;

use Rex::Apache::Deploy qw/Tomcat7/;
use Rex::Commands::File;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Sync;
use Rex::Commands::Service;
use Rex::Commands::Process;
use Rex::Commands::Tail;

require Rex::Commands;

use Apptest::UserAgent;
use Artifactory;

BEGIN {
  use Rex::Shared::Var;
  share qw($download_count $deploy_file);
};

extends qw(Application::Instance);

has manager_user     => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $content = cat(File::Spec->catfile($self->instance_path, "conf", "tomcat-users.xml"));
    my $ref = XMLin($content);
    my ($manager_user) = grep { $_->{roles} =~ m/manager\-script/ } @{ $ref->{user} };
    return $manager_user->{username};
  },
);

has manager_password => (
  is => "ro",
  lazy => 1,
  default => sub {
    my ($self) = @_;
    my $content = cat(File::Spec->catfile($self->instance_path, "conf", "tomcat-users.xml"));
    my $ref = XMLin($content);
    my ($manager_pw) = grep { $_->{roles} =~ m/manager\-script/ } @{ $ref->{user} };
    return $manager_pw->{password};
  },
);


override deploy_lib => sub {
  
  my ($self, $upload_lib_path) = @_;

  if(! -d $upload_lib_path ) {
    die "Directory $upload_lib_path not found.";
  }

  my $instance_path = $self->instance_path;

  Rex::Logger::info("Deploying additional libraries to: $instance_path");

  sudo sub {

    file "$instance_path/lib",
      ensure => 'directory',
      owner  => $self->owner,
      group  => $self->group,
      mode   => 755;

    sync_up $upload_lib_path, "$instance_path/lib";

  };

  $self->restart();
};

override deploy_app => sub {

  my ($self, $war, $context) = @_;

  my $tmp_dir;

  if($war =~ m/^artifactory:/) {
    if(! $download_count) {
      $download_count = 1;
    }
    else {
      $download_count = $download_count + 1;
    }

    Rex::Commands::LOCAL {
      # we must download the war from artifactory
      $tmp_dir = "tmp/deploy";

      if($download_count && $download_count > 1) {
        $war = "$tmp_dir/$deploy_file";
        return;
      }

      rmdir $tmp_dir;
      mkdir $tmp_dir;

      my ($_war, $query_string) = split(/\?/, $war);
      $query_string ||= "";

      my @query_params = split(/\&/, $query_string);
      my %q_params = ();
      for my $qp (@query_params) {
        my ($key, $val) = split(/=/, $qp, 2);
        $q_params{$key} = $val;
      }

      $war = $_war;

      my ($repository, $package, $version) = split(/\//, substr($war, length("artifactory://")));
      $deploy_file = Artifactory::download {
        repository => $repository,
        package    => $package,
        version    => $version,
        to         => $tmp_dir,
      };

      $war = "$tmp_dir/$deploy_file";
    };
  }

  if( ! -f $war ) {
    die "File $war not found.";
  }

  deploy $war,
    username     => $self->manager_user,
    password     => $self->manager_password,
    port         => $self->port,
    context_path => $context;


};


override detect_service_name => sub {
  my ($self) = @_;

  my $out = run "rpm -qa | grep tomcat";

  if($out =~ m/tomcat8/) {
    return "tomcat8" . "-" . $self->instance;
  }
  else {
    return "tomcat7" . "-" . $self->instance;
  }
};


override rescue => sub {

  my ($self, $param) = @_;

  my $sleep_time = $param->{sleep} // 30;

  sudo sub {
    service $self->service_name => "stop";
  };

  sudo sub {
    rm(File::Spec->catfile($self->instance_path, "webapps", "ROOT.war"));
    rmdir File::Spec->catfile($self->instance_path, "webapps", "ROOT");
  };

  if($param->{purge_work_directory}) {
    $self->purge_work_directory()  
  }

  sudo sub {
    service $self->service_name => "start";
  };

  if($self->sleep_by_start) {
    Rex::Logger::info("Sleeping $sleep_time seconds to give tomcat time to start...");
    sleep $sleep_time;
  }
  else {
    $self->wait_for_start;
  }

};

override purge_work_directory => sub {
 
  my ($self) = @_;

  my $work_dir = File::Spec->catdir($self->instance_path, "work", "Catalina", "localhost");

  if(! is_dir($work_dir)) {
    Rex::Logger::info("Tomcat work dir doesn't exist: $work_dir");
    return;
  }

  Rex::Logger::info("Purging work directory: $work_dir");
  sudo sub {
    rmdir $work_dir;
    mkdir $work_dir,
      owner => $self->owner,
      group => $self->group,
      mode => 775;
  };

};

override kill => sub {

  my ($self, $param) = @_;

  my $wait_timeout = $param->{wait_timeout} // Rex::Commands::get("wait_timeout");

  Rex::Logger::info("First trying to stop tomcat in a normal way, waiting $wait_timeout seconds and then using the bigger hammer.");

  eval { $self->stop(); 1; };
  return unless($@);  # tomcat is stopped, so just return

  Rex::Logger::info("Need to use the bigger hammer...");

  sudo sub {
    service $self->service_name => "dump";

    my $instance_name = $self->instance_name;

    my ($pid_file) = map {
        $_->{command} =~ m/wrapper\.pidfile=([^\s]+)/; $_ = $1;
      }
      grep {
        $_->{command} =~ m/wrapper\.pidfile/
        &&
        $_->{command} =~ m/\/$instance_name\//
      } ps;

    if( !$pid_file ) {
      Rex::Logger::info("Process not found. Assuming successfull stop.", "warn");
      return;
    }

    Rex::Logger::info("Try to get pid: $pid_file");
    my $pid = cat $pid_file;

    $pid =~ s/[\r\n]//gms;

    Rex::Logger::info("Got pid-file: $pid_file and pid: $pid");
    Rex::Commands::Process::kill($pid, -9);

    my ($tomcat_pid) =
      map { $_ = $_->{pid}; }
      grep {
        $_->{command} =~ m/wrapper\.pid=$pid/
        &&
        $_->{command} =~ m/\/$instance_name\//
      } ps;

    Rex::Logger::info("Got tomcat-pid-file: $tomcat_pid.");
    Rex::Commands::Process::kill($tomcat_pid, -9);

    my ($process)    =  grep { $_->{pid} eq $pid } ps;
    my ($tc_process) =  grep { $_->{pid} eq $tomcat_pid } ps;
    if($process || $tc_process) {
      Rex::Logger::info("Ouch! Tomcat fought back. Giving up and running away... \\o/", "warn");
      die();
    }

  };

  Rex::Logger::info("Tomcat killed. Hammer was large enough :)");
};

1;

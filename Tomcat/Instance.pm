#
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Application::Tomcat::Instance;

use Moose;

use common::sense;

use File::Spec;
use XML::Simple;
use Time::Local;

use Rex::Apache::Deploy qw/Tomcat7/;
use Rex::Commands::File;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::Sync;
use Rex::Commands::Service;
use Rex::Commands::Process;
use Rex::Commands::Tail;

use Application::Download;
use File::Basename qw/basename/;

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
    my $ref = XMLin($content, Force_Array => 1);
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
    my $ref = XMLin($content, Force_Array => 1);
    my ($manager_pw) = grep { $_->{roles} =~ m/manager\-script/ } @{ $ref->{user} };
    return $manager_pw->{password};
  },
);

has owner => (
  is => "ro",
  lazy => 1,
  default => sub {
    for my $u (qw/tomcat tomcat7 tomcat8/) {
      run "id $u";
      if($? == 0) { return $u; }
    }
  }
);

has group => (
  is => "ro",
  lazy => 1, 
  default => sub {
    for my $u (qw/tomcat tomcat7 tomcat8/) {
      run "id $u";
      if($? == 0) { return $u; }
    }
  }
);

has port => (
  is      => "ro",
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $port;
    sudo sub {
      my @lines = split("\n", cat(File::Spec->catfile($self->instance_path, "conf", "wrapper.conf.d", "java.additional.conf")));
      my ($http_port_line) = grep { m/\-Dtomcat\.http\.port=/ } @lines;
      ($port) = ( $http_port_line =~ m/=(\d+)$/ );
    };
    return $port;
  }
);

after service_start => sub {
  my ($self) = @_;
  $self->wait_for_start;
};


override deploy_lib => sub {
  
  my ($self, $libraries) = @_;

  my $instance_path = $self->instance_path;

  Rex::Logger::info("Deploying additional libraries to: $instance_path");

  sudo sub {

    file "$instance_path/lib",
      ensure => 'directory',
      owner  => $self->owner,
      group  => $self->group,
      mode   => 755;

  };

  for my $lib (@{ $libraries }) {
    my $lib_file = Application::Download::get($lib);

    Rex::Logger::info("Uploading library: " . basename($lib_file) . " -> $instance_path/lib");

    sudo sub {
      file "$instance_path/lib/" . basename($lib_file),
        source => $lib_file,
        mode   => 644;
    };
  }

  $self->restart();
};

override deploy_app => sub {

  my ($self, $war, $context) = @_;

  my $tmp_dir;

  $war = Application::Download::get($war);

  if( ! -f $war ) {
    die "File $war not found.";
  }

  deploy Application::Download::get($war),
    username     => $self->manager_user,
    password     => $self->manager_password,
    port         => $self->port,
    context_path => $context;


};


override detect_service_name => sub {
  my ($self) = @_;

  if(can_run "systemctl") {
    my $sysctl_out = run "systemctl list-units | grep tomcat-" . $self->instance;

    if($sysctl_out) {
      return "tomcat-" . $self->instance;
    }
  }

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

  my $context = "ROOT";

  if(exists $param->{context}) {
    $context = $param->{context};
  }

  if($context eq "/") {
    $context = "ROOT";
  }

  sudo sub {
    service $self->service_name => "stop";
  };

  sudo sub {
    rm(File::Spec->catfile($self->instance_path, "webapps", "$context.war"));
    rmdir File::Spec->catfile($self->instance_path, "webapps", $context);
  };

  if($param->{purge_work_directory}) {
    $self->purge_work_directory($param);
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
 
  my ($self, $param) = @_;

  my $context = "_";

  if(exists $param->{context}) {
    $context = $param->{context};
  }

  if($context eq "/") {
    $context = "_";
  }

  my $work_dir = File::Spec->catdir($self->instance_path, "work", "Catalina", "localhost", $context);

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

override restart => sub {

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
};


override stop => sub {

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

};

sub wait_for_start {
  my ($self) = @_;

  # tail the logfile
  eval {
    my $log_file = File::Spec->catfile($self->instance_path, "logs", "wrapper.log");
    tail $log_file, sub {
      my ($data) = @_;

      Rex::Logger::info($data);

      if($data =~ m/Server startup in (\d+) ms/gms) {
        # 2014/08/15 16:06:29
        my ($log_time_year,
            $log_time_month,
            $log_time_day,
            $log_time_hour,
            $log_time_minute,
            $log_time_second) = ($data =~ m/\| (\d+)\/(\d+)\/(\d+) (\d+):(\d+):(\d+) \|/);

        my $current_time = time;
        my $log_time = timelocal( $log_time_second, $log_time_minute, $log_time_hour, $log_time_day, $log_time_month-1, $log_time_year );
        # wenn der log zeitstempel groesser ist wie die aktuelle Zeit - 60 sekunden
        # dann ist der log eintrag aus dem aktuellen deployment

        Rex::Logger::info("Comparing time: $log_time >= $current_time");

        if( $log_time >= ($current_time - 60) ) {
          die "server startup done";
        }
      }
    };
    1;
  } or do {
    my $e = $@;
    if($e =~ m/server startup done/) {
      Rex::Logger::info("Server successfully started.");
    }
    else {
      Rex::Logger::info("Error: $e", "error");
      die "Error starting server: $e";
    }
  };

}


1;

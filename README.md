# Application

The Application class provides the deployment and instance management functions.

## Types

Currently the following application types are supported. It is easy to create custom ones.

### Static

For static website deployment. This deployment upload files to the webserver and link the document root with the newly uploaded files.


### PHP

PHP deployment is like static deployment.


#### FPM

PHP-FPM deployment extends the PHP deployment with the possibility to restart php-fpm service.


### Tomcat

Tomcat deployment uses the tomcat-manager to deploy war archives. Additionally it supports 2 instance deployments. With this it is possible to deploy all servers with a new version before advising mod_jk to route traffic to the new version.

Additionally it restarts tomcat after the deployment to get a clean jvm.


### JBoss

JBoss deployment uploads an ear file to the deployment directory of JBoss and uses .dodeploy file to trigger the deployment.

Additionally it restarts jboss after the deployment to get a clean jvm.


## Custom Application Types

If you need to extend the deployment you can easily create custom application classes.

For this you need to create 2 classes. One *application* and one *instance* class.

### Application Class

To create an application class you need to inherit from a provided base type. In this example we extend the *Application::PHP::FPM* type.

After this we need to register the new application type to the project class.

```perl
Project->register_app_type($order, $package_Name, $condition_CodeRef);
```

* $oder: an order of "0" will run the detection of this custom application type at first. The provided application types using an order of 100.
* $package_Name: the class name for the application.
* $condition_CodeRef: code that detects the application type.


```perl
package MyApp {

  use Moose;
  use MyApp::Instance;

  require Rex::Commands;

  extends 'Application::PHP::FPM';

  Project->register_app_type(90, __PACKAGE__, sub {
    if(Rex::Commands::connection()->server =~ m/^my\-appsrv/) {
      return 1;
    }

    return 0;
  });

}

1;
```

### Instance Class

The instance class must inherit from one of the provided base types.

```perl
package My::Instance {

  use Moose;
  use Rex::Commands::Run;
  use Rex::Commands::Fs;
  use Rex::Commands::File;

  require Rex::Commands;

  extends 'Application::PHP::FPM::Instance';

  after configure_app => sub {
    # do something after the configuration
  };

}

1;
```

# COPYRIGHT

Copyright 2015 FILIADATA GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.




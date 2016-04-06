# Changes

## Version 201603_21

* Added possibility to display generated content of configuration files instead of uploading.
  For this feature you have to set `REX_APPLICATION_CONFIGURATION_PREVIEW` environment variable to 1.

## Version 201603_01

* Added possibility to define user credentials for http(s) download.
* Added custom document root for php applications.
* Added custom document root for plain html applications.

## Version 201601_01

* Added more `Application::Configuration` classes (Archive, Cmdb_to_properties, ... ).
* Refactored download of files.
* Fixed systemctl call for newer redhat systems.


## Version 8.0.0

* Added `Application::Configuration` factory class.

```perl
$project->deploy(
      deploy_app    => [ "artifactory://$app_repository/$app_package/$app_version" => $context ],
      configure_app => Application::Configuration->get("archive",
                          url => "artifactory://$config_repository/$config_package/$config_version?classifier=properties&package_format=zip",
                          parameter => {
                            multipart_max_request_size => "FOOOOOO",
                          }
                       ),
      test          => {
        location => $test_url,
      }
    );
```

* Added pluggable configuration.
* Added pluggable download options.



# Changes

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



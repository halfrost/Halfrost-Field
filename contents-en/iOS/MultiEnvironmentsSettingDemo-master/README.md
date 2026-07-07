# iOS Multi-Environment Build Configuration
Use a single Scheme to configure multiple environment variables. When running, select different Build Configurations to produce different builds. However, in real-world projects, I do not recommend using one Scheme to build multiple packages like this! This is only a demo to show the process of configuring multiple environments, configuring Schemes, and how to configure things when CocoaPods is involved.

##How to Design Schemes
For an analysis of how Schemes should be designed in an actual project, please see my blog post.

##Exception Occurs
If the app fails to run with “The operation couldn‘t be completed (LaunchServicesError error 0.)”, just run Clean and it should be fine.
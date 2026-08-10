# frozen_string_literal: true

require "xcodeproj"

project_path = ARGV.fetch(0, "ios/Runner.xcodeproj")
bundle_id = ENV.fetch("APP_BUNDLE_ID")
team_id = ENV.fetch("APPLE_TEAM_ID")
profile_name = ENV.fetch("PROFILE_NAME")

raise "APP_BUNDLE_ID must not be empty" if bundle_id.empty?
raise "APPLE_TEAM_ID must not be empty" if team_id.empty?
raise "PROFILE_NAME must not be empty" if profile_name.empty?

project = Xcodeproj::Project.open(project_path)
runner = project.targets.find { |target| target.name == "Runner" }
raise "Runner target was not found in #{project_path}" unless runner

release = runner.build_configurations.find { |configuration| configuration.name == "Release" }
raise "Runner Release configuration was not found in #{project_path}" unless release

release.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
release.build_settings["DEVELOPMENT_TEAM"] = team_id
release.build_settings["CODE_SIGN_STYLE"] = "Manual"
release.build_settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
release.build_settings["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = "Apple Distribution"
release.build_settings["PROVISIONING_PROFILE_SPECIFIER"] = profile_name

project.save

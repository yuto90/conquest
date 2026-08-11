#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require_relative "lib/app_store_release"

module TestFlightInternalGroup
  POLL_INTERVAL_SECONDS = 15

  class CLI
    def initialize(
      argv,
      stdout: $stdout,
      stderr: $stderr,
      sleep_fn: ->(seconds) { sleep(seconds) },
      client_factory: ->(path) { AppStoreRelease::Client.new(api_key_path: path) }
    )
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
      @sleep_fn = sleep_fn
      @client_factory = client_factory
    end

    def run
      command = @argv.shift
      unless %w[validate-manual assign-build assert-no-groups].include?(command)
        raise AppStoreRelease::ValidationError, usage
      end

      api_key_path = required_argument!("API_KEY_PATH")
      bundle_id = required_argument!("BUNDLE_ID")
      group_name = required_argument!("GROUP_NAME")
      client = @client_factory.call(api_key_path)
      app = client.find_app(bundle_id: bundle_id)
      group = validate_manual_group!(client, app.fetch("id"), group_name)

      if command == "validate-manual"
        @stdout.puts(JSON.generate(status: "manual", group_id: group.fetch("id")))
        return 0
      end

      app_version = required_argument!("APP_VERSION")
      build_number = required_argument!("BUILD_NUMBER")
      timeout_seconds = positive_integer!(@argv.shift || "300", "TIMEOUT_SECONDS")
      build = wait_for_build(
        client,
        app_id: app.fetch("id"),
        app_version: app_version,
        build_number: build_number,
        timeout_seconds: timeout_seconds,
      )

      case command
      when "assign-build"
        current_groups = client.beta_groups_for_build(build_id: build.fetch("id"))
        unless current_groups.any? { |candidate| candidate.fetch("id") == group.fetch("id") }
          client.add_build_to_beta_group(group_id: group.fetch("id"), build_id: build.fetch("id"))
        end
        wait_for_internal_assignment(
          client,
          build_id: build.fetch("id"),
          group_id: group.fetch("id"),
          timeout_seconds: timeout_seconds,
        )
        @stdout.puts(JSON.generate(status: "assigned", build_id: build.fetch("id")))
      when "assert-no-groups"
        groups = client.beta_groups_for_build(build_id: build.fetch("id"))
        unless groups.empty?
          names = groups.map { |candidate| candidate.dig("attributes", "name") }.compact
          raise AppStoreRelease::ValidationError,
                "Direct-review build must not belong to a TestFlight group: #{names.join(', ')}"
        end
        @stdout.puts(JSON.generate(status: "unassigned", build_id: build.fetch("id")))
      end
      0
    rescue AppStoreRelease::Error, ArgumentError, Errno::ENOENT,
           JSON::ParserError, KeyError => error
      @stderr.puts("::error::#{error.message}")
      1
    end

    private

    def validate_manual_group!(client, app_id, group_name)
      group = client.find_beta_group(app_id: app_id, name: group_name)
      attributes = group.fetch("attributes")
      unless attributes.fetch("isInternalGroup") == true
        raise AppStoreRelease::ValidationError,
              "TestFlight group is not internal: #{group_name}"
      end
      if attributes.fetch("hasAccessToAllBuilds") == true
        raise AppStoreRelease::ValidationError,
              "Disable automatic distribution for the internal TestFlight group: #{group_name}"
      end
      group
    end

    def wait_for_build(client, app_id:, app_version:, build_number:, timeout_seconds:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
      loop do
        begin
          pre_release = client.find_pre_release_version(app_id: app_id, version: app_version)
          build = client.find_build(
            pre_release_version_id: pre_release.fetch("id"),
            build_number: build_number,
          )
          attributes = build.fetch("attributes")
          state = attributes.fetch("processingState")
          if state == "VALID" && attributes.fetch("expired") == false
            return build
          end
          raise AppStoreRelease::ValidationError,
                "Build processing state is #{state}, expected VALID"
        rescue AppStoreRelease::ValidationError => error
          raise error if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          @sleep_fn.call(POLL_INTERVAL_SECONDS)
        end
      end
    end

    def wait_for_internal_assignment(client, build_id:, group_id:, timeout_seconds:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
      loop do
        groups = client.beta_groups_for_build(build_id: build_id)
        return if groups.any? { |candidate| candidate.fetch("id") == group_id }

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise AppStoreRelease::ValidationError,
                "Timed out waiting for the build to join the internal TestFlight group"
        end
        @sleep_fn.call(POLL_INTERVAL_SECONDS)
      end
    end

    def required_argument!(name)
      value = @argv.shift
      return value if value&.match?(%r{\S})

      raise AppStoreRelease::ValidationError, "#{name} is required; #{usage}"
    end

    def positive_integer!(value, name)
      parsed = Integer(value, 10)
      return parsed if parsed.positive?

      raise ArgumentError, "#{name} must be a positive integer"
    rescue ArgumentError
      raise AppStoreRelease::ValidationError, "#{name} must be a positive integer"
    end

    def usage
      "Usage: #{$PROGRAM_NAME} <validate-manual|assign-build|assert-no-groups> " \
        "API_KEY_PATH BUNDLE_ID GROUP_NAME [APP_VERSION BUILD_NUMBER TIMEOUT_SECONDS]"
    end
  end
end

exit(TestFlightInternalGroup::CLI.new(ARGV).run) if $PROGRAM_NAME == __FILE__

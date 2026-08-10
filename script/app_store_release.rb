#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require_relative "lib/app_store_release"

module AppStoreRelease
  class CLI
    def initialize(argv, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
    end

    def run
      command = @argv.shift
      commands = %w[prepare prepare-check preflight update-metadata]
      raise OptionParser::MissingArgument, "command" unless commands.include?(command)

      options = parse_options(@argv)
      validate_common!(options)
      client = Client.new(api_key_path: options.fetch(:api_key_path))
      service = Service.new(client: client, bundle_id: options.fetch(:bundle_id))

      payload = case command
                when "prepare"
                  result = service.prepare_version(target_version: options.fetch(:app_version))
                  { action: result.action, version_id: result.version_id, message: result.message }
                when "prepare-check"
                  result = service.prepare_check(target_version: options.fetch(:app_version))
                  { action: result.action, version_id: result.version_id, message: result.message }
                when "preflight"
                  preflight(service, options).to_h
                when "update-metadata"
                  result = preflight(service, options)
                  service.update_submission_metadata(
                    preflight: result,
                    whats_new: options.fetch(:whats_new),
                    review_notes: options[:review_notes],
                  )
                  result.to_h.merge(metadata_updated: result.status != :already_submitted)
                end
      @stdout.puts(JSON.generate(payload))
      0
    rescue OptionParser::ParseError, AppStoreRelease::Error, Errno::ENOENT,
           JSON::ParserError, KeyError => error
      @stderr.puts("::error::#{error.message}")
      1
    end

    private

    def parse_options(argv)
      options = {}
      OptionParser.new do |parser|
        parser.on("--api-key-path PATH") { |value| options[:api_key_path] = value }
        parser.on("--bundle-id ID") { |value| options[:bundle_id] = value }
        parser.on("--app-version VERSION") { |value| options[:app_version] = value }
        parser.on("--build-number NUMBER") { |value| options[:build_number] = value }
        parser.on("--internal-group NAME") { |value| options[:internal_group] = value }
        parser.on("--distribution-mode MODE") { |value| options[:distribution_mode] = value }
        parser.on("--whats-new TEXT") { |value| options[:whats_new] = value }
        parser.on("--review-notes TEXT") { |value| options[:review_notes] = value }
      end.parse!(argv)
      options
    end

    def validate_common!(options)
      %i[api_key_path bundle_id app_version].each do |name|
        value = options[name]
        raise OptionParser::MissingArgument, name.to_s.tr("_", "-") unless value&.match?(%r{\S})
      end
      return if options.fetch(:app_version).match?(/\A\d+\.\d+\.\d+\z/)

      raise ValidationError, "App version must be numeric x.y.z"
    end

    def preflight(service, options)
      %i[build_number whats_new].each do |name|
        value = options[name]
        raise OptionParser::MissingArgument, name.to_s.tr("_", "-") unless value&.match?(%r{\S})
      end
      distribution_mode = options.fetch(:distribution_mode, "internal")
      if distribution_mode == "internal" && !options[:internal_group]&.match?(%r{\S})
        raise OptionParser::MissingArgument, "internal-group"
      end
      service.preflight(
        app_version: options.fetch(:app_version),
        build_number: options.fetch(:build_number),
        internal_group: options[:internal_group],
        distribution_mode: distribution_mode,
        whats_new: options.fetch(:whats_new),
        review_notes: options[:review_notes],
      )
    end
  end
end

exit(AppStoreRelease::CLI.new(ARGV).run) if $PROGRAM_NAME == __FILE__

# frozen_string_literal: true

require "rubygems/version"
require "json"
require "net/http"
require "openssl"
require "uri"

module AppStoreRelease
  class Error < StandardError; end
  class ValidationError < Error; end
  class ConflictError < Error; end

  Result = Struct.new(:action, :version_id, :message)
  PreflightResult = Struct.new(
    :status,
    :app_id,
    :version_id,
    :build_id,
    :localization_id,
    :review_detail_id,
    :attached_build_id,
    keyword_init: true,
  )

  EDITABLE_STATES = %w[
    PREPARE_FOR_SUBMISSION
    READY_FOR_REVIEW
    DEVELOPER_REJECTED
    METADATA_REJECTED
    REJECTED
  ].freeze
  LIVE_STATES = %w[READY_FOR_DISTRIBUTION READY_FOR_SALE].freeze
  SUBMITTED_STATES = %w[
    WAITING_FOR_REVIEW
    IN_REVIEW
    PENDING_DEVELOPER_RELEASE
    PENDING_APPLE_RELEASE
  ].freeze

  class NetHttpTransport
    def initialize(base_url: "https://api.appstoreconnect.apple.com")
      @base_url = base_url
    end

    def call(method:, path:, query:, body:, token:)
      uri = URI.join(@base_url, path)
      uri.query = URI.encode_www_form(query) unless query.empty?
      request = request_class(method).new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"
      if body
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      response = Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
      ) { |http| http.request(request) }
      parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      return parsed if response.is_a?(Net::HTTPSuccess)

      details = Array(parsed["errors"]).filter_map do |error|
        error["detail"] || error["title"]
      end
      message = details.empty? ? response.message : details.join("; ")
      raise Error, "App Store Connect API #{response.code}: #{message}"
    rescue JSON::ParserError
      raise Error, "App Store Connect API returned invalid JSON"
    end

    private

    def request_class(method)
      {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PATCH" => Net::HTTP::Patch,
      }.fetch(method)
    end
  end

  class TokenProvider
    def initialize(api_key_path:, now: -> { Time.now.to_i })
      @config = JSON.parse(File.read(api_key_path))
      @now = now
    end

    def token
      require "jwt"
      issued_at = @now.call
      private_key = OpenSSL::PKey::EC.new(@config.fetch("key"))
      JWT.encode(
        {
          iss: @config.fetch("issuer_id"),
          iat: issued_at,
          exp: issued_at + 1_200,
          aud: "appstoreconnect-v1",
        },
        private_key,
        "ES256",
        { kid: @config.fetch("key_id") },
      )
    end
  end

  class Client
    def initialize(transport: NetHttpTransport.new, token: nil, api_key_path: nil)
      @transport = transport
      @token = token
      @token_provider = TokenProvider.new(api_key_path: api_key_path) if api_key_path
      raise ArgumentError, "token or api_key_path is required" unless @token || @token_provider
    end

    def find_app(bundle_id:)
      matches = get(
        "/v1/apps",
        query: { "filter[bundleId]" => bundle_id, "limit" => "2" },
      ).fetch("data").select do |app|
        app.fetch("attributes").fetch("bundleId") == bundle_id
      end
      require_exactly_one(matches, "App Store Connect app for #{bundle_id}")
    end

    def app_store_versions(app_id:)
      get(
        "/v1/apps/#{app_id}/appStoreVersions",
        query: { "filter[platform]" => "IOS", "limit" => "200" },
      ).fetch("data")
    end

    def create_app_store_version(app_id:, version:, release_type:)
      post(
        "/v1/appStoreVersions",
        body: {
          "data" => {
            "type" => "appStoreVersions",
            "attributes" => {
              "platform" => "IOS",
              "versionString" => version,
              "releaseType" => release_type,
            },
            "relationships" => {
              "app" => { "data" => { "type" => "apps", "id" => app_id } },
            },
          },
        },
      ).fetch("data")
    end

    def find_pre_release_version(app_id:, version:)
      matches = get(
        "/v1/preReleaseVersions",
        query: {
          "filter[app]" => app_id,
          "filter[version]" => version,
          "filter[platform]" => "IOS",
          "limit" => "2",
        },
      ).fetch("data").select do |candidate|
        attributes = candidate.fetch("attributes")
        attributes.fetch("version") == version && attributes.fetch("platform") == "IOS"
      end
      require_exactly_one(matches, "iOS pre-release version #{version}")
    end

    def find_build(pre_release_version_id:, build_number:)
      matches = get(
        "/v1/builds",
        query: {
          "filter[preReleaseVersion]" => pre_release_version_id,
          "filter[version]" => build_number,
          "limit" => "2",
        },
      ).fetch("data").select do |build|
        build.fetch("attributes").fetch("version") == build_number
      end
      require_exactly_one(matches, "build #{build_number}")
    end

    def beta_groups_for_build(build_id:)
      response = get(
        "/v1/builds/#{build_id}",
        query: {
          "include" => "betaGroups",
          "fields[betaGroups]" => "name,isInternalGroup",
          "limit[betaGroups]" => "50",
        },
      )
      Array(response["included"]).select { |resource| resource["type"] == "betaGroups" }
    end

    def find_beta_group(app_id:, name:)
      matches = get(
        "/v1/betaGroups",
        query: {
          "filter[app]" => app_id,
          "filter[name]" => name,
          "fields[betaGroups]" => "name,isInternalGroup,hasAccessToAllBuilds",
          "limit" => "2",
        },
      ).fetch("data").select do |group|
        group.fetch("attributes").fetch("name") == name
      end
      require_exactly_one(matches, "TestFlight beta group named #{name}")
    end

    def add_build_to_beta_group(group_id:, build_id:)
      post(
        "/v1/betaGroups/#{group_id}/relationships/builds",
        body: { "data" => [{ "type" => "builds", "id" => build_id }] },
      )
    end

    def version_localizations(version_id:)
      get(
        "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations",
        query: { "limit" => "200" },
      ).fetch("data")
    end

    def review_detail(version_id:)
      get("/v1/appStoreVersions/#{version_id}/appStoreReviewDetail").fetch("data")
    rescue KeyError
      nil
    end

    def attached_build(version_id:)
      get("/v1/appStoreVersions/#{version_id}/relationships/build")["data"]
    end

    def update_localization(localization_id:, whats_new:)
      patch(
        "/v1/appStoreVersionLocalizations/#{localization_id}",
        body: {
          "data" => {
            "type" => "appStoreVersionLocalizations",
            "id" => localization_id,
            "attributes" => { "whatsNew" => whats_new },
          },
        },
      )
    end

    def update_review_detail(review_detail_id:, notes:)
      patch(
        "/v1/appStoreReviewDetails/#{review_detail_id}",
        body: {
          "data" => {
            "type" => "appStoreReviewDetails",
            "id" => review_detail_id,
            "attributes" => { "notes" => notes },
          },
        },
      )
    end

    def attach_build(version_id:, build_id:)
      patch(
        "/v1/appStoreVersions/#{version_id}/relationships/build",
        body: { "data" => { "type" => "builds", "id" => build_id } },
      )
    end

    private

    def get(path, query: {})
      request("GET", path, query: query)
    end

    def post(path, body:)
      request("POST", path, body: body)
    end

    def patch(path, body:)
      request("PATCH", path, body: body)
    end

    def request(method, path, query: {}, body: nil)
      @transport.call(
        method: method,
        path: path,
        query: query,
        body: body,
        token: @token || @token_provider.token,
      )
    end

    def require_exactly_one(matches, label)
      return matches.first if matches.length == 1

      raise ValidationError, "Expected exactly one #{label}, found #{matches.length}"
    end
  end

  def self.compare_versions(left, right)
    Gem::Version.new(left) <=> Gem::Version.new(right)
  rescue ArgumentError
    raise ValidationError, "App version must be numeric x.y.z"
  end

  class Service
    def initialize(client:, bundle_id:)
      @client = client
      @bundle_id = bundle_id
    end

    def prepare_version(target_version:, mutate: true)
      validate_version!(target_version)
      app = @client.find_app(bundle_id: @bundle_id)
      app_id = app.fetch("id")
      versions = @client.app_store_versions(app_id: app_id)
      exact = versions.find { |version| version_string(version) == target_version }
      live = versions
             .select { |version| LIVE_STATES.include?(version_state(version)) }
             .max_by { |version| Gem::Version.new(version_string(version)) }
      conflicting = versions.find do |version|
        version_string(version) != target_version && SUBMITTED_STATES.include?(version_state(version))
      end
      if conflicting
        raise ConflictError,
              "Another iOS App Store version is already in review: #{version_string(conflicting)}"
      end

      if live.nil? && exact
        return reusable_version_result(exact)
      end

      unless live
        if exact
          attached = @client.attached_build(version_id: exact.fetch("id"))
          if attached
            raise ConflictError, "App Store version already has a build attached"
          end
          return reusable_version_result(exact)
        end

        return Result.new(:would_create, nil, "App Store version would be created") unless mutate

        created = @client.create_app_store_version(
          app_id: app_id,
          version: target_version,
          release_type: "MANUAL",
        )
        return Result.new(:created, created.fetch("id"), "App Store version created")
      end

      if exact && LIVE_STATES.include?(version_state(exact))
        return Result.new(:skipped, exact.fetch("id"), "Target version is already live")
      end

      if AppStoreRelease.compare_versions(target_version, version_string(live)) <= 0
        return Result.new(
          :skipped,
          exact&.fetch("id"),
          "Target version is not newer than the live App Store version",
        )
      end

      if exact
        attached = @client.attached_build(version_id: exact.fetch("id"))
        if attached
          raise ConflictError, "App Store version already has a build attached"
        end
        return reusable_version_result(exact)
      end

      return Result.new(:would_create, nil, "App Store version would be created") unless mutate

      created = @client.create_app_store_version(
        app_id: app_id,
        version: target_version,
        release_type: "MANUAL",
      )
      Result.new(:created, created.fetch("id"), "App Store version created")
    end

    def prepare_check(target_version:)
      prepare_version(target_version: target_version, mutate: false)
    end

    def preflight(
      app_version:,
      build_number:,
      whats_new:,
      internal_group: nil,
      distribution_mode: "internal",
      review_notes: nil
    )
      validate_version!(app_version)
      validate_build_number!(build_number)
      validate_required_text!(whats_new, "Japanese what's new")
      validate_review_notes!(review_notes)

      app = @client.find_app(bundle_id: @bundle_id)
      app_id = app.fetch("id")
      versions = @client.app_store_versions(app_id: app_id)
      version = versions.find { |candidate| version_string(candidate) == app_version }
      raise ValidationError, "App Store version #{app_version} was not found" unless version

      state = version_state(version)
      unless (EDITABLE_STATES + SUBMITTED_STATES).include?(state)
        raise ValidationError, "App Store version #{app_version} is not reviewable from state #{state}"
      end
      release_type = version.fetch("attributes").fetch("releaseType")
      raise ValidationError, "App Store version must use manual release" unless release_type == "MANUAL"

      conflicting = versions.find do |candidate|
        version_string(candidate) != app_version && SUBMITTED_STATES.include?(version_state(candidate))
      end
      if conflicting
        raise ConflictError,
              "Another iOS App Store version is already in review: #{version_string(conflicting)}"
      end

      pre_release = @client.find_pre_release_version(app_id: app_id, version: app_version)
      build = @client.find_build(
        pre_release_version_id: pre_release.fetch("id"),
        build_number: build_number,
      )
      validate_build!(build)
      validate_distribution!(
        build.fetch("id"),
        mode: distribution_mode,
        internal_group: internal_group,
      )

      version_id = version.fetch("id")
      localization = japanese_localization!(version_id)
      review_detail = @client.review_detail(version_id: version_id)
      validate_review_detail!(review_detail)
      attached = @client.attached_build(version_id: version_id)
      if attached && attached.fetch("id") != build.fetch("id")
        raise ConflictError, "App Store version has a different build attached"
      end

      status = SUBMITTED_STATES.include?(state) ? :already_submitted : :ready
      if status == :already_submitted && !attached
        raise ConflictError, "Submitted App Store version has no attached build"
      end

      PreflightResult.new(
        status: status,
        app_id: app_id,
        version_id: version_id,
        build_id: build.fetch("id"),
        localization_id: localization.fetch("id"),
        review_detail_id: review_detail.fetch("id"),
        attached_build_id: attached&.fetch("id"),
      )
    end

    def update_submission_metadata(preflight:, whats_new:, review_notes: nil)
      return if preflight.status == :already_submitted

      validate_required_text!(whats_new, "Japanese what's new")
      validate_review_notes!(review_notes)
      @client.update_localization(
        localization_id: preflight.localization_id,
        whats_new: whats_new,
      )
      if review_notes&.match?(%r{\S})
        @client.update_review_detail(
          review_detail_id: preflight.review_detail_id,
          notes: review_notes,
        )
      end
      return if preflight.attached_build_id == preflight.build_id

      @client.attach_build(version_id: preflight.version_id, build_id: preflight.build_id)
    end

    private

    def reusable_version_result(version)
      release_type = version.fetch("attributes").fetch("releaseType")
      unless release_type == "MANUAL"
        raise ConflictError, "Existing App Store version must use manual release"
      end
      state = version_state(version)
      unless (EDITABLE_STATES + SUBMITTED_STATES).include?(state)
        raise ConflictError, "Existing App Store version is not reusable from state #{state}"
      end

      Result.new(:reused, version.fetch("id"), "App Store version already exists")
    end

    def validate_version!(value)
      return if value&.match?(/\A\d+\.\d+\.\d+\z/)

      raise ValidationError, "App version must be numeric x.y.z"
    end

    def validate_build_number!(value)
      return if value&.match?(/\A\d+\z/)

      raise ValidationError, "Build number must contain digits only"
    end

    def validate_required_text!(value, label)
      raise ValidationError, "#{label} must not be blank" unless value&.match?(%r{\S})
      raise ValidationError, "#{label} must be 4,000 characters or fewer" if value.length > 4_000
    end

    def validate_review_notes!(value)
      return unless value&.match?(%r{\S})
      return if value.bytesize <= 4_000

      raise ValidationError, "App Review notes must be 4,000 bytes or fewer"
    end

    def validate_build!(build)
      attributes = build.fetch("attributes")
      state = attributes.fetch("processingState")
      raise ValidationError, "Build processing state is #{state}, expected VALID" unless state == "VALID"
      raise ValidationError, "Build is expired" if attributes.fetch("expired")
    end

    def validate_distribution!(build_id, mode:, internal_group:)
      groups = @client.beta_groups_for_build(build_id: build_id)
      if mode == "none"
        return if groups.empty?

        raise ValidationError, "Direct-review build must not belong to a TestFlight group"
      end
      unless mode == "internal"
        raise ValidationError, "Distribution mode must be internal or none"
      end
      validate_required_text!(internal_group, "Internal TestFlight group")

      matching = groups.select do |group|
        attributes = group.fetch("attributes")
        attributes.fetch("name") == internal_group && attributes.fetch("isInternalGroup") == true
      end
      return if matching.length == 1

      raise ValidationError,
            "Build must belong to exactly one internal TestFlight group named #{internal_group}"
    end

    def japanese_localization!(version_id)
      localizations = @client.version_localizations(version_id: version_id)
      japanese = localizations.find do |localization|
        %w[ja ja-JP].include?(localization.fetch("attributes").fetch("locale"))
      end
      raise ValidationError, "Japanese App Store localization was not found" unless japanese

      attributes = japanese.fetch("attributes")
      %w[description keywords supportUrl].each do |name|
        value = attributes[name]
        raise ValidationError, "Japanese localization #{name} must not be blank" unless value&.match?(%r{\S})
      end
      japanese
    end

    def validate_review_detail!(review_detail)
      raise ValidationError, "App Review details were not found" unless review_detail

      attributes = review_detail.fetch("attributes")
      %w[contactFirstName contactLastName contactPhone contactEmail].each do |name|
        value = attributes[name]
        raise ValidationError, "App Review detail #{name} must not be blank" unless value&.match?(%r{\S})
      end
      demo_required = attributes["demoAccountRequired"]
      unless [true, false].include?(demo_required)
        raise ValidationError, "App Review detail demoAccountRequired must be true or false"
      end
      return unless demo_required

      %w[demoAccountName demoAccountPassword].each do |name|
        value = attributes[name]
        raise ValidationError, "App Review detail #{name} must not be blank" unless value&.match?(%r{\S})
      end
    end

    def version_string(version)
      version.fetch("attributes").fetch("versionString")
    end

    def version_state(version)
      attributes = version.fetch("attributes")
      attributes["appVersionState"] || attributes.fetch("appStoreState")
    end
  end
end

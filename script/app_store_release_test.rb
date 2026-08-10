#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "lib/app_store_release"

class AppStoreReleaseTest < Minitest::Test
  FakeTransport = Struct.new(:response, :requests, keyword_init: true) do
    def call(method:, path:, query:, body:, token:)
      requests << { method: method, path: path, query: query, body: body, token: token }
      response
    end
  end

  FakeClient = Struct.new(
    :versions,
    :created_requests,
    :pre_release_version,
    :build,
    :beta_groups,
    :localizations,
    :review_details,
    :attached,
    :mutations,
    keyword_init: true,
  ) do
    def find_app(bundle_id:)
      raise "unexpected bundle ID" unless bundle_id == "com.conquest.conquest"

      { "id" => "app-1", "attributes" => { "bundleId" => bundle_id } }
    end

    def app_store_versions(app_id:)
      raise "unexpected app ID" unless app_id == "app-1"

      versions
    end

    def create_app_store_version(app_id:, version:, release_type:)
      created_requests << { app_id: app_id, version: version, release_type: release_type }
      {
        "id" => "version-created",
        "attributes" => {
          "versionString" => version,
          "releaseType" => release_type,
          "appStoreState" => "PREPARE_FOR_SUBMISSION",
        },
      }
    end

    def find_pre_release_version(app_id:, version:)
      raise "unexpected pre-release lookup" unless app_id == "app-1" && version == "1.0.1"

      pre_release_version
    end

    def find_build(pre_release_version_id:, build_number:)
      raise "unexpected build lookup" unless pre_release_version_id == "pre-101" && build_number == "123"

      build
    end

    def beta_groups_for_build(build_id:)
      raise "unexpected build ID" unless build_id == "build-123"

      beta_groups
    end

    def version_localizations(version_id:)
      raise "unexpected version ID" unless version_id == "version-101"

      localizations
    end

    def review_detail(version_id:)
      raise "unexpected version ID" unless version_id == "version-101"

      review_details
    end

    def attached_build(version_id:)
      raise "unexpected version ID" unless version_id == "version-101"

      attached
    end

    def update_localization(localization_id:, whats_new:)
      mutations << [:localization, localization_id, whats_new]
    end

    def update_review_detail(review_detail_id:, notes:)
      mutations << [:review_detail, review_detail_id, notes]
    end

    def attach_build(version_id:, build_id:)
      mutations << [:build, version_id, build_id]
    end
  end

  def test_compares_numeric_version_components
    assert_operator AppStoreRelease.compare_versions("1.10.0", "1.9.9"), :>, 0
  end

  def test_prepare_skips_version_that_is_not_newer_than_live
    client = FakeClient.new(
      versions: [version("1.0.0", "READY_FOR_DISTRIBUTION")],
      created_requests: [],
    )

    result = service(client).prepare_version(target_version: "1.0.0")

    assert_equal :skipped, result.action
    assert_empty client.created_requests
  end

  def test_prepare_reuses_existing_editable_version
    client = FakeClient.new(
      versions: [
        version("1.0.0", "READY_FOR_DISTRIBUTION"),
        version("1.0.1", "PREPARE_FOR_SUBMISSION", id: "version-101"),
      ],
      created_requests: [],
    )

    result = service(client).prepare_version(target_version: "1.0.1")

    assert_equal :reused, result.action
    assert_equal "version-101", result.version_id
    assert_empty client.created_requests
  end

  def test_prepare_reuses_existing_submitted_version_without_mutating_it
    client = FakeClient.new(
      versions: [
        version("1.0.0", "READY_FOR_DISTRIBUTION"),
        version("1.0.1", "WAITING_FOR_REVIEW", id: "version-101"),
      ],
      created_requests: [],
    )

    result = service(client).prepare_version(target_version: "1.0.1")

    assert_equal :reused, result.action
    assert_equal "version-101", result.version_id
    assert_empty client.created_requests
  end

  def test_prepare_rejects_existing_version_that_is_not_manual_release
    automatic = version("1.0.1", "PREPARE_FOR_SUBMISSION", id: "version-101")
    automatic["attributes"]["releaseType"] = "AFTER_APPROVAL"
    client = FakeClient.new(
      versions: [version("1.0.0", "READY_FOR_DISTRIBUTION"), automatic],
      created_requests: [],
    )

    error = assert_raises(AppStoreRelease::ConflictError) do
      service(client).prepare_version(target_version: "1.0.1")
    end

    assert_match(/manual release/, error.message)
    assert_empty client.created_requests
  end

  def test_prepare_creates_new_manual_version
    client = FakeClient.new(
      versions: [version("1.0.0", "READY_FOR_DISTRIBUTION")],
      created_requests: [],
    )

    result = service(client).prepare_version(target_version: "1.0.1")

    assert_equal :created, result.action
    assert_equal "version-created", result.version_id
    assert_equal(
      [{ app_id: "app-1", version: "1.0.1", release_type: "MANUAL" }],
      client.created_requests,
    )
  end

  def test_prepare_skips_older_target_before_reading_attached_build
    client = FakeClient.new(
      versions: [
        version("1.0.7", "READY_FOR_DISTRIBUTION", id: "version-live"),
        version("1.0.6", "DEVELOPER_REJECTED", id: "version-old"),
      ],
      created_requests: [],
    )
    client.define_singleton_method(:attached_build) do |version_id:|
      raise "attached build must not be read for an older target" if version_id == "version-old"

      attached
    end

    result = service(client).prepare_version(target_version: "1.0.6")

    assert_equal :skipped, result.action
    assert_equal "version-old", result.version_id
    assert_empty client.created_requests
  end

  def test_prepare_creates_initial_manual_version_when_no_live_version_exists
    client = FakeClient.new(versions: [], created_requests: [])

    result = service(client).prepare_version(target_version: "1.0.1")

    assert_equal :created, result.action
    assert_equal(
      [{ app_id: "app-1", version: "1.0.1", release_type: "MANUAL" }],
      client.created_requests,
    )
  end

  def test_prepare_reuses_existing_manual_version_when_no_live_version_exists
    client = FakeClient.new(
      versions: [version("1.0.1", "PREPARE_FOR_SUBMISSION", id: "version-101")],
      created_requests: [],
    )

    result = service(client).prepare_version(target_version: "1.0.1")

    assert_equal :reused, result.action
    assert_equal "version-101", result.version_id
    assert_empty client.created_requests
  end

  def test_prepare_rejects_another_version_under_review_before_mutating
    client = FakeClient.new(
      versions: [
        version("1.0.0", "READY_FOR_DISTRIBUTION", id: "version-live"),
        version("1.0.2", "WAITING_FOR_REVIEW", id: "version-102"),
      ],
      created_requests: [],
    )

    error = assert_raises(AppStoreRelease::ConflictError) do
      service(client).prepare_version(target_version: "1.0.1")
    end

    assert_match(/already in review: 1\.0\.2/, error.message)
    assert_empty client.created_requests
  end

  def test_prepare_check_accepts_new_version_without_mutating
    client = FakeClient.new(versions: [], created_requests: [])

    result = service(client).prepare_check(target_version: "1.0.1")

    assert_equal :would_create, result.action
    assert_empty client.created_requests
  end

  def test_prepare_rejects_existing_version_with_an_attached_build_before_mutating
    client = FakeClient.new(
      versions: [
        version("1.0.0", "READY_FOR_DISTRIBUTION", id: "version-live"),
        version("1.0.1", "PREPARE_FOR_SUBMISSION", id: "version-101"),
      ],
      created_requests: [],
      attached: { "id" => "build-existing" },
    )

    error = assert_raises(AppStoreRelease::ConflictError) do
      service(client).prepare_version(target_version: "1.0.1")
    end

    assert_match(/already has a build attached/, error.message)
    assert_empty client.created_requests
  end

  def test_client_creates_manual_app_store_version
    transport = FakeTransport.new(
      response: { "data" => version("1.0.1", "PREPARE_FOR_SUBMISSION") },
      requests: [],
    )
    client = AppStoreRelease::Client.new(transport: transport, token: "test-token")

    client.create_app_store_version(app_id: "app-1", version: "1.0.1", release_type: "MANUAL")

    request = transport.requests.fetch(0)
    assert_equal "POST", request.fetch(:method)
    assert_equal "/v1/appStoreVersions", request.fetch(:path)
    assert_equal "MANUAL", request.dig(:body, "data", "attributes", "releaseType")
    assert_equal "app-1", request.dig(:body, "data", "relationships", "app", "data", "id")
  end

  def test_client_reads_beta_groups_from_build_include
    group = {
      "type" => "betaGroups",
      "id" => "group-internal",
      "attributes" => { "name" => "Internal", "isInternalGroup" => true },
    }
    transport = FakeTransport.new(
      response: { "data" => { "type" => "builds", "id" => "build-123" }, "included" => [group] },
      requests: [],
    )
    client = AppStoreRelease::Client.new(transport: transport, token: "test-token")

    assert_equal [group], client.beta_groups_for_build(build_id: "build-123")
    request = transport.requests.fetch(0)
    assert_equal "/v1/builds/build-123", request.fetch(:path)
    assert_equal "betaGroups", request.dig(:query, "include")
  end

  def test_client_attaches_build_with_patch_relationship_request
    transport = FakeTransport.new(response: { "data" => nil }, requests: [])
    client = AppStoreRelease::Client.new(transport: transport, token: "test-token")

    client.attach_build(version_id: "version-101", build_id: "build-123")

    request = transport.requests.fetch(0)
    assert_equal "PATCH", request.fetch(:method)
    assert_equal "/v1/appStoreVersions/version-101/relationships/build", request.fetch(:path)
    assert_equal "builds", request.dig(:body, "data", "type")
    assert_equal "build-123", request.dig(:body, "data", "id")
  end

  def test_preflight_accepts_exact_valid_internal_build
    result = service(release_client).preflight(
      app_version: "1.0.1",
      build_number: "123",
      internal_group: "Internal",
      whats_new: "改善しました",
    )

    assert_equal :ready, result.status
    assert_equal "build-123", result.build_id
    assert_equal "version-101", result.version_id
    assert_equal "localization-ja", result.localization_id
  end

  def test_preflight_rejects_expired_build
    client = release_client
    client.build["attributes"]["expired"] = true

    error = assert_raises(AppStoreRelease::ValidationError) do
      service(client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        internal_group: "Internal",
        whats_new: "改善しました",
      )
    end

    assert_match(/expired/, error.message)
  end

  def test_preflight_rejects_build_that_was_not_distributed_internally
    client = release_client
    client.beta_groups = []

    error = assert_raises(AppStoreRelease::ValidationError) do
      service(client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        internal_group: "Internal",
        whats_new: "改善しました",
      )
    end

    assert_match(/internal TestFlight group/, error.message)
  end

  def test_preflight_accepts_direct_review_build_with_no_beta_groups
    client = release_client
    client.beta_groups = []

    result = service(client).preflight(
      app_version: "1.0.1",
      build_number: "123",
      distribution_mode: "none",
      whats_new: "改善しました",
    )

    assert_equal :ready, result.status
  end

  def test_preflight_rejects_direct_review_build_assigned_to_any_beta_group
    error = assert_raises(AppStoreRelease::ValidationError) do
      service(release_client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        distribution_mode: "none",
        whats_new: "改善しました",
      )
    end

    assert_match(/must not belong to a TestFlight group/, error.message)
  end

  def test_preflight_rejects_review_notes_over_four_thousand_bytes
    error = assert_raises(AppStoreRelease::ValidationError) do
      service(release_client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        internal_group: "Internal",
        whats_new: "改善しました",
        review_notes: "あ" * 1_334,
      )
    end

    assert_match(/4,000 bytes/, error.message)
  end

  def test_preflight_requires_demo_credentials_when_demo_account_is_required
    client = release_client
    client.review_details["attributes"]["demoAccountRequired"] = true
    client.review_details["attributes"]["demoAccountName"] = ""
    client.review_details["attributes"]["demoAccountPassword"] = ""

    error = assert_raises(AppStoreRelease::ValidationError) do
      service(client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        internal_group: "Internal",
        whats_new: "改善しました",
      )
    end

    assert_match(/demoAccountName/, error.message)
  end

  def test_preflight_rejects_different_attached_build
    client = release_client
    client.attached = { "id" => "build-other", "attributes" => { "version" => "122" } }

    error = assert_raises(AppStoreRelease::ConflictError) do
      service(client).preflight(
        app_version: "1.0.1",
        build_number: "123",
        internal_group: "Internal",
        whats_new: "改善しました",
      )
    end

    assert_match(/different build/, error.message)
  end

  def test_preflight_treats_same_submitted_build_as_idempotent
    client = release_client
    client.versions.last["attributes"]["appStoreState"] = "WAITING_FOR_REVIEW"
    client.attached = client.build

    result = service(client).preflight(
      app_version: "1.0.1",
      build_number: "123",
      internal_group: "Internal",
      whats_new: "改善しました",
    )

    assert_equal :already_submitted, result.status
  end

  def test_update_submission_metadata_updates_whats_new_and_attaches_build
    client = release_client
    release_service = service(client)
    preflight = release_service.preflight(
      app_version: "1.0.1",
      build_number: "123",
      internal_group: "Internal",
      whats_new: "改善しました",
    )

    release_service.update_submission_metadata(
      preflight: preflight,
      whats_new: "改善しました",
      review_notes: "遊び方を確認してください",
    )

    assert_equal(
      [
        [:localization, "localization-ja", "改善しました"],
        [:review_detail, "review-detail-1", "遊び方を確認してください"],
        [:build, "version-101", "build-123"],
      ],
      client.mutations,
    )
  end

  def test_update_submission_metadata_keeps_existing_review_notes_when_blank
    client = release_client
    release_service = service(client)
    preflight = release_service.preflight(
      app_version: "1.0.1",
      build_number: "123",
      internal_group: "Internal",
      whats_new: "改善しました",
    )

    release_service.update_submission_metadata(
      preflight: preflight,
      whats_new: "改善しました",
      review_notes: "  ",
    )

    refute client.mutations.any? { |mutation| mutation.first == :review_detail }
  end

  def test_cli_rejects_non_numeric_version_before_calling_api
    script = File.expand_path("app_store_release.rb", __dir__)
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      script,
      "prepare",
      "--app-version",
      "latest",
      "--bundle-id",
      "com.conquest.conquest",
      "--api-key-path",
      "/missing/key.json",
    )

    refute status.success?
    assert_match(/numeric x\.y\.z/, stderr)
  end

  private

  def service(client)
    AppStoreRelease::Service.new(client: client, bundle_id: "com.conquest.conquest")
  end

  def version(number, state, id: "version-#{number}")
    {
      "id" => id,
      "attributes" => {
        "versionString" => number,
        "appStoreState" => state,
        "releaseType" => "MANUAL",
      },
    }
  end

  def release_client
    FakeClient.new(
      versions: [
        version("1.0.0", "READY_FOR_DISTRIBUTION", id: "version-live"),
        version("1.0.1", "PREPARE_FOR_SUBMISSION", id: "version-101"),
      ],
      created_requests: [],
      pre_release_version: {
        "id" => "pre-101",
        "attributes" => { "version" => "1.0.1", "platform" => "IOS" },
      },
      build: {
        "id" => "build-123",
        "attributes" => {
          "version" => "123",
          "processingState" => "VALID",
          "expired" => false,
        },
      },
      beta_groups: [
        {
          "id" => "group-internal",
          "attributes" => { "name" => "Internal", "isInternalGroup" => true },
        },
      ],
      localizations: [
        {
          "id" => "localization-ja",
          "attributes" => {
            "locale" => "ja",
            "description" => "Conquest game",
            "keywords" => "game,strategy",
            "supportUrl" => "https://example.com/support",
          },
        },
      ],
      review_details: {
        "id" => "review-detail-1",
        "attributes" => {
          "contactFirstName" => "Conquest",
          "contactLastName" => "Team",
          "contactPhone" => "+81-90-0000-0000",
          "contactEmail" => "review@example.com",
          "demoAccountRequired" => false,
          "notes" => "遊び方を確認してください",
        },
      },
      attached: nil,
      mutations: [],
    )
  end
end

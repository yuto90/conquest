#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require_relative "testflight-internal-group"

class TestFlightInternalGroupTest < Minitest::Test
  FakeClient = Struct.new(:group, :groups, :mutations, keyword_init: true) do
    def find_app(bundle_id:)
      raise "unexpected bundle" unless bundle_id == "com.conquest.conquest"

      { "id" => "app-1" }
    end

    def find_beta_group(app_id:, name:)
      raise "unexpected app" unless app_id == "app-1"
      raise "unexpected group" unless name == "Internal"

      group
    end

    def find_pre_release_version(app_id:, version:)
      raise "unexpected version" unless app_id == "app-1" && version == "1.0.1"

      { "id" => "pre-101" }
    end

    def find_build(pre_release_version_id:, build_number:)
      raise "unexpected build" unless pre_release_version_id == "pre-101" && build_number == "123"

      {
        "id" => "build-123",
        "attributes" => { "processingState" => "VALID", "expired" => false },
      }
    end

    def beta_groups_for_build(build_id:)
      raise "unexpected build ID" unless build_id == "build-123"

      groups.shift || []
    end

    def add_build_to_beta_group(group_id:, build_id:)
      mutations << [group_id, build_id]
    end
  end

  def test_validate_manual_rejects_automatic_internal_group
    client = fake_client(has_access_to_all_builds: true)
    stderr = StringIO.new

    status = cli(["validate-manual", "key.json", "com.conquest.conquest", "Internal"], client, stderr: stderr).run

    assert_equal 1, status
    assert_match(/Disable automatic distribution/, stderr.string)
  end

  def test_validate_manual_rejects_external_group
    client = fake_client(is_internal_group: false)
    stderr = StringIO.new

    status = cli(["validate-manual", "key.json", "com.conquest.conquest", "Internal"], client, stderr: stderr).run

    assert_equal 1, status
    assert_match(/not internal/, stderr.string)
  end

  def test_assign_build_adds_exact_build_to_manual_internal_group
    client = fake_client(groups: [[], [internal_group]])

    status = cli(
      ["assign-build", "key.json", "com.conquest.conquest", "Internal", "1.0.1", "123", "1"],
      client,
    ).run

    assert_equal 0, status
    assert_equal [["group-internal", "build-123"]], client.mutations
  end

  def test_assign_build_does_not_duplicate_existing_assignment
    client = fake_client(groups: [[internal_group], [internal_group]])

    status = cli(
      ["assign-build", "key.json", "com.conquest.conquest", "Internal", "1.0.1", "123", "1"],
      client,
    ).run

    assert_equal 0, status
    assert_empty client.mutations
  end

  def test_assert_no_groups_rejects_any_testflight_assignment
    client = fake_client(groups: [[internal_group]])
    stderr = StringIO.new

    status = cli(
      ["assert-no-groups", "key.json", "com.conquest.conquest", "Internal", "1.0.1", "123", "1"],
      client,
      stderr: stderr,
    ).run

    assert_equal 1, status
    assert_match(/must not belong to a TestFlight group/, stderr.string)
  end

  def test_assign_build_rejects_unprocessed_build_after_timeout
    client = fake_client(groups: [[]])
    client.define_singleton_method(:find_build) do |pre_release_version_id:, build_number:|
      {
        "id" => "build-123",
        "attributes" => { "processingState" => "PROCESSING", "expired" => false },
      }
    end
    stderr = StringIO.new

    status = cli(
      ["assign-build", "key.json", "com.conquest.conquest", "Internal", "1.0.1", "123", "1"],
      client,
      stderr: stderr,
    ).run

    assert_equal 1, status
    assert_match(/PROCESSING/, stderr.string)
  end

  private

  def cli(argv, client, stderr: StringIO.new)
    TestFlightInternalGroup::CLI.new(
      argv,
      stdout: StringIO.new,
      stderr: stderr,
      sleep_fn: ->(_seconds) {},
      client_factory: ->(_path) { client },
    )
  end

  def fake_client(has_access_to_all_builds: false, is_internal_group: true, groups: [])
    FakeClient.new(
      group: internal_group(
        has_access_to_all_builds: has_access_to_all_builds,
        is_internal_group: is_internal_group,
      ),
      groups: groups,
      mutations: [],
    )
  end

  def internal_group(has_access_to_all_builds: false, is_internal_group: true)
    {
      "id" => "group-internal",
      "attributes" => {
        "name" => "Internal",
        "isInternalGroup" => is_internal_group,
        "hasAccessToAllBuilds" => has_access_to_all_builds,
      },
    }
  end
end

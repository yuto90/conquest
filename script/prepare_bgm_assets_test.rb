#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"
require "yaml"

class PrepareBgmAssetsTest < Minitest::Test
  SCRIPT = File.expand_path("prepare-bgm-assets.sh", __dir__)
  FILENAMES = %w[metropolis_destruction.mp3 tense_tactics.mp3].freeze

  def setup
    @directory = Dir.mktmpdir
    @source = File.join(@directory, "source")
    @destination = File.join(@directory, "assets", "audio")
    FileUtils.mkdir_p(@source)
    FILENAMES.each { |name| File.binwrite(File.join(@source, name), "fixture for #{name}") }
    @env = {
      "BGM_MENU_SHA256" => Digest::SHA256.file(File.join(@source, FILENAMES[0])).hexdigest,
      "BGM_BATTLE_SHA256" => Digest::SHA256.file(File.join(@source, FILENAMES[1])).hexdigest,
      "BGM_MENU_URL" => "https://private.example/menu?token=do-not-log",
      "BGM_BATTLE_URL" => "https://private.example/battle?token=do-not-log",
    }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def run_script(*args)
    Open3.capture3(@env, "bash", SCRIPT, *args)
  end

  def test_copies_both_approved_files_and_verifies_bundle
    _, error, status = run_script(@destination, @source)
    assert status.success?, error
    FILENAMES.each do |name|
      assert_equal File.binread(File.join(@source, name)), File.binread(File.join(@destination, name))
    end
    _, error, status = run_script("--verify", @destination)
    assert status.success?, error
  end

  def test_missing_battle_track_does_not_install_menu_track
    File.delete(File.join(@source, FILENAMES[1]))
    _, error, status = run_script(@destination, @source)
    refute status.success?
    assert_includes error, "Missing source tense_tactics.mp3"
    refute File.exist?(@destination)
  end

  def test_rejects_empty_track_even_when_hash_matches
    File.write(File.join(@source, FILENAMES[0]), "")
    @env["BGM_MENU_SHA256"] = Digest::SHA256.hexdigest("")
    _, error, status = run_script(@destination, @source)
    refute status.success?
    assert_includes error, "Missing or empty metropolis_destruction.mp3"
  end

  def test_hash_mismatch_preserves_existing_assets
    FileUtils.mkdir_p(@destination)
    File.write(File.join(@destination, FILENAMES[0]), "existing")
    @env["BGM_BATTLE_SHA256"] = "0" * 64
    _, error, status = run_script(@destination, @source)
    refute status.success?
    assert_includes error, "SHA-256 mismatch for tense_tactics.mp3"
    assert_equal "existing", File.read(File.join(@destination, FILENAMES[0]))
  end

  def test_requires_approved_hashes
    @env["BGM_MENU_SHA256"] = ""
    _, error, status = run_script(@destination, @source)
    refute status.success?
    assert_includes error, "Set BGM_MENU_SHA256"
  end

  def test_rejects_http_url_without_exposing_it
    @env["BGM_MENU_URL"] = "http://private.example/menu?token=do-not-log"
    output, error, status = run_script(@destination)
    refute status.success?
    assert_includes error, "Set BGM_MENU_URL"
    refute_includes output + error, "do-not-log"
  end

  def stub_curl(fail_download: false)
    bin = File.join(@directory, "bin")
    FileUtils.mkdir_p(bin)
    path = File.join(bin, "curl")
    File.write(path, <<~BASH)
      #!/usr/bin/env bash
      set -eu
      #{fail_download ? "exit 22" : ""}
      output=""
      for argument in "$@"; do
        if [[ "$output" == next ]]; then output="$argument"; break; fi
        if [[ "$argument" == --output ]]; then output=next; fi
      done
      cp "$FIXTURE_SOURCE/$(basename "$output")" "$output"
    BASH
    File.chmod(0o755, path)
    @env["PATH"] = "#{bin}:#{ENV.fetch('PATH')}"
    @env["FIXTURE_SOURCE"] = @source
  end

  def test_downloads_and_verifies_both_tracks_without_logging_urls
    stub_curl
    output, error, status = run_script(@destination)
    assert status.success?, error
    assert File.exist?(File.join(@destination, FILENAMES[1]))
    refute_includes output + error, "do-not-log"
  end

  def test_failed_download_does_not_leave_partial_assets_or_log_url
    stub_curl(fail_download: true)
    output, error, status = run_script(@destination)
    refute status.success?
    refute File.exist?(@destination)
    refute_includes output + error, "do-not-log"
  end

  def test_archive_verification_rejects_missing_or_corrupt_battle_track
    File.delete(File.join(@source, FILENAMES[1]))
    _, _, status = run_script("--verify", @source)
    refute status.success?
    File.write(File.join(@source, FILENAMES[1]), "changed")
    _, error, status = run_script("--verify", @source)
    refute status.success?
    assert_includes error, "SHA-256 mismatch"
  end

  def test_release_workflow_prepares_before_flutter_and_checks_archive_before_export
    workflow = YAML.safe_load(File.read(File.expand_path("../.github/workflows/build-ios-app-store.yml", __dir__)), aliases: true)
    steps = workflow.fetch("jobs").fetch("build").fetch("steps")
    prepare = steps.index { |step| step["name"] == "Prepare approved BGM assets" }
    build = steps.index { |step| step["name"] == "Build signed IPA" }
    assert_operator prepare, :<, build
    assert_equal "${{ secrets.BGM_MENU_URL }}", steps[prepare].fetch("env").fetch("BGM_MENU_URL")
    commands = steps[build].fetch("run")
    assert_operator commands.index("prepare-bgm-assets.sh --verify"), :<, commands.index("-exportArchive")
    cleanup = steps.find { |step| step["name"] == "Clean up signing materials" }
    assert_equal "always()", cleanup.fetch("if")
    FILENAMES.each { |name| assert_includes cleanup.fetch("run"), "assets/audio/#{name}" }
  end
end

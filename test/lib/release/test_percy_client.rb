require 'minitest_helper'
require 'flash_flow/release/percy_client'

module FlashFlow
  module Release
    class TestPercyClient < Minitest::Test

      def setup
        configuration = {}
          .merge(git_config)
          .merge(smtp_config)
        reset_config!
        config!(configuration)

        @percy_client = Release::PercyClient.new({'token' => ''})
      end

      def test_find_latest_by_sha
        @percy_client.stub(:get_builds, sample_response) do
          results = @percy_client.send(:find_latest_by_sha, 'aaaaa')
          assert(results.has_key?('web-url'))
          assert(results.has_key?('approved-at'))
          assert(results.has_key?('total-comparisons-diff'))
        end
      end

      def test_find_commit_by_sha
        commit = @percy_client.send(:find_commit_by_sha, sample_response, 'bbbbb')
        assert_equal(commit['id'], '8888')
      end

      def test_find_build_by_commit_id
        commit = @percy_client.send(:find_commit_by_sha, sample_response, 'aaaaa')
        build = @percy_client.send(:find_build_by_commit_id, sample_response, commit['id'])

        assert_equal(build['web-url'], 'https://percy.io/repo/builds/2222')
        assert(!build['approved-at'].nil?)
      end

      private

      def sample_response
        JSON.parse(
          '{"data": [
              {
                "type": "builds",
                "attributes": {
                  "web-url": "https://percy.io/repo/builds/1111",
                  "approved-at": null,
                  "created-at": "2016-08-01T00:00:00.000Z"
                },
                "relationships": {
                  "commit": {
                    "data": {
                      "type": "commits",
                      "id": "9999"
                    }
                  }
                }
              },
              {
                "type": "builds",
                "attributes": {
                  "web-url": "https://percy.io/repo/builds/2222",
                  "total-comparisons-diff": 0,
                  "approved-at": "2016-08-01T22:41:58.000Z",
                  "created-at": "2016-08-01T11:11:11.111Z"
                },
                "relationships": {
                  "commit": {
                    "data": {
                      "type": "commits",
                      "id": "9999"
                    }
                  }
                }
              }
            ],
            "included": [
              {
                "id": "9999",
                "type": "commits",
                "attributes": {
                  "sha": "aaaaa"
                }
              },
              {
                "id": "8888",
                "type": "commits",
                "attributes": {
                  "sha": "bbbbb"
                }
              }
            ]
          }')
      end

      def git_config
        {
          git: {
            'merge_branch' => 'test_acceptance',
            'merge_remote' => 'test_remote',
            'master_branch' => 'test_master',
            'remotes' => ['fake_origin'],
            'use_rerere' => true
          }
        }
      end

      def smtp_config
        {
          smtp: {}
        }
      end

    end
  end
end

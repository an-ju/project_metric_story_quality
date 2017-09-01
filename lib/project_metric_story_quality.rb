require "project_metric_story_quality/version"
require 'faraday'
require 'json'

class ProjectMetricStoryQuality
  attr_accessor :raw_data

  def initialize(credentials, raw_data = nil)
    @project = credentials[:tracker_project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:tracker_token]
    @raw_data = raw_data
  end

  def image
    refresh unless @raw_data
    { chartType: 'story_quality',
      titleText: 'Story Quality',
      data: @raw_data }.to_json
  end

  def refresh
    @raw_data = stories
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    refresh unless @raw_data
    @score = @raw_data.length
  end

  def self.credentials
    %I[tracker_project tracker_token]
  end

  def get_params(metric_sample)
    {
      title: 'story_quality',
      metric_name: 'story_quality',
      metric_sample_id: metric_sample.id
    }
  end

  private

  def stories
    JSON.parse(
        @conn.get("projects/#{@project}/stories").body
    )
  end
end

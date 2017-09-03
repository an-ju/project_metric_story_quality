require "project_metric_story_quality/version"
require 'faraday'
require 'json'
require 'digest'

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

  def get_params(metric_sample, latest_params)
    @param_state = 1
    existing_params = latest_params.nil? ? {} : JSON.parse(latest_params.parameters)
    new_params = @raw_data.inject(Hash.new) do |new_params, story|
      sid = story['id']
      sdigest = digest_for story
      if existing_params.key?(sid)
        @param_state = 0 if existing_params[sid]['state'].eql? 0
        new_params[sid] = existing_params[sid]['digest'].eql?(sdigest) ? existing_params[sid] : create_item_for(story)
      else
        new_params[sid] = create_item_for(story)
      end
      new_params
    end
    {
      title: 'story_quality',
      metric_name: 'story_quality',
      metric_sample_id: metric_sample.id,
      parameters: new_params.to_json,
      state: @param_state
    }
  end

  private

  def stories
    JSON.parse(
        @conn.get("projects/#{@project}/stories").body
    )
  end

  def digest_for(story)
    msg_string = {
      title: story['name'],
      description: story.key?('description') ? story['description'] : ''
    }.to_json
    Digest::MD5.hexdigest msg_string
  end

  def create_item_for(story)
    @param_state = 0
    {
      digest: digest_for(story),
      state: 0,
      complexity: nil,
      smart: nil
    }
  end

end

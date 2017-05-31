require 'open-uri'

class Article < ApplicationRecord
  belongs_to :user
  has_many :readings
  has_many :comments, through: :readings

  validates :title, :description, presence: true
  validate :audio_file,:is_this_a_youtube_link
  before_create :get_video_duration

  mount_uploader :photo, PhotoUploader

  # Gets a complete link from youtube(ex: "https://www.youtube.com/watch?v=O8EMo-_6ynI")
  # and strips it: hash with provider ("YouTube") and the id ("O8EMo-_6ynI")
  def parse_video_url(url)
    @url = url

    youtube_formats = [
      %r(https?://youtu\.be/(.+)),
      %r(https?://www\.youtube\.com/watch\?v=(.*?)(&|#|$)),
      %r(https?://www\.youtube\.com/embed/(.*?)(\?|$)),
      %r(https?://www\.youtube\.com/v/(.*?)(#|\?|$)),
      %r(https?://www\.youtube\.com/user/.*?#\w/\w/\w/\w/(.+)\b)
    ]

    vimeo_formats = [%r(https?://vimeo.com\/(\d+)), %r(https?:\/\/(www\.)?vimeo.com\/(\d+))]

    if @url
      @url.strip!

      if @url.include? "youtu"
        youtube_formats.find { |format| @url =~ format } and $1
        @results = {provider: "youtube", id: $1}
        @results
      elsif @url.include? "vimeo"
        vimeo_formats.find { |format| @url =~ format } and $1
        @results = {provider: "vimeo", id: $1}
        @results
      else
        return nil # There should probably be some error message here
      end
    end
  end

  # Extract only the video_id ("O8EMo-_6ynI") from the Hash result given by parse_video_url method
  def video_id
    parse_video_url(audio_file)[:id]
  end

  # Calls YouTube API and return duration of the video. Then parse the format to show as MM:SS
  def get_video_duration
    url = "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&key=#{ENV['YOUTUBE_API_KEY']}&part=snippet,contentDetails,statistics,status"

    video_json = open(url).read
    video = JSON.parse(video_json)
    video_duration = video["items"][0]["contentDetails"]["duration"]

    pattern = "PT"
    pattern += "%HH" if video_duration.include? "H"
    pattern += "%MM" if video_duration.include? "M"
    pattern += "%SS"
    Time.at(DateTime.strptime(video_duration, pattern).seconds_since_midnight.to_i).utc.strftime("%M:%S")
  end

  private

  # Authenticates if user is inputting a valid YouTube link; otherwise throws an error
  def is_this_a_youtube_link
    if parse_video_url(audio_file).nil?
      errors.add(:audio_file, "Not a valid YouTube link")
    end
  end
end













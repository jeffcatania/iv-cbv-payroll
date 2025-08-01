class EventTrackingJob < ApplicationJob
  queue_as :default

  RequestAttributes = Struct.new(:remote_ip, :headers)



  def perform(event_type, request_data, attributes)
    if request_data.present?
      request = RequestAttributes.new(remote_ip: request_data[:remote_ip], headers: request_data[:headers].with_indifferent_access)
    else
      request = nil
    end

    if request_data.present?
      device_detector = DeviceDetector.new(request.headers["User-Agent"])
      attributes[:device_name] = device_detector.device_name
      attributes[:device_type] = device_detector.device_type
      attributes[:browser] = device_detector.name
    end

    event_tracker = MixpanelEventTracker.new
    begin
      event_tracker.track(event_type, request, attributes)
    rescue StandardError => e
      Rails.logger.error "  Failed to track #{event_type} in #{service}: #{e.message}"
      raise e
    end
  end
end

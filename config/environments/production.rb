Rails.application.configure do
  config.eager_load = true
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"
  config.active_job.queue_adapter = :solid_queue
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "amazon").to_sym
end

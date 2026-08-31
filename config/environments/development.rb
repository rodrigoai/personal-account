Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.active_job.queue_adapter = :solid_queue
  config.active_storage.service = :local
  config.action_mailer.perform_deliveries = false
end

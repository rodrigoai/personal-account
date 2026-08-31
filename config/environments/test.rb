require_relative "development"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.active_job.queue_adapter = :inline
  config.active_storage.service = :test
  config.active_record.maintain_test_schema = true
  config.action_controller.allow_forgery_protection = false
end

module Execution
  class CallbackNotifier
    def initialize(submission)
      @submission = submission
    end

    def call
      return unless @submission&.callback_url.present?

      Config::CALLBACKS_MAX_TRIES.times do
        HTTParty.put(
          @submission.callback_url,
          body: serialized_submission,
          headers: { "Content-Type" => "application/json" },
          timeout: Config::CALLBACKS_TIMEOUT
        )
        break
      rescue Exception
        next
      end
    rescue Exception
      nil
    end

    private

    def serialized_submission
      @serialized_submission ||= ActiveModelSerializers::SerializableResource.new(
        @submission,
        serializer: SubmissionSerializer,
        base64_encoded: true,
        fields: SubmissionSerializer.default_fields
      ).to_json
    end
  end
end

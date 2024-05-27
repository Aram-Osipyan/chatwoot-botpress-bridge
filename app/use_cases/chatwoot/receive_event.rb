require 'faraday'

class Chatwoot::ReceiveEvent < Micro::Case
  attributes :event

  def call!
    process_event(event)
  end

  def valid_event?(event)
    event['event'] == 'message_created' && event['message_type'] == 'incoming' && valid_status?(event['conversation']['status'])
  end

  def valid_status?(status)
    allowed_statuses = if ENV['CHATWOOT_ALLOWED_STATUSES'].present?
                         ENV['CHATWOOT_ALLOWED_STATUSES'].split(',')
                       else
                         %w[pending]
                       end
    allowed_statuses.include?(status)
  end

  def input_event?(event)
    event['event'] == 'message_updated' && event['message_type'] == 'outgoing' && event['content_type'] == 'input_select'
  end

  def image_input_event?(event)
    event['event'] == 'message_created' &&
      event['message_type'] == 'incoming' &&
      !event['attachments'].blank? &&
      event['attachments'].first[:file_type] == 'image'
  end

  def file_input_event?(event)
    event['event'] == 'message_created' &&
      event['message_type'] == 'incoming' &&
      !event['attachments'].blank? &&
      event['attachments'].first[:file_type] == 'file'
  end

  def send_text_to_botpress(event, text_content)
    botpress_endpoint = event['botpress_endpoint'] || ENV['BOTPRESS_ENDPOINT']
    botpress_bot_id = Chatwoot::GetDynamicAttribute.call(event:, attribute: 'botpress_bot_id').data[:attribute]

    botpress_responses = Chatwoot::SendTextToBotpress.call(
      text_content:,
      event:,
      botpress_endpoint:,
      botpress_bot_id:
    )
    chatwoot_responses = []
    botpress_responses.data['responses'].each do |response|
      result = Chatwoot::SendToChatwoot.call(event:, botpress_response: response)
      chatwoot_responses << result.data

      return Failure result: { message: 'Error send to chatwoot' } if result.failure?

      sleep(ENV['CHATWOOT_MESSAGES_DELAY'].to_i) if ENV['CHATWOOT_MESSAGES_DELAY']
    end

    Success result: { botpress: botpress_responses.data, botpress_bot_id:,
                      chatwoot_responses: }
  end

  def process_event(event)
    if file_input_event?(event)
      send_text_to_botpress(event, 'BOTPRESS.FILE_UPLOAD')
    elsif image_input_event?(event)
      send_text_to_botpress(event, 'BOTPRESS.IMAGE_UPLOAD')
    elsif input_event?(event)
      submitted_value = event[:content_attributes][:submitted_values].first
      text_content = submitted_value[:value]

      send_text_to_botpress(event, text_content)
    elsif Chatwoot::ValidEvent.call(event:).success?
      botpress_endpoint = event['botpress_endpoint'] || ENV['BOTPRESS_ENDPOINT']
      botpress_bot_id = Chatwoot::GetDynamicAttribute.call(event:, attribute: 'botpress_bot_id').data[:attribute]

      botpress_responses = Chatwoot::SendToBotpress.call(
        event:,
        botpress_endpoint:,
        botpress_bot_id:
      )
      chatwoot_responses = []
      botpress_responses.data['responses'].each do |response|
        result = Chatwoot::SendToChatwoot.call(event:, botpress_response: response)
        chatwoot_responses << result.data

        Failure result: { message: 'Error send to chatwoot' } if result.failure?

        sleep(ENV['CHATWOOT_MESSAGES_DELAY'].to_i) if ENV['CHATWOOT_MESSAGES_DELAY']
      end

      Success result: { botpress: botpress_responses.data, botpress_bot_id:,
                        chatwoot_responses: }
    else
      Failure result: { message: 'Invalid event' }
    end
  end
end

require 'digest/sha1'

class Fingerprint

  attr_reader :notice, :api_key

  def self.generate(notice, api_key)
    self.new(notice, api_key).to_s
  end

  def initialize(notice, api_key)
    @notice = notice
    @api_key = api_key
  end

  def to_s
    Digest::SHA1.hexdigest(fingerprint_source.to_s)
  end

  def fingerprint_source
    {
      :file_or_message => file_or_message,
      :error_class => notice.error_class,
      :component => notice.component || 'unknown',
      :action => notice.action,
      :environment => notice.environment_name || 'development',
      :api_key => api_key
    }
  end

  def file_or_message
    @file_or_message ||= unified_message + notice.backtrace.fingerprint
  end

  def unified_message
    notice.message.dup.tap do |message|
      # filter memory addresses out of object strings
      # example: "#<Object:0x007fa2b33d9458>" becomes "#<Object>"
      message.gsub!(/(#<.+?):[0-9a-f]x[0-9a-f]+(>)/, '\1\2')

      # Remove SQL statements from ActiveRecord::StatementInvalid messages
      if notice.error_class == 'ActiveRecord::StatementInvalid'
        message.gsub!(/: (?:UPDATE|SELECT|DELETE) .+\Z/, '\1')
      end
      
      # Remove unique record ids
      # example: "Couldn't find ItemTrait with ID=13323979 for Item with ID=157989381" becomes "Couldn't find ItemTrait for Item"
      if notice.error_class == 'ActiveRecord::RecordNotFound'
        message.gsub!(/ with ID=\S+/, '')
      end
      
      # Ignore any long number (PIDs, record IDs, etc)
      message.gsub!(/\d{3,}/, '')
    end
  end

end

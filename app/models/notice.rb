require 'recurse'

class Notice
  MESSAGE_LENGTH_LIMIT = 1000
  MAX_SAVED_PER_PROBLEM = 3000

  include Mongoid::Document
  include Mongoid::Timestamps

  field :message
  field :server_environment, type: Hash
  field :request, type: Hash
  field :notifier, type: Hash
  field :user_attributes, type: Hash
  field :framework
  field :error_class
  delegate :lines, to: :backtrace, prefix: true
  delegate :problem, to: :err

  belongs_to :app
  belongs_to :err
  belongs_to :backtrace, index: true

  index(created_at: 1)
  index(err_id: 1, created_at: 1, _id: 1)

  before_save :sanitize
  after_create :truncate_excess_notices
  before_destroy :problem_recache

  validates :backtrace_id, :server_environment, :notifier, presence: true

  scope :ordered, -> { order_by(:created_at.asc) }
  scope :reverse_ordered, -> { order_by(:created_at.desc) }
  scope :for_errs, lambda { |errs|
    where(:err_id.in => errs.all.map(&:id))
  }

  # Overwrite the default setter to make sure the message length is no longer
  # than the limit we impose
  def message=(m)
    super(m.is_a?(String) ? m[0, MESSAGE_LENGTH_LIMIT] : m)
  end

  def user_agent
    agent_string = env_vars['HTTP_USER_AGENT']
    agent_string.blank? ? nil : UserAgent.parse(agent_string)
  end

  def user_agent_string
    if user_agent.nil? || user_agent.none?
      "N/A"
    else
      "#{user_agent.browser} #{user_agent.version} (#{user_agent.os})"
    end
  end

  def environment_name
    n = server_environment['server-environment'] || server_environment['environment-name']
    n.blank? ? 'development' : n
  end

  def component
    request['component']
  end

  def action
    request['action']
  end

  def where
    where = component.to_s.dup
    where << "##{action}" if action.present?
    where
  end

  def request
    super || {}
  end

  def url
    request['url']
  end

  def hostname
    server_environment && server_environment["hostname"] || host
  end

  def host
    uri = url && URI.parse(url)
    uri && uri.host || "N/A"
  rescue URI::InvalidURIError
    "N/A"
  end

  def to_curl
    return "N/A" if url.blank?
    headers = %w(Accept Accept-Encoding Accept-Language Cookie Referer User-Agent).each_with_object([]) do |name, h|
      if (value = env_vars["HTTP_#{name.underscore.upcase}"])
        h << "-H '#{name}: #{value}'"
      end
    end

    "curl -X #{env_vars['REQUEST_METHOD'] || 'GET'} #{headers.join(' ')} #{url}"
  end

  def env_vars
    vars = request['cgi-data']
    vars.is_a?(Hash) ? vars : {}
  end

  def params
    request['params'] || {}
  end

  def session
    request['session'] || {}
  end

  ##
  # TODO: Move on decorator maybe
  #
  def project_root
    server_environment['project-root'] || '' if server_environment
  end

  def app_version
    server_environment['app-version'] || '' if server_environment
  end

  def filtered_message
    message.
      # filter memory addresses out of object strings
      # example: "#<Object:0x007fa2b33d9458>" becomes "#<Object>"
      gsub(/(#<.+?):[0-9a-f]x[0-9a-f]+(>)[^>]*/, '\1\2').
      # filter IDs from common rails exceptions:
      # example: "Couldn't find SomeModel with ID=274594056 for SomeOtherModel with ID=458060932"
      # becomes: "Couldn't find SomeModel with ID=[ID] for SomeOtherModel with ID=[ID]"
      gsub(/\bID=\d+/, 'ID=[ID]').
      # example: "Mysql2::Error: Duplicate entry '283215168' for key 'index_some_table_on_something"
      # becomes: "Mysql2::Error: Duplicate entry '[ID]' for key 'index_some_table_on_something"
      sub(/\A(Mysql2::Error: Duplicate entry ')[\d-]+(' for key)/, '\1[ID]\2').
      # example: "Mysql2::Error: Timeout waiting for a response from the last query. (waited 15 seconds): UPDATE `some_table` SET `some_value` = 1 WHERE `some_table`.`id` = 1"
      # becomes: "Mysql2::Error: Timeout waiting for a response from the last query. (waited 15 seconds): UPDATE [QUERY]"
      sub(/\A(Mysql2::Error: .+: [A-Z]+ ).+\Z/, '\1[QUERY]').
      # Filter inspected value from undefined method X for Y:Klass exceptions
      # example: "undefined method `beginnning_of_day' for Wed, 13 Jun 2018 01:15:14 PDT -07:00:Time"
      # becomes: "undefined method `beginnning_of_day' for [INSTANCE]:Time"
      sub(/(undefined method `.+' for ).+(:\w+)$/, '\1[INSTANCE]\2').
      # At this point, any relatively long number is probably not a useful signal for grouping
      gsub(/\d{3,}/, '[NUM]')
  end

protected

  def problem_recache
    problem.uncache_notice(self)
  end

  def sanitize
    [:server_environment, :request, :notifier].each do |h|
      send("#{h}=", sanitize_hash(send(h)))
    end
  end

  def sanitize_hash(hash)
    hash.recurse do |recurse_hash|
      recurse_hash.inject({}) do |h, (k, v)|
        if k.is_a?(String)
          h[k.gsub(/\./, '&#46;').gsub(/^\$/, '&#36;')] = v
        else
          h[k] = v
        end
        h
      end
    end
  end

  def truncate_excess_notices
    if problem && problem.notices.count > MAX_SAVED_PER_PROBLEM
      excess_records = problem.notices.count - MAX_SAVED_PER_PROBLEM
      Rails.logger.info "#{ excess_records } notices exist past problem limit of #{ MAX_SAVED_PER_PROBLEM }. Querying for notices"
      destroyable_notices = problem.notices.order(created_at: :asc).limit(excess_records).to_a
      Rails.logger.info "Got #{ destroyable_notices.size } sorted records to destroy"

      # WBH June 2020 sees at least a couple ways this could become more efficient:
      # 1. We could delete more than the minimal records every pass, so this wouldn't be invoked via every single incoming notice when a problem is > 3k
      # 2. We could pass mongo the list of IDs directly for deletion (WBH has avoided in v1 out of fear of locking operation, possibility of AR callbacks we want to catch, and laziness)
      # These were not pursued in the v1 implementation upon observation that even amidst a flurry of exceptions, the
      # "delete one notice per incoming exception" method was able to process each incoming request in <100ms while finding and deleting a notice record
      destroyable_notices.each(&:destroy)
      Rails.logger.info "Destruction complete"
    end
  end
end

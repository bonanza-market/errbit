class Api::V1::StatsController < ApplicationController
  respond_to :json, :xml

  # The stats API only requires an api_key for the given app.
  skip_before_action :authenticate_user!
  before_action :require_api_key_or_authenticate_user!

  def app
    from, to = params.values_at(:from, :to)

    problems_scope = @app.problems
    problems_scope = problems_scope.where(:first_notice_at.gte => from.to_i) if from
    problems_scope = problems_scope.where(:last_notice_at.lte => to.to_i) if to

    last_error_time = if problem = problems_scope.order_by(:last_notice_at.desc).first
      problem.last_notice_at
    end

    stats = {
      :name => @app.name,
      :id => @app.id,
      :last_error_time => last_error_time,
      :errors => problems_scope.count,
      :unresolved_errors => problems_scope.unresolved.count
    }
    
    if params[:detailed]
      errs_scope = Err.where(:problem_id.in => @app.problems.pluck(:id))
      notices_scope = Notice.where(:err_id.in => errs_scope.pluck(:id))
      notices_scope = notices_scope.where(:created_at.gte => from.to_i) if from
      notices_scope = notices_scope.where(:created_at.lte => to.to_i) if to
      
      stats[:notices] = notices_scope.count
    end

    respond_to do |format|
      format.any(:html, :json) { render :json => JSON.dump(stats) } # render JSON if no extension specified on path
      format.xml { render :xml => stats }
    end
  end

  protected def require_api_key_or_authenticate_user!
    if params[:api_key].present?
      if (@app = App.where(:api_key => params[:api_key]).first)
        return true
      end
    end

    authenticate_user!
  end
end

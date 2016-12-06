require 'problem_destroy'

class OldProblemClearer

  ##
  # Clear all problems that haven't received a notice in the last month
  #
  def execute
    nb_problem_resolved.tap { |nb|
      if nb > 0
        criteria.each do |problem|
          ProblemDestroy.new(problem).execute
        end
        repair_database
      end
    }
  end

  private

  def nb_problem_resolved
    @count ||= criteria.count
  end

  def criteria
    @criteria = Problem.where(:last_notice_at.lte => 1.month.ago)
  end

  def repair_database
    Mongoid.default_client.command repairDatabase: 1
  end
end

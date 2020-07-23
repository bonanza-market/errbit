namespace :errbit do
  task :dump, [ :problem_id ] => [ :environment ] do |problem_id|
    # This line causes an error:
    # NoMethodError: undefined method `bson_type' for <Rake::Task errbit:dump => [environment]>:Rake::Task
    problem = Problem.where(id: problem_id).last
    notices = problem.notices.to_a
    File.open(::Rails.root.join("tmp", "error_#{ problem_id }.json"), "w") do |f|
      f.puts(notices.map { |n| [ n.created_at, n.params ] }.to_h.to_json)
    end
  end
end

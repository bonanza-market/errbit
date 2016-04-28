Fabricator :backtrace do
  lines(count: 99) do
    {
      number: rand(999),
      file: "[PROJECT_ROOT]/path/to/file/#{SecureRandom.hex(4)}.rb",
      method: ActiveSupport.methods.sample
    }
  end
end

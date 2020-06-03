set :stage, :app
set :rails_env, "production"

server 'misc1.bonanza.com', user: 'deployuser', roles: %w(app web), primary: true

# if ENV["SILENT"] != "true"
#   before "deploy:starting", "slack:notify_start"
#   after "deploy:finished", "slack:notify_end"
# end

# after :deploy, "passenger:conditional_restart"

# Wbh June 2020: taken from original file
# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

# role :app, %w(deploy@example.com)
# role :web, %w(deploy@example.com)
# role :db,  %w(deploy@example.com)



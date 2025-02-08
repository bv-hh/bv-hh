# frozen_string_literal: true

# config valid for current version and patch releases of Capistrano
lock '~> 3.19.1'

set :application, 'bezirkr'
set :repo_url, 'git@github.com:bv-hh/bv-hh.git'

current_branch = `git branch`.match(/\* (\S+)\s/m)[1]
set :branch, ENV.fetch('branch', nil) || current_branch || 'master'

set :deploy_to, '/home/deploy/app'

set :rbenv_type, :user
set :rbenv_ruby, '3.3.5'

set :migration_role, :web

set :assets_roles, [:web]

append :linked_files, 'config/master.key'
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'data', 'storage', 'vendor/bundle', 'public/system', '.bundle'

namespace :deploy do
  task :restart do
    on roles(:web) do
      within release_path do
        if test "[ -f #{shared_path.join('tmp', 'pids', 'puma.pid')} ]"
          execute :bundle, :exec, :pumactl, '-P', shared_path.join('tmp', 'pids', 'puma.pid'), :restart
        else
          execute :sudo, :systemctl, :restart, 'app-web'
        end
      end
    end

    on roles(:worker) do
      execute :sudo, :systemctl, :restart, "'app-worker'"
    end
  end
end

after 'deploy:publishing', 'deploy:restart'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml"

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

import Config

# Configure your database
config :gitgud, GitGud.DB,
  username: System.get_env("DB_USER"),
  password:  System.get_env("DB_PASSWORD"),
  database: System.get_env("DB_NAME"),
  hostname: System.get_env("DB_HOST"),
  show_sensitive_data_on_connection_error: false,
  pool_size: 10

# Configure your SSH server
config :gitgud, GitGud.SSHServer,
  port: System.get_env("SSH_PORT"),
  host_key_dir: System.get_env("SSH_HOST_KEY_DIR")

# Configure your Git storage location
config :gitgud, GitGud.RepoStorage,
  git_root: System.get_env("GIT_ROOT")

# Configure your repository pool
config :gitgud, GitGud.RepoPool,
  max_children_per_pool: 10

# Resque.redis = Redis.new(
#   host:     ENV["REDIS_HOST"],
#   port:     ENV["REDIS_PORT"],
#   password: ENV["REDIS_PASSWORD"],
#   thread_safe: true
# )

# if ENV["RESQUE_NAMESPACE"].present?
#   Resque.redis.namespace = ENV["RESQUE_NAMESPACE"].to_sym
# end


redis =
  if ENV["REDIS_URL"].present?
    # Preferred: Managed Redis (DigitalOcean / ElastiCache / TLS)
    Redis.new(
      url: ENV["REDIS_URL"],
      thread_safe: true,
      reconnect_attempts: 3
    )
  else
    # Fallback: host/port/password (local or EC2 Redis)
    Redis.new(
      host:     ENV.fetch("REDIS_HOST", "localhost"),
      port:     ENV.fetch("REDIS_PORT", 6379),
      password: ENV["REDIS_PASSWORD"],
      thread_safe: true,
      reconnect_attempts: 3
    )
  end

Resque.redis = redis

if ENV["RESQUE_NAMESPACE"].present?
  Resque.redis.namespace = ENV["RESQUE_NAMESPACE"].to_sym
end

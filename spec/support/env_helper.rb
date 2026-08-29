# frozen_string_literal: true

# Scoped ENV mutation for the specs that redirect StreamWeaver's per-user
# state files (STREAMWEAVER_UNIVERSITY_PROGRESS, STREAMWEAVER_UNIVERSITY_WORKER)
# at a tmpdir. Restores the previous values -- including "was unset" -- so a
# spec can never leave the developer's real ledger or recorded worker session
# in play for the next example. Include it in the describe block that needs it.
module EnvHelper
  def with_env(vars)
    previous = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end

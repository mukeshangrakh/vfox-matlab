function PLUGIN:BackendExecEnv(ctx)
  local install_path = ctx.install_path
  return {
    env_vars = {
      { key = "PATH", value = install_path .. "/bin" }
    }
  }
end
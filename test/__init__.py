import os

# 应用现在会拒绝以空密钥或公开默认密钥启动，测试自带一个占位密钥，
# 这样就不依赖仓库里 config.json 的 auth-key 取值。
os.environ.setdefault("CHATGPT2API_AUTH_KEY", "test-key-for-local-security-tests")

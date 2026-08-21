# claude.zsh — Claude Code CLI

export PATH="$HOME/.local/bin:$PATH"

# Should NOT use AWS Bedrock models in Claude CLI in Enterprise subscriptions
unset CLAUDE_CODE_USE_BEDROCK
unset ANTHROPIC_MODEL

;;; lib.el --- GPtel AI assistant support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Library for GPtel AI assistant integration with OpenRouter and other providers.
;;; Loaded by myde/ai-gptel/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defvar myde/openrouter-models
  '(anthropic/claude-haiku-4.5
    anthropic/claude-opus-4.5
    anthropic/claude-opus-4.6
    anthropic/claude-opus-4.7
    anthropic/claude-sonnet-4.5
    anthropic/claude-sonnet-4.6
    deepseek/deepseek-v3.2
    google/gemini-2.5-flash
    google/gemini-2.5-flash-lite
    google/gemini-3-flash-preview
    google/gemini-3-pro-image-preview
    google/gemini-3-pro-preview
    google/gemma-4-26b-a4b-it:free
    google/gemma-4-31b-it:free
    minimax/minimax-m2.1
    minimax/minimax-m2.5
    minimax/minimax-m2.5:free
    minimax/minimax-m2.7
    mistralai/codestral-embed-2505
    mistralai/devstral-2512
    mistralai/ministral-14b-2512
    mistralai/mistral-large-2512
    mistralai/mistral-nemo             ; roleplay, translation, trivia
    moonshotai/kimi-k2
    moonshotai/kimi-k2-0905            ; roleplay, trivia
    moonshotai/kimi-k2-thinking
    moonshotai/kimi-k2.5
    moonshotai/kimi-k2.6
    nvidia/nemotron-3-super-120b-a12b:free
    nvidia/nemotron-nano-12b-v2-vl:free
    nvidia/nemotron-nano-9b-v2:free
    openai/gpt-5.2
    openai/gpt-5.2-codex
    openai/gpt-5.2-pro
    openai/gpt-5.3-codex
    openai/gpt-5.4
    openai/gpt-5.4-mini
    openai/gpt-oss-120b
    openai/gpt-oss-120b:free
    openrouter/free
    qwen/qwen3-coder-next
    qwen/qwen3-coder:free
    qwen/qwen3-max-thinking
    qwen/qwen3.6-plus:free
    x-ai/grok-4
    x-ai/grok-4-fast
    x-ai/grok-4.20
    x-ai/grok-4.20-multi-agent
    x-ai/grok-code-fast-1
    z-ai/glm-4.5-air:free
    z-ai/glm-4.7
    z-ai/glm-4.7-flash
    z-ai/glm-5
    z-ai/glm-5.1))

(defun myde/gptel-api-key-from-environment (&optional var)
  "Get API key from environment variable.
If VAR is provided, use that environment variable.
Otherwise, derive the variable name from the current gptel-backend type."
  (lambda ()
    (getenv (or var                     ;provided key
                (thread-first           ;or fall back to <TYPE>_API_KEY
                  (type-of gptel-backend)
                  (symbol-name)
                  (substring 6)
                  (upcase)
                  (concat "_API_KEY"))))))

(provide 'myde-ai-gptel)
;;; lib.el ends here

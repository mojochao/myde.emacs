;;; lib.el --- AI support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Shared variables and utilities for AI modules.


;;; Code:

(defvar myde-openrouter-models
  '(anthropic/claude-haiku-4.5
    anthropic/claude-opus-4.5
    anthropic/claude-opus-4.6
    anthropic/claude-opus-4.7
    anthropic/claude-sonnet-4.5
    anthropic/claude-sonnet-4.6
    deepseek/deepseek-v3.2
    deepseek/deepseek-v4-flash
    deepseek/deepseek-v4-pro
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
    nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free
    nvidia/nemotron-3-super-120b-a12b:free
    nvidia/nemotron-nano-12b-v2-vl:free
    nvidia/nemotron-nano-9b-v2:free
    openai/gpt-5.2
    openai/gpt-5.2-codex
    openai/gpt-5.2-pro
    openai/gpt-5.3-codex
    openai/gpt-5.4
    openai/gpt-5.4-mini
    openai/gpt-5.5
    openai/gpt-5.5-pro
    openai/gpt-oss-120b
    openai/gpt-oss-120b:free
    openrouter/free
    poolside/laguna-m.1:free
    poolside/laguna-xs.2:free
    qwen/qwen3-coder-next
    qwen/qwen3-coder:free
    qwen/qwen3-max-thinking
    qwen/qwen3.6-27b
    qwen/qwen3.6-35b-a3b
    qwen/qwen3.6-flash
    qwen/qwen3.6-max-preview
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

(provide 'myde-ai-base)
;;; lib.el ends here

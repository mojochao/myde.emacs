;;; cfg.el --- GPtel AI assistant configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Package configuration for GPtel AI assistant with OpenRouter backend and related tools.
;;; Entry point for the ai-gptel module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-ai-gptel)
  (load-file (expand-file-name "myde/ai-gptel/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; GPtel main package
;; -----------------------------------------------------------------------------

(use-package gptel  ;; https://github.com/karthink/gptel
  :after transient
  :config
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (auth-source-pick-first-password :host "OPENROUTER_API_KEY")
    :models myde/openrouter-models)
  (setq gptel-model 'moonshotai/kimi-k2.6
        gptel-backend (gptel-get-backend "OpenRouter"))
  :ensure t)

;; -----------------------------------------------------------------------------
;; GPtel forge integration
;; -----------------------------------------------------------------------------

(use-package gptel-forge-prs  ;; https://github.com/ArthurHeymans/gptel-forge-prs
  :after forge
  :config
  (gptel-forge-prs-install)
  :ensure t)

;; -----------------------------------------------------------------------------
;; GPtel magit integration
;; -----------------------------------------------------------------------------

(use-package gptel-magit  ;; https://github.com/ragnard/gptel-magit
  :after (magit markdown-mode)
  :hook (magit-mode . gptel-magit-install)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Minuet AI completions
;; -----------------------------------------------------------------------------

(use-package minuet  ;; https://github.com/milanglacier/minuet-ai.el
  :after gptel
  ;; :init
  ;; ;; if you want to enable auto suggestion.
  ;; ;; Note that you can manually invoke completions without enable minuet-auto-suggestion-mode
  ;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  :config
  (setq minuet-provider 'codestral)  ;; Use Codestral FIM completions via the Mistral API.
  (plist-put minuet-codestral-options :api-key (auth-source-pick-first-password :host "MISTRAL_API_KEY"))
  (plist-put minuet-codestral-options :end-point "https://api.mistral.ai/v1/fim/completions")
  (plist-put minuet-codestral-options :model "codestral-latest")
  (minuet-set-optional-options minuet-codestral-options :max_tokens 128)
  (minuet-set-optional-options minuet-codestral-options :stop ["\n\n"])
  :bind
  (("M-y" . #'minuet-complete-with-minibuffer) ;; use minibuffer for completion
   ("M-i" . #'minuet-show-suggestion) ;; use overlay for completion
   ("C-c m" . #'minuet-configure-provider)
   :map minuet-active-mode-map
   ;; These keymaps activate only when a minuet suggestion is displayed in the current buffer
   ("M-p" . #'minuet-previous-suggestion) ;; invoke completion or cycle to next completion
   ("M-n" . #'minuet-next-suggestion) ;; invoke completion or cycle to previous completion
   ("M-A" . #'minuet-accept-suggestion) ;; accept whole completion
   ;; Accept the first line of completion, or N lines with a numeric-prefix:
   ;; e.g. C-u 2 M-a will accepts 2 lines of completion.
   ("M-a" . #'minuet-accept-suggestion-line)
   ("M-e" . #'minuet-dismiss-suggestion))
  :ensure t)

(provide 'myde-ai-gptel-cfg)
;;; cfg.el ends here

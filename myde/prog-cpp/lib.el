;;; lib.el --- C/C++ support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Code:

(defun myde/cpp-ts-mode-setup ()
  "Set buffer-local settings for c++-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde/c-ts-mode-setup ()
  "Set buffer-local settings for c-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde/cpp-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde/cpp-format-on-save-setup ()
  "Install buffer-local before-save formatting for C/C++ ts modes."
  (add-hook 'before-save-hook #'myde/cpp-eglot-format-buffer nil t))

(defun myde/cpp-run-tests ()
  "Build and run CTest tests for the current project."
  (interactive)
  (compile "cmake --build build && ctest --test-dir build --output-on-failure"))

(defun myde/cpp-dape-binary ()
  "Prompt for the C++ debug binary, defaulting to the project build/ directory."
  (read-file-name "Binary: "
                  (expand-file-name "build/" (or (projectile-project-root)
                                                  default-directory))))

(provide 'myde-prog-cpp)
;;; lib.el ends here

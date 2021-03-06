;; integrates flowjs to spacemacs
;;
;; depends:
;;   - on company-flow and popup.el
;;     Popup should be in spacemacs default config. For
;;     company-flow, manually add in dotspacemasc/layers, eg:
;;       dotspacemacs-additional-packages '(company-flow)
;;
;;  - on spacemacs layers:
;;    - auto-completion (for company)
;;    - syntax-checking (for flycheck)
;;    - react for react-mode
;;    - javascript for js-mode
;;
;;  - on js tooling, see example folder:
;;    - local flow (partial global support)
;;    - local or global eslint with babel-eslint
;;
;; usage:
;;   load this file and call (init-flowjs) from dospacemacs/user-config, eg:
;;     (load-file "~/config/spacemacs/flow.el")
;;     (init-flowjs)
;;


;; defining basic mode to diplay npm run flow -- --json
;; results.
(require 'generic-x) ;; we need this
(defun flowing-mode-config ()
  "For use in `foo-mode-hook'."
  ;;(define-key map (kbd [tab]) 'evil-toggle-fold)
  (local-set-key (kbd "TAB") 'evil-toggle-fold)
  (outline-minor-mode)
  )

(define-generic-mode
    'flowing-mode                         ;; name of the mode to create
  '("!!")                           ;; comments start with '!!'
  '("flow" "error" "linting" "Error" "boolean"
    "This type is incompatible with")
  '(("=" . 'font-lock-operator)     ;; '=' is an operator
    (";" . 'font-lock-builtin))     ;; ';' is a built-in
  '("\\.flowing$")                      ;; files for which to activate this mode
  (list (lambda () (flowing-mode-config)))             ;; other functions to call
  "A mode for flow js files"            ;; doc string for this mode
  )

(defun print-elements-of-list (list)
  "Print each element of LIST on a line of its own."
  (while list
    (print (car list))
    (setq list (cdr list))))

(defun print-flow-status-error (e)
  (mapcar
   (lambda (err)
             (insert (format "\n*** File error "))
             (insert "\n\n\n")
             (insert "              ")
             (mapcar
              (lambda (y)
                (if (equal (format "%s" (cdr (assoc 'type y))) "Blame")
                    (insert (propertize (format "%s " (cdr (assoc 'descr y))) 'font-lock-face '(:foreground "green")))
                    (insert (propertize (format "%s " (cdr (assoc 'descr y))) 'font-lock-face '(:foreground "orange")))
                    ))
              (cdr (assoc 'message err)))
             (insert "\n\n")
             (mapcar
              (lambda (y)
                (if (equal (format "%s" (cdr (assoc 'type y))) "Blame")
                  (insert (propertize (format "        error start: %s (%s)\n" (cdr (assoc 'context y)) (cdr (assoc 'descr y))) 'font-lock-face '(:foreground "white")))))
              (cdr (assoc 'message err)))
             (insert "\n\n")
             (mapcar
              (lambda (y)
                (if (equal (format "%s" (cdr (assoc 'type y))) "Blame")
                    ((lambda ()
                      (insert (propertize (format "    path: \n        %s\n         "
                                            (cdr (assoc 'source (cdr (assoc 'loc y))))) 'font-lock-face '(:foreground "grey")))
                      (insert (propertize (format "(start: l. %s, "
                                                  (cdr (assoc 'line (cdr (assoc 'start (cdr (assoc 'loc y))))))) 'font-lock-face '(:foreground "grey")))
                      (insert (propertize (format "c. %s; "
                                                  (cdr (assoc 'column (cdr (assoc 'start (cdr (assoc 'loc y))))))) 'font-lock-face '(:foreground "grey")))
                    (insert (propertize (format "end: l. %s, "
                                                (cdr (assoc 'line (cdr (assoc 'end (cdr (assoc 'loc y))))))) 'font-lock-face '(:foreground "grey")))
                    (insert (propertize (format "c. %s)\n"
                                                (cdr (assoc 'column (cdr (assoc 'end (cdr (assoc 'loc y))))))) 'font-lock-face '(:foreground "grey")))))))
              (cdr (assoc 'message err)))
            (insert "\n"))
   e))
  ;;(mapc (lambda (m) (format "hello %s" m)) (assoc 'message e)))

;; create new window and show flow status in it
(defun create-flow-status-window (json)
    (interactive)
    ;;(split-window-right)
    (let ((file (buffer-file-name))
          (region (string-of-region))
          (buffer (current-buffer)))
      (switch-to-buffer-other-window "*Flowing status*")
      (erase-buffer)
      (insert "* flow status window \n\n\n")
      (insert "** Errors (tab over section to toggle): \n")
      (print-flow-status-error (cdr (assoc 'errors
                      (json-read-from-string
                        json)))))
    (outline-mode)
    (local-set-key (kbd "TAB") 'evil-toggle-fold))


(defun init-flowjs ()
  ;; Flow integation into flycheck
  ;; https://github.com/bodil/emacs.d/blob/master/bodil/bodil-js.el#L129
  (require 'f)
  (require 'json)
  (require 'flycheck)
  (defun flycheck-parse-flow (output checker buffer)
    (let ((json-array-type 'list))
      (let ((o (json-read-from-string output)))
        (mapcar #'(lambda (errp)
                    (let ((err (cadr (assoc 'message errp)))
                          (err2 (cadr (cdr (assoc 'message errp)))))
                      (flycheck-error-new
                      :line (cdr (assoc 'line err))
                      :column (cdr (assoc 'start err))
                      :level 'error
                      :message (concat (cdr (assoc 'descr err)) ". " (cdr (assoc 'descr err2)))
                      :filename (f-relative
                                  (cdr (assoc 'path err))
                                  (f-dirname (file-truename
                                              (buffer-file-name))))
                      :buffer buffer
                      :checker checker)))
                (cdr (assoc 'errors o))))))

  (flycheck-define-checker javascript-flow
    "Static type checking using Flow."
    :command ("flow" "--json")
    :error-parser flycheck-parse-flow
    :modes (react-mode js2-mode)
    :next-checkers ((error . javascript-eslint))
    )
  (add-to-list 'flycheck-checkers 'javascript-flow)

  ;; https://github.com/syl20bnr/spacemacs/blob/bd7ef98e4c35fd87538dd2a81356cc83f5fd02f3/layers/%2Bframeworks/react/funcs.el#L30
  (defun spacemacs//react-use-flow-from-node-modules ()
    (let* ((root (locate-dominating-file
                  (or (buffer-file-name) default-directory)
                  "node_modules"))
           (global-flow (executable-find "flow"))
           (local-flow (expand-file-name "node_modules/.bin/flow"
                                           root))
           (flow (if (file-executable-p local-flow)
                       local-flow
                     global-flow)))
      (setq-local flycheck-javascript-flow-executable flow)))

  (add-hook 'react-mode-hook #'spacemacs//react-use-flow-from-node-modules)
  (add-hook 'js2-mode-hook #'spacemacs//react-use-flow-from-node-modules)


  ;;
  ;; Copyright (c) 2016-present, Facebook, Inc.
  ;; All rights reserved.
  ;;
  ;; This source code is licensed under the BSD-style license found in the LICENSE
  ;; file in the root directory of this source tree. An additional grant of patent
  ;; rights can be found in the PATENTS file in the same directory.
  ;;
  ;; source: https://github.com/flowtype/flow-for-emacs

  (setq flow_binary "npm run -s flow -- ")

  (defun column-number-at-pos (pos)
    "column number at pos"
    (save-excursion (goto-char pos) (current-column))
  )

  (defun string-of-region ()
    "string of region"
    (if (use-region-p)
        (let ((begin (region-beginning))
              (end (region-end)))
          (format ":%d:%d,%d:%d"
                  (line-number-at-pos begin)
                  (column-number-at-pos begin)
                  (line-number-at-pos end)
                  (column-number-at-pos end)))
      "")
  )

  (defun get-assoc-value (key alist)
    "get assoc value"
    (setq blah (assoc key alist))
    (if blah
        (cdr blah)
      nil)
  )

  (defun flow-start ()
    (shell-command (format "%s start" flow_binary))
  )

  (defun flow-stop ()

    (interactive)
    (shell-command (format "%s stop" flow_binary))
  )

  (defun flow-status ()
    "Initialize flow"
    (interactive)
    (create-flow-status-window
    (shell-command-to-string
     (format "npm run -s flow -- status --json")))
  )

  (global-set-key (kbd "C-x C-m") 'flow-status)
  (spacemacs/set-leader-keys-for-major-mode 'react-mode "ff" 'flow-status)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "ff" 'flow-status)

  (require 'popup)
  ;; futur pretty print version of flow-type-at-pos using regex
  (defun flow-type-at-pos-pp ()
   "show type"
   (interactive)
   (let ((file (buffer-file-name))
         (line (line-number-at-pos))
    (col (current-column))
    (buffer-content (buffer-string))
    (buffer (current-buffer)))
     (popup-tip
      (replace-regexp-in-string "\\(, {\\)\\|\\(: {\\)" "\\& \n"
      (format "%s"
       (cdr(assoc 'type
                   (json-read-from-string
                   (nth 1
                         (split-string
                         (shell-command-to-string
                           (concat
                           "echo "
                           (shell-quote-argument buffer-content)
                           " | "
                           (format "%s type-at-pos --from emacs --path=%s %d %d --pretty"
                                   flow_binary
                                   file
                                   line
                                   (1+ col))))
                         "\n$"))))))))))

  (spacemacs/set-leader-keys-for-major-mode 'react-mode "fp" 'flow-type-at-pos-pp)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "fp" 'flow-type-at-pos-pp)

  ;; uses popup.el to display type at pos
  (defun flow-type-at-pos ()
   "show type"
   (interactive)
   (let ((file (buffer-file-name))
         (line (line-number-at-pos))
    (col (current-column))
    (buffer-content (buffer-string))
    (buffer (current-buffer)))
     (popup-tip
      (format "%s"
       (cdr(assoc 'type
                   (json-read-from-string
                   (nth 1
                         (split-string
                         (shell-command-to-string
                           (concat
                           "echo "
                           (shell-quote-argument buffer-content)
                           " | "
                           (format "%s type-at-pos --from emacs --path=%s %d %d --json"
                                   flow_binary
                                   file
                                   line
                                   (1+ col))))
                         "\n$")))))))))

  (spacemacs/set-leader-keys-for-major-mode 'react-mode "ft" 'flow-type-at-pos)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "ft" 'flow-type-at-pos)

  (defun flow-suggest ()
    "fill types"
    (interactive)
    (let ((file (buffer-file-name))
          (region (string-of-region))
          (buffer (current-buffer)))
      (switch-to-buffer-other-window "*Shell Command Output*")
      (shell-command
      (format "%s suggest %s%s"
              flow_binary
              file
              region))
      (diff-mode)
      (switch-to-buffer-other-window buffer))
  )

  (global-set-key (kbd "C-t") 'flow-suggest)
  (spacemacs/set-leader-keys-for-major-mode 'react-mode "fs" 'flow-suggest)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "fs" 'flow-suggest)

  (defun flow-get-def ()
    "jump to definition"
    (interactive)
    (let ((file (buffer-file-name))
          (line (line-number-at-pos))
          (col (current-column))
          (buffer-content (buffer-string))
          (buffer (current-buffer)))
      (switch-to-buffer-other-window "*Shell Command Output*")
      (shell-command
       (concat
        "echo "
        (shell-quote-argument buffer-content)
        " | "
        (format "%s get-def --from emacs --path=%s %d %d"
                flow_binary
                file
                line
                (1+ col))))
      (compilation-mode))
  )

  (spacemacs/set-leader-keys-for-major-mode 'react-mode "fd" 'flow-get-def)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "fd" 'flow-get-def)

  ;; raw flow autocomplete suggestions at pos
  (defun flow-autocomplete ()
    "autocomplete"
    (interactive)
    (let ((file (buffer-file-name))
          (line (line-number-at-pos))
          (col (current-column))
          (buffer-content (buffer-string))
          (buffer (current-buffer)))
      (switch-to-buffer-other-window "*Shell Command Output*")
      (shell-command
        (concat
          "echo "
          (shell-quote-argument buffer-content)
          " | "
          (format "%s autocomplete %d %d "
                  flow_binary
                  line
                  (1+ col))
          )
        )
      (compilation-mode)
      (select-window (get-buffer-window buffer)))
  )

  (spacemacs/set-leader-keys-for-major-mode 'react-mode "fa" 'flow-autocomplete)
  (spacemacs/set-leader-keys-for-major-mode 'js2-mode "fa" 'flow-autocomplete)

  (add-hook 'kill-emacs-hook
    (lambda ()
  (flow-stop)))

  ;; autocomplete with menu through company-flow
  (eval-after-load 'company
    '(add-to-list 'company-backends 'company-flow))


  (defun company-force-flow ()
    (setq company-backends-js2-mode '(company-flow company-tern
                                                   (company-dabbrev-code company-gtags company-etags company-keywords)
                                                   company-files company-dabbrev))
    (setq company-backends-react-mode '(company-flow company-tern
                                                     (company-dabbrev-code company-gtags company-etags company-keywords)
                                                     company-files company-dabbrev)))

  (add-hook 'js-mode-hook 'company-force-flow)
  (add-hook 'react-mode-hook 'company-force-flow))

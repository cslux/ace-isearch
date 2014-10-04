;;; ace-isearch.el --- A seamless bridge between isearch and ace-jump-mode -*- coding: utf-8; lexical-binding: t -*-

;; Copyright (C) 2014 by Akira TAMAMORI

;; Author: Akira Tamamori
;; URL: https://github.com/tam17aki/ace-isearch
;; Version: 0.1
;; Created: Sep 25 2014
;; Package-Requires: ((ace-jump-mode "2.0") (helm "1.4"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; `ace-isearch.el' provides a minor mode which combines `isearch' and
;; `ace-jump-mode'.
;;
;; The "default" behavior can be summrized as:
;;
;; L = 1     : `ace-jump-mode'
;; 1 < L < 6 : `isearch'
;; L > 6     : `helm-occur-from-isearch'
;;
;; where L is the input string length during `isearch'.  When L is 1, after a
;; few seconds specified by `ace-isearch-input-idle-delay', `ace-jump-mode' will
;; be invoked. Of course you can customize the above behaviour.

;;; Installation:
;;
;; To use this package, add following code to your init file.
;;
;;   (require 'ace-isearch)
;;   (global-ace-isearch-mode +1)

;;; Code:

(eval-when-compile (defvar migemo-isearch-enable-p))

(require 'helm)
(require 'ace-jump-mode)

(defgroup ace-isearch nil
  "Group of ace-isearch."
  :group 'ace-jump)

(defcustom ace-isearch-lighter " AceI"
  "Lighter of ace-isearch-mode."
  :type 'string
  :group 'ace-isearch)

(defcustom ace-isearch-input-idle-delay 0.4
  "Idle second before invoking `ace-isearch-function-from-iserach'."
  :type 'number
  :group 'ace-isearch)

(defcustom ace-isearch-input-length 6
  "Minimum input length to invoke `ace-isearch-function-from-isearch'."
  :type 'integer
  :group 'ace-isearch)

(defcustom ace-isearch-submode 'ace-jump-word-mode
  "Sub-mode for ace-jump-mode."
  :type '(choice (const :tag "Use ace-jump-word-mode." ace-jump-word-mode)
                 (const :tag "Use ace-jump-char-mode." ace-jump-char-mode))
  :group 'ace-isearch)

(defcustom ace-isearch-use-ace-jump t
  "When non-nil, invoke `ace-jump' if the length of `isearch-string' is equal
to 1."
  :type 'boolean
  :group 'ace-isearch)

(defcustom ace-isearch-funtion-from-isearch 'helm-occur-from-isearch
  "A function which is invoked when the length of `isearch-string'
is longer than or equal to `ace-isearch-input-length'."
  :type 'symbol
  :group 'ace-isearch)

(defcustom ace-isearch-use-function-from-isearch t
  "When non-nil, invoke `ace-isearch-funtion-from-isearch' if the length
of `isearch-string' is longer than or equal to `ace-isearch-input-length'."
  :type 'boolean
  :group 'ace-isearch)

(defvar ace-isearch--submode-list
  (list "ace-jump-word-mode" "ace-jump-char-mode")
  "List of jump type for ace-jump-mode.")

;;;###autoload
(defun ace-isearch-switch-submode ()
  (interactive)
  (let ((submode (completing-read
                  (format "Sub-mode (current is %s): " ace-isearch-submode)
                  ace-isearch--submode-list nil t)))
    (setq ace-isearch-submode (intern-soft submode))
    (message "Sub-mode of ace-isearch is set to %s." submode)))

(defun ace-isearch--jumper-function ()
  (cond ((and (= (length isearch-string) 1)
              ace-isearch-use-ace-jump
              (sit-for ace-isearch-input-idle-delay))
         (isearch-exit)
         (funcall ace-isearch-submode (string-to-char isearch-string)))
        ((and (>= (length isearch-string) ace-isearch-input-length)
              ace-isearch-use-function-from-isearch
              (sit-for ace-isearch-input-idle-delay))
         (if (not (fboundp ace-isearch-funtion-from-isearch))
             (error (format "%s is not bounded!"
                            ace-isearch-funtion-from-isearch)))
         (isearch-exit)
         (cond ((not (featurep 'migemo))
                (funcall ace-isearch-funtion-from-isearch))
               ((and (featurep 'migemo)
                     (not migemo-isearch-enable-p))
                (funcall ace-isearch-funtion-from-isearch))))))

;;;###autoload
(define-minor-mode ace-isearch-mode
  "Minor-mode which connects isearch and ace-jump-mode seamlessly."
  :group      'ace-isearch
  :init-value nil
  :global     nil
  :lighter    ace-isearch-mode-lighter
  (if ace-isearch-mode
      (add-hook 'isearch-update-post-hook 'ace-isearch--jumper-function nil t)
    (remove-hook 'isearch-update-post-hook 'ace-isearch--jumper-function t)))

(defun ace-isearch--turn-on ()
  (unless (minibufferp)
    (ace-isearch-mode +1)))

;;;###autoload
(define-globalized-minor-mode global-ace-isearch-mode
  ace-isearch-mode ace-isearch--turn-on
  :group 'ace-isearch)

;; misc
(defvar ace-isearch--active-when-isearch-exit-p nil)

(defadvice isearch-exit (after do-ace-isearch-jump disable)
  (if (and ace-isearch--active-when-isearch-exit-p
           (> (length isearch-string) 1)
           (< (length isearch-string) ace-isearch-input-length))
      (let ((ace-jump-mode-scope 'window))
        (ace-jump-do (regexp-quote isearch-string)))))

(defun ace-isearch-set-ace-jump-after-isearch-exit (activate)
  "Set invoking ace-jump-mode automatically when `isearch-exit' has done."
  (if activate
      (ad-enable-advice 'isearch-exit 'after 'do-ace-isearch-jump)
    (ad-disable-advice 'isearch-exit 'after 'do-ace-isearch-jump))
  (ad-activate 'isearch-exit)
  (setq ace-isearch--active-when-isearch-exit-p activate))

;;;###autoload
(defun ace-isearch-toggle-ace-jump-after-isearch-exit ()
  "Toggle invoking ace-jump-mode automatically when `isearch-exit' has done."
  (interactive)
  (cond ((eq ace-isearch--active-when-isearch-exit-p t)
         (ace-isearch-set-ace-jump-after-isearch-exit nil)
         (message "ace-jump-after-isearch-exit is disabled."))
        ((eq ace-isearch--active-when-isearch-exit-p nil)
         (ace-isearch-set-ace-jump-after-isearch-exit t)
         (message "ace-jump-after-isearch-exit is enabled."))))

(provide 'ace-isearch)
;;; ace-isearch.el ends here

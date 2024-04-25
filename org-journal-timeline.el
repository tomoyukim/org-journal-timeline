;;; org-journal-timeline.el --- Timeline view for org-journal

;; Copyright (C) 2024 tomoyukim <tomoyukim@outlook.com>
;; Author: Tomoyuki Murakami
;; URL: http://github.com/tomoyukim/org-journal-timeline.el
;; Created: 2024
;; Package-Version: 202404025.1
;; Version: 1.0
;; Homepage: https://github.com/tomoyukim/org-journal-timeline
;; Keywords: org-mode org-journal
;; Package-Requires: ((magit-section "20230428") (org))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This package provides a view showing multiple journals in one buffer.

;;; TODO:

;; * support visiting each journal from the timeline
;; * deploy to MELPA

;;; Code:
(require 'org)
(require 'magit-section)

(defcustom org-journal-timeline-days 10
  "How many days shown in the timeline buffer"
  :type 'integer
  :group 'org-journal-timeline)

(defcustom org-journal-timeline-directory "~/.org/journals"
  "org-journal directory"
  :type '(string)
  :group 'org-journal-timeline)

(defcustom org-journal-timeline-date-format "^\\([0-9]+-[0-9]+-[0-9]+\\.org\\)$"
  "File name format for journal files"
  :type '(string)
  :group 'org-journal-timeline)


;; Stolen code
;;
;; From:
;; https://emacs.stackexchange.com/questions/21713/how-to-get-property-values-from-org-file-headers
(defun org-journal-timeline--org-global-props (&optional property buffer)
  "Get the plists of global org properties of current buffer."
  (unless property (setq property "PROPERTY"))
  (with-current-buffer (or buffer (current-buffer))
    (org-element-map (org-element-parse-buffer) 'keyword
      (lambda (el) (when (string-match property (org-element-property :key el)) el)))))

;; Magit section operations
(defun org-journal-timeline--get-section-title (file)
  "Attempt to retrieve the 'title' property from an Org file.
   If the title property is nil, return the file name without its extension."
  (let ((title (with-temp-buffer
                 (insert-file-contents file)
                 (org-element-property :value (car (org-journal-timeline--org-global-props "title"))))))
    (or title (file-name-sans-extension (file-name-nondirectory file)))))

(defun org-journal-timeline--get-section-contents (file)
  (with-temp-buffer
    (insert-file-contents file)
    (file-name-sans-extension (file-name-nondirectory file))
    (let ((body (buffer-string))
          (title (org-journal-timeline--get-section-title file)))
      (list title body))
    ))

(defun org-journal-timeline--insert-custom-sections (file-list)
  "Insert custom sections into the current buffer."
  (magit-insert-section (section)
    (magit-insert-heading)
    (dolist (file file-list)
      (let ((contents (org-journal-timeline--get-section-contents file)))
        (magit-insert-section (journal)
          (magit-insert-heading (car contents))
          (insert (org-fontify-like-in-org-mode (cadr contents))))) ; org-roam-fontify-like-in-org-mode
      (insert ?\n)))
  (magit-section-show-level-2-all)
  (goto-char (point-min)))

;; File list operations
(defun org-journal-timeline--generate-file-list (directory)
  "Generate a list of file names in DIRECTORY matching the date format."
  (directory-files directory t org-journal-timeline-date-format))

(defun org-journal-timeline--sort-file-list (file-list)
  "Sort the list of file names in FILE-LIST based on the date format."
  (sort file-list (lambda (file1 file2)
                    (let* ((date1 (file-name-sans-extension (file-name-nondirectory file1)))
                           (date2 (file-name-sans-extension (file-name-nondirectory file2)))
                           (time1 (date-to-time date1))
                           (time2 (date-to-time date2)))
                      (time-less-p time2 time1)))))

(defun org-journal-timeline--take-n-elements (n lst)
  "Return the first N elements of the list LST."
  (let ((result '()))
    (while (and (> n 0) lst)
      (setq result (cons (car lst) result))
      (setq lst (cdr lst))
      (setq n (1- n)))
    (nreverse result)))

;; Buffer creation
(defun org-journal-timeline--create-journal-timeline-buffer (file-list)
  "Create a buffer with custom sections."
  (with-current-buffer (get-buffer-create "*Journal Timeline*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (org-journal-timeline--insert-custom-sections file-list)
      (magit-section-mode)
      (pop-to-buffer (current-buffer)))))

;;;###autoload
(defun org-journal-timeline-show ()
  "Show org-journal-timeline buffer"
  (interactive)
  (let* ((directory org-journal-timeline-directory)
         (file-list (org-journal-timeline--generate-file-list directory))
         (filtered-list (org-journal-timeline--take-n-elements
                         org-journal-timeline-days (org-journal-timeline--sort-file-list file-list))))
    (org-journal-timeline--create-journal-timeline-buffer filtered-list)))

(provide 'org-journal-timeline)

;;; org-journal-timelie.el ends here

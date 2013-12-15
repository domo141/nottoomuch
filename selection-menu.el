;;; selection-menu.el --- "generic" menu to choose one string.
;;;
;;; Author: Tomi Ollila -- too ät iki piste fi

;;; License: GPLv2+

;; read-key is available in emacs 23.2 & newer...
(if (fboundp 'read-key)
    (defalias 'selection-menu--read-key 'read-key)
  (defalias 'selection-menu--read-key
    (lambda (msg) (aref (read-key-sequence-vector msg) 0))))

;; popup.el or company.el could give insight how to "improve"
;; key reading (and get mouse events into picture, too)
;; (or maybe mouse events could already be read but how to handle...)

(defun selection-menu-current-option ()
  (get-text-property (point) 'selection-menu-option))

(defun selection-menu-current-start ()
  (get-text-property (point) 'selection-menu-option-start))

(defun selection-menu-current-end ()
  (get-text-property (point) 'selection-menu-option-end))

(defun selection-menu-adjust ()
  (let ((start (selection-menu-current-start)))
    (when start
      (goto-char start))))

(defun selection-menu-up ()
  (goto-char (selection-menu-current-start))
  (unless (bobp)
    (forward-line -1)
    (selection-menu-adjust)))

(defun selection-menu-down ()
  (let ((current-point (point)))
    (goto-char (selection-menu-current-end))
    (unless (selection-menu-adjust)
      (goto-char current-point))))

(defun selection-menu--select (ident &optional unread key-short-cut-list)
  (let ((helpmsg "Type ESC to abort, Space or Enter to select.")
	(buffer-read-only t)
	first last overlay pevent select)
    (forward-line -1)
    (setq last (point))
    (goto-char (point-min))
    (setq first (point))
    (save-window-excursion
      (pop-to-buffer (current-buffer))
      (setq mode-name "Selection Menu"
	    mode-line-buffer-identification (concat "*" ident "*"))
      (setq overlay (make-overlay (selection-menu-current-start) (selection-menu-current-end)))
      (overlay-put overlay 'face 'highlight)
      (while
	  (let ((event (selection-menu--read-key helpmsg)))
	    (cond ((or (eq event 'up) (eq event 16))
		     (selection-menu-up)
		     (move-overlay overlay (selection-menu-current-start) (selection-menu-current-end))
		   t)
		  ((or (eq event 'down) (eq event 14))
		     (selection-menu-down)
		     (move-overlay overlay (selection-menu-current-start) (selection-menu-current-end))
		   t)
		  ((or (eq event 32) (eq event 13) (eq event 'return))
		   (setq select
			 (selection-menu-current-option))
		   nil)
		  ((setq select (plist-get key-short-cut-list event))
		   nil)
		  ((eq event 'escape)
		   nil)
		  (t (setq pevent event)
		     nil)
		  ))))
    (if (and unread pevent)
	(push pevent unread-command-events))
    (message nil)
    select))

(defun selection-menu (ident items &optional unread)
  "Pops up a buffer listing lines given ITEMS one per line.
Use arrow keys (or C-p/C-n) to select and SPC/RET to select.
Return to parent buffer when any other key is pressed.
In this case if optional UNREAD is non-nil return the
read key back to input queue for parent to consume."
  (if (eq (length items) 0) nil
    (save-excursion
      (with-temp-buffer
	(let (key-short-cut-list)
	  (dolist (item items)
	    (let ((option (if (listp item) (nth 0 item) item))
		  (description (if (listp item) (nth 1 item) (concat " " item)))
		  (key-short-cuts (if (listp item) (nth 2 item)))
		  (start (point-marker))
		  end)
	      (insert description "\n")
	      (setq end (point-marker))
	      (dolist (key key-short-cuts)
		(setq key-short-cut-list (plist-put key-short-cut-list key option)))
	      (put-text-property start end 'selection-menu-option option)
	      (put-text-property start end 'selection-menu-option-start start)
	      (put-text-property start end 'selection-menu-option-end end)))
	  (selection-menu--select ident unread key-short-cut-list))))))

;;(selection-menu "foo" (list))
;;(selection-menu "foo" (list "a"))
;;(selection-menu "Send mail to:" (list "a" "b" "c" "d" "faaarao") t)
;; test by entering c-x c-e at the end of previous lines

(provide 'selection-menu)

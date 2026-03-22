;;; pacifism.el --- Delete without kill ring pollution -*- lexical-binding: t -*-

(defun pacifism--delete-word (arg)
  "Delete word forward without polluting the kill ring."
  (interactive "p")
  (delete-region (point) (progn (forward-word arg) (point))))

(defun pacifism--backward-delete-word (arg)
  "Delete word backward without polluting the kill ring."
  (interactive "p")
  (delete-region (point) (progn (backward-word arg) (point))))

(defun pacifism--delete-line (&optional arg)
  "Delete to end of line without polluting the kill ring.
With ARG, delete that many lines forward."
  (interactive "P")
  (if arg
      (delete-region (point) (progn (forward-line (prefix-numeric-value arg)) (point)))
    (if (eolp)
        (delete-char 1)
      (delete-region (point) (line-end-position)))))

(defun pacifism--delete-whole-line ()
  "Delete entire line without polluting the kill ring."
  (interactive)
  (delete-region (line-beginning-position)
                 (min (point-max) (1+ (line-end-position)))))

(defun pacifism--delete-sentence ()
  "Delete forward sentence without polluting the kill ring."
  (interactive)
  (delete-region (point) (save-excursion (forward-sentence) (point))))

(defun pacifism--backward-delete-sentence ()
  "Delete backward sentence without polluting the kill ring."
  (interactive)
  (delete-region (point) (save-excursion (backward-sentence) (point))))

(global-set-key (kbd "M-d")             #'pacifism--delete-word)
(global-set-key (kbd "C-<delete>")      #'pacifism--delete-word)
(global-set-key (kbd "M-<backspace>")   #'pacifism--backward-delete-word)
(global-set-key (kbd "C-<backspace>")   #'pacifism--backward-delete-word)
(global-set-key (kbd "C-k")             #'pacifism--delete-line)
(global-set-key (kbd "C-S-<backspace>") #'pacifism--delete-whole-line)
(global-set-key (kbd "M-k")             #'pacifism--delete-sentence)
(global-set-key (kbd "C-x DEL")         #'pacifism--backward-delete-sentence)

(define-prefix-command 'pacifism--kill-map)
(global-set-key (kbd "C-c k") #'pacifism--kill-map)

(define-key pacifism--kill-map (kbd "k")   #'kill-line)
(define-key pacifism--kill-map (kbd "K")   #'kill-whole-line)
(define-key pacifism--kill-map (kbd "d")   #'kill-word)
(define-key pacifism--kill-map (kbd "DEL") #'backward-kill-word)
(define-key pacifism--kill-map (kbd "s")   #'kill-sentence)
(define-key pacifism--kill-map (kbd "S")   #'backward-kill-sentence)

(provide 'pacifism)

;;; pacifism.el ends here

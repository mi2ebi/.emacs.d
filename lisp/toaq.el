;;; toaq.el --- Toaq input method for Emacs -*- lexical-binding: t -*-

(require 'quail)
(require 'ucs-normalize)

(quail-define-package
 "toaq"
 "UTF-8"
 "Ꝡ"
 nil
 "An input method for Toaq.
w -> ꝡ        i -> ı             x -> ’            []{} -> «»‹›
' -> acute    ; -> circumflex    \" -> diaeresis    v -> underdot
: -> hook     = -> macron        + -> grave
^ -> hacek    ~ -> tilde         \\ -> escape
` -> undo diacritic")

(defun toaq--vowel-p (ch)
  "Return t if CH is a Toaq vowel."
  (and ch (string-match-p "[aeiıouyAEIOUY]"
                          (string (aref (ucs-normalize-NFD-string (string ch)) 0)))))
(defun toaq--final-p (ch)
  "Return t if CH is a Toaq final (m or q)."
  (and ch (string-match-p "[mqMQ]" (string ch))))
(defun toaq--combining-p (ch)
  "Return t if CH is in the unicode block Combining Diacritical Marks (a superset of Toaq tones)."
  (and ch (>= ch #x0300) (<= ch #x036f)))

(defun toaq--char-extent (pos)
  "Return (START . END) of the character at POS including combining characters after it."
  (let ((end (1+ pos)))
    (save-excursion
      (goto-char end)
      (while (toaq--combining-p (char-after))
        (forward-char)
        (setq end (point))))
    (cons pos end)))

(defun toaq--find-nucleus ()
  "Scan backwards from point to find the (START . END) of a Toaq raku nucleus."
  (save-excursion
    (while (toaq--final-p (char-before))
      (backward-char))
    (while (toaq--combining-p (char-before))
      (backward-char))
    (when (toaq--vowel-p (char-before))
      (let ((end (point)))
        (while (let ((ch (char-before)))
                 (or (toaq--vowel-p ch) (toaq--combining-p ch)))
          (backward-char))
        (cons (point) end)))))

(defvar-local toaq--escape-next nil
  "When non-nil, the next key will insert literally instead of applying its normal behavior.")

(defun toaq-escape ()
  "Set the escape flag so the next keypress will be literal."
  (interactive)
  (if toaq--escape-next
      (progn
        (setq toaq--escape-next nil)
        (insert "\\"))
    (setq toaq--escape-next t)
    (message "toaq: literal next")))

(defun toaq--clear-escape-on-unbound ()
  "Clear escape flag if a non-Toaq key is pressed."
  (when (and toaq--escape-next
             (not (lookup-key toaq-keymap (this-command-keys))))
    (setq toaq--escape-next nil)))

(defun toaq--apply-diacritic (combining-char fallback)
  "Apply COMBINING-CHAR to the first vowel of the raku.
If no vowel is found, insert FALLBACK instead."
  (if toaq--escape-next
      (progn
        (setq toaq--escape-next nil)
        (insert fallback))
    (let ((nucleus (toaq--find-nucleus)))
      (if nucleus
          (let ((target-pos (car nucleus))
                (original-pos (point)))
            (let* ((extent (toaq--char-extent target-pos))
                   (base-str (ucs-normalize-NFD-string
                              (buffer-substring (car extent) (cdr extent))))
                   (base-char (aref base-str 0))
                   (actual-base (if (and (= base-char ?ı)
                                         (not (and (= combining-char ?\x0323)
                                                   (string-empty-p (substring base-str 1)))))
                                    ?i base-char))
                   (deleted-len (- (cdr extent) (car extent)))
                   (new-str (ucs-normalize-NFC-string
                             (concat (string actual-base) (substring base-str 1) (string combining-char))))
                   (delta (- (length new-str) deleted-len)))
              (delete-region (car extent) (cdr extent))
              (goto-char (car extent))
              (insert new-str)
              (goto-char (if (<= target-pos original-pos)
                             (+ original-pos delta)
                           original-pos))))
        (insert fallback)))))

(defun toaq--make-inserter (literal substitution)
  "Return a command that inserts SUBSTITUTION, or LITERAL if escaped."
  (lambda ()
    (interactive)
    (if toaq--escape-next
        (progn (setq toaq--escape-next nil) (insert literal))
      (insert substitution))))

(defun toaq-acute ()
  (interactive)
  (toaq--apply-diacritic ?\x0301 "'"))
(defun toaq-diaeresis ()
  (interactive)
  (toaq--apply-diacritic ?\x0308 "\""))
(defun toaq-circumflex ()
  (interactive)
  (toaq--apply-diacritic ?\x0302 ";"))
(defun toaq-hook ()
  (interactive)
  (toaq--apply-diacritic ?\x0309 ":"))
(defun toaq-dotbelow ()
  (interactive)
  (toaq--apply-diacritic ?\x0323 "v"))
(defun toaq-grave ()
  (interactive)
  (toaq--apply-diacritic ?\x0300 "+"))
(defun toaq-macron ()
  (interactive)
  (toaq--apply-diacritic ?\x0304 "="))
(defun toaq-hacek ()
  (interactive)
  (toaq--apply-diacritic ?\x030c "^"))
(defun toaq-tilde ()
  (interactive)
  (toaq--apply-diacritic ?\x0303 "~"))

(defun toaq-undo-diacritic ()
  "Remove all diacritics from the current raku nucleus.
If the escape flag is set, insert a literal backtick instead."
  (interactive)
  (if toaq--escape-next
      (progn (setq toaq--escape-next nil) (insert "`"))
    (let ((nucleus (toaq--find-nucleus)))
      (if nucleus
          (let* ((start (car nucleus))
                 (extent (toaq--char-extent start))
                 (cluster-nfd (ucs-normalize-NFD-string
                               (buffer-substring (car extent) (cdr extent))))
                 (new-str (ucs-normalize-NFC-string
                           (string (let ((base (aref cluster-nfd 0)))
                                     (if (= base ?i) ?ı base)))))
                 (delta (- (length new-str) (- (cdr extent) (car extent))))
                 (orig-pos (point)))
            (delete-region (car extent) (cdr extent))
            (goto-char (car extent))
            (insert new-str)
            (goto-char (if (<= (car extent) orig-pos)
                           (+ orig-pos delta)
                         orig-pos)))
        (message "toaq: nothing to undo")))))

(defun toaq--backward-delete-cluster ()
  "Delete the active region, or the grapheme cluster before point."
  (interactive)
  (if (use-region-p)
      (delete-region (region-beginning) (region-end))
    (let ((end (point)))
      (save-excursion
        (while (toaq--combining-p (char-before))
          (backward-char))
        (if (toaq--vowel-p (char-before))
            (progn (backward-char)
                   (delete-region (point) end))
          (delete-char -1))))))

(defvar toaq-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "DEL") #'toaq--backward-delete-cluster)
    (define-key map (kbd "`")  #'toaq-undo-diacritic)
    (define-key map (kbd "\\") #'toaq-escape)
    (define-key map (kbd "'")  #'toaq-acute)
    (define-key map (kbd "\"") #'toaq-diaeresis)
    (define-key map (kbd ";")  #'toaq-circumflex)
    (define-key map (kbd ":")  #'toaq-hook)
    (define-key map (kbd "v")  #'toaq-dotbelow)
    (define-key map (kbd "+")  #'toaq-grave)
    (define-key map (kbd "=")  #'toaq-macron)
    (define-key map (kbd "^")  #'toaq-hacek)
    (define-key map (kbd "~")  #'toaq-tilde)
    (define-key map (kbd "w") (toaq--make-inserter "w" "ꝡ"))
    (define-key map (kbd "W") (toaq--make-inserter "W" "Ꝡ"))
    (define-key map (kbd "i") (toaq--make-inserter "i" "ı"))
    (define-key map (kbd "x") (toaq--make-inserter "x" "’"))
    (define-key map (kbd "[") (toaq--make-inserter "[" "«"))
    (define-key map (kbd "]") (toaq--make-inserter "]" "»"))
    (define-key map (kbd "{") (toaq--make-inserter "{" "‹"))
    (define-key map (kbd "}") (toaq--make-inserter "}" "›"))
    map))

(defun toaq-activate ()
  (when (string= current-input-method "toaq")
    (set-keymap-parent toaq-keymap (current-local-map))
    (use-local-map toaq-keymap)
    (add-hook 'pre-command-hook #'toaq--clear-escape-on-unbound nil t)))
(defun toaq-deactivate ()
  (when (string= current-input-method "toaq")
    (setq toaq--escape-next nil)
    (remove-hook 'pre-command-hook #'toaq--clear-escape-on-unbound t)
    (when (eq (current-local-map) toaq-keymap)
      (use-local-map (keymap-parent toaq-keymap)))))

(with-eval-after-load 'quail
  (add-hook 'input-method-activate-hook #'toaq-activate)
  (add-hook 'input-method-deactivate-hook #'toaq-deactivate))

(provide 'toaq)

;;; toaq.el ends here

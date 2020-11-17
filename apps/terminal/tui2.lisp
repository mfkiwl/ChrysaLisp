;imports
(import "lib/pipe/pipe.inc")

;override print for TUI output
(defun print (_)
  (each (lambda (c)
    (setq c (code c))
    (if (= c 13) (setq c 10))
    (cond
      ((= c 9)
        ;print tab
        (pii-write-char 1 (ascii-code " "))
        (pii-write-char 1 (ascii-code " "))
        (pii-write-char 1 (ascii-code " "))
        (pii-write-char 1 (ascii-code " ")))
      (t  ;print char
        (pii-write-char 1 c)))) _))

; Uncomment to enable commands segregated after testing
; (import "apps/terminal/icmds.lisp")

(defun fn (ic &optional args) (print (cat ic " " args (ascii-char 0x0a))))

(defq
  ; Internal command dictionary
  internals (xmap-kv "ls" fn "cd" fn "set" fn)
  settings  (emap-kv :prompt ">"))

(defun prompt ()
  (gets settings :prompt))

(defun process-input (bfr)
  ; (process-input buffer) -> prompt
  ; Either process internal commands or pass
  ; to pipe to execute external commands
  (defq
    sp (split bfr " ")
    ic (first sp)
    in (gets internals ic))
  (cond
    (in
      ; Found internal command, execute and return
      (in ic (if (> (length sp) 1) (join (rest sp) " ") ""))
      (print (prompt)))
    (t
      ; New command pipe
      (catch (setq cmd (pipe-open bfr)) (progn (setq cmd nil) t))
      (unless cmd
        (print (cat
                 "Command '"
                 bfr
                 "' Error!"
                 (ascii-char 10)
                 (prompt)))))))

(defun terminal-input (c)
  ; (terminal-input character)
  (cond
    ;send line ?
    ((or (= c 10) (= c 13))
      ;what state ?
      (cond
        (cmd
          ;feed active pipe
          (pipe-write cmd (cat buffer (ascii-char 10))))
        (t  ; otherwise
          (cond
            ((/= (length buffer) 0)
              ; Process input buffer content
              (process-input buffer))
            (t (print (prompt))))))
      (setq buffer ""))
    ((= c 27)
      ;esc
      (when cmd
        ;feed active pipe, then EOF
        (when (/= (length buffer) 0)
          (pipe-write cmd buffer))
        (pipe-close cmd)
        (setq cmd nil buffer "")
        (print (cat (ascii-char 10) (prompt)))))
    ((and (= c 8) (/= (length buffer) 0))
      ;backspace
      (setq buffer (slice 0 -2 buffer)))
    ((<= 32 c 127)
      ;buffer the char
      (setq buffer (cat buffer (char c))))))

(defun main ()
  ;sign on msg
  (print (cat (const (cat "ChrysaLisp Terminal-2 0.1 - experimental" (ascii-char 10))) (prompt)))
  ;create child and send args
  (mail-send (list (task-mailbox)) (open-child "apps/terminal/tui_child.lisp" kn_call_open))
  (defq cmd nil buffer "")
  (while t
    (defq data t)
    (if cmd (setq data (pipe-read cmd)))
    (cond
      ((eql data t)
        ;normal mailbox event
        (terminal-input (get-byte (mail-read (task-mailbox)) 0)))
      ((eql data nil)
        ;pipe is closed
        (pipe-close cmd)
        (setq cmd nil)
        (print (const (cat (ascii-char 10) ">"))))
      (t  ;string from pipe
        (print data)))))
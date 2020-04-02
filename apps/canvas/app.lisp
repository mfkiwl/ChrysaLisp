;imports
(import 'sys/lisp.inc)
(import 'class/lisp.inc)
(import 'gui/lisp.inc)

(structure 'event 0
	(byte 'win_close))

(defq canvas_width 600 canvas_height 600 canvas_scale 1 id t)

(ui-tree window (create-window) nil
	(ui-element _ (create-flow) ('flow_flags (logior flow_flag_down flow_flag_fillw flow_flag_lasth))
		(ui-element _ (create-flow) ('flow_flags (logior flow_flag_left flow_flag_fillh flow_flag_lastw)
				'font (create-font "fonts/Entypo.ctf" 22) 'color title_col)
			(ui-buttons (0xea19) (const event_win_close))
			(ui-element _ (create-title) ('text "Canvas" 'font (create-font "fonts/OpenSans-Regular.ctf" 18))))
		(ui-element canvas (create-canvas canvas_width canvas_height canvas_scale))))

(defun-bind main ()
	(canvas-set-flags (canvas-fill canvas 0) 1)
	(gui-add (apply view-change (cat (list window 512 256) (view-pref-size window))))
	;create child and send args
	(mail-send (list canvas (* canvas_width 1.0) (* canvas_height 1.0) (* canvas_scale 1.0))
		(defq mbox (open-child "apps/canvas/child.lisp" kn_call_open)))
	(while id
		(cond
			((= (setq id (get-long (defq msg (mail-read (task-mailbox))) ev_msg_target_id)) event_win_close)
				(setq id nil))
			(t (view-event window msg))))
	;close child and window
	(mail-send "" mbox)
	(view-hide window))

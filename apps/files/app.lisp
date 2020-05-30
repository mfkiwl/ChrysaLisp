;imports
(import 'sys/lisp.inc)
(import 'class/lisp.inc)
(import 'gui/lisp.inc)

(structure 'event 0
	(byte 'close)
	(byte 'file_button 'tree_button)
	(byte 'filter_action))

(defun-bind tree (dir)
	(defq dirs (list) files (list))
	(each! 0 -1 (lambda (f d)
		(unless (or (starts-with "." f) (starts-with "obj" f))
			(cond
				((eql "4" d)
					(push dirs (cat dir "/" f)))
				(t	(push files (cat dir "/" f))))))
		(unzip (split (pii-dirlist dir) ",") (list (list) (list))))
	(each (lambda (d)
		(setq files (cat files (tree d)))) dirs)
	files)

(defun-bind populate-files (files dir exts)
	;filter files and dirs to only those that match and are unique
	(if (= (length (defq exts (map trim (split exts ",")))) 0) (setq exts '("")))
	(defq dirs_with_exts (list) files_within_dir (list))
	(each (lambda (_)
			(defq i (inc (find-rev "/" _)) d (slice 0 i _) f (slice i -1 _))
			(if (notany (lambda (_) (eql d _)) dirs_with_exts)
				(push dirs_with_exts d))
			(if (eql dir d)
				(push files_within_dir _)))
		(filter (lambda (f) (some (lambda (ext) (ends-with ext f)) exts)) files))
	(setq dirs_with_exts (sort cmp dirs_with_exts))
	;populate tree and files flows
	(def tree_scroll 'min_width 0 'min_height 0)
	(def files_scroll 'min_width 0 'min_height 0)
	(each view-sub tree_buttons)
	(each view-sub file_buttons)
	(clear tree_buttons file_buttons)
	(each (lambda (_)
		(def (defq b (create-button)) 'text _ 'border 1)
		(if (eql _ dir) (def b 'color argb_grey14))
		(view-add-child tree_flow (component-connect b event_tree_button))
		(push tree_buttons b)) dirs_with_exts)
	(each (lambda (_)
		(def (defq b (create-button)) 'text _ 'border 1)
		(view-add-child files_flow (component-connect b event_file_button))
		(push file_buttons b)) files_within_dir)
	;layout and size window
	(bind '(_ ch) (view-get-size tree_scroll))
	(bind '(w h) (view-pref-size tree_flow))
	(view-set-size tree_flow w h)
	(view-layout tree_flow)
	(def tree_scroll 'min_width w 'min_height (max ch 256))
	(bind '(w h) (view-pref-size files_flow))
	(view-set-size files_flow w h)
	(view-layout files_flow)
	(def files_scroll 'min_width w 'min_height (max ch 256)))

(ui-window window nil
	(ui-flow _ (flow_flags flow_down_fill)
		(ui-title-bar _ "Files" (0xea19) (const event_close))
		(ui-flow _ (flow_flags flow_right_fill)
			(ui-label _ (text "Filter:"))
			(component-connect (ui-textfield ext_filter (text "")) event_filter_action))
		(ui-flow _ (flow_flags flow_right_fill font *env_terminal_font* color argb_white)
			(ui-flow _ (flow_flags flow_down_fill)
				(ui-label _ (text "Folders" font *env_window_font*))
				(ui-scroll tree_scroll scroll_flag_vertical nil
					(ui-flow tree_flow (flow_flags (logior flow_flag_down flow_flag_fillw) color argb_white))))
			(ui-flow _ (flow_flags flow_down_fill)
				(ui-label _ (text "Files" font *env_window_font*))
				(ui-scroll files_scroll scroll_flag_vertical nil
					(ui-flow files_flow (flow_flags (logior flow_flag_down flow_flag_fillw) color argb_white)))))))

(defun-bind main ()
	(defq all_files (sort cmp (tree ".")) tree_buttons (list) file_buttons (list) current_dir "./")
	(populate-files all_files current_dir (get ext_filter 'text))
	(gui-add (apply view-change (cat (list window 256 64) (view-pref-size window))))
	(while (cond
		((= (defq id (get-long (defq msg (mail-read (task-mailbox))) ev_msg_target_id)) (const event_close))
			nil)
		((= id (const event_tree_button))
			(setq current_dir (get (view-find-id window (get-long msg ev_msg_action_source_id)) 'text))
			(populate-files all_files current_dir (get ext_filter 'text))
			(bind '(x y) (view-get-pos window))
			(bind '(w h) (view-pref-size window))
			(view-change-dirty window x y w h))
		((= id (const event_filter_action))
			(populate-files all_files current_dir (get ext_filter 'text))
			(bind '(x y) (view-get-pos window))
			(bind '(w h) (view-pref-size window))
			(view-change-dirty window x y w h))
		(t (view-event window msg))))
	(view-hide window))
